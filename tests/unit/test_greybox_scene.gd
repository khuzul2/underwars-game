## scenes/Main.tscn + scripts/render/greybox_boot.gd — GDD §10 ("Greybox first ... Target: Medium map
## at 60 fps on mid-range hardware; SDFGI off"), §9.1 (the orbiting tactical camera the scene points
## at the map), §4.1 (the Medium map the 60-fps criterion names), §11.1 (data -> Sim Core -> EventBus
## -> Renderer/UI; the sim never calls the renderer), §11.2 (`scenes/  # Main.tscn, minimal base
## scenes`), §11.3, §13.2 tier 1, §13.4, §13.6, §14 M1.
##
## WHAT THIS FILE PINS, transcribed VERBATIM from `docs/GAME_DESIGN.md`:
##   §10 line 680:  "Rock rendered as chunked MultiMeshInstance3D (per-instance custom data =
##                  type/tint); dirty-chunk rebuilds on dig. **Target: Medium map at 60 fps on
##                  mid-range hardware; SDFGI off.**"
##   §10 line 678:  "Greybox first. All MVP visuals are flat-shaded prisms and capsules with faction
##                  palette tints ... Readability > fidelity".
##   §10 line 679:  the Lit/Dark tint is a SHADER driven by the sim's Lit/Dark state — **M3**. This
##                  scene therefore carries NO shader, and the per-instance tints M1-T7 writes are
##                  WRITTEN BUT NOT DISPLAYED at M1. One uniform material colour is EXPECTED here and
##                  is not a bug to "fix".
##   §4.1 line 174: "Map sizes (hex radius): Small 24 (1,801 hexes), **Medium 32 (3,169)**, Large 40
##                  (4,921)." — the map the fps criterion names. The six literals stay FORBIDDEN in
##                  engine code (M1-T1 item 4); this file DERIVES 3,169 from `HexMath` and from
##                  `data/mapgen/concentric_bowl.json` instead of trusting either.
##   §9.1 line 666: "Orbiting tactical camera (rotate 360°, tilt 15–80°, zoom 8–60 m); edge-pan +
##                  WASD ..." — pinned in full by `tests/unit/test_camera_rig.gd`; here only the
##                  scene WIRING is pinned (a CameraRig carrying exactly one Camera3D).
##   §14 line 1097: M1 acceptance "Golden mapgen test (seed ⇒ terrain hash); **60 fps on Medium map
##                  greybox**; LOS property tests".
##
## `docs/decisions.md` was re-read END TO END this iteration: no logged override touches §4.1, §9.1
## or §10. Resolutions (AI)–(AM) are stated in `tests/unit/test_camera_rig.gd`; this file continues
## with the two that belong to the SCENE:
##   (AN) THE GREYBOX SCENE IS A FIXED FOUR-CHILD NODE3D. `scenes/Main.tscn` has a `GreyboxBoot`
##        (Node3D) root with EXACTLY the children `MapRenderer`, `CameraRig`, `WorldEnvironment` and
##        `DirectionalLight3D`. The `MapRenderer` node has **ZERO** children, because
##        `MapRenderer._clear_chunks()` frees ALL of its children on every build (decisions.md M1-T7
##        item 13(c)) — anything parked there would be destroyed by the first `build()`. The
##        `CameraRig` carries EXACTLY ONE child, a `Camera3D`. `sdfgi_enabled` is written EXPLICITLY
##        as `false` in the `.tscn` text (§10 line 680), on the precedent of `project.godot`'s
##        hand-written `[debug]` gate (M0-T4 item (c)): a future engine default flip must be a
##        visible diff, never a silent regression. A `DirectionalLight3D` is present because
##        `MapRenderer`'s shared `StandardMaterial3D` is a lit material — with no light the greybox
##        renders black, which would make a passing fps number meaningless.
##   (AO) THE MEASUREMENT RUN IS UNATTENDED AND REPEATABLE. `GreyboxBoot` exports `size_id`
##        (defaulting to the **medium** map §14 M1's criterion names), an integer `map_seed`, an
##        integer `warmup_frames` (excluded from the sample, so shader/mesh warm-up cannot flatter
##        the average) and an integer `auto_quit_frames` (> `warmup_frames`, so the windowed run ends
##        by itself). `project.godot` sets `run/main_scene` to this scene, so the measurement is
##        `godot --path . --resolution WxH` with no extra arguments.
##
## HEADLESS SCOPE — decisions.md M1-T6 **(Z)** IS BINDING: under `--headless` the dummy renderer
## stores NO MultiMesh instance data, so this file NEVER reads an instance transform or custom datum
## back. Readable headless, and therefore all that is asserted: node parenting / naming / order,
## `get_class()`, child counts, exported property values and RESOURCE properties — which is exactly
## what makes the SDFGI pin real. The scene is INSTANTIATED BUT NEVER ADDED TO THE TREE, so `_ready`
## never fires and no 3,169-hex map is generated inside the unit suite.
##
## THE 60-FPS CRITERION ITSELF IS NOT PINNED HERE AND CANNOT BE: it is a WINDOWED measurement (M1-T6
## (Z)), recorded in `docs/decisions.md` at this task. No test in this suite may ever be read as
## evidence that it passed.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): a statically-decidable `is` test parse-errors and silently
## un-collects the WHOLE file, so class kind is asserted via `get_class()` ONLY, and Variant values
## are inspected with `typeof` / assigned through a typed local before reaching a typed parameter.
##
## HARNESS TRAP (decisions.md M1-T5 item 9, standing rule): `tools/run_tests.sh` greps the WHOLE run
## output for five diagnostics. No failure message in this file may contain any of them — this file
## says "is MISSING".
extends GutTest

const SCENE_PATH: String = "res://scenes/Main.tscn"
const BOOT_PATH: String = "res://scripts/render/greybox_boot.gd"
const RIG_PATH: String = "res://scripts/render/camera_rig.gd"
const RENDERER_PATH: String = "res://scripts/render/map_renderer.gd"
const PROJECT_GODOT_PATH: String = "res://project.godot"
const MAPGEN_PATH: String = "res://data/mapgen/concentric_bowl.json"
const CAMERA_PATH: String = "res://data/render/camera.json"
const GREYBOX_PATH: String = "res://data/render/greybox.json"

## (AN) — the scene's child names, SORTED, so the assertion catches an EXTRA child as well as a
## missing one.
const CHILD_NAMES: Array[String] = [
	"CameraRig",
	"DirectionalLight3D",
	"MapRenderer",
	"WorldEnvironment",
]

## §14 M1 / §4.1 line 174 — the map the 60-fps acceptance criterion names. The radius is re-derived
## from `data/mapgen/concentric_bowl.json` and the hex count from `HexMath`, never trusted as a pair
## of literals.
const MEDIUM_SIZE_ID: String = "medium"
const MEDIUM_RADIUS: int = 32
const MEDIUM_HEX_COUNT: int = 3169

## (AO) — the exported knobs that make the windowed run unattended and repeatable.
const EXPORTED_INT_KNOBS: Array[String] = ["map_seed", "warmup_frames", "auto_quit_frames"]

## §10 line 680 — the property that must be written EXPLICITLY in the `.tscn` text.
const SDFGI_LINE: String = "sdfgi_enabled = false"

## The `project.godot` entry that makes `godot --path .` open this scene with no extra arguments.
const MAIN_SCENE_LINE: String = "run/main_scene=\"res://scenes/Main.tscn\""

# ---------------------------------------------------------------------------------------------
# Source-scan vocabularies for `greybox_boot.gd` — WRITTEN FRESH. This file is the ONE place in the
# project allowed to read the frame rate and to quit the process, so its scan differs from
# `test_map_renderer.gd`'s and `test_camera_rig.gd`'s by exactly those two allowances.
# ---------------------------------------------------------------------------------------------

## The two EXPLICIT allowances, stripped from the source BEFORE the forbidden scan runs, so
## `Engine.` and `get_tree` stay forbidden in every other form.
const ALLOWED_TOKENS: Array[String] = ["Engine.get_frames_per_second(", "get_tree()"]

## §11.1/§13.4 — non-determinism stays forbidden (M1-T5 (R)); wall-clock and OS access stay forbidden
## (the fps readout must come from the allowed engine counter, not from a clock); `queue_free(` stays
## forbidden project-wide for Nodes (M1-T7 item 11); the two sim MUTATORS and `EventBus` stay
## forbidden because the boot READS the sim and wires nothing — the EventBus seam belongs to M2's
## dig, which is what `mark_hex_dirty` / `flush_dirty` already exist for.
const FORBIDDEN_TOKENS: Array[String] = [
	"randi(",
	"randf(",
	"randomize(",
	"RandomNumberGenerator",
	"SceneTree",
	"get_tree",
	"Engine.",
	"Time.",
	"OS.",
	"queue_free(",
	"set_elevation(",
	"set_terrain_type(",
	"EventBus",
]

## The other direction: the boot must actually load every content file, generate the named map with a
## SEEDED Rng, build the renderer, read the frame counter and quit by itself.
const REQUIRED_TOKENS: Array[String] = [
	"extends Node3D",
	"HexLayout",
	"MapGenerator",
	"MapRenderer",
	"CameraRig",
	"Rng",
	"RulesError",
	"load_params_file(",
	"load_palette_file(",
	"radius_for_size(",
	"generate(",
	"set_layout(",
	"build(",
	"chunk_keys(",
	"hex_count(",
	"Engine.get_frames_per_second(",
	"get_tree()",
	"print(",
]

## §4.1 line 174 — radii and hex counts are content, never engine code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## Doc-comment sections accepted by the §11.3 scan for `greybox_boot.gd`.
const DOC_SECTIONS: Array[String] = ["§4.1", "§9.1", "§10", "§11.1", "§13.4", "§14"]


# =============================================================================================
# A. (AN) THE SCENE ITSELF — the project's FIRST scene
# =============================================================================================

## §11.2 — `scenes/  # Main.tscn, minimal base scenes` exists and loads as a [PackedScene].
func test_the_main_scene_exists_and_loads_as_a_packed_scene() -> void:
	assert_true(
		ResourceLoader.exists(SCENE_PATH),
		"§11.2/§14 M1: the greybox scene is MISSING at %s" % SCENE_PATH
	)
	var scene: PackedScene = _scene()
	assert_not_null(scene, "§11.2: %s must load as a PackedScene" % SCENE_PATH)
	if scene == null:
		return
	assert_true(scene.can_instantiate(), "§11.2: %s must be instantiable" % SCENE_PATH)


## (AN) — the root is a [Node3D] carrying EXACTLY the four greybox children, by name. An extra child
## fails too: this scene is the fps measurement's subject and must stay minimal.
func test_the_scene_root_is_a_node3d_with_exactly_the_four_greybox_children() -> void:
	var root: Node = _instantiated_root()
	if root == null:
		return
	assert_eq(root.get_class(), "Node3D", "(AN): the greybox root is a Node3D")
	assert_eq(_child_names(root), CHILD_NAMES, "(AN): the scene's children are exactly %s" % [
		str(CHILD_NAMES)
	])


## (AN)/M1-T7 item 13(c) — THE CARRY-OVER THAT BITES: `MapRenderer._clear_chunks()` frees ALL of its
## children on every `build()`, so the scene must park nothing under it.
func test_the_map_renderer_node_has_no_non_chunk_children() -> void:
	var renderer_node: Node = _child_named("MapRenderer")
	if renderer_node == null:
		return
	assert_eq(renderer_node.get_class(), "Node3D", "(AN): the MapRenderer node is a Node3D")
	assert_eq(
		renderer_node.get_child_count(),
		0,
		"M1-T7 item 13(c): MapRenderer._clear_chunks() frees ALL children, so the .tscn must give"
		+ " the MapRenderer node none — the camera, light and environment hang elsewhere"
	)
	assert_eq(
		_script_path(renderer_node),
		RENDERER_PATH,
		"(AN): the MapRenderer node carries %s" % RENDERER_PATH
	)


## (AN)/§9.1 — the CameraRig carries EXACTLY ONE child, the [Camera3D] it drives.
func test_the_camera_rig_carries_exactly_one_camera() -> void:
	var rig_node: Node = _child_named("CameraRig")
	if rig_node == null:
		return
	assert_eq(_script_path(rig_node), RIG_PATH, "(AN): the CameraRig node carries %s" % RIG_PATH)
	assert_eq(rig_node.get_child_count(), 1, "(AN): the rig drives exactly one camera")
	if rig_node.get_child_count() != 1:
		return
	var camera: Node = rig_node.get_child(0)
	assert_eq(camera.get_class(), "Camera3D", "§9.1/(AN): the rig's only child is a Camera3D")


## §10 line 680 ("SDFGI off") — pinned on the RESOURCE, which is readable headless even though
## nothing renders.
func test_sdfgi_is_off_on_the_scenes_environment() -> void:
	var world_env_node: Node = _child_named("WorldEnvironment")
	if world_env_node == null:
		return
	var world_env: WorldEnvironment = world_env_node as WorldEnvironment
	assert_not_null(world_env, "(AN): the WorldEnvironment node is a WorldEnvironment")
	if world_env == null:
		return
	var environment: Environment = world_env.environment
	assert_not_null(environment, "§10: the WorldEnvironment must carry an Environment resource")
	if environment == null:
		return
	assert_false(environment.sdfgi_enabled, "§10 line 680: SDFGI is OFF on the Medium-map greybox")


## §10 line 680 / M0-T4 item (c) — and it is written EXPLICITLY in the scene TEXT, so a future engine
## default flip is a visible diff rather than a silent regression of the fps target.
func test_the_scene_text_writes_sdfgi_enabled_explicitly() -> void:
	var text: String = _raw_text(SCENE_PATH)
	assert_false(text.is_empty(), "§11.2: %s must be readable (it may be MISSING)" % SCENE_PATH)
	assert_true(
		text.contains(SDFGI_LINE),
		(
			"§10 line 680: %s must write `%s` explicitly, on the precedent of project.godot's"
			+ " hand-written [debug] gate"
		) % [SCENE_PATH, SDFGI_LINE]
	)
	assert_true(
		text.contains("DirectionalLight3D"),
		(
			"(AN): %s must carry a light — MapRenderer's shared material is LIT, so an unlit"
			+ " greybox renders black and any fps number measured on it is meaningless"
		) % SCENE_PATH
	)
	for shader_token: String in [".gdshader", "ShaderMaterial"]:
		assert_false(
			text.contains(shader_token),
			"§10 line 679/§13.4: the Lit/Dark SHADER is M3 — %s must not carry %s yet" % [
				SCENE_PATH, shader_token
			]
		)


## §13.1/§14 M1 — `project.godot` points `run/main_scene` at a scene that EXISTS. A dangling path
## breaks `godot --import`, which every `tools/` script runs first, so this is a harness pin as much
## as a scene pin.
func test_project_godot_points_run_main_scene_at_the_existing_scene() -> void:
	var text: String = _raw_text(PROJECT_GODOT_PATH)
	assert_false(text.is_empty(), "sanity: project.godot must be readable")
	assert_true(
		text.contains(MAIN_SCENE_LINE),
		(
			"§14 M1: project.godot's [application] section must carry `%s` so the windowed"
			+ " measurement is `godot --path .` with no extra arguments"
		) % MAIN_SCENE_LINE
	)
	assert_true(
		FileAccess.file_exists(SCENE_PATH),
		"M0-T4 item (f): run/main_scene must not dangle — %s is MISSING" % SCENE_PATH
	)


# =============================================================================================
# B. (AO) THE BOOT DEFAULTS — the measurement's subject is the map §14 M1 names
# =============================================================================================

## §14 M1/§4.1 line 174 — the boot defaults to the MEDIUM map, and "medium" really is radius 32 /
## 3,169 hexes: the radius is read out of `data/mapgen/concentric_bowl.json` and the count re-derived
## by `HexMath`, so neither number is trusted as a literal.
func test_the_boot_defaults_to_the_medium_map_the_criterion_names() -> void:
	var root: Node = _instantiated_root()
	if root == null:
		return
	var raw_size: Variant = root.get("size_id")
	assert_eq(typeof(raw_size), TYPE_STRING, "(AO): GreyboxBoot exports a String `size_id`")
	var size_id: String = str(raw_size)
	assert_eq(size_id, MEDIUM_SIZE_ID, "§14 M1: the greybox boot defaults to the Medium map")

	var generator: MapGenerator = MapGenerator.new()
	assert_true(generator.load_params_file(MAPGEN_PATH), "sanity: %s must load" % MAPGEN_PATH)
	var radius: int = generator.radius_for_size(size_id)
	assert_eq(radius, MEDIUM_RADIUS, "§4.1 line 174: Medium is hex radius 32")
	assert_eq(
		HexMath.hex_count_for_radius(radius),
		MEDIUM_HEX_COUNT,
		"§4.1 line 174: Medium 32 is 3,169 hexes — the map the 60-fps criterion names"
	)


## (AO) — the seed and the two frame budgets are exported INTEGERS, and the run terminates by itself:
## a measurement nobody can repeat unattended is not a measurement.
func test_the_measurement_run_is_seeded_unattended_and_repeatable() -> void:
	var root: Node = _instantiated_root()
	if root == null:
		return
	for knob: String in EXPORTED_INT_KNOBS:
		var raw: Variant = root.get(knob)
		assert_eq(typeof(raw), TYPE_INT, "(AO): GreyboxBoot exports an int `%s`" % knob)

	var raw_warmup: Variant = root.get("warmup_frames")
	var raw_quit: Variant = root.get("auto_quit_frames")
	if typeof(raw_warmup) != TYPE_INT or typeof(raw_quit) != TYPE_INT:
		return
	var warmup: int = raw_warmup
	var quit_at: int = raw_quit
	assert_true(warmup > 0, "(AO): the sample excludes a non-empty warm-up window")
	assert_true(
		quit_at > warmup,
		"(AO): auto_quit_frames (%d) must leave frames to sample after warmup_frames (%d)" % [
			quit_at, warmup
		]
	)


## §11.1/(AO) — the boot READS the sim and mutates nothing: generating the map twice from the same
## exported seed yields the same `content_hash()`, so the measured scene is reproducible frame for
## frame. This re-derives the boot's own pipeline WITHOUT running `_ready()` (which would build 3,169
## hexes inside the unit suite).
func test_the_exported_seed_reproduces_the_same_map() -> void:
	var root: Node = _instantiated_root()
	if root == null:
		return
	var raw_seed: Variant = root.get("map_seed")
	var raw_size: Variant = root.get("size_id")
	if typeof(raw_seed) != TYPE_INT or typeof(raw_size) != TYPE_STRING:
		return
	var map_seed: int = raw_seed
	var size_id: String = str(raw_size)

	var generator: MapGenerator = MapGenerator.new()
	assert_true(generator.load_params_file(MAPGEN_PATH), "sanity: %s must load" % MAPGEN_PATH)
	var radius: int = generator.radius_for_size(size_id)
	var first: HexMap = generator.generate(radius, Rng.new(map_seed))
	var second: HexMap = generator.generate(radius, Rng.new(map_seed))
	assert_eq(
		first.content_hash(),
		second.content_hash(),
		"§11.1: the boot's (seed, size) pair reproduces one map exactly"
	)
	assert_eq(first.hex_count(), MEDIUM_HEX_COUNT, "§4.1 line 174: the measured map is 3,169 hexes")


## §13.6 — every content file the boot loads is present, so a failed boot can only ever be a code
## fault, never a MISSING file discovered in the windowed run.
func test_every_content_file_the_boot_loads_is_present() -> void:
	for path: String in [GREYBOX_PATH, MAPGEN_PATH, CAMERA_PATH, "res://data/render/terrain_palette.json"]:
		assert_true(FileAccess.file_exists(path), "§13.6: %s is MISSING" % path)


# =============================================================================================
# C. MECHANICAL SOURCE SCANS ON scripts/render/greybox_boot.gd — WRITTEN FRESH.
#    Comment stripping is LOAD-BEARING: the doc block cites "§4.1" and quotes "3,169", which naive
#    regexes would hit.
# =============================================================================================

## S1 §11.1/§13.4 — the two allowances (`Engine.get_frames_per_second(` and `get_tree()`) are
## stripped FIRST, so every other form of `Engine.` / `get_tree` / `SceneTree` stays forbidden, and
## so do non-determinism, the wall clock, `queue_free(`, the sim mutators and the EventBus.
func test_boot_source_holds_no_forbidden_token() -> void:
	var code: String = _allowance_stripped_code(BOOT_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty (it may be MISSING)" % [
		BOOT_PATH
	])
	for banned: String in FORBIDDEN_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/§13.4: %s must not contain %s (the only allowed forms are %s)" % [
				BOOT_PATH, banned, str(ALLOWED_TOKENS)
			]
		)


## S2 — the other direction: the boot really does load every content file, generate the named map
## with a SEEDED Rng, build the renderer, read the frame counter and quit by itself.
func test_boot_source_carries_every_required_token() -> void:
	var code: String = _code_text(BOOT_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty (it may be MISSING)" % [
		BOOT_PATH
	])
	for required: String in REQUIRED_TOKENS:
		assert_true(code.contains(required), "§10/§11.1: %s must contain %s" % [BOOT_PATH, required])


## S3 M1-T7 item 13(b) — `set_layout()` is effectively ONCE PER RENDERER: the shared prism mesh is
## sized on the first `build()` and is NOT resized by a later layout. The boot must call it exactly
## once.
func test_boot_source_calls_set_layout_exactly_once() -> void:
	var code: String = _code_text(BOOT_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty (it may be MISSING)" % [
		BOOT_PATH
	])
	assert_eq(
		code.count("set_layout("),
		1,
		(
			"M1-T7 item 13(b): the shared prism mesh is sized on the FIRST build, so %s must call"
			+ " set_layout() exactly once"
		) % BOOT_PATH
	)


## S4 §4.1 line 174 / §13.6 — the map radius and hex count are CONTENT: the boot names a size id and
## asks the generator, and prints counts it derived, never a literal.
func test_boot_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(BOOT_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty (it may be MISSING)" % [
		BOOT_PATH
	])
	var number: RegEx = RegEx.new()
	assert_eq(
		number.compile("\\b(24|32|40|1801|3169|4921)\\b"), OK, "sanity: the map-size pattern compiles"
	)
	var hit: RegExMatch = number.search(code)
	assert_null(hit, "§4.1/§13.6: map sizes are content — %s must not hard-code %s" % [
		BOOT_PATH, "" if hit == null else hit.get_string()
	])
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S5 §11.3 — every public function of the boot cites the GDD section it implements. The engine
## callbacks (`_ready`, `_process`, `_unhandled_input`) are private by name and are exempt.
func test_boot_public_functions_cite_their_gdd_section() -> void:
	assert_false(
		_raw_text(BOOT_PATH).is_empty(),
		"sanity: %s must be readable and non-empty (it may be MISSING) — without this guard the"
		% BOOT_PATH
		+ " scan below would pass VACUOUSLY on an absent file"
	)
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(BOOT_PATH, public_functions, undocumented)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §<section>' doc comment (%s); missing on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## The greybox scene, or null when it is MISSING. Guarded by `ResourceLoader.exists` so a MISSING
## scene fails an ASSERTION rather than emitting an engine diagnostic — `tools/run_tests.sh` refuses
## a run whose output carries one, and a refusal is not an honest red.
func _scene() -> PackedScene:
	if not ResourceLoader.exists(SCENE_PATH):
		return null
	var resource: Resource = load(SCENE_PATH)
	return resource as PackedScene


## The scene's ROOT node, instantiated and `autofree`d but NEVER added to the SceneTree, so `_ready`
## never fires and no 3,169-hex map is generated inside the unit suite. Null (with one assertion)
## when the scene is MISSING.
func _instantiated_root() -> Node:
	var scene: PackedScene = _scene()
	assert_not_null(scene, "§11.2/§14 M1: the greybox scene is MISSING at %s" % SCENE_PATH)
	if scene == null:
		return null
	var root: Node = scene.instantiate()
	autofree(root)
	return root


## A named child of the scene root, or null (with one assertion) when it is absent.
func _child_named(child_name: String) -> Node:
	var root: Node = _instantiated_root()
	if root == null:
		return null
	var child: Node = root.get_node_or_null(NodePath(child_name))
	assert_not_null(child, "(AN): %s must carry a child named %s" % [SCENE_PATH, child_name])
	return child


## Child node names, SORTED, so the comparison catches an extra child as well as a missing one.
func _child_names(root: Node) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(root.get_child_count()):
		var child_name: String = root.get_child(i).name
		out.append(child_name)
	out.sort()
	return out


## The `res://` path of the script attached to a node, or "" when it carries none.
func _script_path(node: Node) -> String:
	var attached: Variant = node.get_script()
	if attached == null:
		return ""
	var script: Script = attached as Script
	if script == null:
		return ""
	return script.resource_path


## Reads a file verbatim; the empty string when it is MISSING, so the assertion naming it belongs to
## the calling test rather than to this helper.
func _raw_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## Reads a source file with every comment stripped, so asserting on source content can never be
## tripped by a doc comment that quotes the very rule being enforced.
func _code_text(path: String) -> String:
	var code_lines: PackedStringArray = PackedStringArray()
	for raw_line: String in _raw_text(path).split("\n"):
		var comment_at: int = raw_line.find("#")
		code_lines.append(raw_line if comment_at == -1 else raw_line.substr(0, comment_at))
	return "\n".join(code_lines)


## Comment-stripped source with the two EXPLICIT allowances removed, so the forbidden scan sees every
## OTHER use of `Engine.` / `get_tree` / `SceneTree`.
func _allowance_stripped_code(path: String) -> String:
	var code: String = _code_text(path)
	for allowed: String in ALLOWED_TOKENS:
		code = code.replace(allowed, "")
	return code


## Walks a source file and fills `public_functions` with every public function name (in source order)
## and `undocumented` with those whose preceding comment block cites no DOC_SECTIONS entry.
func _collect_public_functions(
	path: String,
	public_functions: Array[String],
	undocumented: Array[String]
) -> void:
	var lines: PackedStringArray = _raw_text(path).split("\n")
	for i: int in range(lines.size()):
		var stripped: String = lines[i].strip_edges()
		if not (stripped.begins_with("func ") or stripped.begins_with("static func ")):
			continue
		var name_at: int = stripped.find("func ") + 5
		var paren_at: int = stripped.find("(", name_at)
		if paren_at == -1:
			continue
		var function_name: String = stripped.substr(name_at, paren_at - name_at)
		if function_name.begins_with("_"):
			continue
		public_functions.append(function_name)
		var doc_block: String = ""
		var j: int = i - 1
		while j >= 0 and lines[j].strip_edges().begins_with("#"):
			doc_block = lines[j] + "\n" + doc_block
			j -= 1
		var documented: bool = false
		for section: String in DOC_SECTIONS:
			if doc_block.contains(section):
				documented = true
		if not documented:
			undocumented.append(function_name)
