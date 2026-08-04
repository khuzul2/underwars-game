## GreyboxBoot — the `scenes/Main.tscn` root script. GDD §10 ("Greybox first ... Rock rendered as
## chunked MultiMeshInstance3D ... Target: Medium map at 60 fps on mid-range hardware; SDFGI
## off"), §9.1 (the orbiting tactical camera the scene points at the map), §4.1 (map sizes; the
## Medium map the 60-fps criterion names), §11.1 (data -> Sim Core (engine-free) -> EventBus ->
## Renderer/UI — the sim never calls the renderer, and THIS FILE READS the sim and mutates
## nothing), §11.2 (`scenes/  # Main.tscn, minimal base scenes`), §11.3, §13.4, §14 M1 ("60 fps
## on Medium map greybox").
##
## Boots the greybox scene: loads every content file the render pipeline needs
## (`data/render/greybox.json`, `data/mapgen/concentric_bowl.json`,
## `data/render/terrain_palette.json`, `data/render/camera.json`), generates the named map with a
## SEEDED [Rng], builds the chunked MultiMesh renderer exactly once, frames the [CameraRig] on the
## map (hex (0,0) is the world origin — HexLayout's (W)), then auto-orbits and samples
## `Engine.get_frames_per_second()` during an unattended windowed run (resolution (AO)), printing
## a warm-up-excluded fps sample block before quitting by itself. On any content load failure it
## prints every [RulesError] and draws nothing — a failed boot must be loud, never a silent black
## screen (the MapRenderer (AB) totality spirit).
##
## §13.4 SCOPE: this file READS `MapGenerator`/`HexMap`/`Rng` but constructs no Command, mutates
## no map (`set_elevation(`/`set_terrain_type(` are forbidden tokens here too) and subscribes to
## no EventBus — that seam belongs to M2's dig, which is exactly what MapRenderer's
## `mark_hex_dirty`/`flush_dirty` already exist for.
##
## THE 60-FPS CRITERION ITSELF IS NOT PROVEN BY ANY TEST — it is a manual windowed measurement
## recorded in docs/decisions.md at M1-T8 (decisions.md M1-T6 (Z): the headless dummy renderer has
## no renderer to measure, so this file is exercised only by structural pins on its exported
## defaults and a source scan).
class_name GreyboxBoot
extends Node3D

## §14 M1/§4.1 — the map size id the 60-fps criterion names ("medium" => radius 32 => 3,169
## hexes, §4.1 line 174); §4.1's radii/hex-counts stay content in
## `data/mapgen/concentric_bowl.json`, never literals here.
@export var size_id: String = "medium"

## §11.1 — the single seed handed to the one sanctioned [Rng], so the measured map is
## reproducible frame for frame.
@export var map_seed: int = 1

## (AO) — frames excluded from the fps sample so start-up cannot poison it. CALIBRATED, not guessed
## (M1-T8 Verify probe): `Engine.get_frames_per_second()` is a ONE-SECOND WINDOW average, so its
## first two windows are always start-up transients — it reports the engine's initial sentinel `1`
## until its first tick, then the window containing `_ready`'s generate+build (21 fps when measured),
## and only then the steady rate. A warm-up shorter than those two windows poisons `fps_min` with a
## start-up artifact rather than a real dip, so this budget is sized in FRAMES to outlast ~2 s even
## at an uncapped rate (613 fps measured with `--disable-vsync`), which is ~10 s at a 144 Hz vsync.
@export var warmup_frames: int = 1500

## (AO) — the run quits itself after this many frames, making the windowed measurement unattended
## and repeatable. Must exceed [member warmup_frames] by enough frames to be a sample rather than a
## spot reading (1,800 sampled frames ~= 12.5 s at a 144 Hz vsync).
@export var auto_quit_frames: int = 3300

@onready var _renderer: MapRenderer = $MapRenderer
@onready var _rig: CameraRig = $CameraRig

var _map: HexMap = null
var _booted: bool = false
var _frame: int = 0
var _fps_min: float = 0.0
var _fps_max: float = 0.0
var _fps_sum: float = 0.0
var _fps_samples: int = 0


## §10/§11.1 — loads every content file, generates the named map with a seeded [Rng], builds the
## renderer exactly once and frames the camera at the world origin. On any failure, prints every
## [RulesError] and draws nothing.
func _ready() -> void:
	var layout: HexLayout = HexLayout.new()
	var generator: MapGenerator = MapGenerator.new()
	var layout_ok: bool = layout.load_params_file("res://data/render/greybox.json")
	var generator_ok: bool = generator.load_params_file("res://data/mapgen/concentric_bowl.json")
	var palette_ok: bool = _renderer.load_palette_file("res://data/render/terrain_palette.json")
	var camera_ok: bool = _rig.load_params_file("res://data/render/camera.json")

	if not (layout_ok and generator_ok and palette_ok and camera_ok):
		_print_errors(layout.errors)
		_print_errors(generator.errors)
		_print_errors(_renderer.errors)
		_print_errors(_rig.errors)
		return

	var radius: int = generator.radius_for_size(size_id)
	_map = generator.generate(radius, Rng.new(map_seed))
	_renderer.set_layout(layout)
	_renderer.build(_map)
	_rig.set_focus(Vector3.ZERO)
	_booted = true


## §9.1/§14 M1 — auto-orbits the camera at [method CameraRig.orbit_speed_dps] and samples the
## frame rate outside the warm-up window, printing the sample block and quitting once
## [member auto_quit_frames] elapses.
func _process(delta: float) -> void:
	if not _booted:
		return
	_frame += 1
	_rig.orbit(_rig.orbit_speed_dps() * delta)

	if _frame > warmup_frames:
		var fps: float = Engine.get_frames_per_second()
		if _fps_samples == 0:
			_fps_min = fps
			_fps_max = fps
		else:
			_fps_min = minf(_fps_min, fps)
			_fps_max = maxf(_fps_max, fps)
		_fps_sum += fps
		_fps_samples += 1

	if _frame >= auto_quit_frames:
		_print_sample_block()
		get_tree().quit()


# -------------------------------------------------------------------------------------------
# Internal
# -------------------------------------------------------------------------------------------

## Prints every [RulesError] from one failed load, in the loader's own reported order.
func _print_errors(source_errors: Array[RulesError]) -> void:
	for error: RulesError in source_errors:
		print(error.format_for("greybox_boot"))


## §14 M1 — prints the warm-up-excluded `hexes=… chunks=… fps_min=… fps_avg=… fps_max=…` block
## the windowed measurement records in docs/decisions.md.
func _print_sample_block() -> void:
	var hex_count: int = 0
	if _map != null:
		hex_count = _map.hex_count()
	var chunk_count: int = _renderer.chunk_keys().size()
	var fps_avg: float = 0.0
	if _fps_samples > 0:
		fps_avg = _fps_sum / float(_fps_samples)
	print(
		"hexes=%d chunks=%d fps_min=%.2f fps_avg=%.2f fps_max=%.2f" % [
			hex_count, chunk_count, _fps_min, fps_avg, _fps_max
		]
	)
