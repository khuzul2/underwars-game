## DigTick — GDD §3.4 step 4 ("Dig progress ticks; completed digs apply yields, then **Breach
## checks** (§4.6), then **Noise pings** (§4.8)"), run per player AT THE START OF THEIR TURN.
##
## (BA) THE RULE.
##   - (BA)(iii) a site spends `digger_ids().size()` worker-turns per tick (§4.2 line 197's TOTAL
##     worker-turns — N diggers spend N per tick, never a fixed 1), applied through
##     [method DigSite.set_remaining_turns], which is TOTAL and CLAMPS into [0, total_turns] — an
##     overshoot lands on exactly 0 rather than a negative remainder or a second payout.
##   - (BA)(iv) completion = the remainder reaches 0 AFTER the decrement: the row's §4.2 yield is
##     applied to the SITE'S OWNER's stockpile (never "the current player"), the hex is flipped to
##     [method DigRules.cave_terrain_id], the site is removed from the registry and its diggers are
##     freed IMPLICITLY — assignment IS site membership, so no [UnitState] is ever touched here.
##   - (BA)(v) TWO events per moved site, `dig_progressed` then (on completion) `dig_completed` —
##     never four separate ones for the four things one completion changes.
##   - (BA)(vi) an unconfigured/null [DigRules], a null `state` or a mapless `state` runs NO pass at
##     all and returns an empty array (the [DigHexCommand] unconfigured precedent).
##   - (BA)(vii) vein NODE state (stock/rate) and Extractors stay deferred ((AW) item 4): only the
##     row's LUMP applies, and the node is dropped along with the terrain it stood on.
##
## Pure sim core (§11.1): no Node, no SceneTree, no engine singleton, no `randi()`, integer math
## only, every returned Array fresh. Iterates the snapshot [method GameState.dig_site_hexes]
## returns (r ascending, then q ascending), filtered to `player_index`'s own sites, so §11.1 line
## 707's stable-ID iteration order governs the emitted event order too. Called ONLY from
## `EndTurnCommand.apply()` (§3.4 step 4 is a turn-sequence rule, not a fourth of §11.1 line 705's
## fourteen printed Commands) — never from a Node.
##
## STILL OUT OF SCOPE at M2-T7 (§13.4): the `EventBus` -> `MapRenderer.mark_hex_dirty` seam and a
## palette tint for the Cave terrain (M2-T8); §4.2's "Dig 2x" halving
## ([method DigRules.halve_remaining_turns] has no caller yet — no ability exists); vein-node
## stock/rate and Extractors; §3.4's other eight per-player steps and its three World-phase steps,
## including this same step's Breach checks (§4.6) and Noise pings (§4.8), which are M5.
class_name DigTick
extends RefCounted

## §12.1/§4.2 — the already-loaded dig table this tick reads every number through. May be null
## (unconfigured), in which case [method tick_digs] runs no pass at all.
var _dig_rules: DigRules = null


## §12.1/§4.2 — holds an already-loaded [DigRules]; `p_dig_rules` may be null (unconfigured).
func _init(p_dig_rules: DigRules) -> void:
	_dig_rules = p_dig_rules


## §3.4 step 4/§4.2/§5.1 — ticks `player_index`'s dig sites: each site owned by `player_index`
## spends its digger count in worker-turns, and any site that reaches zero remaining applies its
## §4.2 yield to its owner, flips its hex to the Cave terrain and is removed. Totally safe: a null
## `state`, a mapless `state`, a site with no digger, AND a non-null but UNCONFIGURED [DigRules]
## (the (AL) precedent: its `cave_terrain_id()` answers "" only when unconfigured, since the real
## §12.1 leaf is a required non-empty string) all answer/tick nothing rather than crashing, writing
## a hex to "", or moving a number for free.
func tick_digs(state: GameState, player_index: int) -> Array[Event]:
	var out: Array[Event] = []
	if _dig_rules == null or state == null or state.map == null:
		return out
	if _dig_rules.cave_terrain_id().is_empty():
		return out
	for hex: Vector2i in state.dig_site_hexes():
		var site: DigSite = state.dig_site(hex)
		if site == null or site.owner_index() != player_index:
			continue
		var digger_count: int = site.digger_ids().size()
		if digger_count == 0:
			continue
		site.set_remaining_turns(site.remaining_turns() - digger_count)
		var remaining_after: int = site.remaining_turns()
		out.append(DigProgressedEvent.new(player_index, hex, digger_count, remaining_after))
		if remaining_after > 0:
			continue
		out.append(_complete(state, site, hex))
	return out


## §3.4 step 4/§4.2/§5.1 — completes a site that just reached zero: reads the terrain it still
## carries, applies every yielded resource id/amount pair to the site's owner, flips the hex to
## [method DigRules.cave_terrain_id], removes the site (freeing its diggers IMPLICITLY — no
## [UnitState] is touched) and returns the announcing [DigCompletedEvent].
func _complete(state: GameState, site: DigSite, hex: Vector2i) -> DigCompletedEvent:
	var owner_index: int = site.owner_index()
	var terrain_id: String = state.map.get_terrain_type(hex)
	var resource_ids: Array[String] = _dig_rules.yield_resource_ids(terrain_id)
	var amounts: Array[int] = []
	var holder: PlayerState = state.player(owner_index)
	for resource_id: String in resource_ids:
		var amount: int = _dig_rules.yield_amount(terrain_id, resource_id)
		amounts.append(amount)
		if holder != null:
			holder.add(resource_id, amount)
	var digger_ids: Array[int] = site.digger_ids()
	var cave_terrain_id: String = _dig_rules.cave_terrain_id()
	state.map.set_terrain_type(hex, cave_terrain_id)
	state.remove_dig_site(hex)
	return DigCompletedEvent.new(owner_index, hex, digger_ids, resource_ids, amounts, cave_terrain_id)
