## CameraRig + data/render/camera.json — GDD §9.1 (the orbiting tactical camera), §10 (greybox art
## direction and the Medium-map 60 fps / SDFGI-off target), §4.1 (the map the target names), §11.1
## (data -> Sim Core -> EventBus -> Renderer/UI; the sim never calls the renderer), §11.2
## (`scripts/render/` — MapRenderer, UnitView, LightOverlay, **CameraRig**), §11.3, §13.2 tier 1,
## §13.4, §13.6, §14 M1 ("camera rig"; "60 fps on Medium map greybox").
##
## WHAT THIS FILE PINS, transcribed VERBATIM from `docs/GAME_DESIGN.md`:
##   §9.1 line 666: "Orbiting tactical camera (rotate 360°, tilt 15–80°, zoom 8–60 m); edge-pan +
##                  WASD; tap-select, drag-box multi-select (mobile-friendly hit targets)."
##                  — the ONLY printed numeric source for this task. Overlays, the north compass and
##                  the minimap are also §9.1 but belong to M8; tap-select / drag-box selection to
##                  M4/M8; hex picking to M1-T9 (§13.4: invent nothing ahead of its milestone).
##   §10 line 678:  "Greybox first. All MVP visuals are flat-shaded prisms and capsules with faction
##                  palette tints ... Readability > fidelity".
##   §10 line 679:  the Lit/Dark tint is a SHADER driven by the sim's Lit/Dark state — **M3**, not
##                  this task.
##   §10 line 680:  "Rock rendered as chunked MultiMeshInstance3D (per-instance custom data =
##                  type/tint); dirty-chunk rebuilds on dig. Target: Medium map at 60 fps on
##                  mid-range hardware; SDFGI off."
##   §4.1 line 173: "**Elevation:** integer 0–3 per hex."
##   §4.1 line 174: "Map sizes (hex radius): Small 24 (1,801 hexes), Medium 32 (3,169), Large 40
##                  (4,921)." — used here only to justify the sibling scene suite; the six literals
##                  stay FORBIDDEN in engine code (M1-T1 item 4).
##   §14 line 1097: M1 deliverables "... chunked MultiMesh renderer, **camera rig**, hex picking";
##                  acceptance "Golden mapgen test (seed ⇒ terrain hash); **60 fps on Medium map
##                  greybox**; LOS property tests".
##
## `docs/decisions.md` was re-read END TO END this iteration: it contains **no mention of §9.1 at
## all** and **no logged override touching §4.1 or §10**, so the printed text above governs
## unamended. The lettering ended at **(AH)** in the M1-T7 entry, so this file continues at **(AI)**:
##   (AI) CAMERA FRAME AND DERIVED TRANSFORM. World +Y up, ground = XZ (matching HexLayout's (W)),
##        hex (0,0) at the world origin. `yaw` rotates about +Y; yaw 0 puts the camera on the **+Z**
##        side of the focus looking toward −Z. With P = pitch and Y = yaw in radians,
##        `camera_transform().origin == focus + zoom * Vector3(cos(P)*sin(Y), sin(P), cos(P)*cos(Y))`
##        and the transform is oriented `looking_at(focus, Vector3.UP)` — so `basis.z` (Godot puts
##        −Z forward) is the unit vector from the focus toward the camera, there is no roll, and the
##        camera's distance to the focus is EXACTLY the zoom at every yaw/pitch.
##   (AJ) YAW WRAPS, PITCH AND ZOOM CLAMP — §9.1 says "rotate 360°" (unbounded) but "tilt 15–80°"
##        and "zoom 8–60 m" (bounded). So `yaw_deg()` is canonicalised into **[0.0, 360.0)** and is
##        NEVER clamped, while pitch and zoom clamp to the data limits **inclusively at both ends**.
##        A successful load frames the WIDEST LEGAL VIEW — yaw 0, pitch at its maximum (most
##        top-down), zoom at its maximum (furthest out), focus at the world origin — which is the
##        only initial state derivable from data alone. `360.0` may be a NAMED const in the `.gd`
##        (`DEGREES_PER_TURN`) on the SQRT_3 (M1-T6 (W)) / RADIAL_SEGMENTS (M1-T7 (AD)) / FNV (M1-T5
##        item 7) precedent; the four §9.1 limits and the three speeds may NOT — they are content.
##   (AK) PAN IS CAMERA-RELATIVE AND STAYS ON THE GROUND PLANE. `pan(right_m, forward_m)` translates
##        the FOCUS only, by `right_m * right(yaw) + forward_m * forward(yaw)` where
##        `right(yaw) = (cos yaw, 0, −sin yaw)` and `forward(yaw) = (−sin yaw, 0, −cos yaw)`. Both
##        are unit, orthogonal and horizontal, they agree with the camera basis (`right == basis.x`,
##        `forward == the ground projection of −basis.z`), and `focus_point().y` NEVER changes.
##   (AL) LOAD CONTRACT mirrors MapGenerator's (P), HexLayout's (Y) and MapRenderer's (AF) EXACTLY
##        and REUSES `RulesError` — no second error type is invented (§13.4, simplest reading;
##        `RulesError` is explicitly allowed in renderer files, M1-T6 (Y)). Line 0 is reserved for a
##        missing/unreadable file and is NEVER emitted for a schema error; schema errors carry the
##        offending top-level key's own 1-based line (fallback 1); ALL errors are collected, never
##        stopping at the first; error ORDER comes from the loader's own DECLARED key-spec order,
##        never the parsed Dictionary's; unknown extra top-level keys load clean (the shipped `"id"`
##        is one); ANY error leaves the rig UNCONFIGURED, including a failed load after a successful
##        one. SEMANTIC rejections and their ATTRIBUTION (decided here, so error lines are a
##        contract rather than an accident): `min_pitch_deg >= max_pitch_deg` -> **max_pitch_deg**;
##        `min_zoom_m <= 0` -> **min_zoom_m**; `min_zoom_m >= max_zoom_m` -> **max_zoom_m**; a speed
##        `<= 0` -> **that speed's own key**; `edge_pan_margin_px < 0` -> **edge_pan_margin_px**. A
##        leaf that already failed its own validation must NOT also raise a cascading band error.
##   (AM) THE THREE SPEEDS AND THE EDGE MARGIN ARE NEW TUNABLE CONTENT — §9.1 prints limits, never
##        speeds — so NO GDD cell moves. All seven numbers plus the margin live in
##        `data/render/camera.json`, a NEW file rather than four more keys in `greybox.json`
##        precisely because `tests/unit/test_hex_layout.gd` asserts `greybox.json` BYTE-FOR-BYTE.
##        Its formatting is LOAD-BEARING (line 1 a lone `{`, one top-level key per line, exactly like
##        `ruleset.json` / `greybox.json` / `terrain_palette.json`) because the line-attribution
##        fixtures below derive every expected line number from it. Data-drivenness is proven BY
##        MUTATION, not merely by a token scan.
##
## TOTALITY (the M1-T1 (B) spirit, re-measured for a Node): a rig whose load failed — or was never
## attempted — reports the ZERO sentinel from every accessor, returns `Transform3D.IDENTITY` from
## `camera_transform()`, and treats `orbit`/`tilt`/`dolly`/`pan`/`set_focus`/`apply_to_camera` as
## SILENT no-ops. No engine error, no crash, no half-configured state.
##
## HEADLESS SCOPE: every assertion here is on PLAIN VALUES (floats, Vector2/3, Transform3D,
## RulesError) — nothing is read back out of a renderer, so decisions.md M1-T6 **(Z)** (the headless
## dummy renderer stores no MultiMesh instance data) does not bite this file. The rig is instantiated
## with `autofree` and **NEVER added to the SceneTree**, so `_ready`, `@onready` and `_process` never
## run: §9.1's "edge-pan + WASD" input is deliberately UNTESTABLE headless and is pinned only by the
## source scan requiring `Input.` and `get_viewport(`. The 60-fps criterion itself is NOT
## headless-measurable at all (M1-T6 (Z)) — it is the windowed run this task owes, recorded in
## `docs/decisions.md`, and no test here pretends to measure it.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): a statically-decidable `is` test parse-errors and silently
## un-collects the WHOLE file, so class kind is asserted via `get_class()` ONLY — and a CameraRig IS
## a Node by design, so this file's scans are WRITTEN FRESH and are NOT `test_hex_layout.gd`'s
## engine-bound token list. Variant values are always assigned through a typed local (or inspected
## with `typeof`) before reaching a typed parameter, which is a hard parse error otherwise.
##
## HARNESS TRAP (decisions.md M1-T5 item 9, standing rule): `tools/run_tests.sh` greps the WHOLE run
## output for five diagnostics. No failure message in this file may contain any of them — this file
## says "is MISSING".
extends GutTest

const RIG_PATH: String = "res://scripts/render/camera_rig.gd"
const CAMERA_PATH: String = "res://data/render/camera.json"
const MISSING_CAMERA_PATH: String = "res://data/render/__no_such_camera__.json"
const SOURCE: String = "camera.json"

## Vector3/Transform3D components are 32-bit floats in Godot 4, so geometry is compared at 1e-4;
## scalar returns are 64-bit and are compared at 1e-9.
const TOL: float = 0.0001
const SCALAR_TOL: float = 0.000000001

# ---------------------------------------------------------------------------------------------
# §9.1 line 666 — "tilt 15–80°, zoom 8–60 m", transcribed verbatim. These four numbers are the ONLY
# printed content in this task; they are CONTENT and must not appear as literals in `camera_rig.gd`
# (section I scans for exactly that).
# ---------------------------------------------------------------------------------------------
const MIN_PITCH_DEG: float = 15.0
const MAX_PITCH_DEG: float = 80.0
const MIN_ZOOM_M: float = 8.0
const MAX_ZOOM_M: float = 60.0

## §9.1's "rotate 360°" — a MATHEMATICAL constant (one full turn), the SQRT_3 / RADIAL_SEGMENTS / FNV
## precedent, and the only number section I does NOT forbid in the `.gd`.
const DEGREES_PER_TURN: float = 360.0

# ---------------------------------------------------------------------------------------------
# (AM) — NEW tunable content. §9.1 prints limits and never speeds, so no GDD cell moves. The three
# speed values deliberately avoid 24 / 32 / 40 so that no §4.1 map-size literal can appear anywhere.
# ---------------------------------------------------------------------------------------------
const PAN_SPEED_MPS: float = 45.0
const ORBIT_SPEED_DPS: float = 35.0
const ZOOM_SPEED_MPS: float = 25.0
const EDGE_PAN_MARGIN_PX: int = 16

## The shipped document's `"id"` — an unknown EXTRA top-level key as far as the loader's spec table
## is concerned (M0-T2 item 5), exactly like `greybox.json`'s and `terrain_palette.json`'s.
const CAMERA_ID: String = "greybox_camera"

## (AL) — the loader's DECLARED key-spec order. Error ORDER must come from this table, never from the
## parsed Dictionary's key order.
const SPEC_KEYS: Array[String] = [
	"min_pitch_deg",
	"max_pitch_deg",
	"min_zoom_m",
	"max_zoom_m",
	"pan_speed_mps",
	"orbit_speed_dps",
	"zoom_speed_mps",
	"edge_pan_margin_px",
]

## The three speed keys, which share one semantic rule: strictly positive.
const SPEED_KEYS: Array[String] = ["pan_speed_mps", "orbit_speed_dps", "zoom_speed_mps"]

## The one INT leaf: a pixel margin is a whole number of pixels. Godot 4.7 parses every JSON number
## as TYPE_FLOAT (M0-T2 item 8), so an integral float is ACCEPTED and a fractional one REJECTED,
## never truncated.
const INT_KEY: String = "edge_pan_margin_px"

# ---------------------------------------------------------------------------------------------
# Deterministic sweeps. No RNG anywhere in a test (§11.1) — every "property" here is a fixed walk.
# ---------------------------------------------------------------------------------------------

## (AJ) — a fixed free walk whose partial sums leave the printed bands repeatedly, in both
## directions, including exact-boundary landings.
const WALK_DELTAS: Array[float] = [
	12.5, -40.0, 999.0, -0.5, -999.0, 65.0, 0.0, -13.25, 250.0, -120.0, 7.75, -1000.0,
]

## (AI) — the pitch and zoom stations of the distance sweep: both printed limits plus interior
## values, so a sin/cos swap cannot hide behind a symmetric hand case.
const SWEEP_PITCHES: Array[float] = [15.0, 30.0, 45.0, 60.0, 80.0]
const SWEEP_ZOOMS: Array[float] = [8.0, 30.0, 60.0]

## (AK) — the yaws the pan/basis agreement is checked at: the four cardinals plus two off-axis.
const PAN_YAWS: Array[float] = [0.0, 37.5, 90.0, 143.0, 180.0, 271.25, 315.0, 359.5]

# ---------------------------------------------------------------------------------------------
# Source-scan vocabularies (§11.1, §11.2, §11.3, §13.6). WRITTEN FRESH — a CameraRig IS a Node by
# design, so `test_hex_layout.gd`'s engine-bound list is deliberately NOT pasted here, and
# `test_map_renderer.gd`'s is not either (this file must ALLOW `Input.` and `get_viewport(`, which a
# renderer has no business touching).
# ---------------------------------------------------------------------------------------------

## §11.1 — engine-bound is legal in `scripts/render/`, non-determinism is not. `randi(`/`randf(`/
## `randomize(`/`RandomNumberGenerator` stay forbidden project-wide outside `scripts/core/rng.gd`
## (M1-T5 (R)); wall-clock and frame-time are forbidden as inputs; `SceneTree`/`get_tree` are
## forbidden because a camera rig has no business reaching for the tree (the fps readout and the
## auto-quit that DO need them live in `greybox_boot.gd`, whose own scan allows exactly those two
## tokens); `queue_free(` is forbidden project-wide for Nodes (M1-T7 item 11); the two sim MUTATORS
## and `EventBus` are forbidden because the camera reads nothing from the sim and subscribes to
## nothing (§11.1, §13.4).
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
	"HexMap",
	"MapGenerator",
]

## The other direction: what the file MUST contain. `Input.` and `get_viewport(` are the ONLY
## headless-unverifiable half of §9.1 ("edge-pan + WASD") and are therefore EXPLICITLY ALLOWED and
## REQUIRED — their presence is the only evidence the input half was built at all.
const REQUIRED_TOKENS: Array[String] = [
	"extends Node3D",
	"RulesError",
	"Transform3D",
	"Input.",
	"get_viewport(",
]

## §4.1 line 174 — radii and hex counts are content, never engine code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public function surface (§13.4: no hex picking (M1-T9), no tap-select or drag-box
## multi-select (M4/M8), no overlays / north compass / minimap (M8), no EventBus subscription, no
## shader (M3)). A MISSING **or EXTRA** member fails.
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"load_params_text",
	"load_params_file",
	"pitch_limits_deg",
	"zoom_limits_m",
	"pan_speed_mps",
	"orbit_speed_dps",
	"zoom_speed_mps",
	"edge_pan_margin_px",
	"yaw_deg",
	"pitch_deg",
	"zoom_m",
	"focus_point",
	"set_focus",
	"orbit",
	"tilt",
	"dolly",
	"pan",
	"camera_transform",
	"apply_to_camera",
]

## The COMPLETE public field surface — the existing shared error type, and nothing else.
const REQUIRED_PUBLIC_VARS: Array[String] = ["errors"]

## Doc-comment sections accepted by the §11.3 scan for this file.
const DOC_SECTIONS: Array[String] = ["§9.1", "§10", "§11.1", "§13.4"]


# =============================================================================================
# A. THE PRINTED §9.1 TEXT, THE SHIPPED CONTENT, AND THE SELF-CHECK OF EVERY PINNED NUMBER
# =============================================================================================

## The mechanical re-derivation demanded by the M1-T1 item 3 standing rule: every number pinned in
## this file is re-checked against an INDEPENDENT property here, so a transcription typo fails HERE
## rather than being blamed on the implementation.
func test_the_pinned_section_9_1_numbers_are_self_consistent() -> void:
	assert_true(MIN_PITCH_DEG < MAX_PITCH_DEG, "§9.1: the printed tilt band 15-80 is non-empty")
	assert_true(MIN_ZOOM_M < MAX_ZOOM_M, "§9.1: the printed zoom band 8-60 m is non-empty")
	assert_true(MIN_ZOOM_M > 0.0, "§9.1: a camera can never sit at or behind its focus")
	assert_true(
		MAX_PITCH_DEG < 90.0,
		"§9.1/(AI): the printed 80 deg ceiling keeps the view vector off the +Y axis, so"
		+ " looking_at(focus, Vector3.UP) is never degenerate"
	)
	assert_almost_eq(DEGREES_PER_TURN, 360.0, SCALAR_TOL, "§9.1: 'rotate 360' is one full turn")
	assert_eq(SPEC_KEYS.size(), 8, "(AL): the camera document declares eight required keys")
	assert_eq(SPEED_KEYS.size(), 3, "(AM): three tunable speeds")
	assert_true(SPEC_KEYS.has(INT_KEY), "(AL): the int leaf is one of the declared keys")

	var seen: Dictionary = {}
	for key: String in SPEC_KEYS:
		assert_false(seen.has(key), "(AL): key %s is declared once" % key)
		seen[key] = true
	for key: String in SPEED_KEYS:
		assert_true(SPEC_KEYS.has(key), "(AL): speed %s is a declared key" % key)

	var positives: Array[float] = [PAN_SPEED_MPS, ORBIT_SPEED_DPS, ZOOM_SPEED_MPS]
	for speed: float in positives:
		assert_true(speed > 0.0, "(AM): every shipped speed is strictly positive")
	assert_true(EDGE_PAN_MARGIN_PX >= 0, "(AM): the shipped edge margin is a non-negative pixel count")

	for pitch: float in SWEEP_PITCHES:
		assert_true(
			pitch >= MIN_PITCH_DEG and pitch <= MAX_PITCH_DEG,
			"sanity: sweep pitch %f lies inside the printed band" % pitch
		)
	for zoom: float in SWEEP_ZOOMS:
		assert_true(
			zoom >= MIN_ZOOM_M and zoom <= MAX_ZOOM_M,
			"sanity: sweep zoom %f lies inside the printed band" % zoom
		)


## (AM) — the shipped content file EXISTS where §11.2 puts renderer content, and its layout is
## line-addressable (M0-T2 item 7): line 1 a lone `{`, every top-level key starting exactly one line.
## That layout is the only reason schema-error line attribution below is meaningful.
func test_the_shipped_camera_file_exists_and_is_line_addressable() -> void:
	assert_true(
		FileAccess.file_exists(CAMERA_PATH),
		"§13.6/(AM): the §9.1 camera limits are content and live at %s (it is MISSING)" % CAMERA_PATH
	)
	var lines: PackedStringArray = _shipped_text(CAMERA_PATH).replace("\r\n", "\n").split("\n")
	assert_true(lines.size() >= 3, "M0-T2 item 7: %s has a line-addressable layout" % CAMERA_PATH)
	assert_eq(lines[0].strip_edges(), "{", "M0-T2 item 7: line 1 is a lone opening brace")
	for key: String in SPEC_KEYS:
		var hits: int = 0
		for line: String in lines:
			if line.strip_edges().begins_with('"%s":' % key):
				hits += 1
		assert_eq(hits, 1, "M0-T2 item 7: \"%s\" starts exactly one line of %s" % [key, CAMERA_PATH])


## The in-file fixture and the shipped content are the SAME document, so every rejection fixture
## below really is "the shipped file plus exactly one planted defect".
func test_the_canonical_fixture_matches_the_shipped_camera_file() -> void:
	assert_eq(
		_shipped_text(CAMERA_PATH).replace("\r\n", "\n").strip_edges(),
		_camera_text().strip_edges(),
		"(AM): the fixture in this file must equal the shipped %s" % CAMERA_PATH
	)


## §9.1/(AM) — the shipped document transcribes the four printed limits and the four new tunables,
## read from the DOCUMENT itself rather than through the loader, so a content edit is caught even if
## the loader happens to agree with it.
func test_the_shipped_camera_file_transcribes_the_printed_limits() -> void:
	var root: Dictionary = _parsed_json(CAMERA_PATH)
	assert_eq(str(root.get("id", "")), CAMERA_ID, "(AM): the shipped camera id")
	assert_almost_eq(
		_numeric(root.get("min_pitch_deg", null)), MIN_PITCH_DEG, SCALAR_TOL, "§9.1: tilt floor 15"
	)
	assert_almost_eq(
		_numeric(root.get("max_pitch_deg", null)), MAX_PITCH_DEG, SCALAR_TOL, "§9.1: tilt ceiling 80"
	)
	assert_almost_eq(
		_numeric(root.get("min_zoom_m", null)), MIN_ZOOM_M, SCALAR_TOL, "§9.1: zoom floor 8 m"
	)
	assert_almost_eq(
		_numeric(root.get("max_zoom_m", null)), MAX_ZOOM_M, SCALAR_TOL, "§9.1: zoom ceiling 60 m"
	)
	assert_almost_eq(
		_numeric(root.get("pan_speed_mps", null)), PAN_SPEED_MPS, SCALAR_TOL, "(AM): pan speed"
	)
	assert_almost_eq(
		_numeric(root.get("orbit_speed_dps", null)), ORBIT_SPEED_DPS, SCALAR_TOL, "(AM): orbit speed"
	)
	assert_almost_eq(
		_numeric(root.get("zoom_speed_mps", null)), ZOOM_SPEED_MPS, SCALAR_TOL, "(AM): zoom speed"
	)
	assert_almost_eq(
		_numeric(root.get(INT_KEY, null)),
		float(EDGE_PAN_MARGIN_PX),
		SCALAR_TOL,
		"(AM): edge-pan margin"
	)


## (AL) — the shipped file loads clean and configures EVERY accessor.
func test_the_shipped_camera_file_loads_clean_and_configures_every_accessor() -> void:
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_file(CAMERA_PATH)
	assert_true(ok, "(AL): %s must load: %s" % [CAMERA_PATH, str(_error_lines(rig))])
	assert_eq(_error_lines(rig), [] as Array[String], "(AL): a valid document yields no errors")
	_assert_vec2(
		rig.pitch_limits_deg(),
		Vector2(MIN_PITCH_DEG, MAX_PITCH_DEG),
		"§9.1: pitch_limits_deg is the printed 15-80 band"
	)
	_assert_vec2(
		rig.zoom_limits_m(),
		Vector2(MIN_ZOOM_M, MAX_ZOOM_M),
		"§9.1: zoom_limits_m is the printed 8-60 m band"
	)
	assert_almost_eq(rig.pan_speed_mps(), PAN_SPEED_MPS, SCALAR_TOL, "(AM): pan speed is configured")
	assert_almost_eq(
		rig.orbit_speed_dps(), ORBIT_SPEED_DPS, SCALAR_TOL, "(AM): orbit speed is configured"
	)
	assert_almost_eq(rig.zoom_speed_mps(), ZOOM_SPEED_MPS, SCALAR_TOL, "(AM): zoom speed is configured")
	assert_eq(rig.edge_pan_margin_px(), EDGE_PAN_MARGIN_PX, "(AM): the edge margin is configured")


## (AJ) — a successful load frames the WIDEST LEGAL VIEW, the only initial state derivable from data
## alone: yaw 0, pitch at its data maximum, zoom at its data maximum, focus at the world origin
## (M1-T6 (W): hex (0,0) IS the world origin, so a boot that frames the map needs no offset).
func test_a_successful_load_frames_the_widest_legal_view() -> void:
	var rig: CameraRig = _loaded()
	assert_almost_eq(rig.yaw_deg(), 0.0, SCALAR_TOL, "(AJ): a loaded rig starts at yaw 0")
	assert_almost_eq(
		rig.pitch_deg(), MAX_PITCH_DEG, SCALAR_TOL, "(AJ): a loaded rig starts at its pitch ceiling"
	)
	assert_almost_eq(
		rig.zoom_m(), MAX_ZOOM_M, SCALAR_TOL, "(AJ): a loaded rig starts at its zoom ceiling"
	)
	_assert_vec3(rig.focus_point(), Vector3.ZERO, "(AJ): a loaded rig focuses the world origin")


# =============================================================================================
# B. DATA-DRIVENNESS BY MUTATION (§13.6 "constants read from data, not code") — the pin that
#    actually matters, mirroring M1-T7's palette mutation tests. A token scan alone cannot tell a
#    data-driven limit from a code literal that happens to agree with the data.
# =============================================================================================

## §13.6 — mutate the pitch CEILING in the params text and the clamp must follow it.
func test_the_pitch_ceiling_is_read_from_data_not_shadowed_by_a_code_literal() -> void:
	var moved_ceiling: float = 70.0
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_text(_with_value("max_pitch_deg", "%d" % int(moved_ceiling)), SOURCE)
	assert_true(ok, "sanity: the mutated document is still valid: %s" % str(_error_lines(rig)))
	_assert_vec2(
		rig.pitch_limits_deg(),
		Vector2(MIN_PITCH_DEG, moved_ceiling),
		"§13.6: the pitch ceiling comes from the document"
	)
	rig.tilt(999.0)
	assert_almost_eq(
		rig.pitch_deg(),
		moved_ceiling,
		SCALAR_TOL,
		"§13.6/(AJ): tilt clamps to the DOCUMENT's ceiling, not to a literal in camera_rig.gd"
	)


## §13.6 — and the pitch FLOOR likewise.
func test_the_pitch_floor_is_read_from_data_not_shadowed_by_a_code_literal() -> void:
	var moved_floor: float = 25.0
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_text(_with_value("min_pitch_deg", "%d" % int(moved_floor)), SOURCE)
	assert_true(ok, "sanity: the mutated document is still valid: %s" % str(_error_lines(rig)))
	_assert_vec2(
		rig.pitch_limits_deg(),
		Vector2(moved_floor, MAX_PITCH_DEG),
		"§13.6: the pitch floor comes from the document"
	)
	rig.tilt(-999.0)
	assert_almost_eq(
		rig.pitch_deg(),
		moved_floor,
		SCALAR_TOL,
		"§13.6/(AJ): tilt clamps to the DOCUMENT's floor, not to a literal in camera_rig.gd"
	)


## §13.6 — both zoom limits move with the document, in one fixture carrying both mutations.
func test_the_zoom_limits_are_read_from_data_not_shadowed_by_code_literals() -> void:
	var moved_floor: float = 12.0
	var moved_ceiling: float = 40.0
	var text: String = _with_value("min_zoom_m", "%d" % int(moved_floor))
	text = _replace_value(text, "max_zoom_m", "%d" % int(moved_ceiling))
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_text(text, SOURCE)
	assert_true(ok, "sanity: the mutated document is still valid: %s" % str(_error_lines(rig)))
	_assert_vec2(
		rig.zoom_limits_m(),
		Vector2(moved_floor, moved_ceiling),
		"§13.6: both zoom limits come from the document"
	)
	rig.dolly(999.0)
	assert_almost_eq(
		rig.zoom_m(), moved_ceiling, SCALAR_TOL, "§13.6/(AJ): dolly clamps to the DOCUMENT's ceiling"
	)
	rig.dolly(-999.0)
	assert_almost_eq(
		rig.zoom_m(), moved_floor, SCALAR_TOL, "§13.6/(AJ): dolly clamps to the DOCUMENT's floor"
	)


## §13.6/(AM) — each of the three speeds and the edge margin is read from the document, one planted
## mutation at a time so a single shared accessor cannot satisfy all four.
func test_every_speed_and_the_edge_margin_are_read_from_data() -> void:
	var moved: Array[float] = [11.0, 13.0, 17.0]
	for i: int in range(SPEED_KEYS.size()):
		var key: String = SPEED_KEYS[i]
		var rig: CameraRig = _bare_rig()
		var ok: bool = rig.load_params_text(_with_value(key, "%d" % int(moved[i])), SOURCE)
		assert_true(ok, "sanity [%s]: the mutated document is still valid" % key)
		assert_almost_eq(
			_speed_of(rig, key),
			moved[i],
			SCALAR_TOL,
			"§13.6/(AM): %s comes from the document" % key
		)

	var margin_rig: CameraRig = _bare_rig()
	var margin_ok: bool = margin_rig.load_params_text(_with_value(INT_KEY, "29"), SOURCE)
	assert_true(margin_ok, "sanity: the mutated margin document is still valid")
	assert_eq(margin_rig.edge_pan_margin_px(), 29, "§13.6/(AM): %s comes from the document" % INT_KEY)


# =============================================================================================
# C. §9.1's PRINTED CLAMPS — "tilt 15–80°, zoom 8–60 m", INCLUSIVE at both ends (AJ)
# =============================================================================================

## §9.1 — tilt never leaves the printed 15-80 degree band, from an interior start, in either
## direction, however violent the delta.
func test_tilt_clamps_to_the_printed_fifteen_to_eighty_degree_band() -> void:
	var up: CameraRig = _at_pitch(_loaded(), 45.0)
	up.tilt(999.0)
	assert_almost_eq(up.pitch_deg(), MAX_PITCH_DEG, SCALAR_TOL, "§9.1: tilt clamps at 80 deg")

	var down: CameraRig = _at_pitch(_loaded(), 45.0)
	down.tilt(-999.0)
	assert_almost_eq(down.pitch_deg(), MIN_PITCH_DEG, SCALAR_TOL, "§9.1: tilt clamps at 15 deg")


## (AJ) — the band is INCLUSIVE: a tilt landing EXACTLY on a limit is accepted unchanged, and a
## further zero-delta tilt at a limit does not nudge it off.
func test_a_tilt_landing_exactly_on_a_limit_is_accepted_unchanged() -> void:
	var high: CameraRig = _at_pitch(_loaded(), 45.0)
	high.tilt(MAX_PITCH_DEG - 45.0)
	assert_almost_eq(high.pitch_deg(), MAX_PITCH_DEG, SCALAR_TOL, "(AJ): exactly 80 deg is legal")
	high.tilt(0.0)
	assert_almost_eq(high.pitch_deg(), MAX_PITCH_DEG, SCALAR_TOL, "(AJ): 80 deg is a stable state")

	var low: CameraRig = _at_pitch(_loaded(), 45.0)
	low.tilt(MIN_PITCH_DEG - 45.0)
	assert_almost_eq(low.pitch_deg(), MIN_PITCH_DEG, SCALAR_TOL, "(AJ): exactly 15 deg is legal")
	low.tilt(0.0)
	assert_almost_eq(low.pitch_deg(), MIN_PITCH_DEG, SCALAR_TOL, "(AJ): 15 deg is a stable state")


## §9.1 — dolly never leaves the printed 8-60 m band.
func test_dolly_clamps_to_the_printed_eight_to_sixty_metre_band() -> void:
	var out: CameraRig = _at_zoom(_loaded(), 30.0)
	out.dolly(999.0)
	assert_almost_eq(out.zoom_m(), MAX_ZOOM_M, SCALAR_TOL, "§9.1: zoom clamps at 60 m")

	var into: CameraRig = _at_zoom(_loaded(), 30.0)
	into.dolly(-999.0)
	assert_almost_eq(into.zoom_m(), MIN_ZOOM_M, SCALAR_TOL, "§9.1: zoom clamps at 8 m")


## (AJ) — the zoom band is INCLUSIVE at both ends too.
func test_a_dolly_landing_exactly_on_a_limit_is_accepted_unchanged() -> void:
	var far: CameraRig = _at_zoom(_loaded(), 30.0)
	far.dolly(MAX_ZOOM_M - 30.0)
	assert_almost_eq(far.zoom_m(), MAX_ZOOM_M, SCALAR_TOL, "(AJ): exactly 60 m is legal")
	far.dolly(0.0)
	assert_almost_eq(far.zoom_m(), MAX_ZOOM_M, SCALAR_TOL, "(AJ): 60 m is a stable state")

	var near: CameraRig = _at_zoom(_loaded(), 30.0)
	near.dolly(MIN_ZOOM_M - 30.0)
	assert_almost_eq(near.zoom_m(), MIN_ZOOM_M, SCALAR_TOL, "(AJ): exactly 8 m is legal")
	near.dolly(0.0)
	assert_almost_eq(near.zoom_m(), MIN_ZOOM_M, SCALAR_TOL, "(AJ): 8 m is a stable state")


## §9.1/(AJ) — the PROPERTY behind the hand cases: no walk of tilts and dollies, however long, can
## ever put pitch or zoom outside the printed bands, and the state stays finite.
func test_pitch_and_zoom_stay_inside_the_printed_bands_under_a_free_walk() -> void:
	var rig: CameraRig = _loaded()
	var breaks: Array[String] = []
	for step: int in range(WALK_DELTAS.size()):
		rig.tilt(WALK_DELTAS[step])
		rig.dolly(WALK_DELTAS[WALK_DELTAS.size() - 1 - step])
		var pitch: float = rig.pitch_deg()
		var zoom: float = rig.zoom_m()
		if pitch < MIN_PITCH_DEG - SCALAR_TOL or pitch > MAX_PITCH_DEG + SCALAR_TOL:
			breaks.append("step %d left pitch at %f" % [step, pitch])
		if zoom < MIN_ZOOM_M - SCALAR_TOL or zoom > MAX_ZOOM_M + SCALAR_TOL:
			breaks.append("step %d left zoom at %f" % [step, zoom])
	assert_eq(breaks.size(), 0, "§9.1/(AJ): the printed bands hold under a free walk; %s" % [
		str(breaks.slice(0, 5))
	])


# =============================================================================================
# D. §9.1's "rotate 360°" — YAW WRAPS, IT NEVER CLAMPS (AJ)
# =============================================================================================

## §9.1 — the hand-walked wrap table. A CLAMPED yaw fails every one of these except orbit(+360).
func test_yaw_wraps_through_a_full_turn_and_never_clamps() -> void:
	var cases: Array[float] = [370.0, -10.0, 360.0, 720.0, -730.0]
	var expected: Array[float] = [10.0, 350.0, 0.0, 0.0, 350.0]
	for i: int in range(cases.size()):
		var rig: CameraRig = _loaded()
		rig.orbit(cases[i])
		assert_almost_eq(
			rig.yaw_deg(),
			expected[i],
			SCALAR_TOL,
			"§9.1/(AJ): orbit(%f) from yaw 0 wraps to %f" % [cases[i], expected[i]]
		)


## (AJ) — the canonical range is the HALF-OPEN turn [0, 360): 360 itself is never reported.
func test_yaw_stays_in_the_canonical_half_open_turn_under_a_sweep() -> void:
	var breaks: Array[String] = []
	for k: int in range(-5, 6):
		var rig: CameraRig = _loaded()
		var delta: float = float(k) * 97.5
		rig.orbit(delta)
		var yaw: float = rig.yaw_deg()
		if yaw < 0.0 or yaw >= DEGREES_PER_TURN:
			breaks.append("orbit(%f) left yaw at %f" % [delta, yaw])
	assert_eq(breaks.size(), 0, "(AJ): yaw is canonicalised into [0, 360); %s" % [str(breaks)])


## (AJ) — orbiting ACCUMULATES and re-wraps, so the auto-orbit of the windowed 60-fps run cannot
## drift out of range however many frames it runs for.
func test_orbit_accumulates_across_many_turns_and_re_wraps() -> void:
	var rig: CameraRig = _loaded()
	for _step: int in range(10):
		rig.orbit(100.0)
	assert_almost_eq(
		rig.yaw_deg(), 280.0, TOL, "(AJ): ten orbits of 100 deg land at 1000 mod 360 = 280"
	)
	for _step: int in range(4):
		rig.orbit(-90.0)
	assert_almost_eq(rig.yaw_deg(), 280.0, TOL, "(AJ): a full turn backwards returns to the same yaw")


## (AJ) — yaw is INDEPENDENT of the clamped axes: orbiting never touches pitch, zoom or focus.
func test_orbiting_moves_only_the_yaw() -> void:
	var rig: CameraRig = _at_pitch(_at_zoom(_loaded(), 22.0), 33.0)
	rig.set_focus(Vector3(5.0, 2.0, -7.0))
	rig.orbit(123.5)
	assert_almost_eq(rig.pitch_deg(), 33.0, SCALAR_TOL, "(AJ): orbit does not tilt")
	assert_almost_eq(rig.zoom_m(), 22.0, SCALAR_TOL, "(AJ): orbit does not dolly")
	_assert_vec3(rig.focus_point(), Vector3(5.0, 2.0, -7.0), "(AJ): orbit does not move the focus")


# =============================================================================================
# E. (AI) THE DERIVED CAMERA TRANSFORM
# =============================================================================================

## (AI) — the hand-computed offset table at the printed extremes (pitch 80, zoom 60): yaw 0 puts the
## camera on the +Z side, yaw 90 on the +X side, yaw 180 on the -Z side, all at the same height.
func test_the_camera_sits_on_the_pinned_offset_from_the_focus() -> void:
	var horizontal: float = MAX_ZOOM_M * cos(deg_to_rad(MAX_PITCH_DEG))
	var height: float = MAX_ZOOM_M * sin(deg_to_rad(MAX_PITCH_DEG))
	assert_almost_eq(horizontal, 10.418890660015824, TOL, "sanity: 60 * cos(80 deg)")
	assert_almost_eq(height, 59.08846518073248, TOL, "sanity: 60 * sin(80 deg)")

	var yaws: Array[float] = [0.0, 90.0, 180.0, 270.0]
	var expected: Array[Vector3] = [
		Vector3(0.0, height, horizontal),
		Vector3(horizontal, height, 0.0),
		Vector3(0.0, height, -horizontal),
		Vector3(-horizontal, height, 0.0),
	]
	for i: int in range(yaws.size()):
		var rig: CameraRig = _at_yaw(_loaded(), yaws[i])
		_assert_vec3(
			rig.camera_transform().origin,
			expected[i],
			"(AI): at yaw %f the camera sits at the pinned offset" % yaws[i]
		)


## (AI) — the camera LOOKS AT the focus with +Y up and NO roll, pinned as the full orthonormal basis
## re-derived independently here (Godot's `looking_at` puts -Z forward, so +Z points back at the
## camera).
func test_the_camera_looks_at_the_focus_with_no_roll() -> void:
	var focus: Vector3 = Vector3(12.0, -3.0, 40.0)
	var breaks: Array[String] = []
	for yaw: float in PAN_YAWS:
		var rig: CameraRig = _at_pitch(_at_zoom(_at_yaw(_loaded(), yaw), 30.0), 45.0)
		rig.set_focus(focus)
		var xform: Transform3D = rig.camera_transform()
		var away: Vector3 = (xform.origin - focus).normalized()
		var expected_x: Vector3 = Vector3.UP.cross(away).normalized()
		var expected_y: Vector3 = away.cross(expected_x)
		if xform.basis.z.distance_to(away) > TOL:
			breaks.append("yaw %f: basis.z %s is not the away vector %s" % [
				yaw, str(xform.basis.z), str(away)
			])
		if xform.basis.x.distance_to(expected_x) > TOL:
			breaks.append("yaw %f: basis.x %s carries roll (expected %s)" % [
				yaw, str(xform.basis.x), str(expected_x)
			])
		if xform.basis.y.distance_to(expected_y) > TOL:
			breaks.append("yaw %f: basis.y %s is not the up vector" % [yaw, str(xform.basis.y)])
		if absf(xform.basis.x.y) > TOL:
			breaks.append("yaw %f: the right vector is not horizontal (%f)" % [yaw, xform.basis.x.y])
		if xform.basis.y.dot(Vector3.UP) <= 0.0:
			breaks.append("yaw %f: the camera is upside down" % yaw)
	assert_eq(breaks.size(), 0, "(AI): looking_at(focus, +Y) with no roll; %s" % [
		str(breaks.slice(0, 4))
	])


## (AI) — the PROPERTY that catches a sin/cos swap no single hand case can: over the whole orbit, at
## every printed pitch station and zoom station, the camera's distance to the focus is EXACTLY the
## zoom.
func test_the_camera_distance_to_the_focus_always_equals_the_zoom() -> void:
	var focus: Vector3 = Vector3(-8.5, 4.25, 17.0)
	var breaks: Array[String] = []
	for pitch: float in SWEEP_PITCHES:
		for zoom: float in SWEEP_ZOOMS:
			for step: int in range(36):
				var yaw: float = float(step) * 10.0
				var rig: CameraRig = _at_pitch(_at_zoom(_at_yaw(_loaded(), yaw), zoom), pitch)
				rig.set_focus(focus)
				var origin: Vector3 = rig.camera_transform().origin
				var distance: float = origin.distance_to(focus)
				if absf(distance - zoom) > TOL:
					breaks.append("yaw %f pitch %f zoom %f gave distance %f" % [
						yaw, pitch, zoom, distance
					])
				if origin.y <= focus.y:
					breaks.append("yaw %f pitch %f: the camera sank to or below the focus" % [
						yaw, pitch
					])
	assert_eq(breaks.size(), 0, "(AI): |camera - focus| == zoom everywhere; %s" % [
		str(breaks.slice(0, 4))
	])


## (AI) — the focus TRANSLATES the whole rig: the offset from focus to camera is invariant under
## set_focus, so framing the map is a pure translation.
func test_the_focus_translates_the_whole_rig() -> void:
	var rig: CameraRig = _at_pitch(_at_zoom(_at_yaw(_loaded(), 61.0), 44.0), 27.0)
	var offset: Vector3 = rig.camera_transform().origin - rig.focus_point()
	var moved: Vector3 = Vector3(103.5, -7.25, -62.0)
	rig.set_focus(moved)
	_assert_vec3(rig.focus_point(), moved, "(AI): set_focus stores the point verbatim")
	_assert_vec3(
		rig.camera_transform().origin - moved,
		offset,
		"(AI): moving the focus translates the camera by the same vector"
	)


## (AI) — `apply_to_camera` writes the derived transform onto a real [Camera3D] and keeps writing it
## as the rig moves. `apply_to_camera(null)` is a silent no-op (the (B) totality spirit).
func test_apply_to_camera_writes_the_derived_transform() -> void:
	var rig: CameraRig = _loaded()
	var camera: Camera3D = Camera3D.new()
	autofree(camera)
	rig.apply_to_camera(camera)
	_assert_transform(
		camera.transform, rig.camera_transform(), "(AI): apply_to_camera writes camera_transform()"
	)

	rig.orbit(47.5)
	rig.tilt(-20.0)
	rig.dolly(-15.0)
	rig.set_focus(Vector3(9.0, 0.0, -4.0))
	rig.apply_to_camera(camera)
	_assert_transform(
		camera.transform, rig.camera_transform(), "(AI): a moved rig re-applies its new transform"
	)
	rig.apply_to_camera(null)


# =============================================================================================
# F. (AK) CAMERA-RELATIVE GROUND PAN — §9.1 "edge-pan + WASD"
# =============================================================================================

## (AK) — the hand-walked pan table. At yaw 0 the camera is on the +Z side looking toward -Z, so
## "forward" is -Z and "right" is +X; every other yaw is that pair rotated about +Y.
func test_pan_moves_the_focus_along_the_camera_relative_ground_axes() -> void:
	var yaws: Array[float] = [0.0, 0.0, 90.0, 90.0, 180.0, 180.0, 270.0, 270.0]
	var rights: Array[float] = [0.0, 10.0, 0.0, 10.0, 0.0, 10.0, 0.0, 10.0]
	var forwards: Array[float] = [10.0, 0.0, 10.0, 0.0, 10.0, 0.0, 10.0, 0.0]
	var expected: Array[Vector3] = [
		Vector3(0.0, 0.0, -10.0),
		Vector3(10.0, 0.0, 0.0),
		Vector3(-10.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -10.0),
		Vector3(0.0, 0.0, 10.0),
		Vector3(-10.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 10.0),
	]
	for i: int in range(yaws.size()):
		var rig: CameraRig = _at_yaw(_loaded(), yaws[i])
		rig.pan(rights[i], forwards[i])
		_assert_vec3(
			rig.focus_point(),
			expected[i],
			"(AK): at yaw %f, pan(right %f, forward %f)" % [yaws[i], rights[i], forwards[i]]
		)


## (AK) — pan NEVER leaves the ground plane, from the origin and from a raised focus alike, however
## many mixed pans at however many yaws.
func test_pan_never_leaves_the_ground_plane() -> void:
	var rig: CameraRig = _loaded()
	var breaks: Array[String] = []
	for i: int in range(20):
		rig.orbit(PAN_YAWS[i % PAN_YAWS.size()])
		rig.pan(float(i) * 1.5 - 6.0, 4.0 - float(i))
		if absf(rig.focus_point().y) > TOL:
			breaks.append("pan %d lifted the focus to y=%f" % [i, rig.focus_point().y])
	assert_eq(breaks.size(), 0, "(AK): pan stays on the XZ ground plane; %s" % [str(breaks.slice(0, 4))])

	var raised: CameraRig = _loaded()
	raised.set_focus(Vector3(3.0, 7.0, -2.0))
	for i: int in range(8):
		raised.orbit(PAN_YAWS[i])
		raised.pan(5.0, -3.0)
	assert_almost_eq(
		raised.focus_point().y, 7.0, TOL, "(AK): pan preserves whatever height the focus was given"
	)


## (AK) — panning back at the SAME yaw returns exactly to the start (the axes are a pure rotation,
## not a projection that loses information).
func test_pan_is_reversible_at_the_same_yaw() -> void:
	var breaks: Array[String] = []
	for yaw: float in PAN_YAWS:
		var rig: CameraRig = _at_yaw(_loaded(), yaw)
		var start: Vector3 = rig.focus_point()
		rig.pan(13.5, -21.25)
		rig.pan(-13.5, 21.25)
		if rig.focus_point().distance_to(start) > TOL:
			breaks.append("yaw %f drifted to %s" % [yaw, str(rig.focus_point())])
	assert_eq(breaks.size(), 0, "(AK): pan is invertible at a fixed yaw; %s" % [str(breaks)])


## (AK)/(AI) — the pan axes are UNIT, ORTHOGONAL and AGREE WITH THE CAMERA BASIS: "right" is the
## camera's own +X, "forward" is the ground projection of its view direction. This is what makes
## §9.1's WASD feel camera-relative rather than world-relative.
func test_the_pan_axes_are_unit_orthogonal_and_agree_with_the_camera_basis() -> void:
	var breaks: Array[String] = []
	for yaw: float in PAN_YAWS:
		var right_rig: CameraRig = _at_yaw(_loaded(), yaw)
		right_rig.pan(1.0, 0.0)
		var right_axis: Vector3 = right_rig.focus_point()

		var forward_rig: CameraRig = _at_yaw(_loaded(), yaw)
		forward_rig.pan(0.0, 1.0)
		var forward_axis: Vector3 = forward_rig.focus_point()

		var basis: Basis = _at_yaw(_loaded(), yaw).camera_transform().basis
		var view_ground: Vector3 = Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()

		if absf(right_axis.length() - 1.0) > TOL:
			breaks.append("yaw %f: the right axis is not unit (%f)" % [yaw, right_axis.length()])
		if absf(forward_axis.length() - 1.0) > TOL:
			breaks.append("yaw %f: the forward axis is not unit (%f)" % [yaw, forward_axis.length()])
		if absf(right_axis.dot(forward_axis)) > TOL:
			breaks.append("yaw %f: the pan axes are not orthogonal (%f)" % [
				yaw, right_axis.dot(forward_axis)
			])
		if right_axis.distance_to(basis.x) > TOL:
			breaks.append("yaw %f: the right axis %s is not the camera's +X %s" % [
				yaw, str(right_axis), str(basis.x)
			])
		if forward_axis.distance_to(view_ground) > TOL:
			breaks.append("yaw %f: the forward axis %s is not the view direction %s" % [
				yaw, str(forward_axis), str(view_ground)
			])
	assert_eq(breaks.size(), 0, "(AK)/(AI): the pan axes ARE the camera's ground axes; %s" % [
		str(breaks.slice(0, 4))
	])


## (AK) — panning moves ONLY the focus: it never orbits, tilts or dollies.
func test_panning_moves_only_the_focus() -> void:
	var rig: CameraRig = _at_pitch(_at_zoom(_at_yaw(_loaded(), 210.0), 19.0), 62.0)
	rig.pan(-40.0, 55.0)
	assert_almost_eq(rig.yaw_deg(), 210.0, TOL, "(AK): pan does not orbit")
	assert_almost_eq(rig.pitch_deg(), 62.0, SCALAR_TOL, "(AK): pan does not tilt")
	assert_almost_eq(rig.zoom_m(), 19.0, SCALAR_TOL, "(AK): pan does not dolly")


# =============================================================================================
# G. TOTALITY — the UNCONFIGURED sentinel (the M1-T1 (B) / M1-T6 (Y) / M1-T7 (AB) spirit)
# =============================================================================================

## (AJ) — a rig that never loaded reports the ZERO sentinel from every accessor and the IDENTITY
## transform, so a failed boot can never be mistaken for a working camera.
func test_an_unconfigured_rig_reports_the_sentinel_everywhere() -> void:
	_assert_unconfigured(_bare_rig(), "never loaded")


## (AJ) — every mutator is a SILENT no-op while unconfigured: no engine error, no crash, no
## half-configured state.
func test_every_mutator_is_a_silent_no_op_while_unconfigured() -> void:
	var rig: CameraRig = _bare_rig()
	rig.orbit(123.0)
	rig.tilt(45.0)
	rig.dolly(30.0)
	rig.pan(10.0, -10.0)
	rig.set_focus(Vector3(1.0, 2.0, 3.0))
	rig.apply_to_camera(null)
	_assert_unconfigured(rig, "mutated while unconfigured")


## (AL) — a FAILED load after a SUCCESSFUL one leaves the rig UNCONFIGURED (the (Y)/(AB) rule,
## re-pinned here: stale limits from a previous document are worse than none).
func test_a_failed_load_after_a_successful_one_leaves_the_rig_unconfigured() -> void:
	var rig: CameraRig = _bare_rig()
	assert_true(rig.load_params_text(_camera_text(), SOURCE), "sanity: the canonical document loads")
	assert_almost_eq(rig.pitch_deg(), MAX_PITCH_DEG, SCALAR_TOL, "sanity: it configured the rig")

	var ok: bool = rig.load_params_text("{ not json", SOURCE)
	assert_false(ok, "(AL): the broken document is rejected")
	_assert_unconfigured(rig, "failed load after a successful one")


# =============================================================================================
# H. (AL) THE LOAD CONTRACT — mirrors MapGenerator's (P), HexLayout's (Y) and MapRenderer's (AF)
# =============================================================================================

## M0-T2 item 2 — a missing file is EXACTLY ONE error attributed to the reserved line 0.
func test_a_missing_camera_file_is_one_file_level_error_on_line_zero() -> void:
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_file(MISSING_CAMERA_PATH)
	assert_false(ok, "(AL): a missing params file is a failure, not a default")
	assert_eq(rig.errors.size(), 1, "M0-T2 item 2: exactly one file-level error")
	if rig.errors.size() == 1:
		assert_eq(rig.errors[0].line, 0, "M0-T2 item 2: line 0 is reserved for missing files")
	_assert_unconfigured(rig, "missing file")


## (AL) — the canonical document is accepted, so every rejection fixture below really is "this
## document plus exactly one planted defect".
func test_the_canonical_camera_text_is_accepted() -> void:
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_text(_camera_text(), SOURCE)
	assert_true(ok, "(AL): the canonical document loads: %s" % str(_error_lines(rig)))
	assert_eq(_error_lines(rig), [] as Array[String], "(AL): and reports no error")


## (AL) — malformed JSON is rejected with a 1-BASED line (Godot's `JSON.get_error_line()` is 0-based;
## the loader normalizes it) and never with the reserved line 0.
func test_reject_malformed_json_with_a_one_based_line() -> void:
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_text("{\n  \"id\": \"x\"\n  \"min_pitch_deg\": 15\n}", SOURCE)
	assert_false(ok, "(AL): malformed JSON is rejected")
	assert_true(rig.errors.size() >= 1, "(AL): a syntax error is reported")
	for error: RulesError in rig.errors:
		assert_true(error.line >= 1, "M0-T2 item 2: a syntax error never uses the reserved line 0")
	_assert_unconfigured(rig, "malformed json")


## (AL) — a root that is not a JSON object is rejected on line 1.
func test_reject_a_root_that_is_not_a_json_object() -> void:
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_text("[1, 2, 3]", SOURCE)
	assert_false(ok, "(AL): the document root must be an object")
	assert_true(rig.errors.size() >= 1, "(AL): a root error is reported")
	if rig.errors.size() >= 1:
		assert_eq(rig.errors[0].line, 1, "(AL): a root error is attributed to line 1")
	_assert_unconfigured(rig, "non-object root")


## (AL) — EVERY required key is required, each rejected with its own key's line.
func test_reject_a_document_missing_any_required_key() -> void:
	for key: String in SPEC_KEYS:
		var text: String = _without_line(key)
		_assert_rejected(text, key, 1, "missing %s" % key)


## (AL) — every value must be a NUMBER; a string is rejected at that key's own line.
func test_reject_a_non_numeric_value_for_every_key() -> void:
	for key: String in SPEC_KEYS:
		var text: String = _with_value(key, "\"nope\"")
		_assert_rejected(text, key, _line_of(text, key), "non-numeric %s" % key)


## (AL)/M0-T2 item 8 — the ONE int leaf REJECTS a fractional value (never truncating it) and ACCEPTS
## an integral float, because Godot 4.7 hands every JSON number back as TYPE_FLOAT.
func test_reject_a_fractional_edge_margin_but_accept_an_integral_float() -> void:
	var fractional: String = _with_value(INT_KEY, "16.5")
	_assert_rejected(fractional, INT_KEY, _line_of(fractional, INT_KEY), "fractional %s" % INT_KEY)

	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_text(_with_value(INT_KEY, "16.0"), SOURCE)
	assert_true(ok, "M0-T2 item 8: an integral float is a whole number: %s" % str(_error_lines(rig)))
	assert_eq(rig.edge_pan_margin_px(), EDGE_PAN_MARGIN_PX, "M0-T2 item 8: and is never truncated")


## (AL) — an INVERTED or DEGENERATE pitch band is rejected, attributed to `max_pitch_deg`.
func test_reject_an_inverted_or_degenerate_pitch_band() -> void:
	var inverted: String = _with_value("min_pitch_deg", "%d" % int(MAX_PITCH_DEG + 5.0))
	_assert_rejected(inverted, "max_pitch_deg", _line_of(inverted, "max_pitch_deg"), "inverted pitch")

	var degenerate: String = _with_value("max_pitch_deg", "%d" % int(MIN_PITCH_DEG))
	_assert_rejected(
		degenerate, "max_pitch_deg", _line_of(degenerate, "max_pitch_deg"), "degenerate pitch"
	)


## (AL) — a NON-POSITIVE zoom floor is rejected (a camera cannot stand on its focus), attributed to
## `min_zoom_m`; an inverted band is attributed to `max_zoom_m`.
func test_reject_a_non_positive_or_inverted_zoom_band() -> void:
	for value: String in ["0", "-8"]:
		var text: String = _with_value("min_zoom_m", value)
		_assert_rejected(text, "min_zoom_m", _line_of(text, "min_zoom_m"), "min_zoom_m %s" % value)

	var inverted: String = _with_value("min_zoom_m", "%d" % int(MAX_ZOOM_M + 5.0))
	_assert_rejected(inverted, "max_zoom_m", _line_of(inverted, "max_zoom_m"), "inverted zoom")

	var degenerate: String = _with_value("max_zoom_m", "%d" % int(MIN_ZOOM_M))
	_assert_rejected(degenerate, "max_zoom_m", _line_of(degenerate, "max_zoom_m"), "degenerate zoom")


## (AM) — a speed of zero or less is rejected: a camera that cannot move is not a camera.
func test_reject_a_non_positive_speed() -> void:
	for key: String in SPEED_KEYS:
		for value: String in ["0", "-5"]:
			var text: String = _with_value(key, value)
			_assert_rejected(text, key, _line_of(text, key), "%s %s" % [key, value])


## (AM) — a NEGATIVE edge margin is rejected, but ZERO is legal (edge-pan simply switched off).
func test_reject_a_negative_edge_margin_but_accept_zero() -> void:
	var negative: String = _with_value(INT_KEY, "-1")
	_assert_rejected(negative, INT_KEY, _line_of(negative, INT_KEY), "negative %s" % INT_KEY)

	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_text(_with_value(INT_KEY, "0"), SOURCE)
	assert_true(ok, "(AM): a zero margin disables edge-pan: %s" % str(_error_lines(rig)))
	assert_eq(rig.edge_pan_margin_px(), 0, "(AM): and is stored verbatim")


## (AL) — ERROR ORDER comes from the loader's own DECLARED key-spec order, never the parsed
## Dictionary's: the fixture presents all eight keys REVERSED and breaks two of them, one early in
## the spec table and one late, so document order and spec order disagree.
func test_error_order_follows_the_loaders_key_spec_order_not_the_documents() -> void:
	var text: String = _reversed_document_text()
	var rig: CameraRig = _bare_rig()
	assert_true(rig.load_params_text(_camera_text(), SOURCE), "sanity: the un-mutated document loads")

	var ok: bool = rig.load_params_text(text, SOURCE)
	assert_false(ok, "(AL): the two planted defects are rejected")
	var paths: Array[String] = []
	for error: RulesError in rig.errors:
		paths.append(error.path)
	assert_eq(
		paths,
		["min_pitch_deg", "zoom_speed_mps"] as Array[String],
		"(AL): errors come out in SPEC order (min_pitch_deg first) though the document lists"
		+ " zoom_speed_mps first; a leaf that failed its own check must not cascade a band error"
	)
	if rig.errors.size() == 2:
		assert_eq(
			rig.errors[0].line,
			_line_of(text, "min_pitch_deg"),
			"(AL): each error still carries its own key's DOCUMENT line"
		)
		assert_eq(
			rig.errors[1].line,
			_line_of(text, "zoom_speed_mps"),
			"(AL): each error still carries its own key's DOCUMENT line"
		)
	_assert_unconfigured(rig, "reversed document with two defects")


## (AL)/M0-T2 item 5 — unknown EXTRA top-level keys load clean; the shipped `"id"` is one.
func test_an_unknown_extra_top_level_key_loads_clean() -> void:
	var lines: Array[String] = []
	for line: String in _camera_text().split("\n"):
		lines.append(line)
		if line.strip_edges() == "{":
			lines.append('  "future_tunable": 99,')
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_text(_joined(lines), SOURCE)
	assert_true(ok, "M0-T2 item 5: an unknown key is ignored: %s" % str(_error_lines(rig)))
	_assert_vec2(
		rig.pitch_limits_deg(),
		Vector2(MIN_PITCH_DEG, MAX_PITCH_DEG),
		"M0-T2 item 5: and the known keys still configure the rig"
	)


# =============================================================================================
# I. MECHANICAL SOURCE SCANS ON scripts/render/camera_rig.gd — WRITTEN FRESH.
#    A CameraRig IS a Node by design AND must reach for `Input`/`get_viewport`, so neither
#    `test_hex_layout.gd`'s nor `test_map_renderer.gd`'s token list is pasted here. Comment
#    stripping is LOAD-BEARING: the doc block quotes the very numbers being scanned for (it cites
#    "15–80°" and "§9.1", which a naive numeric regex would hit).
# =============================================================================================

## S1 §11.1 — engine-bound is legal in `scripts/render/`; NON-DETERMINISM is not, and neither is
## reaching into the sim or the tree from a camera.
func test_source_holds_no_forbidden_token() -> void:
	var code: String = _code_text(RIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RIG_PATH)
	for banned: String in FORBIDDEN_TOKENS:
		assert_false(code.contains(banned), "§11.1/§13.6: %s must not contain %s" % [RIG_PATH, banned])


## S2 §9.1 — the other direction. `Input.` and `get_viewport(` are the ONLY evidence available
## headless that §9.1's "edge-pan + WASD" was built at all: the rig is never added to the SceneTree
## in this suite, so `_process` never runs and no assertion can observe input.
func test_source_carries_every_required_token() -> void:
	var code: String = _code_text(RIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RIG_PATH)
	for required: String in REQUIRED_TOKENS:
		assert_true(code.contains(required), "§9.1/§11.1: %s must contain %s" % [RIG_PATH, required])


## S3 §9.1/§13.6 — the four PRINTED limits are CONTENT: none of `15`, `80`, `8`, `60` may appear as a
## literal in the comment-stripped source. `\b60\b` deliberately does NOT match inside `360.0`, which
## is the one number (AJ) allows as a named mathematical const.
func test_source_hard_codes_no_section_9_1_limit() -> void:
	var code: String = _code_text(RIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RIG_PATH)
	var pattern: RegEx = RegEx.new()
	assert_eq(pattern.compile("\\b(15|80|8|60)\\b"), OK, "sanity: the §9.1 limit pattern compiles")
	var hit: RegExMatch = pattern.search(code)
	assert_null(
		hit,
		"§9.1/§13.6: the tilt and zoom limits are content in %s — %s must not hard-code %s" % [
			CAMERA_PATH, RIG_PATH, "" if hit == null else hit.get_string()
		]
	)
	var turn_probe: RegExMatch = pattern.search("var t: float = 360.0")
	assert_null(turn_probe, "sanity: the pattern does not fire inside 360.0 (AJ allows that const)")


## S4 §4.1 line 174 / §13.6 — map radii and hex counts are content, never engine code, in the camera
## exactly as in the renderer and the sim.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(RIG_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RIG_PATH)
	var number: RegEx = RegEx.new()
	assert_eq(
		number.compile("\\b(24|32|40|1801|3169|4921)\\b"), OK, "sanity: the map-size pattern compiles"
	)
	var hit: RegExMatch = number.search(code)
	assert_null(hit, "§4.1/§13.6: map sizes are content — %s must not hard-code %s" % [
		RIG_PATH, "" if hit == null else hit.get_string()
	])
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S5 §11.3 ("public rule functions documented with the GDD section they implement"), tightened the
## M1-T6 / M1-T7 way: the expected public surface is listed EXPLICITLY, so a MISSING member fails
## instead of passing vacuously and an EXTRA member (hex picking (M1-T9), drag-box selection (M4/M8),
## an overlay toggle or a minimap hook (M8), an EventBus subscription — all §13.4 violations here)
## fails too.
func test_public_api_is_exactly_the_documented_surface() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(RIG_PATH, public_functions, undocumented)

	var rig: CameraRig = _bare_rig()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, RIG_PATH]
		)
		assert_true(
			rig.has_method(required), "§11.2: %s must be callable on a CameraRig instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			RIG_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
		]
	)
	assert_eq(
		undocumented.size(),
		0,
		"§11.3: every public function needs a '## §<section>' doc comment (%s); missing on: %s" % [
			str(DOC_SECTIONS), str(undocumented)
		]
	)
	assert_eq(
		_collect_public_vars(RIG_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public field surface of %s is exactly %s" % [RIG_PATH, str(REQUIRED_PUBLIC_VARS)]
	)


## S6 §11.2 — the rig is a [Node3D] living exactly where §11.2 names it. Class kind is read from an
## INSTANCE via `get_class()`, never with a statically-decidable `is` (M0-T2 item 11).
func test_camera_rig_is_a_node3d_in_scripts_render() -> void:
	var rig: CameraRig = _bare_rig()
	assert_eq(rig.get_class(), "Node3D", "§11.2: CameraRig extends Node3D")
	assert_true(FileAccess.file_exists(RIG_PATH), "§11.2: the rig lives at %s" % RIG_PATH)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A CameraRig with NOTHING loaded, registered for automatic freeing so no orphan Node survives.
func _bare_rig() -> CameraRig:
	var rig: CameraRig = CameraRig.new()
	autofree(rig)
	return rig


## A CameraRig loaded from the SHIPPED content file, so every expectation is derived from data.
func _loaded() -> CameraRig:
	var rig: CameraRig = _bare_rig()
	var ok: bool = rig.load_params_file(CAMERA_PATH)
	assert_true(ok, "(AL): %s must load for the camera fixtures: %s" % [
		CAMERA_PATH, str(_error_lines(rig))
	])
	return rig


## Drives `rig` to an exact yaw through the public mutator (there is deliberately no absolute
## setter — §13.4, the boot needs none).
func _at_yaw(rig: CameraRig, yaw: float) -> CameraRig:
	rig.orbit(yaw - rig.yaw_deg())
	return rig


## Drives `rig` to an exact pitch through the public mutator.
func _at_pitch(rig: CameraRig, pitch: float) -> CameraRig:
	rig.tilt(pitch - rig.pitch_deg())
	return rig


## Drives `rig` to an exact zoom through the public mutator.
func _at_zoom(rig: CameraRig, zoom: float) -> CameraRig:
	rig.dolly(zoom - rig.zoom_m())
	return rig


## The speed accessor named by a spec key, so the mutation loop needs no branchy duplication.
func _speed_of(rig: CameraRig, key: String) -> float:
	if key == "pan_speed_mps":
		return rig.pan_speed_mps()
	if key == "orbit_speed_dps":
		return rig.orbit_speed_dps()
	if key == "zoom_speed_mps":
		return rig.zoom_speed_mps()
	return -1.0


## (AJ) — the UNCONFIGURED contract used by every totality case.
func _assert_unconfigured(rig: CameraRig, label: String) -> void:
	_assert_vec2(rig.pitch_limits_deg(), Vector2.ZERO, "(AJ) [%s]: no pitch band" % label)
	_assert_vec2(rig.zoom_limits_m(), Vector2.ZERO, "(AJ) [%s]: no zoom band" % label)
	assert_almost_eq(rig.pan_speed_mps(), 0.0, SCALAR_TOL, "(AJ) [%s]: no pan speed" % label)
	assert_almost_eq(rig.orbit_speed_dps(), 0.0, SCALAR_TOL, "(AJ) [%s]: no orbit speed" % label)
	assert_almost_eq(rig.zoom_speed_mps(), 0.0, SCALAR_TOL, "(AJ) [%s]: no zoom speed" % label)
	assert_eq(rig.edge_pan_margin_px(), 0, "(AJ) [%s]: no edge margin" % label)
	assert_almost_eq(rig.yaw_deg(), 0.0, SCALAR_TOL, "(AJ) [%s]: no yaw" % label)
	assert_almost_eq(rig.pitch_deg(), 0.0, SCALAR_TOL, "(AJ) [%s]: no pitch" % label)
	assert_almost_eq(rig.zoom_m(), 0.0, SCALAR_TOL, "(AJ) [%s]: no zoom" % label)
	_assert_vec3(rig.focus_point(), Vector3.ZERO, "(AJ) [%s]: no focus" % label)
	_assert_transform(
		rig.camera_transform(), Transform3D.IDENTITY, "(AJ) [%s]: the identity transform" % label
	)


## Runs one rejection fixture end to end: a document differing from the canonical one by exactly one
## planted defect must be rejected with at least one 1-based error carrying `key` at `expected_line`,
## must never emit the reserved line 0, and must leave the rig UNCONFIGURED even though it had just
## loaded successfully.
func _assert_rejected(text: String, key: String, expected_line: int, label: String) -> void:
	var rig: CameraRig = _bare_rig()
	assert_true(
		rig.load_params_text(_camera_text(), SOURCE),
		"sanity [%s]: the un-mutated document loads first" % label
	)

	var ok: bool = rig.load_params_text(text, SOURCE)
	assert_false(ok, "(AL) [%s]: the planted defect must be rejected" % label)
	assert_true(rig.errors.size() >= 1, "(AL) [%s]: rejection reports at least one error" % label)

	var document_lines: PackedStringArray = text.split("\n")
	var zero_lines: int = 0
	var off_document: int = 0
	var at_key: int = 0
	for error: RulesError in rig.errors:
		if error.line == 0:
			zero_lines += 1
		if error.line < 0 or error.line > document_lines.size():
			off_document += 1
		if error.path == key and error.line == expected_line:
			at_key += 1
	assert_eq(zero_lines, 0, "M0-T2 item 2 [%s]: line 0 is reserved for missing files" % label)
	assert_eq(off_document, 0, "(AL) [%s]: every error line is inside the document" % label)
	assert_true(
		at_key >= 1,
		"(AL) [%s]: an error must carry path \"%s\" at line %d; got %s" % [
			label, key, expected_line, str(_error_lines(rig))
		]
	)
	_assert_unconfigured(rig, label)


## Component-wise Vector2 comparison at [constant TOL], with a readable message.
func _assert_vec2(observed: Vector2, expected: Vector2, label: String) -> void:
	assert_true(
		absf(observed.x - expected.x) <= TOL and absf(observed.y - expected.y) <= TOL,
		"%s: expected %s, got %s" % [label, str(expected), str(observed)]
	)


## Component-wise Vector3 comparison at [constant TOL] (Vector3 components are 32-bit floats).
func _assert_vec3(observed: Vector3, expected: Vector3, label: String) -> void:
	assert_true(
		observed.distance_to(expected) <= TOL,
		"%s: expected %s, got %s" % [label, str(expected), str(observed)]
	)


## Basis + origin comparison at [constant TOL].
func _assert_transform(observed: Transform3D, expected: Transform3D, label: String) -> void:
	var same: bool = (
		observed.origin.distance_to(expected.origin) <= TOL
		and observed.basis.x.distance_to(expected.basis.x) <= TOL
		and observed.basis.y.distance_to(expected.basis.y) <= TOL
		and observed.basis.z.distance_to(expected.basis.z) <= TOL
	)
	assert_true(same, "%s: expected %s, got %s" % [label, str(expected), str(observed)])


## The canonical camera document, in the LOAD-BEARING layout `ruleset.json` established (line 1 a
## lone `{`, one top-level key per line) so every expected error line is computed, never magic.
func _camera_text() -> String:
	return _joined([
		"{",
		'  "id": "%s",' % CAMERA_ID,
		'  "min_pitch_deg": %d,' % int(MIN_PITCH_DEG),
		'  "max_pitch_deg": %d,' % int(MAX_PITCH_DEG),
		'  "min_zoom_m": %d,' % int(MIN_ZOOM_M),
		'  "max_zoom_m": %d,' % int(MAX_ZOOM_M),
		'  "pan_speed_mps": %d,' % int(PAN_SPEED_MPS),
		'  "orbit_speed_dps": %d,' % int(ORBIT_SPEED_DPS),
		'  "zoom_speed_mps": %d,' % int(ZOOM_SPEED_MPS),
		'  "edge_pan_margin_px": %d' % EDGE_PAN_MARGIN_PX,
		"}",
	])


## The canonical document with the eight required keys in REVERSE spec order and two of them broken —
## one early in the spec table, one late — so document order and spec order genuinely disagree.
func _reversed_document_text() -> String:
	var lines: Array[String] = ["{", '  "id": "%s",' % CAMERA_ID]
	var values: Dictionary = {
		"min_pitch_deg": "\"nope\"",
		"max_pitch_deg": "%d" % int(MAX_PITCH_DEG),
		"min_zoom_m": "%d" % int(MIN_ZOOM_M),
		"max_zoom_m": "%d" % int(MAX_ZOOM_M),
		"pan_speed_mps": "%d" % int(PAN_SPEED_MPS),
		"orbit_speed_dps": "%d" % int(ORBIT_SPEED_DPS),
		"zoom_speed_mps": "\"nope\"",
		"edge_pan_margin_px": "%d" % EDGE_PAN_MARGIN_PX,
	}
	for i: int in range(SPEC_KEYS.size()):
		var key: String = SPEC_KEYS[SPEC_KEYS.size() - 1 - i]
		var raw: Variant = values[key]
		var value_text: String = str(raw)
		var suffix: String = "" if i == SPEC_KEYS.size() - 1 else ","
		lines.append('  "%s": %s%s' % [key, value_text, suffix])
	lines.append("}")
	return _joined(lines)


## Joins source lines with newlines through a PackedStringArray, which is what String.join takes.
func _joined(source_lines: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for line: String in source_lines:
		packed.append(line)
	return "\n".join(packed)


## The canonical document with one top-level key's VALUE replaced verbatim — one planted defect per
## fixture, with the key's own line number preserved.
func _with_value(key: String, value_text: String) -> String:
	return _replace_value(_camera_text(), key, value_text)


## `_with_value` on an ARBITRARY document, so two mutations can be layered for the zoom-band fixture.
func _replace_value(text: String, key: String, value_text: String) -> String:
	var lines: Array[String] = []
	var replaced: int = 0
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with('"%s":' % key):
			var suffix: String = "," if line.strip_edges().ends_with(",") else ""
			lines.append('  "%s": %s%s' % [key, value_text, suffix])
			replaced += 1
		else:
			lines.append(line)
	assert_eq(replaced, 1, "sanity: the fixture carries exactly one top-level \"%s\" line" % key)
	return _joined(lines)


## The canonical document with the whole top-level key `key` DELETED, repairing the trailing comma so
## the result is still valid JSON — the defect must be a MISSING KEY, not a syntax error.
func _without_line(key: String) -> String:
	var kept: Array[String] = []
	var dropped: int = 0
	for line: String in _camera_text().split("\n"):
		if line.strip_edges().begins_with('"%s":' % key):
			dropped += 1
			continue
		kept.append(line)
	assert_eq(dropped, 1, "sanity: the fixture carries exactly one top-level \"%s\" line" % key)

	var last_value_at: int = -1
	for i: int in range(kept.size()):
		var stripped: String = kept[i].strip_edges()
		if stripped != "{" and stripped != "}":
			last_value_at = i
	if last_value_at != -1 and kept[last_value_at].ends_with(","):
		kept[last_value_at] = kept[last_value_at].substr(0, kept[last_value_at].length() - 1)
	return _joined(kept)


## 1-based line number of the first line carrying the JSON key token `"key"`, or 1 when the key is
## absent entirely — never a magic constant (decisions.md M0-T2 item 7).
func _line_of(text: String, key: String) -> int:
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")
	for i: int in range(lines.size()):
		if lines[i].contains('"%s"' % key):
			return i + 1
	return 1


## Rendered errors, for readable failure messages.
func _error_lines(rig: CameraRig) -> Array[String]:
	var out: Array[String] = []
	for error: RulesError in rig.errors:
		out.append(error.format_for(SOURCE))
	return out


## A content file, read verbatim; the empty string when it is MISSING (the assertion that names it
## belongs to the calling test, so the failure reads as a content failure, not a helper crash).
func _shipped_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## A content file, parsed — so its values are read from the DOCUMENT, independently of any loader.
func _parsed_json(path: String) -> Dictionary:
	var json: JSON = JSON.new()
	assert_eq(json.parse(_shipped_text(path)), OK, "§13.6: %s must be valid JSON" % path)
	var data: Variant = json.data
	if not (data is Dictionary):
		assert_true(false, "§13.6: %s must be a JSON object" % path)
		return {}
	var root: Dictionary = data
	return root


## A Variant known to be a JSON number, as a [float]; NAN when it is not one, so a malformed document
## fails an equality assertion rather than aborting the run. Assigning through a typed local first is
## mandatory — handing a Variant straight to a typed parameter is a hard PARSE error, which in a test
## file silently un-collects the WHOLE file.
func _numeric(value: Variant) -> float:
	if value is float:
		var as_float: float = value
		return as_float
	if value is int:
		var as_int: int = value
		return float(as_int)
	return NAN


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


## Every top-level public `var` declared by a source file, in source order, so an EXTRA public field
## fails the scan.
func _collect_public_vars(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw_line: String in _raw_text(path).split("\n"):
		if not raw_line.begins_with("var "):
			continue
		var rest: String = raw_line.substr(4)
		var cut: int = rest.length()
		for token: String in [":", "=", " "]:
			var at: int = rest.find(token)
			if at != -1 and at < cut:
				cut = at
		var declared: String = rest.substr(0, cut)
		if not declared.begins_with("_"):
			out.append(declared)
	return out


## Reads a source file verbatim, comments included.
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
