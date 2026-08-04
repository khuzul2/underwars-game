## MapRenderer + data/render/terrain_palette.json — GDD §10 ("Rock rendered as chunked
## MultiMeshInstance3D (per-instance custom data = type/tint); dirty-chunk rebuilds on dig";
## "Greybox first. All MVP visuals are flat-shaded prisms and capsules"), §4.1 ("**Flat-top hexes,
## axial coordinates (q, r)**"; "Elevation: integer 0-3 per hex"; the map-size table), §4.2 (the
## nine Solid type ids), §1.2 ("Hex scale ~ 15-20 m (cosmetic only)"), §11.1 (data -> Sim Core ->
## EventBus -> Renderer/UI; the sim never calls the renderer), §11.2 (`scripts/render/`), §11.3,
## §13.2 tier 1, §13.4, §13.6, §14 M1 ("chunked MultiMesh renderer").
##
## WHAT THIS FILE PINS, transcribed verbatim from `docs/GAME_DESIGN.md`:
##   §10 line 680:  "Rock rendered as chunked MultiMeshInstance3D (per-instance custom data =
##                  type/tint); dirty-chunk rebuilds on dig. Target: Medium map at 60 fps on
##                  mid-range hardware; SDFGI off."
##   §10 line 678:  "Greybox first. All MVP visuals are flat-shaded prisms and capsules with
##                  faction palette tints ..." — the hex PRISM this task draws.
##   §10 line 679:  the Lit/Dark SHADER tint is M3, NOT this task; custom-data alpha stays 1.0,
##                  reserved for it.
##   §4.1 line 171: "**Flat-top hexes, axial coordinates (q, r)**; cube coordinates for
##                  algorithms. Distance = cube distance. Neighbor order (fixed, index 0-5): E,
##                  NE, NW, W, SW, SE." — flat-top is already realised by HexLayout (M1-T6 (V));
##                  the six names stay INDEX LABELS ONLY (M1-T1 (A)) and NO sim value moves here.
##   §4.1 line 173: "**Elevation:** integer 0-3 per hex."
##   §4.1 line 174: "Map sizes (hex radius): Small 24 (1,801 hexes), Medium 32 (3,169), Large 40
##                  (4,921)." — used here ONLY as test fixtures; the six literals stay FORBIDDEN
##                  in engine code (M1-T1 item 4).
##   §4.2 lines 178-193: the NINE Solid types — Soft Dirt, Hard Rock, Dense Granite, Artificial
##                  Granite, Rubble, Gold Vein, Iron Vein, Magestone Crust, Mithril Seam.
##
## `docs/decisions.md` was re-scanned end to end this iteration: **NO logged override touches
## §1.2, §4.1, §4.2 or §10**, so the printed text above governs unamended. The lettering genuinely
## ended at **(Z)** in the M1-T6 entry, so this file continues at **(AA)**:
##   (AA) ONE MultiMeshInstance3D child per chunk, added in HexLayout.chunk_keys() canonical order
##        (M1-T6 (X): ascending chunk-r then chunk-q, matching HexMap's (O) hex order), named
##        "chunk_%d_%d" % [key.x, key.y].
##   (AB) TOTALITY. build() requires a configured HexLayout AND a successfully loaded palette AND a
##        non-null map with hex_count() > 0; otherwise zero children, empty chunk_keys(), empty
##        flush_dirty(). Any palette error leaves the palette UNLOADED, including a failed load
##        after a successful one.
##   (AC) PER-INSTANCE DATA IS WRITTEN, NEVER READ BACK (see (Z) below). Instance transform origin
##        = layout.hex_to_world(hex, map.get_elevation(hex)) with an identity basis, in
##        MapRenderer-local space; custom data = tint_for(map.get_terrain_type(hex)) with alpha 1.0
##        reserved for §10 line 679's M3 Lit/Dark shader tint.
##   (AD) ONE shared CylinderMesh (radial_segments 6; top_radius = bottom_radius =
##        layout.hex_width_m() / 2; height = layout.elevation_step_m()) and ONE shared
##        StandardMaterial3D across every chunk. Sharing is what keeps a 3,169-hex Medium map
##        viable at §10's 60 fps target.
##   (AE) mark_hex_dirty(hex) marks layout.chunk_of(hex) only if that chunk was BUILT (else a
##        silent no-op); flush_dirty(map) rebuilds ONLY marked chunks, IN PLACE (same nodes, same
##        MultiMesh objects), returns their keys in canonical order and clears the dirty set.
##   (AF) PALETTE LOAD CONTRACT mirrors MapGenerator's (P) / HexLayout's (Y) exactly and REUSES
##        `RulesError` — line 0 reserved for missing/unreadable files, schema errors carry the
##        top-level key's own 1-based line (fallback 1), error order from the loader's declared
##        key-spec order (fallback_rgb -> tints), unknown extra top-level keys load clean, and ANY
##        error leaves the palette UNLOADED.
##   (AG) The nine tints + the fallback are NEW tunable CONTENT (§10 prints only FACTION palettes,
##        never terrain tints), so no GDD cell moves; §4.2's vocabulary stays un-whitelisted in
##        engine code and is pinned BY TEST here.
##   (AH) At M1 every in-bounds hex is drawn as solid rock; cave-hex culling arrives with M2's dig.
##
## ============================ (Z) IS BINDING ON EVERY ASSERTION BELOW ============================
## decisions.md M1-T6 **(Z)**, measured live on the pinned repo-local Godot 4.7 console binary:
## under `--headless` the dummy renderer **DOES NOT STORE MultiMesh instance data**.
## `set_instance_transform(0, T)` then `get_instance_transform(0)` returns the **identity**;
## `set_instance_custom_data(0, c)` reads back **(0, 0, 0, 1)**; `MultiMesh.buffer` is **size 0**
## even with `instance_count = 3`. Re-measured again this iteration, same result. So EVERY
## assertion in this file is **STRUCTURAL**: instance_count, transform_format, use_custom_data,
## use_colors, mesh != null, resource properties, get_class(), node parenting/naming/order and
## get_instance_id(). **NEVER read an instance transform or custom datum back** — such a test can
## only ever pass vacuously. The placement math itself is already pinned by
## `tests/unit/test_hex_layout.gd`; that is exactly why slice 1 exists, and it is not re-tested
## through a MultiMesh here. That per-instance data is written AT ALL is pinned the only way
## headless allows: by requiring the two setter tokens in the source scan (section H).
## ===============================================================================================
##
## Also measured live this iteration and worth not re-deriving: `MultiMesh`'s DEFAULT
## `transform_format` is TRANSFORM_2D (0), so asserting TRANSFORM_3D (1) is meaningful; `use_colors`
## and `use_custom_data` both default to **false**; and toggling `use_custom_data` AFTER
## `instance_count` has been set is refused by the engine ("Instance count must be 0 to toggle
## whether custom data is used"), so the format must be configured BEFORE the count.
##
## SCOPE (§13.4: invent nothing ahead of its milestone). This task is the renderer NODE only.
## `scenes/Main.tscn`, the CameraRig, SDFGI-off and the MANUAL WINDOWED 60-fps measurement on the
## Medium map (radius 32 / 3,169 hexes) are **M1-T8**; hex picking is **M1-T9**. §14 M1's "60 fps
## on Medium map greybox" criterion therefore REMAINS NOT MET after this task, and per (Z) it is
## not headless-measurable at all. No Camera3D, no WorldEnvironment, no `.tscn`, no EventBus
## subscription and no shader appears here or in the file under test.
##
## §13.6 clauses that are VACUOUS here, stated rather than assumed: MapRenderer mutates no
## GameState, constructs no Command and touches no EventBus, so "events emitted for every state
## change" has no subject matter. Goldens: NONE re-recorded — the project's single golden
## (`tests/golden/mapgen_concentric_bowl_small_seed1337.json`, content_hash 0xcad24923) is not
## touched, and section E proves this renderer cannot move it.
##
## Godot 4.7 JSON facts this file depends on, already measured (decisions.md M0-T2 item 8, do not
## re-derive): `JSON.get_error_line()` is 0-BASED (the loader normalizes +1); the parser ACCEPTS
## trailing commas, so they are useless as a syntax-error fixture; EVERY JSON number arrives as
## TYPE_FLOAT, even `128` — so an int leaf must ACCEPT an integral float and REJECT a fractional
## one, never truncate.
##
## TRAP (M0-T2 item 11 / M0-T5 item (a)): a statically-decidable `is` test parse-errors and
## silently un-collects the WHOLE file. Class kind is asserted via get_class() ONLY — and note that
## a MapRenderer **IS a Node by design**, so this file's scans are written FRESH and are NOT
## `test_hex_layout.gd`'s engine-bound token list.
##
## HARNESS TRAP (decisions.md M1-T5 item 9, standing rule): `tools/run_tests.sh` greps the WHOLE
## run output for "Nothing was run" / "does not exist" / "have not been imported" / "Failed to load
## script" / "Ignoring script". No failure message in this file may contain any of them — this file
## says "is MISSING".
extends GutTest

const RENDERER_PATH: String = "res://scripts/render/map_renderer.gd"
const PALETTE_PATH: String = "res://data/render/terrain_palette.json"
const MISSING_PALETTE_PATH: String = "res://data/render/__no_such_terrain_palette__.json"
const GREYBOX_PATH: String = "res://data/render/greybox.json"
const MAPGEN_PATH: String = "res://data/mapgen/concentric_bowl.json"
const SOURCE: String = "terrain_palette.json"

const TOL: float = 0.000001

# ---------------------------------------------------------------------------------------------
# §4.2 lines 178-193 — the NINE Solid type ids, in the printed table's own order, snake_cased
# exactly as `data/mapgen/concentric_bowl.json` already spells them. `artificial_granite` and
# `rubble` are included deliberately: the concentric-bowl generator never emits them, so only this
# list keeps §4.2's vocabulary complete. There must be NO terrain-type whitelist in engine code
# (EventBus resolution (f) / M1-T5 precedent) — section H forbids every one of these ids in
# `map_renderer.gd`, so the vocabulary is pinned BY TEST and by content, never by an enum.
# ---------------------------------------------------------------------------------------------
const SOLID_TYPE_IDS: Array[String] = [
	"soft_dirt",
	"hard_rock",
	"dense_granite",
	"artificial_granite",
	"rubble",
	"gold_vein",
	"iron_vein",
	"magestone_crust",
	"mithril_seam",
]

## (AG) — the shipped greybox tint per §4.2 type, parallel to [constant SOLID_TYPE_IDS]. NEW
## tunable content: §10 prints FACTION palettes (Dwarf bronze/teal, Elf violet/black, Goblin
## lime/rust, Orc crimson/bone) and never a terrain tint, so no GDD cell moves.
const TINT_RGB: Array[Vector3i] = [
	Vector3i(138, 109, 74),
	Vector3i(112, 112, 118),
	Vector3i(78, 78, 86),
	Vector3i(96, 104, 112),
	Vector3i(134, 128, 118),
	Vector3i(201, 162, 39),
	Vector3i(124, 100, 84),
	Vector3i(96, 84, 168),
	Vector3i(176, 214, 226),
]

## (AG) — the tint an id outside the palette resolves to. Distinct from every shipped tint.
const FALLBACK_RGB: Vector3i = Vector3i(128, 128, 128)

## The shipped document's `"id"` — an unknown EXTRA top-level key as far as the loader's spec table
## is concerned (M0-T2 item 5), exactly like `greybox.json`'s.
const PALETTE_ID: String = "greybox_terrain"

## The loader's declared key-spec order. Error ORDER must come from this table, never from the
## parsed Dictionary's key order (AF).
const SPEC_KEYS: Array[String] = ["fallback_rgb", "tints"]

## RGB channel bounds — the byte range a tint component must lie in.
const RGB_MIN: int = 0
const RGB_MAX: int = 255
const RGB_COMPONENTS: int = 3

# ---------------------------------------------------------------------------------------------
# Map fixtures. §4.1 line 174's radii are TEST fixtures only (the six literals stay forbidden in
# engine code). The radius-3 map is the hand-checkable one: 37 hexes across exactly four chunks at
# the shipped chunk edge, one per quadrant of the origin.
# ---------------------------------------------------------------------------------------------
const TINY_RADIUS: int = 3
const TINY_HEX_COUNT: int = 37
const SMALL_RADIUS: int = 24
const SMALL_HEX_COUNT: int = 1801

const FIXTURE_RADII: Array[int] = [TINY_RADIUS, SMALL_RADIUS]
const FIXTURE_HEX_COUNTS: Array[int] = [TINY_HEX_COUNT, SMALL_HEX_COUNT]

## (AD) — a hexagonal prism has six sides. A MATHEMATICAL constant (the SQRT_3 / FNV precedent,
## decisions.md M1-T5 item 7), so it is a named const in the `.gd` and NOT a §13.6 violation.
const RADIAL_SEGMENTS: int = 6

## Two hexes of the radius-3 map that share chunk (0, 0), and one in each of the two extreme
## chunks. All four are re-checked against `HexMap.is_in_bounds` before use.
const SAME_CHUNK_HEXES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
const FIRST_CHUNK_HEX: Vector2i = Vector2i(-1, -1)
const LAST_CHUNK_HEX: Vector2i = Vector2i(0, 0)

## Far outside both the radius-3 disc AND any chunk the radius-3 build creates, so (AE)'s
## chunk-level no-op and the off-disc case agree and nothing ambiguous is pinned.
const UNBUILT_CHUNK_HEX: Vector2i = Vector2i(100, 100)

# ---------------------------------------------------------------------------------------------
# Source-scan vocabularies (§11.1, §11.2, §11.3, §13.6). WRITTEN FRESH — a MapRenderer IS a Node by
# design, so `test_hex_layout.gd`'s engine-bound list is deliberately NOT pasted here.
# ---------------------------------------------------------------------------------------------

## §11.1 — engine-bound is legal in `scripts/render/`, non-determinism is not. `randi(`/`randf(`/
## `randomize(` and `RandomNumberGenerator` stay forbidden project-wide outside
## `scripts/core/rng.gd` (decisions.md M1-T5 (R)); wall-clock, frame-time and SceneTree lookups are
## forbidden because §11.1 bans them as inputs; `MapGenerator` and the two sim MUTATORS are
## forbidden because the renderer reads the map and never writes it; `queue_free(` is forbidden
## because it defers to the next frame and would double a same-frame rebuild's children.
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
	"MapGenerator",
	"set_elevation(",
	"set_terrain_type(",
	"queue_free(",
]

## The other direction: what the file MUST contain. The last three are the only headless-available
## evidence that per-instance data is written at all — (Z) makes reading it back impossible.
##
## `Basis(Vector3.UP` is the FLAT-TOP CORRECTION YAW added at M1-T8 (resolving M1-T7 item 16):
## Godot 4.7's [CylinderMesh] lays its radial vertices at {0, +/-60, +/-120, 180} degrees measured
## from +Z toward +X — a vertex on +Z and NONE on +X — so an identity-basis instance is exactly
## half a segment away from the flat-top orientation HexLayout's (V) placement needs, and the field
## tiles with visible triangular gaps and overlapping slivers. (Z) makes the resulting instance
## basis unreadable headless (M1-T8 probe P7: reverting the yaw broke ZERO tests), so this token is
## the ONLY automated guard against that regression silently returning; the tiling itself is
## verifiable only in the windowed run.
const REQUIRED_TOKENS: Array[String] = [
	"extends Node3D",
	"HexLayout",
	"HexMap",
	"RulesError",
	"MultiMeshInstance3D",
	"hex_to_world(",
	"partition(",
	"chunk_of(",
	"get_elevation(",
	"get_terrain_type(",
	"set_instance_transform(",
	"set_instance_custom_data(",
	"Basis(Vector3.UP",
]

## §4.1 line 174 — radii and hex counts are content, never engine code.
const MAP_SIZE_TOKENS: Array[String] = ["24", "32", "40", "1801", "3169", "4921"]

## The COMPLETE public function surface (§13.4: no camera, no picking, no EventBus subscription, no
## shader, no mesh-builder entry point — those are M1-T8/M1-T9/M3).
const REQUIRED_PUBLIC_FUNCTIONS: Array[String] = [
	"load_palette_text",
	"load_palette_file",
	"tint_for",
	"set_layout",
	"build",
	"chunk_keys",
	"mark_hex_dirty",
	"flush_dirty",
]

## The COMPLETE public field surface — the existing shared error type, and nothing else.
const REQUIRED_PUBLIC_VARS: Array[String] = ["errors"]

## Doc-comment sections accepted by the §11.3 scan for this file.
const DOC_SECTIONS: Array[String] = ["§4.1", "§4.2", "§10", "§11.1", "§11.2"]


# =============================================================================================
# A. THE PRINTED GDD TEXT, THE SHIPPED CONTENT, AND THE SELF-CHECK OF EVERY PINNED NUMBER
# =============================================================================================

## The mechanical re-derivation demanded by the M1-T1 item 3 / M1-T6 standing rule: every fixture
## number pinned in this file is recomputed here from an INDEPENDENT source, so a typo in the table
## fails HERE rather than being blamed on the implementation.
func test_the_pinned_fixtures_are_self_consistent() -> void:
	assert_eq(SOLID_TYPE_IDS.size(), 9, "§4.2: the printed Solid table has nine type ids")
	assert_eq(TINT_RGB.size(), SOLID_TYPE_IDS.size(), "sanity: the tint table is parallel")

	var seen: Dictionary = {}
	for type_id: String in SOLID_TYPE_IDS:
		assert_false(type_id.is_empty(), "§4.2: no Solid type id is empty")
		assert_false(seen.has(type_id), "§4.2: type id %s appears once" % type_id)
		seen[type_id] = true

	var out_of_range: Array[String] = []
	for i: int in range(TINT_RGB.size()):
		var rgb: Vector3i = TINT_RGB[i]
		for component: int in [rgb.x, rgb.y, rgb.z]:
			if component < RGB_MIN or component > RGB_MAX:
				out_of_range.append("%s has component %d" % [SOLID_TYPE_IDS[i], component])
	for component: int in [FALLBACK_RGB.x, FALLBACK_RGB.y, FALLBACK_RGB.z]:
		if component < RGB_MIN or component > RGB_MAX:
			out_of_range.append("fallback has component %d" % component)
	assert_eq(out_of_range.size(), 0, "(AG): every tint component is a byte 0-255; %s" % [
		str(out_of_range)
	])

	assert_eq(
		HexMath.hex_count_for_radius(TINY_RADIUS),
		TINY_HEX_COUNT,
		"sanity: the hand-checkable radius-3 fixture is 37 hexes"
	)
	assert_eq(
		HexMath.hex_count_for_radius(SMALL_RADIUS),
		SMALL_HEX_COUNT,
		"§4.1 line 174: Small radius 24 is 1,801 hexes"
	)
	assert_eq(
		RADIAL_SEGMENTS,
		HexMath.DIRECTIONS.size(),
		"(AD): a hex prism has one side per §4.1 direction"
	)
	assert_eq(FIXTURE_RADII.size(), FIXTURE_HEX_COUNTS.size(), "sanity: the radius table is parallel")


## §4.2/(AG) — the shipped content file transcribes the nine tints and the fallback, read from the
## DOCUMENT itself rather than through the loader, so a content edit is caught even if the loader
## agrees with it.
func test_the_shipped_palette_file_transcribes_the_pinned_tints() -> void:
	var root: Dictionary = _parsed_json(PALETTE_PATH)
	assert_eq(str(root.get("id", "")), PALETTE_ID, "(AG): the shipped palette id")
	assert_eq(
		_rgb_of(root.get("fallback_rgb", null)),
		FALLBACK_RGB,
		"(AG): the shipped fallback_rgb"
	)

	var rows: Array = _array_of(root.get("tints", null))
	assert_eq(rows.size(), SOLID_TYPE_IDS.size(), "§4.2: the palette carries one row per Solid type")
	var wrong: Array[String] = []
	for i: int in range(mini(rows.size(), SOLID_TYPE_IDS.size())):
		var row: Variant = rows[i]
		if not (row is Dictionary):
			wrong.append("row %d is not an object" % i)
			continue
		var entry: Dictionary = row
		if str(entry.get("type", "")) != SOLID_TYPE_IDS[i]:
			wrong.append("row %d is %s, expected %s" % [
				i, str(entry.get("type", "")), SOLID_TYPE_IDS[i]
			])
			continue
		if _rgb_of(entry.get("rgb", null)) != TINT_RGB[i]:
			wrong.append("%s is %s, expected %s" % [
				SOLID_TYPE_IDS[i], str(_rgb_of(entry.get("rgb", null))), str(TINT_RGB[i])
			])
	assert_eq(wrong.size(), 0, "(AG): the shipped palette matches the pinned table in order; %s" % [
		str(wrong)
	])


## §4.2 — ALL NINE Solid type ids have a tint, INCLUDING `artificial_granite` (Dwarf-built, §7.1)
## and `rubble` (the result of collapses), which the concentric-bowl generator never emits. §4.2's
## vocabulary is pinned here and by content, never by a whitelist in engine code.
func test_every_one_of_the_nine_section_4_2_solid_types_has_a_tint() -> void:
	var ids: Array[String] = _shipped_palette_ids()
	var missing: Array[String] = []
	for type_id: String in SOLID_TYPE_IDS:
		if not ids.has(type_id):
			missing.append(type_id)
	assert_eq(missing.size(), 0, "§4.2: every printed Solid type needs a tint; absent: %s" % [
		str(missing)
	])
	assert_true(
		ids.has("artificial_granite"),
		"§4.2: artificial_granite is a Solid type even though the generator never emits it"
	)
	assert_true(
		ids.has("rubble"),
		"§4.2: rubble is a Solid type even though the generator never emits it"
	)


## decisions.md M0-T2 item 7 — the shipped file's layout is LOAD-BEARING, not cosmetic: line 1 is a
## lone `{` and every top-level key starts exactly one line, which is the only reason schema-error
## line attribution is meaningful and every expected line below is COMPUTED from the fixture.
func test_the_shipped_palette_file_layout_is_line_addressable() -> void:
	var lines: PackedStringArray = _shipped_text(PALETTE_PATH).replace("\r\n", "\n").split("\n")
	assert_true(lines.size() >= 3, "M0-T2 item 7: the palette file has a line-addressable layout")
	assert_eq(lines[0].strip_edges(), "{", "M0-T2 item 7: line 1 is a lone opening brace")
	for key: String in SPEC_KEYS:
		var hits: int = 0
		for line: String in lines:
			if line.strip_edges().begins_with('"%s":' % key):
				hits += 1
		assert_eq(hits, 1, "M0-T2 item 7: \"%s\" starts exactly one line of %s" % [key, PALETTE_PATH])


## The in-file fixture and the shipped content are the SAME document, so every rejection fixture
## below really is "the shipped file plus exactly one planted defect" (the M1-T6 precedent).
func test_the_canonical_fixture_matches_the_shipped_palette_file() -> void:
	assert_eq(
		_shipped_text(PALETTE_PATH).replace("\r\n", "\n").strip_edges(),
		_palette_text().strip_edges(),
		"the in-test palette fixture must equal the shipped %s byte for byte" % PALETTE_PATH
	)


# =============================================================================================
# B. THE PALETTE LOAD CONTRACT — resolution (AF), mirroring MapGenerator's (P) / HexLayout's (Y)
#    and REUSING `RulesError` rather than inventing a second line-numbered error type.
# =============================================================================================

## (AF) — the shipped file loads clean and every one of the nine tints resolves.
func test_the_shipped_palette_file_loads_clean_and_resolves_every_tint() -> void:
	var renderer: MapRenderer = _bare_renderer()
	var ok: bool = renderer.load_palette_file(PALETTE_PATH)
	assert_true(ok, "(AF): %s must load: %s" % [PALETTE_PATH, str(_error_lines(renderer))])
	assert_eq(_error_lines(renderer), [] as Array[String], "(AF): a valid document yields no errors")

	var wrong: Array[String] = []
	for i: int in range(SOLID_TYPE_IDS.size()):
		var observed: Color = renderer.tint_for(SOLID_TYPE_IDS[i])
		if not _color_matches(observed, TINT_RGB[i]):
			wrong.append("%s -> %s, expected %s" % [
				SOLID_TYPE_IDS[i], str(observed), str(TINT_RGB[i])
			])
	assert_eq(wrong.size(), 0, "(AG): tint_for resolves every §4.2 type; %s" % [str(wrong)])


## (AG)/§10 line 679 — the spot checks stated as their own values, and the ALPHA contract: custom
## data's alpha stays 1.0, reserved for M3's Lit/Dark shader tint.
func test_tint_for_returns_the_pinned_colours_with_alpha_reserved_at_one() -> void:
	var renderer: MapRenderer = _renderer()
	assert_true(
		_color_matches(renderer.tint_for("soft_dirt"), Vector3i(138, 109, 74)),
		"(AG): soft_dirt is (138, 109, 74), got %s" % str(renderer.tint_for("soft_dirt"))
	)
	assert_true(
		_color_matches(renderer.tint_for("gold_vein"), Vector3i(201, 162, 39)),
		"(AG): gold_vein is (201, 162, 39), got %s" % str(renderer.tint_for("gold_vein"))
	)
	assert_true(
		_color_matches(renderer.tint_for("mithril_seam"), Vector3i(176, 214, 226)),
		"(AG): mithril_seam is (176, 214, 226), got %s" % str(renderer.tint_for("mithril_seam"))
	)
	for type_id: String in SOLID_TYPE_IDS:
		assert_almost_eq(
			renderer.tint_for(type_id).a,
			1.0,
			TOL,
			"§10 line 679/(AC): alpha stays 1.0, reserved for M3's Lit/Dark shader tint (%s)" % type_id
		)


## (AF) — an id outside the palette, and the EMPTY id a fresh `HexMap` hex reads back (M1-T4 (O)),
## both resolve to the fallback rather than to black, to garbage or to an abort.
func test_an_unknown_and_an_empty_type_id_both_resolve_to_the_fallback() -> void:
	var renderer: MapRenderer = _renderer()
	assert_true(
		_color_matches(renderer.tint_for("no_such_terrain"), FALLBACK_RGB),
		"(AF): an unknown id resolves to the fallback, got %s" % [
			str(renderer.tint_for("no_such_terrain"))
		]
	)
	assert_true(
		_color_matches(renderer.tint_for(""), FALLBACK_RGB),
		"(AF): the empty id a fresh HexMap hex carries resolves to the fallback, got %s" % [
			str(renderer.tint_for(""))
		]
	)


## §13.6 "constants read from data, not code", PROVEN BY MUTATION rather than only by a token scan:
## retune soft_dirt in the document TEXT and the resolved tint must move with it.
func test_a_tint_is_read_from_data_not_shadowed_by_a_code_literal() -> void:
	var retuned: Vector3i = Vector3i(1, 2, 3)
	var rows: Array[String] = _default_rows()
	rows[0] = _row(SOLID_TYPE_IDS[0], _rgb_text(retuned))

	var renderer: MapRenderer = _bare_renderer()
	var ok: bool = renderer.load_palette_text(_palette_text_with_rows(rows), SOURCE)
	assert_true(ok, "§13.6: a retuned palette must load: %s" % str(_error_lines(renderer)))
	assert_true(
		_color_matches(renderer.tint_for(SOLID_TYPE_IDS[0]), retuned),
		"§13.6: %s must come from the document, got %s" % [
			SOLID_TYPE_IDS[0], str(renderer.tint_for(SOLID_TYPE_IDS[0]))
		]
	)
	assert_true(
		_color_matches(renderer.tint_for(SOLID_TYPE_IDS[1]), TINT_RGB[1]),
		"§13.6: retuning one row must not disturb its neighbours"
	)


## §13.6 — the same proof for the fallback: retune `fallback_rgb` in TEXT and the unknown-id result
## must move with it.
func test_the_fallback_is_read_from_data_not_shadowed_by_a_code_literal() -> void:
	var retuned: Vector3i = Vector3i(7, 11, 13)
	var renderer: MapRenderer = _bare_renderer()
	var ok: bool = renderer.load_palette_text(
		_with_value("fallback_rgb", _rgb_text(retuned)), SOURCE
	)
	assert_true(ok, "§13.6: a retuned fallback must load: %s" % str(_error_lines(renderer)))
	assert_true(
		_color_matches(renderer.tint_for("no_such_terrain"), retuned),
		"§13.6: the fallback must come from the document, got %s" % [
			str(renderer.tint_for("no_such_terrain"))
		]
	)


## M0-T2 item 2 — line 0 is RESERVED for missing/unreadable files, and a missing file is EXACTLY one
## error. (The message says "is MISSING": the harness refuses on other phrasings.)
func test_a_missing_palette_file_is_one_file_level_error_on_line_zero() -> void:
	var renderer: MapRenderer = _bare_renderer()
	var ok: bool = renderer.load_palette_file(MISSING_PALETTE_PATH)
	assert_false(ok, "(AF): a palette file that is MISSING must not load")
	assert_eq(renderer.errors.size(), 1, "(AF): a missing file is exactly one error: %s" % [
		str(_error_lines(renderer))
	])
	if renderer.errors.size() == 1:
		assert_eq(
			renderer.errors[0].line,
			0,
			"M0-T2 item 2: line 0 is reserved for missing/unreadable files"
		)
	_assert_palette_unloaded(renderer, "missing file")


## (AF) — the canonical text is accepted, so every rejection fixture below differs from a VALID
## document by exactly one planted defect.
func test_the_canonical_palette_text_is_accepted() -> void:
	var renderer: MapRenderer = _bare_renderer()
	var ok: bool = renderer.load_palette_text(_palette_text(), SOURCE)
	assert_true(ok, "(AF): the canonical text must load: %s" % str(_error_lines(renderer)))
	assert_eq(_error_lines(renderer), [] as Array[String], "(AF): a valid document yields no errors")


## (AF) + M0-T2 item 8 — a JSON syntax error carries a 1-BASED line (Godot's `get_error_line()` is
## 0-based and must be normalized), never the reserved 0. A trailing comma is useless as a fixture
## on this engine, so an unquoted bareword is planted instead — and the trailing-comma fact is
## re-pinned in the same test so no future author re-derives it wrongly.
func test_reject_malformed_json_with_a_one_based_line() -> void:
	var renderer: MapRenderer = _bare_renderer()
	var ok: bool = renderer.load_palette_text(
		_with_value("fallback_rgb", "[grey, grey, grey]"), SOURCE
	)
	assert_false(ok, "(AF): malformed JSON must not load")
	assert_true(renderer.errors.size() >= 1, "(AF): malformed JSON reports at least one error")
	if renderer.errors.size() >= 1:
		assert_true(
			renderer.errors[0].line >= 1,
			"M0-T2 item 2/8: a syntax error carries a 1-based line, never the reserved 0 (got %d)" % [
				renderer.errors[0].line
			]
		)
		assert_true(
			renderer.errors[0].format_for(SOURCE).begins_with("%s:" % SOURCE),
			"M0-T2 item 6: errors render as '<source>:<line>: <message>'"
		)
	_assert_palette_unloaded(renderer, "malformed JSON")

	var tolerant: MapRenderer = _bare_renderer()
	assert_true(
		tolerant.load_palette_text(_palette_text().replace("]\n}", "],\n}"), SOURCE),
		"M0-T2 item 8: Godot 4.7 ACCEPTS trailing commas, so they are useless as a syntax fixture"
	)


## (AF) — the document root must be a JSON object; a top-level array is a whole-document failure at
## line 1 (never the reserved 0).
func test_reject_a_root_that_is_not_a_json_object() -> void:
	var renderer: MapRenderer = _bare_renderer()
	var ok: bool = renderer.load_palette_text('["greybox_terrain"]', SOURCE)
	assert_false(ok, "(AF): a non-object root must not load")
	assert_eq(renderer.errors.size(), 1, "(AF): a bad root is exactly one error: %s" % [
		str(_error_lines(renderer))
	])
	if renderer.errors.size() == 1:
		assert_eq(renderer.errors[0].line, 1, "(AF): a bad root is attributed to line 1, never 0")
	_assert_palette_unloaded(renderer, "root is not an object")


## (AF) — both top-level keys are REQUIRED. With the key deleted outright nothing carries its token,
## so the error falls back to line 1 (never the reserved 0).
func test_reject_a_document_missing_either_required_key() -> void:
	for key: String in SPEC_KEYS:
		_assert_palette_rejected(_without_line(key), key, 1, "missing \"%s\"" % key)


## (AF) — `tints` must be a NON-EMPTY array: an empty palette would silently paint the whole map
## the fallback colour, which is a content bug the loader must refuse rather than render.
func test_reject_a_tints_key_that_is_not_a_non_empty_array() -> void:
	var not_an_array: String = _with_value("tints", '"soft_dirt"')
	_assert_palette_rejected(
		not_an_array, "tints", _line_of(not_an_array, "tints"), "tints is a string"
	)
	var empty: String = _with_value("tints", "[]")
	_assert_palette_rejected(empty, "tints", _line_of(empty, "tints"), "tints is empty")


## (AF) — `fallback_rgb` is an RGB TRIPLE of whole bytes: not a string, not the wrong length, not
## fractional and never outside 0-255.
func test_reject_a_malformed_fallback_rgb() -> void:
	var fixtures: Array[String] = [
		'"grey"',
		"[128, 128]",
		"[128, 128, 128, 255]",
		"[128.5, 128, 128]",
		'["128", 128, 128]',
		"[256, 128, 128]",
		"[-1, 128, 128]",
	]
	for value_text: String in fixtures:
		var text: String = _with_value("fallback_rgb", value_text)
		_assert_palette_rejected(
			text,
			"fallback_rgb",
			_line_of(text, "fallback_rgb"),
			"fallback_rgb is %s" % value_text
		)


## (AF) — every tint ROW is an object carrying a non-empty, UNIQUE `type` id. Row errors attribute
## to the `tints` key's own line, exactly as MapGenerator's composition errors attribute to the
## `composition` line (resolution (P)).
func test_reject_a_malformed_tint_row() -> void:
	var canonical: String = _palette_text()
	var tints_line: int = _line_of(canonical, "tints")

	var not_an_object: Array[String] = _default_rows()
	not_an_object[0] = '"soft_dirt"'
	_assert_palette_rejected(
		_palette_text_with_rows(not_an_object), "tints", tints_line, "a row is not an object"
	)

	var no_type: Array[String] = _default_rows()
	no_type[0] = '{"rgb": [138, 109, 74]}'
	_assert_palette_rejected(
		_palette_text_with_rows(no_type), "tints", tints_line, "a row has no \"type\""
	)

	var empty_type: Array[String] = _default_rows()
	empty_type[0] = _row("", _rgb_text(TINT_RGB[0]))
	_assert_palette_rejected(
		_palette_text_with_rows(empty_type), "tints", tints_line, "a row has an empty \"type\""
	)

	var numeric_type: Array[String] = _default_rows()
	numeric_type[0] = '{"type": 7, "rgb": [138, 109, 74]}'
	_assert_palette_rejected(
		_palette_text_with_rows(numeric_type), "tints", tints_line, "a \"type\" is not a string"
	)

	var duplicated: Array[String] = _default_rows()
	duplicated.append(_row(SOLID_TYPE_IDS[0], _rgb_text(Vector3i(1, 2, 3))))
	_assert_palette_rejected(
		_palette_text_with_rows(duplicated), "tints", tints_line, "a \"type\" is duplicated"
	)


## (AF) + M0-T2 item 8 — a row's `rgb` is an RGB triple of whole bytes. EVERY Godot 4.7 JSON number
## arrives as TYPE_FLOAT, so an integral float is ACCEPTED and a fractional one REJECTED, never
## truncated to 128.
func test_reject_a_malformed_row_rgb_but_accept_integral_floats() -> void:
	var canonical: String = _palette_text()
	var tints_line: int = _line_of(canonical, "tints")

	var fixtures: Array[String] = [
		'{"type": "soft_dirt"}',
		'{"type": "soft_dirt", "rgb": "brown"}',
		'{"type": "soft_dirt", "rgb": [138, 109]}',
		'{"type": "soft_dirt", "rgb": [138, 109, 74, 255]}',
		'{"type": "soft_dirt", "rgb": [128.5, 109, 74]}',
		'{"type": "soft_dirt", "rgb": ["138", 109, 74]}',
		'{"type": "soft_dirt", "rgb": [256, 109, 74]}',
		'{"type": "soft_dirt", "rgb": [-1, 109, 74]}',
	]
	for row_text: String in fixtures:
		var rows: Array[String] = _default_rows()
		rows[0] = row_text
		_assert_palette_rejected(
			_palette_text_with_rows(rows), "tints", tints_line, "row %s" % row_text
		)

	var integral: Array[String] = _default_rows()
	integral[0] = '{"type": "soft_dirt", "rgb": [138.0, 109.0, 74.0]}'
	var renderer: MapRenderer = _bare_renderer()
	var ok: bool = renderer.load_palette_text(_palette_text_with_rows(integral), SOURCE)
	assert_true(ok, "M0-T2 item 8: an integral float is a valid byte leaf: %s" % [
		str(_error_lines(renderer))
	])
	assert_true(
		_color_matches(renderer.tint_for(SOLID_TYPE_IDS[0]), TINT_RGB[0]),
		"M0-T2 item 8: 138.0 reads back as 138"
	)


## (AF)/M0-T2 item 5 — §12.1's forward-compatibility precedent: an unknown EXTRA top-level key is
## not an error. The shipped `"id"` is exactly such a key.
func test_an_unknown_extra_top_level_key_loads_clean() -> void:
	var renderer: MapRenderer = _bare_renderer()
	var text: String = _palette_text().replace(
		'"id": "%s",' % PALETTE_ID, '"id": "%s", "future_tunable": 7,' % PALETTE_ID
	)
	assert_ne(text, _palette_text(), "sanity: the extra key really was planted")
	var ok: bool = renderer.load_palette_text(text, SOURCE)
	assert_true(ok, "M0-T2 item 5: an unknown extra key is not an error: %s" % [
		str(_error_lines(renderer))
	])
	assert_true(
		_color_matches(renderer.tint_for(SOLID_TYPE_IDS[0]), TINT_RGB[0]),
		"M0-T2 item 5: the known keys still load"
	)


## (AF)/§11.1 — error ORDER is deterministic and follows the loader's OWN declared key-spec order
## (`fallback_rgb` then `tints`), never the parsed Dictionary's. The fixture presents the two keys
## in the OPPOSITE order and breaks BOTH, so the reported order can only come from the spec table;
## the error LINES therefore come out descending, which is the visible proof.
func test_error_order_follows_the_loaders_key_spec_order_not_the_documents() -> void:
	var text: String = _joined([
		"{",
		'  "id": "%s",' % PALETTE_ID,
		'  "tints": "nope",',
		'  "fallback_rgb": [128, 128]',
		"}",
	])
	var renderer: MapRenderer = _bare_renderer()
	var ok: bool = renderer.load_palette_text(text, SOURCE)
	assert_false(ok, "(AF): a document with both keys broken must not load")
	assert_true(
		renderer.errors.size() >= SPEC_KEYS.size(),
		"(AF): ALL errors are collected, never just the first: %s" % str(_error_lines(renderer))
	)

	var order: Array[String] = []
	var zero_lines: int = 0
	var off_document: int = 0
	var document_lines: PackedStringArray = text.split("\n")
	for error: RulesError in renderer.errors:
		if not order.has(error.path):
			order.append(error.path)
		if error.line == 0:
			zero_lines += 1
		if error.line < 1 or error.line > document_lines.size():
			off_document += 1
	assert_eq(zero_lines, 0, "M0-T2 item 2: a schema error may never carry the reserved line 0")
	assert_eq(off_document, 0, "(AF): every error line lies inside the document")
	assert_eq(
		order,
		SPEC_KEYS,
		"(AF)/§11.1: error order is the loader's spec order %s, not the document's" % [str(SPEC_KEYS)]
	)

	var fallback_line: int = _line_of(text, "fallback_rgb")
	var tints_line: int = _line_of(text, "tints")
	assert_true(
		fallback_line > tints_line,
		"sanity: this fixture really presents the keys in the OPPOSITE order (%d vs %d)" % [
			fallback_line, tints_line
		]
	)
	_assert_palette_unloaded(renderer, "both keys broken")


## (AB)/(AF) — a failed load AFTER a successful one still leaves the palette UNLOADED: a half-valid
## palette can never be read, stale tints can never survive, and `build` consequently draws nothing.
func test_a_failed_load_after_a_successful_one_leaves_the_palette_unloaded() -> void:
	var renderer: MapRenderer = _bare_renderer()
	assert_true(renderer.load_palette_file(PALETTE_PATH), "sanity: the shipped file loads first")
	assert_true(
		_color_matches(renderer.tint_for(SOLID_TYPE_IDS[0]), TINT_RGB[0]),
		"sanity: the first load populated the palette"
	)

	var ok: bool = renderer.load_palette_text(_without_line("tints"), SOURCE)
	assert_false(ok, "(AF): the second, defective load must fail")
	_assert_palette_unloaded(renderer, "failed load after a successful one")


# =============================================================================================
# C. THE CHUNK NODE STRUCTURE — resolutions (AA)/(AC)/(AD), §10 line 680
#    STRUCTURAL ONLY, per (Z). Nothing below reads an instance transform or a custom datum.
# =============================================================================================

## (AA)/§10 — one MultiMeshInstance3D child per HexLayout chunk, in the canonical (X) order,
## named "chunk_<q>_<r>". The ORACLE is HexLayout itself, never a magic count.
func test_build_creates_one_named_multimesh_chunk_node_per_layout_chunk() -> void:
	var layout: HexLayout = _layout()
	for radius: int in FIXTURE_RADII:
		var map: HexMap = HexMap.new(radius)
		var renderer: MapRenderer = _renderer()
		renderer.build(map)

		var expected: Array[Vector2i] = layout.chunk_keys(map.hexes())
		assert_true(
			expected.size() > 1,
			"sanity: radius %d must be genuinely chunked, got %d key(s)" % [radius, expected.size()]
		)
		assert_eq(
			renderer.get_child_count(),
			expected.size(),
			"(AA): radius %d needs one chunk node per layout chunk" % radius
		)
		assert_eq(
			renderer.chunk_keys(),
			expected,
			"(AA)/(X): radius %d chunk keys must equal HexLayout's, element for element" % radius
		)

		var wrong_name: Array[String] = []
		var wrong_class: Array[String] = []
		for i: int in range(mini(renderer.get_child_count(), expected.size())):
			var child: Node = renderer.get_child(i)
			var child_name: String = child.name
			var wanted: String = "chunk_%d_%d" % [expected[i].x, expected[i].y]
			if child_name != wanted:
				wrong_name.append("child %d is '%s', expected '%s'" % [i, child_name, wanted])
			if child.get_class() != "MultiMeshInstance3D":
				wrong_class.append("child %d is a %s" % [i, child.get_class()])
		assert_eq(wrong_name.size(), 0, "(AA): chunk nodes are named chunk_<q>_<r>; %s" % [
			str(wrong_name.slice(0, 5))
		])
		assert_eq(wrong_class.size(), 0, "§10: every chunk node is a MultiMeshInstance3D; %s" % [
			str(wrong_class.slice(0, 5))
		])

		var out_of_order: Array[String] = []
		var keys: Array[Vector2i] = renderer.chunk_keys()
		for i: int in range(1, keys.size()):
			if not _chunk_less(keys[i - 1], keys[i]):
				out_of_order.append("%s then %s" % [str(keys[i - 1]), str(keys[i])])
		assert_eq(out_of_order.size(), 0, "(AA)/(X): keys ascend by chunk-r then chunk-q; %s" % [
			str(out_of_order.slice(0, 5))
		])


## §11.2 — MapRenderer is the Node half of the renderer and lives where §11.2 lists it. Asserted
## through get_class(): a statically-decidable `is` test parse-errors and silently un-collects the
## whole file (M0-T2 item 11 / M0-T5 (a)).
func test_map_renderer_is_a_node3d_in_scripts_render() -> void:
	assert_true(
		FileAccess.file_exists(RENDERER_PATH),
		"§11.2: MapRenderer lives at %s" % RENDERER_PATH
	)
	assert_true(
		FileAccess.file_exists(PALETTE_PATH),
		"(AG): the terrain tints live at %s" % PALETTE_PATH
	)
	var renderer: MapRenderer = _bare_renderer()
	assert_eq(renderer.get_class(), "Node3D", "§11.2: MapRenderer is the renderer's Node half")


## §10 — EVERY hex reaches the renderer, exactly once. This is the only headless pin available for
## that, since (Z) forbids reading the instances back: per chunk the instance count must equal
## HexLayout's own bucket size, and the counts must sum to the map's hex count.
func test_every_hex_is_drawn_exactly_once_across_the_chunks() -> void:
	var layout: HexLayout = _layout()
	for i: int in range(FIXTURE_RADII.size()):
		var radius: int = FIXTURE_RADII[i]
		var map: HexMap = HexMap.new(radius)
		assert_eq(map.hex_count(), FIXTURE_HEX_COUNTS[i], "sanity: radius %d is %d hexes" % [
			radius, FIXTURE_HEX_COUNTS[i]
		])
		var renderer: MapRenderer = _renderer()
		renderer.build(map)

		var buckets: Array[PackedInt32Array] = layout.partition(map.hexes())
		assert_eq(
			renderer.get_child_count(),
			buckets.size(),
			"(AA): radius %d has one chunk node per bucket" % radius
		)
		var total: int = 0
		var wrong: Array[String] = []
		for c: int in range(mini(renderer.get_child_count(), buckets.size())):
			var mm: MultiMesh = _multimesh(renderer, c)
			if mm == null:
				wrong.append("chunk %d carries no MultiMesh" % c)
				continue
			total += mm.instance_count
			if mm.instance_count != buckets[c].size():
				wrong.append("chunk %d holds %d instance(s), expected %d" % [
					c, mm.instance_count, buckets[c].size()
				])
		assert_eq(wrong.size(), 0, "§10: each chunk draws exactly its own bucket; %s" % [
			str(wrong.slice(0, 5))
		])
		assert_eq(
			total,
			map.hex_count(),
			"§10/(AH): radius %d draws every in-bounds hex exactly once" % radius
		)


## §10 line 680 ("per-instance custom data = type/tint") — the MultiMesh FORMAT. Measured live: the
## default `transform_format` is TRANSFORM_2D and `use_custom_data`/`use_colors` both default to
## false, so all four assertions are meaningful rather than tautological.
func test_every_chunk_multimesh_declares_the_required_format() -> void:
	var renderer: MapRenderer = _renderer()
	renderer.build(HexMap.new(TINY_RADIUS))
	assert_true(renderer.get_child_count() > 0, "sanity: the radius-3 build produced chunk nodes")

	var wrong: Array[String] = []
	for c: int in range(renderer.get_child_count()):
		var mm: MultiMesh = _multimesh(renderer, c)
		if mm == null:
			wrong.append("chunk %d carries no MultiMesh" % c)
			continue
		if mm.transform_format != MultiMesh.TRANSFORM_3D:
			wrong.append("chunk %d transform_format is %d" % [c, mm.transform_format])
		if not mm.use_custom_data:
			wrong.append("chunk %d has use_custom_data off" % c)
		if mm.use_colors:
			wrong.append("chunk %d has use_colors on" % c)
		if mm.mesh == null:
			wrong.append("chunk %d has no mesh assigned" % c)
	assert_eq(
		wrong.size(),
		0,
		"§10: 3D transforms + per-instance custom data (type/tint), no per-instance colours; %s" % [
			str(wrong.slice(0, 5))
		]
	)


## (AD)/§10 — the 60-fps-relevant pin: ONE shared prism mesh and ONE shared material across every
## chunk, whatever the map size. A radius-24 build must allocate exactly 1 mesh and 1 material,
## never 1,801 and never one per chunk.
func test_all_chunks_share_one_prism_mesh_and_one_material() -> void:
	var layout: HexLayout = _layout()
	for radius: int in FIXTURE_RADII:
		var renderer: MapRenderer = _renderer()
		renderer.build(HexMap.new(radius))
		assert_true(renderer.get_child_count() > 0, "sanity: radius %d produced chunks" % radius)

		var mesh_ids: Dictionary = {}
		var material_ids: Dictionary = {}
		var missing: Array[String] = []
		for c: int in range(renderer.get_child_count()):
			var mm: MultiMesh = _multimesh(renderer, c)
			if mm == null or mm.mesh == null:
				missing.append("chunk %d" % c)
				continue
			mesh_ids[mm.mesh.get_instance_id()] = true
			var prism: PrimitiveMesh = mm.mesh as PrimitiveMesh
			if prism == null or prism.material == null:
				missing.append("chunk %d mesh has no material" % c)
				continue
			material_ids[prism.material.get_instance_id()] = true
		assert_eq(missing.size(), 0, "(AD): every chunk has a mesh and a material; %s" % [
			str(missing.slice(0, 5))
		])
		assert_eq(mesh_ids.size(), 1, "(AD): radius %d must allocate exactly ONE mesh, got %d" % [
			radius, mesh_ids.size()
		])
		assert_eq(
			material_ids.size(),
			1,
			"(AD): radius %d must allocate exactly ONE material, got %d" % [radius, material_ids.size()]
		)

	var probe: MapRenderer = _renderer()
	probe.build(HexMap.new(TINY_RADIUS))
	var first: MultiMesh = _multimesh(probe, 0)
	assert_not_null(first, "sanity: chunk 0 carries a MultiMesh")
	if first == null:
		return
	var cylinder: CylinderMesh = first.mesh as CylinderMesh
	assert_not_null(cylinder, "§10 line 678/(AD): the greybox rock is a hex PRISM (CylinderMesh)")
	if cylinder == null:
		return
	assert_eq(cylinder.get_class(), "CylinderMesh", "(AD): the shared mesh is a CylinderMesh")
	assert_eq(cylinder.radial_segments, RADIAL_SEGMENTS, "(AD): a hex prism has six sides")
	assert_almost_eq(
		cylinder.top_radius,
		layout.hex_width_m() / 2.0,
		TOL,
		"(AD)/(W): the prism radius is the layout's circumradius, read from data"
	)
	assert_almost_eq(
		cylinder.bottom_radius,
		layout.hex_width_m() / 2.0,
		TOL,
		"(AD): a prism, not a cone — top and bottom radii agree"
	)
	assert_almost_eq(
		cylinder.height,
		layout.elevation_step_m(),
		TOL,
		"(AD)/(W): the prism is one elevation step tall, read from data"
	)
	var material: Material = cylinder.material
	assert_not_null(
		material,
		"(AD): the shared prism carries the shared material on the MESH itself, not per instance"
	)
	if material != null:
		assert_eq(
			material.get_class(),
			"StandardMaterial3D",
			"§10 line 678: greybox visuals are FLAT-SHADED prisms on a StandardMaterial3D"
		)


## §10 — a rebuild in the SAME FRAME is idempotent. This is the test that goes red if the
## implementation calls `queue_free()` on the old chunk nodes: that is deferred to the next frame,
## GUT's assertions run synchronously, and the children would appear DOUBLED. Asserted immediately,
## with no `await` anywhere.
func test_rebuilding_in_the_same_frame_is_idempotent() -> void:
	var renderer: MapRenderer = _renderer()
	var map: HexMap = HexMap.new(TINY_RADIUS)

	renderer.build(map)
	var first_count: int = renderer.get_child_count()
	var first_names: Array[String] = _child_names(renderer)
	var first_keys: Array[Vector2i] = renderer.chunk_keys()
	assert_true(first_count > 0, "sanity: the first build produced chunk nodes")

	renderer.build(map)
	assert_eq(
		renderer.get_child_count(),
		first_count,
		"§10: a same-frame rebuild must REPLACE the chunk nodes, never accumulate them"
	)
	assert_eq(_child_names(renderer), first_names, "(AA): the rebuilt chunk names and order match")
	assert_eq(renderer.chunk_keys(), first_keys, "(AA): the rebuilt chunk keys and order match")


# =============================================================================================
# D. DIRTY-CHUNK REBUILDS — resolution (AE), §10 line 680 ("dirty-chunk rebuilds on dig")
# =============================================================================================

## (AE) — marking one hex dirties exactly its own chunk, and flushing CLEARS the set.
func test_marking_one_hex_flushes_exactly_its_own_chunk_once() -> void:
	var layout: HexLayout = _layout()
	var map: HexMap = HexMap.new(TINY_RADIUS)
	var renderer: MapRenderer = _renderer()
	renderer.build(map)

	var hex: Vector2i = SAME_CHUNK_HEXES[0]
	assert_true(map.is_in_bounds(hex), "sanity: %s is on the radius-3 disc" % str(hex))
	renderer.mark_hex_dirty(hex)

	var expected: Array[Vector2i] = [layout.chunk_of(hex)]
	assert_eq(renderer.flush_dirty(map), expected, "(AE): a dirty hex flushes exactly its own chunk")
	assert_eq(
		renderer.flush_dirty(map),
		[] as Array[Vector2i],
		"(AE): flushing CLEARS the dirty set — an immediate second flush rebuilds nothing"
	)


## (AE)/(X) — the ORDER PIN. Marking runs LAST-chunk-first, so a flush that returned marking order
## would be visibly wrong; the canonical (X) order (chunk-r then chunk-q) is what must come back.
func test_flush_returns_the_canonical_order_not_the_marking_order() -> void:
	var layout: HexLayout = _layout()
	var map: HexMap = HexMap.new(TINY_RADIUS)
	var renderer: MapRenderer = _renderer()
	renderer.build(map)

	assert_true(map.is_in_bounds(FIRST_CHUNK_HEX), "sanity: the first-chunk hex is on the disc")
	assert_true(map.is_in_bounds(LAST_CHUNK_HEX), "sanity: the last-chunk hex is on the disc")
	var last_key: Vector2i = layout.chunk_of(LAST_CHUNK_HEX)
	var first_key: Vector2i = layout.chunk_of(FIRST_CHUNK_HEX)
	assert_true(
		_chunk_less(first_key, last_key),
		"sanity: %s really precedes %s in the canonical order" % [str(first_key), str(last_key)]
	)

	renderer.mark_hex_dirty(LAST_CHUNK_HEX)
	renderer.mark_hex_dirty(FIRST_CHUNK_HEX)
	assert_eq(
		renderer.flush_dirty(map),
		[first_key, last_key] as Array[Vector2i],
		"(AE)/(X): flush returns canonical (chunk-r then chunk-q) order, not marking order"
	)


## (AE) — two hexes in the SAME chunk collapse to ONE key: the dirty set is a set of CHUNKS, so a
## 64-hex dig designation costs one rebuild, not 64.
func test_two_hexes_in_one_chunk_collapse_to_a_single_dirty_key() -> void:
	var layout: HexLayout = _layout()
	var map: HexMap = HexMap.new(TINY_RADIUS)
	var renderer: MapRenderer = _renderer()
	renderer.build(map)

	var a: Vector2i = SAME_CHUNK_HEXES[0]
	var b: Vector2i = SAME_CHUNK_HEXES[1]
	assert_true(map.is_in_bounds(a) and map.is_in_bounds(b), "sanity: both hexes are on the disc")
	assert_eq(
		layout.chunk_of(a),
		layout.chunk_of(b),
		"sanity: %s and %s really share a chunk" % [str(a), str(b)]
	)
	renderer.mark_hex_dirty(a)
	renderer.mark_hex_dirty(b)
	assert_eq(
		renderer.flush_dirty(map),
		[layout.chunk_of(a)] as Array[Vector2i],
		"(AE): two hexes in one chunk are ONE dirty key"
	)


## (AE)/M1-T1 (B) spirit — TOTALITY. A hex whose chunk was never built is a silent no-op: no crash,
## no phantom key, no aborted headless run. (The hex chosen is off the disc AND outside every chunk
## the radius-3 build created, so nothing ambiguous is pinned here.)
func test_marking_a_hex_in_an_unbuilt_chunk_is_a_silent_no_op() -> void:
	var layout: HexLayout = _layout()
	var map: HexMap = HexMap.new(TINY_RADIUS)
	var renderer: MapRenderer = _renderer()
	renderer.build(map)

	assert_false(map.is_in_bounds(UNBUILT_CHUNK_HEX), "sanity: the probe hex is off the disc")
	assert_false(
		renderer.chunk_keys().has(layout.chunk_of(UNBUILT_CHUNK_HEX)),
		"sanity: the probe hex's chunk %s was never built" % str(layout.chunk_of(UNBUILT_CHUNK_HEX))
	)
	renderer.mark_hex_dirty(UNBUILT_CHUNK_HEX)
	assert_eq(
		renderer.flush_dirty(map),
		[] as Array[Vector2i],
		"(AE): marking an unbuilt chunk is a silent no-op"
	)
	assert_eq(
		renderer.get_child_count(),
		renderer.chunk_keys().size(),
		"(AE): a no-op mark never creates a chunk node"
	)


## (AE)/(AB) — flushing before ANY build is empty, not an abort.
func test_flushing_before_any_build_is_empty() -> void:
	var renderer: MapRenderer = _renderer()
	assert_eq(
		renderer.flush_dirty(HexMap.new(TINY_RADIUS)),
		[] as Array[Vector2i],
		"(AB): nothing is built, so nothing can be dirty"
	)
	assert_eq(renderer.get_child_count(), 0, "(AB): a flush never builds chunks by itself")


## (AE) — a dirty rebuild refills the MultiMesh IN PLACE: every chunk node survives with the same
## object identity, so no node churn (and no dangling reference held by a future CameraRig or
## picking layer) can happen on a dig.
func test_a_dirty_flush_preserves_every_chunk_node_identity() -> void:
	var map: HexMap = HexMap.new(TINY_RADIUS)
	var renderer: MapRenderer = _renderer()
	renderer.build(map)

	var before_nodes: Array[int] = _child_ids(renderer)
	var before_multimeshes: Array[int] = _multimesh_ids(renderer)
	assert_true(before_nodes.size() > 0, "sanity: the build produced chunk nodes")

	renderer.mark_hex_dirty(SAME_CHUNK_HEXES[0])
	var flushed: Array[Vector2i] = renderer.flush_dirty(map)
	assert_eq(flushed.size(), 1, "sanity: exactly one chunk was dirty")
	assert_eq(_child_ids(renderer), before_nodes, "(AE): a dirty flush REUSES the chunk nodes")
	assert_eq(
		_multimesh_ids(renderer),
		before_multimeshes,
		"(AE): a dirty flush refills the SAME MultiMesh objects in place"
	)
	assert_eq(_child_names(renderer).size(), before_nodes.size(), "(AE): no chunk node was added")


## (AE)/§4.2 — a terrain TYPE change moves a tint, never a count: the instance counts per chunk are
## byte-identical across the dig-shaped mutate-mark-flush cycle M2 will drive.
func test_a_terrain_type_change_never_moves_an_instance_count() -> void:
	var map: HexMap = HexMap.new(TINY_RADIUS)
	var renderer: MapRenderer = _renderer()
	renderer.build(map)
	var before: Array[int] = _instance_counts(renderer)
	assert_true(before.size() > 0, "sanity: the build produced chunk nodes")

	var hex: Vector2i = SAME_CHUNK_HEXES[0]
	map.set_terrain_type(hex, SOLID_TYPE_IDS[5])
	renderer.mark_hex_dirty(hex)
	var flushed: Array[Vector2i] = renderer.flush_dirty(map)
	assert_eq(flushed.size(), 1, "sanity: exactly one chunk was dirty")
	assert_eq(
		_instance_counts(renderer),
		before,
		"(AE): a type change changes a TINT, never an instance count"
	)


# =============================================================================================
# E. THE RENDERER NEVER MUTATES THE SIM — §11.1 (data -> Sim Core -> EventBus -> Renderer/UI)
# =============================================================================================

## §11.1 — the boundary held in the mirror-image direction, proven by CONTENT HASH rather than by
## inspection: building, marking and flushing leave `HexMap.content_hash()` byte-identical. This is
## also what guarantees the M1-T5 golden (0xcad24923) cannot move on a renderer commit.
func test_building_and_flushing_never_mutate_the_map() -> void:
	for radius: int in FIXTURE_RADII:
		var map: HexMap = HexMap.new(radius)
		var before: int = map.content_hash()
		var renderer: MapRenderer = _renderer()

		renderer.build(map)
		assert_eq(map.content_hash(), before, "§11.1: radius %d — build() mutates no sim state" % radius)

		renderer.mark_hex_dirty(SAME_CHUNK_HEXES[0])
		assert_eq(
			map.content_hash(),
			before,
			"§11.1: radius %d — mark_hex_dirty() mutates no sim state" % radius
		)

		var flushed: Array[Vector2i] = renderer.flush_dirty(map)
		assert_eq(flushed.size(), 1, "sanity: radius %d had exactly one dirty chunk" % radius)
		assert_eq(
			map.content_hash(),
			before,
			"§11.1: radius %d — flush_dirty() mutates no sim state" % radius
		)
		assert_eq(map.hex_count(), HexMath.hex_count_for_radius(radius), "§11.1: the map still stands")


# =============================================================================================
# F. TOTALITY — resolution (AB). An unconfigured renderer draws NOTHING; it never half-builds.
# =============================================================================================

## (AB) — build() needs a layout AND a loaded palette AND a non-empty map. Each of the five
## incomplete configurations draws nothing at all: no children, no keys, nothing to flush.
func test_an_unconfigured_renderer_draws_nothing() -> void:
	var map: HexMap = HexMap.new(TINY_RADIUS)

	_assert_draws_nothing(_bare_renderer(), map, "no layout and no palette")

	var layout_only: MapRenderer = _bare_renderer()
	layout_only.set_layout(_layout())
	_assert_draws_nothing(layout_only, map, "layout but no palette")

	var palette_only: MapRenderer = _bare_renderer()
	assert_true(palette_only.load_palette_file(PALETTE_PATH), "sanity: the shipped palette loads")
	_assert_draws_nothing(palette_only, map, "palette but no layout")

	_assert_draws_nothing(_renderer(), null, "configured but a null map")
	_assert_draws_nothing(_renderer(), HexMap.new(-1), "configured but a negative-radius map")


# =============================================================================================
# G. CROSS-FILE COVERAGE — §13.6. A generator content change that outruns the palette goes RED.
# =============================================================================================

## §4.4/§4.2 — every terrain type the shipped `data/mapgen/concentric_bowl.json` can emit has a
## tint in `data/render/terrain_palette.json`. Both files are parsed HERE, independently of both
## loaders, so adding a type to the generator without a tint fails this test rather than silently
## painting the map its fallback grey.
func test_every_generated_terrain_type_has_a_palette_entry() -> void:
	var palette_ids: Array[String] = _shipped_palette_ids()
	assert_true(palette_ids.size() > 0, "sanity: the shipped palette carries tints")

	var generated: Array[String] = []
	var root: Dictionary = _parsed_json(MAPGEN_PATH)
	var composition: Array = _array_of(root.get("composition", null))
	assert_true(composition.size() > 0, "sanity: the generator document carries a composition table")
	for band_entry: Variant in composition:
		if not (band_entry is Dictionary):
			continue
		var band: Dictionary = band_entry
		for weight_entry: Variant in _array_of(band.get("weights", null)):
			if not (weight_entry is Dictionary):
				continue
			var weight: Dictionary = weight_entry
			var type_id: String = str(weight.get("type", ""))
			if not type_id.is_empty() and not generated.has(type_id):
				generated.append(type_id)
	assert_true(generated.size() > 0, "sanity: the composition table names terrain types")

	var uncovered: Array[String] = []
	var unknown: Array[String] = []
	for type_id: String in generated:
		if not palette_ids.has(type_id):
			uncovered.append(type_id)
		if not SOLID_TYPE_IDS.has(type_id):
			unknown.append(type_id)
	assert_eq(uncovered.size(), 0, "§13.6: every generated type needs a tint; uncovered: %s" % [
		str(uncovered)
	])
	assert_eq(unknown.size(), 0, "§4.2: the generator emits only printed Solid types; stray: %s" % [
		str(unknown)
	])


# =============================================================================================
# H. MECHANICAL SOURCE SCANS ON scripts/render/map_renderer.gd — WRITTEN FRESH.
#    A MapRenderer IS a Node by design, so `test_hex_layout.gd`'s engine-bound token list is NOT
#    pasted here. Comment stripping is LOAD-BEARING: the doc block quotes the very tokens being
#    scanned for (it cites "§4.1", which a naive numeric regex would hit).
# =============================================================================================

## S1 §11.1 — engine-bound is legal in `scripts/render/`; NON-DETERMINISM is not, and neither is
## reaching into the sim to MUTATE it. `queue_free(` is forbidden for the same-frame reason section
## C pins behaviourally.
func test_source_holds_no_forbidden_token() -> void:
	var code: String = _code_text(RENDERER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RENDERER_PATH)
	for banned: String in FORBIDDEN_TOKENS:
		assert_false(
			code.contains(banned),
			"§11.1/§13.6: %s must not contain %s" % [RENDERER_PATH, banned]
		)


## S2 §11.1/§10 — the other direction. The last two tokens are the ONLY headless-available evidence
## that per-instance transforms and custom data are written at all: (Z) makes reading them back
## impossible, so their absence could otherwise never be detected before M1-T8's windowed run.
func test_source_carries_every_required_token() -> void:
	var code: String = _code_text(RENDERER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RENDERER_PATH)
	for required: String in REQUIRED_TOKENS:
		assert_true(
			code.contains(required),
			"§10/§11.1: %s must contain %s" % [RENDERER_PATH, required]
		)


## S3 §4.2/§13.6 — there is NO terrain-type whitelist in engine code (the EventBus resolution (f)
## and M1-T5 precedent): type ids are opaque strings to the renderer and the vocabulary lives in
## `data/render/terrain_palette.json`, pinned by section A instead.
func test_source_carries_no_terrain_type_whitelist() -> void:
	var code: String = _code_text(RENDERER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RENDERER_PATH)
	for type_id: String in SOLID_TYPE_IDS:
		assert_false(
			code.contains(type_id),
			"§4.2/§13.6: terrain ids are content — %s must not name %s" % [RENDERER_PATH, type_id]
		)


## S4 §4.1 line 174 / §13.6 — the map radii and hex counts are content, never engine code, in the
## renderer's Node half exactly as in its pure half and in the sim.
func test_source_carries_no_map_size_constant() -> void:
	var code: String = _code_text(RENDERER_PATH)
	assert_false(code.is_empty(), "sanity: %s must be readable and non-empty" % RENDERER_PATH)
	var number: RegEx = RegEx.new()
	assert_eq(
		number.compile("\\b(24|32|40|1801|3169|4921)\\b"),
		OK,
		"sanity: the map-size pattern compiles"
	)
	var hit: RegExMatch = number.search(code)
	assert_null(
		hit,
		"§4.1/§13.6: map sizes are content — %s must not hard-code %s" % [
			RENDERER_PATH, "" if hit == null else hit.get_string()
		]
	)
	assert_eq(MAP_SIZE_TOKENS.size(), 6, "sanity: all three §4.1 radii and their counts are covered")


## S5 §11.3 ("public rule functions documented with the GDD section they implement"), tightened the
## M1-T2 item 11 / M1-T6 way: the expected public surface is listed EXPLICITLY, so a MISSING member
## fails instead of passing vacuously and an EXTRA member (a camera hook, a picking entry point, an
## EventBus subscription, a shader setter — all §13.4 violations at M1-T7) fails too.
func test_public_api_is_exactly_the_eight_documented_functions() -> void:
	var public_functions: Array[String] = []
	var undocumented: Array[String] = []
	_collect_public_functions(RENDERER_PATH, public_functions, undocumented)

	var renderer: MapRenderer = _bare_renderer()
	for required: String in REQUIRED_PUBLIC_FUNCTIONS:
		assert_true(
			public_functions.has(required),
			"§11.2: %s must be a public function of %s" % [required, RENDERER_PATH]
		)
		assert_true(
			renderer.has_method(required),
			"§11.2: %s must be callable on a MapRenderer instance" % required
		)
	assert_eq(
		public_functions.size(),
		REQUIRED_PUBLIC_FUNCTIONS.size(),
		"§13.4: the public API of %s is exactly %s — found %s" % [
			RENDERER_PATH, str(REQUIRED_PUBLIC_FUNCTIONS), str(public_functions)
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
		_collect_public_vars(RENDERER_PATH),
		REQUIRED_PUBLIC_VARS,
		"§13.4: the public field surface of %s is exactly %s" % [
			RENDERER_PATH, str(REQUIRED_PUBLIC_VARS)
		]
	)


# =============================================================================================
# Helpers (never start with test_)
# =============================================================================================

## A [HexLayout] configured from the SHIPPED `data/render/greybox.json`, so every geometry
## expectation in this file is derived from content rather than from a test literal.
func _layout() -> HexLayout:
	var layout: HexLayout = HexLayout.new()
	var ok: bool = layout.load_params_file(GREYBOX_PATH)
	assert_true(ok, "§13.6: %s must load for the renderer fixtures" % GREYBOX_PATH)
	return layout


## A MapRenderer with NOTHING configured, registered for automatic freeing so no orphan Node
## survives the test.
func _bare_renderer() -> MapRenderer:
	var renderer: MapRenderer = MapRenderer.new()
	autofree(renderer)
	return renderer


## A fully configured MapRenderer: the shipped layout and the shipped palette.
func _renderer() -> MapRenderer:
	var renderer: MapRenderer = _bare_renderer()
	renderer.set_layout(_layout())
	var ok: bool = renderer.load_palette_file(PALETTE_PATH)
	assert_true(ok, "(AF): %s must load: %s" % [PALETTE_PATH, str(_error_lines(renderer))])
	return renderer


## (AB) — the "draws nothing" contract used by every totality case: no chunk nodes, no chunk keys,
## nothing to flush, and no abort.
func _assert_draws_nothing(renderer: MapRenderer, map: HexMap, label: String) -> void:
	renderer.build(map)
	assert_eq(renderer.get_child_count(), 0, "(AB) [%s]: build() must create no chunk node" % label)
	assert_eq(
		renderer.chunk_keys(),
		[] as Array[Vector2i],
		"(AB) [%s]: build() must publish no chunk key" % label
	)
	assert_eq(
		renderer.flush_dirty(map),
		[] as Array[Vector2i],
		"(AB) [%s]: nothing is built, so nothing can flush" % label
	)


## (AF) — the UNLOADED contract: every tint (known id, unknown id and the empty id alike) reads the
## black sentinel rather than the fallback, and a build consequently draws nothing even with a
## perfectly good layout and map.
func _assert_palette_unloaded(renderer: MapRenderer, label: String) -> void:
	var sentinel: Color = Color(0.0, 0.0, 0.0, 1.0)
	assert_eq(
		renderer.tint_for(SOLID_TYPE_IDS[0]),
		sentinel,
		"(AF) [%s]: an unloaded palette resolves no tint" % label
	)
	assert_eq(
		renderer.tint_for("no_such_terrain"),
		sentinel,
		"(AF) [%s]: an unloaded palette has no fallback either" % label
	)
	renderer.set_layout(_layout())
	renderer.build(HexMap.new(TINY_RADIUS))
	assert_eq(
		renderer.get_child_count(),
		0,
		"(AB) [%s]: an unloaded palette draws nothing, even with a layout and a map" % label
	)
	assert_eq(
		renderer.chunk_keys(),
		[] as Array[Vector2i],
		"(AB) [%s]: an unloaded palette publishes no chunk key" % label
	)


## Runs one rejection fixture end to end: a document differing from a VALID one by exactly one
## planted defect must be rejected with at least one 1-based error carrying the offending key's
## path at `expected_line`, must never emit the reserved line 0, and must leave the palette
## UNLOADED even though it had just loaded successfully.
func _assert_palette_rejected(text: String, key: String, expected_line: int, label: String) -> void:
	var renderer: MapRenderer = _bare_renderer()
	var loaded: bool = renderer.load_palette_text(_palette_text(), SOURCE)
	assert_true(loaded, "sanity [%s]: the un-mutated document loads first" % label)

	var ok: bool = renderer.load_palette_text(text, SOURCE)
	assert_false(ok, "(AF) [%s]: the planted defect must be rejected" % label)
	assert_true(renderer.errors.size() >= 1, "(AF) [%s]: rejection reports at least one error" % label)

	var document_lines: PackedStringArray = text.split("\n")
	var zero_lines: int = 0
	var off_document: int = 0
	var at_key: int = 0
	for error: RulesError in renderer.errors:
		if error.line == 0:
			zero_lines += 1
		if error.line < 0 or error.line > document_lines.size():
			off_document += 1
		if error.path == key and error.line == expected_line:
			at_key += 1
	assert_eq(zero_lines, 0, "M0-T2 item 2 [%s]: line 0 is reserved for missing files" % label)
	assert_eq(off_document, 0, "(AF) [%s]: every error line is inside the document" % label)
	assert_true(
		at_key >= 1,
		"(AF) [%s]: an error must carry path \"%s\" at line %d; got %s" % [
			label, key, expected_line, str(_error_lines(renderer))
		]
	)
	_assert_palette_unloaded(renderer, label)


## True when `observed` is the byte triple `rgb` with alpha exactly 1.0. Compared per channel
## against `component / 255`, so both `Color8()` and an explicit division satisfy it.
func _color_matches(observed: Color, rgb: Vector3i) -> bool:
	if absf(observed.a - 1.0) > TOL:
		return false
	if absf(observed.r - float(rgb.x) / 255.0) > TOL:
		return false
	if absf(observed.g - float(rgb.y) / 255.0) > TOL:
		return false
	return absf(observed.b - float(rgb.z) / 255.0) <= TOL


## Resolution (X)'s ordering predicate, written fresh as this file's own oracle: ascending chunk-r
## (y), then ascending chunk-q (x). Strict, so equal keys are NOT less.
func _chunk_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## The chunk node at index `i`, typed. `get_child` returns a plain Node, so the cast is explicit
## (`unsafe_cast` is a level-0 warning in this project — decisions.md M0-T4 item c).
func _chunk_node(renderer: MapRenderer, i: int) -> MultiMeshInstance3D:
	if i < 0 or i >= renderer.get_child_count():
		return null
	return renderer.get_child(i) as MultiMeshInstance3D


## The MultiMesh of chunk node `i`, or null when the node or its resource is absent.
func _multimesh(renderer: MapRenderer, i: int) -> MultiMesh:
	var node: MultiMeshInstance3D = _chunk_node(renderer, i)
	if node == null:
		return null
	return node.multimesh


## Chunk node names in child order.
func _child_names(renderer: MapRenderer) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(renderer.get_child_count()):
		var child_name: String = renderer.get_child(i).name
		out.append(child_name)
	return out


## Chunk node object identities in child order — the (AE) in-place-rebuild pin.
func _child_ids(renderer: MapRenderer) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(renderer.get_child_count()):
		out.append(renderer.get_child(i).get_instance_id())
	return out


## Chunk MultiMesh object identities in child order; -1 where a chunk carries none.
func _multimesh_ids(renderer: MapRenderer) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(renderer.get_child_count()):
		var mm: MultiMesh = _multimesh(renderer, i)
		out.append(-1 if mm == null else mm.get_instance_id())
	return out


## Per-chunk instance counts in child order; -1 where a chunk carries no MultiMesh.
func _instance_counts(renderer: MapRenderer) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(renderer.get_child_count()):
		var mm: MultiMesh = _multimesh(renderer, i)
		out.append(-1 if mm == null else mm.instance_count)
	return out


## One tint row of the palette document.
func _row(type_id: String, rgb_text: String) -> String:
	return '{"type": "%s", "rgb": %s}' % [type_id, rgb_text]


## An RGB triple rendered exactly as the shipped document spells it.
func _rgb_text(rgb: Vector3i) -> String:
	return "[%d, %d, %d]" % [rgb.x, rgb.y, rgb.z]


## The nine canonical tint rows, in §4.2's printed order.
func _default_rows() -> Array[String]:
	var rows: Array[String] = []
	for i: int in range(SOLID_TYPE_IDS.size()):
		rows.append(_row(SOLID_TYPE_IDS[i], _rgb_text(TINT_RGB[i])))
	return rows


## The canonical palette document, in the LOAD-BEARING layout `ruleset.json` established (line 1 a
## lone `{`, one top-level key per line) so every expected error line is computed, not magic.
func _palette_text_with_rows(rows: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for row: String in rows:
		packed.append(row)
	return _joined([
		"{",
		'  "id": "%s",' % PALETTE_ID,
		'  "fallback_rgb": %s,' % _rgb_text(FALLBACK_RGB),
		'  "tints": [%s]' % ", ".join(packed),
		"}",
	])


## The canonical palette document — the exact bytes the shipped content file must carry.
func _palette_text() -> String:
	return _palette_text_with_rows(_default_rows())


## Joins source lines with newlines through a PackedStringArray, which is what String.join takes.
func _joined(source_lines: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for line: String in source_lines:
		packed.append(line)
	return "\n".join(packed)


## The canonical document with one top-level key's VALUE replaced verbatim — one planted defect per
## fixture, and the key's own line number preserved.
func _with_value(key: String, value_text: String) -> String:
	var lines: Array[String] = []
	var replaced: int = 0
	for line: String in _palette_text().split("\n"):
		if line.strip_edges().begins_with('"%s":' % key):
			var suffix: String = "," if line.strip_edges().ends_with(",") else ""
			lines.append('  "%s": %s%s' % [key, value_text, suffix])
			replaced += 1
		else:
			lines.append(line)
	assert_eq(replaced, 1, "sanity: the fixture carries exactly one top-level \"%s\" line" % key)
	return _joined(lines)


## The canonical document with the whole top-level key `key` DELETED, repairing the trailing comma
## so the result is still valid JSON — the defect must be a MISSING KEY, not a syntax error.
func _without_line(key: String) -> String:
	var kept: Array[String] = []
	var dropped: int = 0
	for line: String in _palette_text().split("\n"):
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
func _error_lines(renderer: MapRenderer) -> Array[String]:
	var out: Array[String] = []
	for error: RulesError in renderer.errors:
		out.append(error.format_for(SOURCE))
	return out


## A content file, read verbatim.
func _shipped_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "§13.6: %s must be readable (it may still be MISSING)" % path)
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


## The `type` ids the SHIPPED palette file declares, in document order.
func _shipped_palette_ids() -> Array[String]:
	var out: Array[String] = []
	var root: Dictionary = _parsed_json(PALETTE_PATH)
	for row: Variant in _array_of(root.get("tints", null)):
		if not (row is Dictionary):
			continue
		var entry: Dictionary = row
		var type_id: String = str(entry.get("type", ""))
		if not type_id.is_empty():
			out.append(type_id)
	return out


## A Variant known to be a JSON array, as an [Array]; the empty array otherwise. Assigning through
## a typed local first is mandatory — handing a Variant straight to a typed parameter is a hard
## PARSE error, which in a test file means the whole file is silently un-collected.
func _array_of(value: Variant) -> Array:
	if value is Array:
		var as_array: Array = value
		return as_array
	return []


## A Variant known to be a JSON RGB triple, as a [Vector3i]; `(-1, -1, -1)` when it is not one, so a
## malformed document fails an equality assertion rather than aborting the run.
func _rgb_of(value: Variant) -> Vector3i:
	var components: Array = _array_of(value)
	if components.size() != RGB_COMPONENTS:
		return Vector3i(-1, -1, -1)
	var numbers: Array[int] = []
	for component: Variant in components:
		if component is float:
			var as_float: float = component
			numbers.append(int(as_float))
		elif component is int:
			var as_int: int = component
			numbers.append(as_int)
		else:
			return Vector3i(-1, -1, -1)
	return Vector3i(numbers[0], numbers[1], numbers[2])


## Walks a source file and fills `public_functions` with every public function name (in source
## order) and `undocumented` with those whose preceding comment block cites no DOC_SECTIONS entry.
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
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "source must be readable: %s" % path)
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
