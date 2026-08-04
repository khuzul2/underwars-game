# Underwars — Game Design & Implementation Document

**Version 2.0 (Agent-Ready) — supersedes v1.0** **Engine:** Godot 4.3+ (3D, GDScript) · **Genre:** Turn-based 4X / base-builder / tactical warfare · **Setting:** carved subterranean underworld **Development model:** autonomous AI coding agent with headless test loop

  

## 0\. How the AI Agent Must Use This Document

1.  **Reading order.** Read Part A (§1–§10, rules & content) once in full before writing any code. Part B (§11–§18) is the operational contract: architecture, data schemas, test loop, and the phased plan. Work strictly in milestone order (§14–§16).
2.  **Source of truth.** Where prose and a numeric table disagree, **the table wins**. All constants in §4–§8 must be transcribed into data/ruleset.json and faction JSON files — never hard-coded.
3.  **Deviations.** If implementation forces a rule change, record it in docs/decisions.md (one dated entry: what changed, why, which section it affects) and update the affected table. Never silently diverge.
4.  **Definition of done** for every task is in §13.6. No task is complete until its tests pass headless.
5.  **Numbers are baselines.** All stats are tuned baselines, expected to move during the Phase 3 balance campaign (§16.4). Correctness of *systems* matters more than perfection of *values*.
6.  **Extensibility contract.** New content must be expressible as data using the trait/ability primitives in §12.7. Adding a *new primitive* requires code + tests; adding a *unit/building/tech/faction* must require **zero code**.

  

# PART A — GAME DESIGN

## 1\. High Concept & Design Pillars

**One-liner:** A turn-based 4X where the map is solid rock and every player carves their own fortress, economy, and battlefield out of the dark — then meets the neighbors, and the things that live below.

  

**Core loop:** Dig & Expand → Harvest & Manage → Build the Cavern Settlement → Train & Arm → Explore, Raid & Conquer.

### 1.1 Design Pillars (every feature must serve at least one)

1.  **Carve Your Own Battlefield.** Exploration *is* excavation. The map's shape is a player decision, and terrain is the most important "unit" in the game.
2.  **Every Wall Is a Door.** Chokepoints are strong but never absolute: soft rock can be flanked through, ceilings collapsed, walls blasted, drilled, or warped past. Static defense must always have a counter that costs time or resources.
3.  **Wide vs. Narrow.** Economy wants big open chambers (farms, districts, adjacency); defense wants narrow tunnels. This single tension drives base layout, and raids target the soft, wide heart of an empire.
4.  **Light Against the Dark.** Light is infrastructure. Lit territory is safe, visible, accurate; darkness is cover, ambush, and elf country. Fighting over lamps is fighting over terrain.
5.  **The Deep Hears You.** Digging makes noise; greed makes threat. Information warfare (noise pings, surveys, breach telegraphs) and player-provoked escalation replace flat fog-of-war and rubber-band difficulty.
6.  **Asymmetry with Teeth.** Each faction warps one core rule of the game (stone, darkness, death, or momentum) — different enough to change how you *dig*, not just how you fight.

### 1.2 Scope Statement

  - Single-player skirmish vs. AI (1 human + 1–3 AI, or AI-vs-AI headless), on generated or authored maps.
  - Match target: **80–140 turns, 2–4 hours.** First enemy contact (usually via noise) by \~turn 15; first raids \~turn 20–30; Deep Core contested from \~turn 50.
  - Camera: top-down / high-angle 3D tactical camera, 360° rotation, tilt, zoom. Hex scale ≈ 15–20 m (cosmetic only).
  - **Non-goals for v1** (see §17.2): online multiplayer, story campaign, diplomacy systems, heroes, fluid simulation, multiple stacked depth strata.

  

## 2\. Design Review — What Changed From v1 and Why

This section is the requested double analysis: **(a)** as a game-design review focused on maximizing fun, and **(b)** as an engineering review focused on simplification, robustness, and extensibility. The change log (§2.3) is binding; the rest is rationale the agent and designers should internalize.

### 2.1 Fun Review — the honest assessment

**What v1 already gets right.** The dig-as-exploration hook is genuinely fresh for the 4X genre; the concentric risk/reward bowl guarantees mid-game friction; the four faction spikes are real asymmetries, not stat skins; breach events add push-your-luck to the most common action in the game; and weaponized roof collapses are a signature "clip-worthy" moment. Keep all of it.

  

**Fun risk \#1 — the chokepoint conga line.** Tunnel combat games die when 1-hex corridors make defense free and battles become queues. v1 had no systemic answer. v2's answer is pillar 2 + pillar 3: (a) attackers can always dig, blast, drill, collapse, or warp around a chokepoint at a cost; (b) farms and key economy buildings *require* open chambers (≥3 adjacent cave hexes), so every empire has a wide soft center worth raiding; (c) AoE (splash, detonate, collapse) punishes stacked corridors. Turtling stays viable, never dominant.

  

**Fun risk \#2 — slow, choice-poor early turns.** Digging at 1–4 turns/hex could feel like watching progress bars. Mitigations: soft dirt digs in 1 turn and dominates the starting rim; every dig yields something immediately (food/stone/lump); the Survey/telegraph/breach systems make *where* to dig a real decision every turn; zone designation removes click tedium without removing the decision.

  

**Fun risk \#3 — miss-chance rage.** v1's −30% *accuracy* in darkness means whiffed attacks, the most-hated randomness in TBS. v2 converts all accuracy modifiers into **deterministic damage modifiers**. Same tactical meaning, zero feel-bad dice, and far easier to test.

  

**Fun risk \#4 — rubber-band escalation.** v1's Deep Swarm "targets the richest player" is a hidden tax on winning. v2 replaces targeting with the **Wrath of the Deep** meter: *your own* mithril greed, blasting, and wonder-building provoke the planet. Escalation becomes an agentic risk players price in, with the v1 turn-50/100 timeline kept as an ambient backstop so late games always end.

  

**Fun risk \#5 — the Orc stick.** A penalty-only Momentum mechanic punishes players for the game state. v2's **Waaagh meter** is carrot-first (kills and razing charge tiers of speed/damage/loot) with a single mild floor penalty (Infighting) so the "must fight" identity survives without misery.

  

**Fun additions.** (a) **Noise:** completed digs and explosions ping nearby enemies with an approximate direction — paranoia, counter-intel, and a natural anti-turtle timer. (b) **Light as buildable/destroyable infrastructure**, giving the Elf spike honest counterplay (light your halls) and honest counter-counterplay (Quench, Eclipse). (c) **Breach telegraphs** ("air flows through the cracks…", 75% reliable) turn the gamble into an informed bet. (d) **Two-stage veins** (instant lump + finite extractor node) create rush-vs-develop decisions and make v1's "Depleted Veins" coherent. (e) **Victory conditions** (v1 had none): Conquest, the Deep Throne, and faction Ascension Wonders — three different shapes of endgame pressure.

### 2.2 Engineering Review — simplification, robustness, extensibility

1.  **One logical map layer.** v1's "multi-tiered" underworld implied stacked 3D strata — a complexity multiplier on pathfinding, LOS, UI legibility and map gen. v2 formalizes a **single hex layer with an elevation attribute (0–3)**, rendered in true 3D as a terraced descending bowl. Ridges, chasms, and high ground survive; the strata fantasy is preserved as a clearly-marked extension point (§17.3).
2.  **Deterministic, headless sim core.** All rules live in engine-free RefCounted classes; one seeded RNG stream inside GameState; every mutation flows through validated **Command** objects; the renderer/UI observe via an event bus. Same seed + same commands ⇒ identical state hash. This single decision enables the agent's test loop, golden replays, AI search, and save/load almost for free.
3.  **Data-driven everything, with a primitive contract.** Units, buildings, techs, factions, breach tables, map presets, and the ruleset are JSON. Behavior is composed from an enumerated set of trait/ability primitives (§12.7). Phase 2's editors are thin, schema-driven UIs over these files; Phase 3 authors all content through the editor's **headless CLI**, so content passes the exact same validation as hand-made data.
4.  **Local, cheap world systems.** Structural stress, light, and noise are all bounded BFS computations with dirty-flag recomputation — no global solvers, no fluid sim (floods are one-shot fill events).
5.  **Edge cases pinned down.** The combat formula gains clamps and rounding rules; hex math gets a fixed orientation and coordinate system; turn resolution gets an explicit order of operations (§3.4). Agents fail on ambiguity, not on difficulty.

### 2.3 Binding Change Log (v1 → v2)

|  |  |  |  |
| :-: | :-: | :-: | :-: |
| \*\*\\\#\*\* | \*\*Change\*\* | \*\*Fun rationale\*\* | \*\*Engineering rationale\*\* |
| 1 | Multi-strata 3D → single layer with elevation 0–3 (terraced bowl) | Verticality drama kept via ridges/chasms | −80% path/LOS/UI complexity; strata = extension point |
| 2 | Accuracy/miss chances → deterministic damage modifiers | No whiff rage | Testable, no to-hit subsystem |
| 3 | "Iron/Stone" merged resource → \*\*Stone\*\* and \*\*Iron\*\* split | Clearer build-vs-army tradeoffs | Clean source mapping (dig vs. veins) |
| 4 | Veins → two-stage: instant lump on dig + finite extractor node → Depleted conversion | Rush-vs-develop decisions; makes v1 "Depleted Veins" coherent | Simple node model, no separate mining sim |
| 5 | Orc Momentum (penalty-only) → \*\*Waaagh meter\*\* with bonus tiers + mild floor penalty | Carrot \\\> stick; identity intact | One int + thresholds |
| 6 | Deep Swarm targets richest → \*\*Wrath of the Deep\*\* per-player meter + ambient timeline | Player-provoked escalation; agency | One meter, seeded spawn tables |
| 7 | \*\*Victory conditions added\*\* (Conquest / Deep Throne / Ascension Wonder) | 4X needs endgames; three play shapes | Simple win-check system |
| 8 | \*\*Noise system added\*\* (digs/blasts ping enemies) | Info warfare, anti-turtle, paranoia | Bounded BFS, event-driven |
| 9 | Light formalized as infrastructure (emitters, Lit/Dark hex state, rules) | Elf counterplay; territory identity | Radius BFS + dirty flags |
| 10 | Structural integrity → precise support-radius/stress rules | Collapse tactics readable & plannable | Local computation |
| 11 | Breach → telegraph hints + depth-weighted outcome tables | Informed gambles beat coin flips | One weighted-table system |
| 12 | Multi-hex T4 units → single-hex with \*\*Large\*\* trait | Spectacle preserved visually | No multi-hex pathing/ZOC |
| 13 | Cover defined: adjacent-to-solid defenders +2 ARM vs. non-adjacent ranged (negated by higher attacker) | Simple, readable positioning rule | Local adjacency check |
| 14 | Farms & key economy need ≥3 adjacent open hexes | Creates the wide-vs-narrow tension; raidable soft centers | One placement validator |
| 15 | Magestone doubles as the research currency (no separate science) | One fewer abstraction to learn | One fewer resource pipeline |
| 16 | Heroes, diplomacy, online MP, campaign → explicit non-goals v1 | Focus; v1 mentioned hero hire in passing | Scope control (§17.2) |
| 17 | Combat formula: clamps + rounding + counter-attack rules defined | Predictable outcomes | No div-by-zero / negative-armor exploits |
| 18 | Zones & auto-rally kept, specified as command macros | QoL without new rules | No new sim state |
| 19 | No storage caps on any resource | Removes busywork | Deletes a subsystem |
| 20 | MVP ships 2 data-driven factions (Dwarves, Goblins); Elves & Orcs authored in Phase 3 \*\*through the editor CLI\*\* | Max-contrast pair proves fun early | Proves the no-code content pipeline end-to-end |

  

## 3\. Game Structure

### 3.1 Modes & Setup

  - **Skirmish:** 2–4 players (human + AI) on a generated map (seed + size + ring parameters) or an authored map. Hotseat is a possible free byproduct of sequential turns but is not a v1 requirement.
  - **Headless simulation:** AI vs. AI with no renderer, used by tests and the balance lab.
  - **Starting kit per player:** a pre-carved 7-hex chamber on the Rim containing the faction HQ (with light radius 3), 3 Workers, 1 basic T1 combat unit, and stockpiles: 200 Gold, 100 Food, 50 Stone, 20 Iron, 0 Magestone, 0 Mithril.

### 3.2 Victory Conditions (all active every match)

|  |  |  |
| :-: | :-: | :-: |
| \*\*Victory\*\* | \*\*Rule\*\* | \*\*Pressure it creates\*\* |
| \*\*Conquest\*\* | Destroy or capture every rival HQ (Keep-class building). A player whose HQ is destroyed is eliminated; their units become neutral hostiles after 3 turns. | Classic aggression |
| \*\*The Deep Throne\*\* | Garrison and hold the central Ancient Throne ruin for \*\*10 consecutive turns\*\*. Control is broken the moment an enemy unit stands adjacent with no defender garrisoned. Global announcement each turn it is held. | King-of-the-hill at the map's most dangerous point |
| \*\*Ascension Wonder\*\* | Complete your faction Wonder (§7, \\\~80–100 Mithril + 10 build turns), then \*\*survive 8 turns\*\*. Construction start and completion are globally announced with location. | Economic/tall play with a defend-the-base climax |

  

If turn 200 is reached (configurable), highest score wins: score = military power + stockpiles + territory + techs (exact weights in ruleset.json).

### 3.3 Turn Model

Sequential player turns (IGOUGO, Civ-style), fixed order by player index, then a **World phase**. Chosen over simultaneous resolution deliberately: vastly simpler, deterministic, AI-friendly.

### 3.4 Order of Operations (binding; implement exactly)

**Per player, at start of their turn:**

  

1.  Income: extractor nodes, building trickles, passives.
2.  Upkeep: pay Food/Gold per unit. Deficit: every unpaid unit loses 10% max HP this turn (prioritize paying highest-tier first automatically).
3.  Construction & training progress ticks; completed buildings/units appear.
4.  Dig progress ticks; completed digs apply yields, then **Breach checks** (§4.6), then **Noise pings** (§4.8).
5.  Healing & regeneration; Mechanical units do not self-heal.
6.  Status durations tick down; ability cooldowns tick down.
7.  Structural stress update & collapse rolls (§4.5).
8.  Light and vision recompute (dirty hexes only).
9.  **Action phase:** the player issues commands until End Turn.

  

**World phase (after all players):**

  

1.  Creep AI acts (lairs spawn on cooldown, packs patrol/aggro).
2.  Wrath of the Deep meters decay/trigger; escalation waves spawn (§8.3).
3.  Victory conditions checked; global announcements queued.

  

## 4\. The World — Map, Terrain & Environmental Systems

### 4.1 Hex Grid Specification (binding)

  - **Flat-top hexes, axial coordinates (q, r)**; cube coordinates for algorithms. Distance = cube distance. Neighbor order (fixed, index 0–5): E, NE, NW, W, SW, SE.
  - Line of sight uses standard hex line-drawing (lerp in cube space, round); a line is blocked by any Solid hex, or by any hex whose elevation exceeds **both** endpoints' elevation.
  - **Elevation:** integer 0–3 per hex. Moving up 1 level costs +1 movement point per level; moving down is free. Elevation difference ≥ 2 without a Slope feature is impassable to ground units (cliff).
  - Map sizes (hex radius): Small 24 (1,801 hexes), Medium 32 (3,169), Large 40 (4,921).

### 4.2 Hex Types

**Solid hexes** (volumetric rock; block movement, LOS, and light):

  

|  |  |  |  |
| :-: | :-: | :-: | :-: |
| \*\*Solid type\*\* | \*\*Dig time (worker-turns)\*\* | \*\*Yield on dig\*\* | \*\*Notes\*\* |
| Soft Dirt | 1 | \\+1 Food (spores) | Dominant on the Rim; flanking medium |
| Hard Rock | 2 | \\+2 Stone | Baseline |
| Dense Granite | 4 | \\+4 Stone | Immune to Blast Charges & Detonate (unless teched) |
| Artificial Granite | 3 (owner: 1) | \\+2 Stone | Dwarf-built; §7.1 |
| Rubble | 1 | \\+1 Stone | Result of collapses |
| Gold Vein | 2 | \\+25 Gold lump + node | Node: stock 250, 10/turn via Extractor |
| Iron Vein | 2 | \\+10 Iron lump + node | Node: stock 120, 6/turn |
| Magestone Crust | 2 | \\+15 Magestone lump + node | Node: stock 150, 6/turn |
| Mithril Seam | 4 | \\+10 Mithril lump + node | Node: stock 60, 3/turn; mining adds Wrath (§8.3); Deep Core only |

  

Dig time is total worker-turns; multiple workers on adjacent hexes may work the same target (max 2 simultaneous diggers per hex). "Dig 2×" halves remaining time (round up).

  

**Cave hexes** (passable open space):

  

|  |  |
| :-: | :-: |
| \*\*Cave feature\*\* | \*\*Effect\*\* |
| Plain floor | — |
| Elevated Ridge (elev. 1–3) | High-ground combat bonuses (§6.3); vision over lower terrain |
| Slope | Allows ground movement across a 1-level elevation change at +1 MP |
| Chasm | Impassable to ground; Fly crosses freely; ranged can shoot across |
| Deep Water | Impassable to ground; Fly/Amphibious cross; created by Flood events |
| Geothermal Vent | Adjacency bonuses for certain buildings; source of Magma escalation |
| Fungal Grove | Farm-class yields +2 if a Farm is adjacent; harvestable one-shot +10 Food |
| Ancient Ruins | Explorable node: garrison 1 turn → loot table roll; some house creep lairs |
| Depleted Vein | Convertible by a worker (1 turn): \*\*Deep Storage\*\* (+5% global income of that resource) or \*\*Trench\*\* (defender in hex: +2 ARM, attackers get no high-ground bonus) |
| Ancient Throne | Unique central ruin; Deep Throne victory (§3.2) |

### 4.3 Fog of War & Surveying

Three knowledge states per hex: **Unknown** (never seen), **Explored** (terrain memorized, no live units shown), **Visible** (in a friendly unit/building vision range with clear LOS). Solid hexes adjacent to your open, explored space show their *type* (you can see the wall face) but veins deeper than 1 hex inside rock are hidden until Surveyed (Dwarf ability, §7.1) or dug. Default unit vision: 4 hexes; Dark hexes are only visible at range 1 unless the viewer has Darkvision (§4.7).

### 4.4 Map Generation — the Concentric Bowl

Generated as a descending terraced bowl (elevation falls from Rim 2–3 to Core 0):

  

|  |  |  |
| :-: | :-: | :-: |
| \*\*Ring (share of radius)\*\* | \*\*Composition\*\* | \*\*Purpose\*\* |
| \*\*Safe Rim\*\* (outer 30%) | 70% Soft Dirt, 20% Hard Rock, plentiful small Iron/Gold veins, Fungal Groves; player spawns equidistant | Fast, safe carving; economy foundation |
| \*\*Mid-Mantle\*\* (middle 40%) | 55% Hard Rock, 15% Granite, Magestone crusts, rivers/chasms, minor creep lairs, Ruins | Contact & contest zone |
| \*\*Deep Core\*\* (inner 30%) | Granite-dominant, exposed Mithril Seams, Ancient Throne at center, major lairs, Wonders' best real estate | Endgame gravity well |

  

Generator parameters (ring shares, vein densities, lair counts, seed) live in data/mapgen/\*.json and are editable in Phase 2.

### 4.5 Structural Integrity & Roof Collapse

  - A cave hex is **Supported** if any Solid hex or intact **Pillar** is within distance 2 (BFS through cave hexes).
  - Unsupported hexes gain **+1 Stress** each World phase (global pass, dirty regions only). At Stress ≥ 3, each World phase: 25% collapse chance (seeded RNG).
  - **Collapse:** every unit in the hex takes 120 true damage (ignores ARM); the hex becomes Rubble (Solid); adjacent hexes +1 Stress once.
  - **Weaponizing it:** destroying a Pillar immediately sets all hexes it uniquely supported to Stress 3. The Dwarven Thunder Cannon's *Sunder Ceiling* and the Goblin *Doomsday Payload* trigger an immediate collapse on any currently-unsupported or Stress ≥ 1 hex. UI must display support/stress overlay on demand.
  - Pillars: buildable by any worker (10 Stone, 1 turn, 200 HP, attackable).

### 4.6 The Breach System (digging is a gamble)

When a dig completes and the far side opens into an **undiscovered natural cavern** (map-gen marks pocket-cavern regions), a Breach Event fires from the depth-weighted table in §8.2.

  

**Telegraphs:** whenever a worker *starts* digging a hex flagged as breach-adjacent, the player receives a hint ("Air flows through the cracks", "You hear skittering", "A warm glow seeps through") that is **75% truthful** about the outcome category (Boon/Neutral/Peril). Informed push-your-luck, not a coin flip.

### 4.7 Light & Darkness

  - Every cave hex is **Lit** or **Dark**. Light emitters: Braziers (radius 2), HQs (3), some buildings, and units with the Torchbearer trait (1). Radius propagates by BFS through cave hexes only; Solid blocks light.
  - **Dark combat:** attacks *targeting a unit in a Dark hex* deal −30% damage unless the attacker has **Darkvision**.
  - **Dark vision:** Dark hexes are visible only at range 1 (Darkvision: normal range).
  - Light sources are destructible (Braziers 60 HP) and Quenchable (Elf abilities). Elf **Shadow Warp** requires a *known Dark cave hex* destination — so lighting your halls is the universal counter, and attacking the lamps is the counter-counter.

### 4.8 Noise (information warfare)

  - Events emit Noise with a budget: completed dig = 8; Blast Charge / Detonate / Sunder / Drill-turn = 16.
  - Noise propagates by BFS: cost 1 per cave hex, 2 per Solid hex, until the budget is spent. Any enemy unit or building inside the propagation area receives a **ping**: an approximate direction + intensity marker on their map (not the exact hex), logged in their event feed.
  - **Silent** trait (Elf diggers/scouts) emits no Noise. The Elf Whisper Obelisk doubles received propagation budgets (hears farther) and flags enemy Warp arrivals within 6.

  

## 5\. Economy

### 5.1 Resources

|  |  |  |
| :-: | :-: | :-: |
| \*\*Resource\*\* | \*\*Sources\*\* | \*\*Uses\*\* |
| \*\*Food\*\* | Soft Dirt digs, Farms, Fungal Groves | Unit food upkeep, training costs |
| \*\*Gold\*\* | Vein lumps/nodes, Pillage, bounties, Vault/Hoard trickles | Unit costs & gold upkeep, buildings |
| \*\*Stone\*\* | Digging Hard Rock/Granite/Rubble | Buildings, Pillars, walls, Artificial Granite |
| \*\*Iron\*\* | Iron veins | Armored units, mechs, turrets, some buildings |
| \*\*Magestone\*\* | Magestone crusts, faction buildings | \*\*All research\*\*, caster abilities, Warp fuel |
| \*\*Mithril\*\* | Deep Core seams only | T4 units, Wonders; mining provokes Wrath |
| \*\*Scrap\*\* (Goblin-only) | Any unit death (1/2/4/8 by tier, cap 8/hex) | Instant-spawn units, feed Shredders (§7.3) |

  

No storage caps. Stockpiles are per-player integers; income/expense preview shown in HUD.

### 5.2 Extractors, Housing, Training

  - **Extractor** (generic building, 20 Stone, any faction skin): must be built *on* a vein node hex; yields the node's rate per turn until stock exhausts → hex becomes **Depleted Vein** (§4.2).
  - **Housing** is the unit cap: HQ +6, each housing building +4. Training requires 1 free housing (all units, workers included). No population growth system — housing *is* population (deliberate simplification).
  - Training: paid up front, takes 1–3 turns by tier (T1:1, T2:2, T3:3, T4:4), unit appears at the producing building; **Auto-Rally** (§9.2) can route it onward automatically.
  - **Placement rule (binding):** Farm-class buildings and Wonders require ≥ 3 adjacent cave hexes at placement (the wide-vs-narrow pillar). Turrets/walls/pillars have no such requirement.

### 5.3 Zone Designation (macro layer)

  - **Mining Zone:** drag-select a 3D box of Solid hexes → the TurnManager auto-assigns idle workers (nearest-first, reachable-only), generating ordinary Dig commands each turn. Zones are UI/AI conveniences that create commands; they add **zero** sim rules.
  - **Auto-Rally Paths:** a production building stores a rally target; newly trained units receive queued Move commands along the cached path, re-pathed on terrain change.

  

## 6\. Combat

### 6.1 Damage Formula (binding)

effective\_armor = clamp(ARM \* 10 - PEN, 0, 200)

  

damage = BaseATK \* (100 / (100 + effective\_armor)) \* mod\_product

  

mod\_product = elevation\_mod \* dark\_mod \* cover\_mod \* trait\_mods \* status\_mods

  

final = max(1, round\_half\_up(damage))

  

  - The clamp means PEN can never *amplify* damage past 1.0×, and armor tops out at −66.7% (ARM 12 ≈ 0.455× vs. PEN 0).
  - All modifiers are multiplicative percentages; there is **no to-hit roll** anywhere in the game.

### 6.2 Attack Resolution

1.  Attacker deals damage per §6.1.
2.  **Counter-attack:** if the attack was melee (range 1) and the defender survives and has a melee attack, the defender immediately counters at **75%** of its normal damage. Ranged attacks are never countered.
3.  On kill: remove unit; drop Scrap (§5.1); credit bounty/Waaagh where applicable.
4.  Attacking ends the unit's turn unless a trait says otherwise (Rampage, Twin-Step).

### 6.3 Positional Modifiers

|  |  |
| :-: | :-: |
| \*\*Situation\*\* | \*\*Modifier\*\* |
| Attacker elevation \\\> defender | \\+15% damage per level (max +30%); ranged units also gain \*\*+1 range\*\* when any advantage exists |
| Target in Dark hex, attacker lacks Darkvision | −30% damage |
| Defender adjacent to ≥1 Solid hex, attacker is ranged and not adjacent | Defender +2 ARM (\*\*cover\*\*); negated if attacker elevation is higher |
| Defender in a Trench | \\+2 ARM and attacker's high-ground bonuses negated |

### 6.4 Movement, ZOC, Attacking Terrain

  - Movement points per unit (MOV); each cave hex costs 1 (+1 per level climbed). Entering a hex adjacent to an enemy unit ends movement (Zone of Control). **Fly** ignores terrain costs, chasms, water, and ZOC. No attacks of opportunity.
  - Only units with **Demolisher** or **Drill** can damage Solid hexes/buildings-as-terrain: each Demolisher attack removes 2 worker-turns of dig time from a Solid hex and deals double damage to buildings. Drill (Iron Dozer) converts Solid to cave at 1 hex/turn while moving.

### 6.5 Status Effects (durations in turns)

Poisoned (X dmg/turn), Warded (+ARM), Rooted (MOV 0), Dread (−15% damage dealt), Frenzied (+1 MOV, +20% damage), Burning (10 dmg/turn, spreads to adjacent flammable buildings at 25%). Same status doesn't stack; refresh duration.

  

## 7\. The Factions — Full Content Bible

Shared conventions: **Cost** uses g=Gold, f=Food, s=Stone, i=Iron, ms=Magestone, mi=Mithril, sc=Scrap. **Upk** = per-turn upkeep. Research is bought directly with stockpiled Magestone; tech costs by tier: **T1 30 · T2 60 · T3 120 · T4 240 ms**, linear prerequisites within each branch. Tier-4 units require the matching Tier-4 tech *and* the faction's top-tier production building. Every faction has: an HQ (Keep-class, HP 1000, housing 6, light 3, trains workers), a housing building, a Farm-class building (needs ≥3 open adjacent hexes), an Extractor skin, a Brazier skin (5s, light 2; Elves may skip lighting), a Pillar (10s), a wall-type option (a building, or the faction spike — Dwarven Artificial Granite counts), and one turret. Faction-unique buildings are listed per faction.

  

### 7.1 Dwarven Ironclad — "The mountain obeys."

**Playstyle:** defense, metallurgy, terraforming. Slow, expensive, unstoppable once entrenched.

  

**Spike — Earth-Shapers:** Sappers can build **Artificial Granite** (10s, 1 turn) on any adjacent empty cave hex, creating Solid terrain that reshapes the labyrinth. Enemies dig it in 3 turns; Dwarves clear their own in 1. Combined with Pillars and turrets, Dwarves literally build the kill-zone.

  

**Faction passives:** +100% Stone from all digging; Sappers dig Granite in 3 (not 4); **Survey** ability on Sappers (reveal veins in Solid hexes within radius 2, once per turn per Sapper).

  

**Economy twist:** Geothermal adjacency — Iron Forge / Great Anvil adjacent to a Vent train at −20% cost; Farms adjacent to a Vent +1 Food.

#### Units

|  |  |  |  |  |  |  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| \*\*Unit\*\* | \*\*T\*\* | \*\*Cost\*\* | \*\*Upk\*\* | \*\*HP\*\* | \*\*ATK\*\* | \*\*PEN\*\* | \*\*RNG\*\* | \*\*ARM\*\* | \*\*MOV\*\* | \*\*Traits & Actives\*\* |
| Sapper | 1 | 60g 20f | 1f | 60 | 10 | 0 | 1 | 1 | 2 | Worker; Survey; Raise Granite; Place Pillar; Torchbearer |
| Shield-Bearer | 1 | 80g 30i | 1f 1g | 130 | 18 | 0 | 1 | 5 | 2 | Shield Wall (+2 ARM if adjacent to another Shield-Bearer); Stalwart (immune Dread/Root) |
| Crossbow Gunner | 1 | 70g 25i | 1f 1g | 70 | 26 | 10 | 3 | 1 | 2 | — |
| Steam Vanguard | 2 | 160g 60i | 2f 2g | 190 | 42 | 5 | 1 | 7 | 3 | Steam Charge (+15 flat dmg if moved ≥2 this turn) |
| Rune-Smith | 2 | 130g 40ms | 2f 2g | 100 | 20 | 0 | 2 | 3 | 2 | Actives: Rune of Warding (10ms: ally +3 ARM, 2t); Forge-Mend (8ms: repair Mechanical/building 50 HP) |
| Thunder Cannon | 3 | 280g 120i | 3g | 140 | 85 | 30 | 5 (min 2) | 2 | 1 | Mechanical; Splash (r1, 50%); Active: Sunder Ceiling (collapse an unsupported/stressed hex, cd 2, Noise 16) |
| Steam Golem | 3 | 320g 160i 20ms | 2g | 340 | 60 | 10 | 1 | 9 | 2 | Mechanical; Demolisher |
| Ironclad Juggernaut | 4 | 550g 300i 50mi | 5g 3f | 800 | 110 | 20 | 1 | 12 | 2 | Large; Demolisher; Active: Earthshaker (r1 AoE 60 dmg + Root 1t, cd 3) |

#### Buildings (unique / notable)

|  |  |  |
| :-: | :-: | :-: |
| \*\*Building\*\* | \*\*Cost\*\* | \*\*Effect\*\* |
| The Deep Keep (HQ) | — | Standard HQ; trains Sappers |
| Burrow | 40s | Housing +4 |
| Mushroom Cellar (Farm) | 30s 10f | \\+4 Food/turn; ≥3 open adjacent |
| Stone Mason | 50s | \\+2 Stone/turn; Pillars & Artificial Granite −50% cost |
| Iron Forge | 60s 20i | Trains T1–T2 combat units; Vent adjacency −20% train cost |
| Rune Hall | 80g 40s | Enables research; trains Rune-Smith; +1 ms/turn |
| Deep Vault | 60s | \\+10% Gold income |
| Great Anvil | 120s 80i | Trains T3–T4; requires Iron Forge |
| Ballista Turret | 40s 30i | HP 300; ATK 30, PEN 10, RNG 3 |
| Wonder — The Adamant Throne | 100mi 400s 300g | 10 turns; Ascension victory (§3.2) |

#### Tech Tree

|  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: |
| \*\*Branch\*\* | \*\*T1 (30)\*\* | \*\*T2 (60)\*\* | \*\*T3 (120)\*\* | \*\*T4 (240)\*\* |
| \*\*Industry\*\* | Deep Prospecting — Survey radius 3 | Geothermal Tapping — Vent adjacency bonuses ×2 | Blast Mining — Sappers gain Blast Charge (20g: instantly clear a Soft/Hard hex, Noise 16) | Mithril Smelting — unlock Mithril extraction & Juggernaut |
| \*\*Warfare\*\* | Interlocking Shields — Shield Wall +3 and covers all adjacent Dwarf infantry | Overwatch Bolts — Crossbows free reaction-shot at first enemy entering range (1/turn) | Steam Doctrine — Vanguard +1 MOV; Golem +40 HP | Siege Mastery — Cannons RNG 6, Sunder cd 1 |
| \*\*Runecraft\*\* | Runes of Light — Braziers radius 3 | Warding Mastery — Ward +4 ARM, 3t | Living Stone — Artificial Granite self-repairs; Pillars HP 400 | Runes of Unmaking — Rune-Smith active (30ms): dissolve one Solid hex at RNG 2 |

  

**Play pattern:** carve tight, pillar everything, wall the approaches, let crossbows overwatch a lit kill-box — then walk a Cannon forward and delete the enemy's ceiling. Weakness: slow map presence; punished by Noise-guided early raids before walls exist.

  

### 7.2 Umbral Elves — "The dark was always ours."

**Playstyle:** stealth, sorcery, surgical strikes. Low unit counts, terrifying reach.

  

**Spike — Shadow Warp:** units with **Warp** teleport up to 4 hexes through anything, landing on a *known, Dark, empty cave hex*. Cooldown 3, costs 5 ms per use. Counter: light. Counter-counter: Quench/Eclipse.

  

**Faction passives:** all units have **Darkvision**; Elf buildings emit no light (stealth settlements); Shade Diggers and Scouts are **Silent** (no Noise).

  

**Economy twist:** Moonwells produce Magestone; controlled Dark ruins/crystal features yield +50% with Gloom Harvest tech.

#### Units

|  |  |  |  |  |  |  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| \*\*Unit\*\* | \*\*T\*\* | \*\*Cost\*\* | \*\*Upk\*\* | \*\*HP\*\* | \*\*ATK\*\* | \*\*PEN\*\* | \*\*RNG\*\* | \*\*ARM\*\* | \*\*MOV\*\* | \*\*Traits & Actives\*\* |
| Shade Digger | 1 | 55g 20f | 1f | 50 | 8 | 0 | 1 | 0 | 3 | Worker; Silent |
| Shadow Blade | 1 | 90g 10ms | 1f 1g | 80 | 30 | 5 | 1 | 1 | 3 | Warp; Ambusher (+40% dmg when attacking from a Dark hex) |
| Nightmist Scout | 1 | 60g | 1f | 60 | 18 | 0 | 2 | 0 | 4 | Silent; Vision 6 |
| Dusk Templar | 2 | 170g 20ms | 2f 1g | 160 | 38 | 5 | 1 | 4 | 3 | Warp; Parry (−25% melee dmg taken) |
| Void Weaver | 2 | 140g 50ms | 1f 2g | 90 | 22 | 0 | 3 | 1 | 3 | Actives: Quench (8ms, RNG 3: destroy a small light source or Darken a hex 3t); Void Bolt (12ms, RNG 3: 35 dmg, ignores ARM) |
| Phase Spider | 3 | 260g 40ms | 2f 2g | 250 | 55 | 10 | 1 | 3 | 4 | Warp (cd 2); Venom (Poison 10/2t) |
| Demon Executioner | 3 | 300g 60ms | 3f 2g | 290 | 75 | 15 | 1 | 5 | 3 | Aura: Dread (adjacent enemies −15% dmg) |
| Avatar of the Void | 4 | 500g 40mi 150ms | 4f 4g | 650 | 100 | 20 | 2 | 6 | 3 | Large; Warp (cd 1); Active: Umbral Eclipse (30ms, cd 3: r2 — Darken 3t, destroy light sources, 40 dmg) |

#### Buildings (unique / notable)

|  |  |  |
| :-: | :-: | :-: |
| \*\*Building\*\* | \*\*Cost\*\* | \*\*Effect\*\* |
| Obsidian Spire (HQ) | — | Standard HQ (emits \*\*no\*\* light); trains Shade Diggers |
| Gloom Bower | 40s | Housing +4 |
| Nightcap Grove (Farm) | 30s 10f | \\+4 Food/turn; ≥3 open adjacent |
| Moonwell | 60s 40g | Enables research; +2 ms/turn |
| Shadow Loom | 50s | Trains T1–T2 |
| Veil Sanctum | 80g 60s | Trains casters & T3–T4 |
| Whisper Obelisk | 60g 40s | Doubles Noise detection budget; flags enemy Warp arrivals within 6 |
| Thorn Sentinel | 50s | Turret HP 200; ATK 25, RNG 2; Hidden until it attacks or an enemy is adjacent |
| Dusk Gate (built in pairs) | 100g 80s 50ms each | Friendly units teleport between paired gates (1 action) |
| Wonder — Throne of Endless Night | 100mi 300g 200ms | 10 turns; on completion permanently Darkens radius 6 |

#### Tech Tree

|  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: |
| \*\*Branch\*\* | \*\*T1 (30)\*\* | \*\*T2 (60)\*\* | \*\*T3 (120)\*\* | \*\*T4 (240)\*\* |
| \*\*Umbral\*\* | Farsight Veil — Warp range 5 | Effortless Passage — Warp cost 3ms | Twin-Step — a unit may still act after Warping | Master of the Void — unlock Avatar; all Warp cd −1 |
| \*\*Shadowcraft\*\* | Toxin Craft — Shadow Blades apply Venom | Killing Dark — Ambusher +60% | Spider Broods — Phase Spiders −25% cost; Venom 15/3t | Executioner's Pact — Dread aura radius 2, −25% |
| \*\*Gloamweave\*\* | Moonwell Attunement — Moonwells +1 ms | Gloom Harvest — Dark ruins/crystals +50% yield | Veiled Halls — buildings Hidden until an enemy is adjacent | Endless Night — unlock Wonder; Quench destroys any light source |

  

**Play pattern:** stay invisible, map the enemy by their own Noise, snuff their lamps, then Warp a strike team into the wide soft heart of their base — kill farms and casters, vanish. Weakness: fragile, ms-hungry, hard-countered by disciplined lighting and Whisper-style detection.

  

### 7.3 Goblin Swarmers — "Dead things is free things."

**Playstyle:** speed, numbers, explosives, profit-from-carnage. The fastest diggers in the underworld.

  

**Spike — Scrap Swarm:** every unit death (any faction, anywhere) drops Scrap on the hex (T1:1, T2:2, T3:4, T4:8; cap 8/hex). Goblin workers **Harvest** adjacent Scrap into a stockpile. Scrap **instant-spawns** units at the Great Warren or any Scrap Pile (unit appears exhausted, acts next turn). The longer a war grinds, the stronger the goblins get — even other people's wars.

  

**Faction passives:** Diggers dig at **2× speed** (halve remaining time, round up); all unit Gold costs −25%; T1 units have no Gold upkeep; buildings cost −30% but have −30% HP.

  

**Economy twist:** violence is the economy — Scrap is a renewable resource fed by every battle on the map, and Salvage Economy tech converts it to Gold.

#### Units

|  |  |  |  |  |  |  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| \*\*Unit\*\* | \*\*T\*\* | \*\*Cost\*\* | \*\*Upk\*\* | \*\*HP\*\* | \*\*ATK\*\* | \*\*PEN\*\* | \*\*RNG\*\* | \*\*ARM\*\* | \*\*MOV\*\* | \*\*Traits & Actives\*\* |
| Digger | 1 | 40g 10f | 1f | 40 | 6 | 0 | 1 | 0 | 3 | Worker; Dig 2×; Harvest Scrap |
| Spear Swarmer | 1 | 45g \*\*or\*\* 3sc | 1f | 55 | 16 | 0 | 1 | 0 | 3 | Mob (+10% dmg per adjacent Swarmer-tag ally, max +30%) |
| Sling Tosser | 1 | 45g \*\*or\*\* 3sc | 1f | 45 | 14 | 0 | 2 | 0 | 3 | Mob |
| Kamikaze Gobbo | 2 | 70g \*\*or\*\* 5sc | 1f | 50 | — | — | — | 0 | 4 | Detonate (dies: 60 dmg r1; destroys a targeted Soft/Hard Solid hex → Rubble; Noise 16) |
| Bat Rider | 2 | 120g 20f | 1f 1g | 90 | 28 | 0 | 1 | 1 | 5 | Fly; ignores ZOC |
| Shaman | 3 | 180g 60ms | 2f 1g | 110 | 18 | 0 | 3 | 1 | 3 | Actives: Fungal Frenzy (10ms: ally Frenzied 2t); Stinking Cloud (12ms: r1 enemies −20% dmg 2t); Scrap-Call (8ms + 3sc: spawn a Spear Swarmer adjacent to any friendly unit within RNG 3) |
| Scrap Shredder | 3 | 260g 100i | 2g | 270 | 65 | 10 | 1 | 6 | 3 | Mechanical; Demolisher; Scrap-Eater (start of turn: consume 2sc within r1 → heal 40) |
| The Iron Dozer | 4 | 450g 250i 40mi | 4g | 700 | 95 | 25 | 1 | 8 | 2 | Large; Mechanical; Splash (r1, 50%); \*\*Drill\*\* (moves through Solid, converting it to cave at 1 hex/turn regardless of hardness; Noise 16/turn while drilling) |

#### Buildings (unique / notable)

|  |  |  |
| :-: | :-: | :-: |
| \*\*Building\*\* | \*\*Cost\*\* | \*\*Effect\*\* |
| Great Warren (HQ) | — | Standard HQ; Scrap spawn point; trains Diggers |
| Breeding Pit | 30s | Housing +5; trains Diggers |
| Fungus Heap (Farm) | 20s | \\+4 Food/turn; ≥3 open adjacent |
| Scrap Pile | 20s | Scrap spawn point; Harvest range +1 for adjacent Diggers |
| Boom Lab | 40s | Trains Kamikaze & T2; explosives techs |
| Bat Roost | 40s | Trains Bat Riders |
| Shaman Hut | 60g 40s | Enables research; trains Shamans & T3 |
| Junk Barricade | 5s | Wall building, HP 150 (blocks a hex) |
| Spike Launcha | 30s | Turret HP 180; ATK 22, RNG 2 |
| Wonder — The Mother Drill | 80mi 300i 200g | 10 turns; Ascension victory |

#### Tech Tree

|  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: |
| \*\*Branch\*\* | \*\*T1 (30)\*\* | \*\*T2 (60)\*\* | \*\*T3 (120)\*\* | \*\*T4 (240)\*\* |
| \*\*Swarm\*\* | Endless Litters — instant-spawn costs −1sc | Mob Rule — Mob cap +50% | Warren Networks — any friendly building is a spawn point | The Great Swarm — all T1 +1 MOV, T1 gold costs −50% |
| \*\*Boom\*\* | Bigger Booms — Detonate 90 dmg | Dig Charges — Detonate can destroy Granite | Rocket Bats — Bat Riders gain RNG 2 | Doomsday Payload — Detonate r2 and triggers collapse on unsupported/stressed hexes |
| \*\*Scrap-Tech\*\* | Scrap Magnets — Harvest range 2 | Shredder Works — Scrap-Eater heals 60 | Salvage Economy — +5g per Scrap harvested | The Mother Drill — unlock Iron Dozer & Wonder |

  

**Play pattern:** out-dig everyone, feed early skirmishes to bank Scrap, then chain instant-spawns to bury the enemy in bodies while a Dozer drills through their back wall. Weakness: everything is paper; AoE and disciplined kill-boxes erase swarms — but even losses pay the goblins in Scrap.

  

### 7.4 Orcish Warbands — "Peace is what starving looks like."

**Playstyle:** relentless aggression, beast-taming, plunder. The war machine that stalls if it idles.

  

**Spike — Momentum (Waaagh\! meter, 0–100):** +15 per enemy unit killed, +25 per building razed, +10 per Pillage strike; **−5 per turn** decay. Thresholds: **25+** all units +1 MOV · **50+** +15% damage and kills grant +10 Gold loot · **75+** all units heal 10% max HP per turn and training is 1 turn faster. Floor penalty: at 0 for 3 consecutive turns → **Infighting** (−15% resource output, units −10% damage) until the next kill. Carrot-first; the stick only bites true pacifists.

  

**Faction passives:** **Pillage** — attacks against enemy buildings return 25% of damage dealt as Gold. **Enslaver** — Grunts that kill an enemy Worker have a 50% chance to convert it into a Captive Thrall.

  

**Economy twist:** the frontline *is* the economy — loot, pillage returns, captured Thralls (no Food upkeep), and tamed beasts substitute for infrastructure.

#### Units

|  |  |  |  |  |  |  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| \*\*Unit\*\* | \*\*T\*\* | \*\*Cost\*\* | \*\*Upk\*\* | \*\*HP\*\* | \*\*ATK\*\* | \*\*PEN\*\* | \*\*RNG\*\* | \*\*ARM\*\* | \*\*MOV\*\* | \*\*Traits & Actives\*\* |
| Captive Thrall | 1 | 30g | 1g | 45 | 5 | 0 | 1 | 0 | 2 | Worker; Capturable |
| Orc Grunt | 1 | 70g 20f | 1f 1g | 100 | 24 | 0 | 1 | 2 | 3 | Enslaver; Blood Rush (+10% dmg vs. wounded targets) |
| Javelin Hurler | 1 | 65g 10f | 1f 1g | 70 | 20 | 5 | 2 | 0 | 3 | — |
| Berserker | 2 | 140g 30f | 2f 1g | 140 | 48 | 0 | 1 | 1 | 4 | Rampage (on kill: one extra attack); Reckless (+15% dmg taken) |
| Beast Tamer | 2 | 120g 20f | 2f 1g | 100 | 25 | 0 | 1 | 1 | 3 | Tame (adjacent neutral Beast ≤T2 below 35% HP joins you; cd 5); Goad (ally Beast +1 MOV, 1/turn) |
| Blood Shaman | 3 | 200g 60ms | 2f 2g | 120 | 20 | 0 | 3 | 2 | 3 | Aura: War Drums (adjacent allies +10% dmg); Actives: Blood Ritual (drain ally 30 HP → +10 Waaagh and heal another ally 40); Spirit Chains (10ms, RNG 3: Root 1t) |
| Under-Troll | 3 | 300g 80f | 3f 2g | 350 | 70 | 0 | 1 | 5 | 3 | Beast; Regeneration 25; Active: Hurl Boulder (RNG 3, ATK 50, PEN 10, cd 2) |
| Dread-Behemoth | 4 | 550g 60mi 150f | 5f 3g | 900 | 120 | 20 | 1 | 9 | 2 | Large; Beast; Demolisher; Splash (r1, 50%); Aura: Terrifying Roar (r2 enemies Dread) |

#### Buildings (unique / notable)

|  |  |  |
| :-: | :-: | :-: |
| \*\*Building\*\* | \*\*Cost\*\* | \*\*Effect\*\* |
| War Hall (HQ) | — | Standard HQ; trains Thralls |
| Slave Pens | 30s | Housing +4; trains Thralls |
| Blood-Fungus Farm | 30s | \\+4 Food/turn; ≥3 open adjacent |
| Loot Hoard | 40s | \\+10% Gold income; Pillage +10% |
| War Forge | 60s 20i | Trains T1–T2 |
| Beast Kennel | 60s | Trains Beast Tamer & Under-Troll |
| Shaman Circle | 80g 40s | Enables research; trains Blood Shamans & T3–T4 |
| Drum Tower | 40s | Aura r3: allied units +5% dmg |
| Spike Barricade | 5s | Wall building, HP 200 |
| Wonder — Idol of the Great Waaagh | 80mi 300g 200f | 10 turns; Ascension victory; while standing, Waaagh decay is 0 |

#### Tech Tree

|  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: |
| \*\*Branch\*\* | \*\*T1 (30)\*\* | \*\*T2 (60)\*\* | \*\*T3 (120)\*\* | \*\*T4 (240)\*\* |
| \*\*Waaagh\*\* | Battle Fury — kills grant +20 Waaagh | Waaagh Banners — 50+ tier grants +25% dmg | Endless War — decay −3/turn | The Great Waaagh — unlock Behemoth & Idol; at 100 Waaagh all units +1 MOV |
| \*\*Beastcraft\*\* | Whips & Chains — Tame threshold 50% HP | Troll Husbandry — Trolls −25% cost, Regen 35 | War-Beast Armor — Beasts +2 ARM | Apex Predators — Tame works on T3 Beasts |
| \*\*Plunder\*\* | Plunderers — Pillage 40% | Slave Drivers — Enslaver chance 100% | Tribute of Fear — razing a building +50g | Horde Economy — all Gold upkeep −50% |

  

**Play pattern:** raid on a metronome — hit creep lairs and enemy outposts to keep the meter above 50, tame the Mantle's monsters into a free army, and pay for the war with the enemy's own buildings. Weakness: a starved meter and long sieges; kiting and walls (especially Dwarven granite) bleed the Waaagh dry.

  

## 8\. The Neutral World

### 8.1 Creeps & Lairs

Lairs sit on Ruin/feature hexes, spawn a guard pack, and respawn it every 8 turns if cleared but not occupied. Killing creeps pays a Gold bounty (≈ unit tier × 15) and drops Scrap normally.

  

|  |  |  |  |  |  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| \*\*Creep\*\* | \*\*T\*\* | \*\*HP\*\* | \*\*ATK\*\* | \*\*PEN\*\* | \*\*RNG\*\* | \*\*ARM\*\* | \*\*MOV\*\* | \*\*Traits\*\* | \*\*Where\*\* |
| Giant Cave Bat | 1 | 40 | 12 | 0 | 1 | 0 | 5 | Fly; aggressive toward units in Dark | Rim/Mantle |
| Troglodyte Scavenger | 1 | 70 | 18 | 0 | 1 | 1 | 3 | Packs of 3–4 | Rim/Mantle |
| Phase Spiderling | 1 | 50 | 15 | 0 | 1 | 0 | 3 | Warp (cd 3); Venom 5/2t | Breach spawns |
| Stone Elemental | 2 | 200 | 35 | 0 | 1 | 8 | 2 | Beast; Demolisher | Mantle |
| Undead Miner | 2 | 90 | 25 | 5 | 1 | 1 | 2 | Spawn from Tombs; no upkeep concept | Ruins |
| Magma Elemental | 3 | 260 | 60 | 10 | 1 | 4 | 3 | Burning aura (adjacent 10/turn); immune Burning | Vents / Eruption |
| Ancient Golem | 3 | 400 | 70 | 10 | 1 | 9 | 2 | Beast; joins the breacher (Boon outcome only) | Breach |
| Subterranean Great Worm | 3 (boss) | 1200 | 110 | 20 | 1 | 6 | 3 | Drill (1 hex/turn); Splash (r1, 50%) | Deep Core lair |

### 8.2 Breach Event Table (weights % by ring: Rim / Mantle / Core)

|  |  |  |  |  |  |
| :-: | :-: | :-: | :-: | :-: | :-: |
| \*\*Category\*\* | \*\*Event\*\* | \*\*Effect\*\* | \*\*Rim\*\* | \*\*Mantle\*\* | \*\*Core\*\* |
| Boon | Magestone Geode | \\+60 ms | 8 | 10 | 12 |
| Boon | Gold Cache | \\+80 g | 10 | 8 | 6 |
| Boon | Fungal Bloom | \\+40 f; hex becomes Fungal Grove | 12 | 6 | 2 |
| Boon | Ancient Golem | Friendly Ancient Golem joins | 2 | 4 | 6 |
| Boon | Ancient Teleporter | Hex becomes a one-way gate to a random explored hex (usable 1/turn) | 1 | 3 | 5 |
| Neutral | Empty Cavern | Reveal the pocket cavern | 30 | 20 | 10 |
| Neutral | Echoing Chamber | Reveal terrain in radius 6 (Explored, not Visible) | 8 | 8 | 8 |
| Neutral | Underground Stream | 2–4 hexes become Deep Water | 6 | 8 | 6 |
| Peril | Gas Pocket | r1 Poison cloud, 15/turn for 3t | 8 | 10 | 10 |
| Peril | Spider Nest | Spawn 3 Phase Spiderlings (hostile) | 8 | 8 | 8 |
| Peril | Undead Tomb | Spawn 3 Undead Miners guarding +120g treasure on the hex | 4 | 7 | 9 |
| Peril | Sinkhole | Digging worker falls (dies); hex becomes Chasm | 2 | 4 | 6 |
| Peril | Magma Seep | r1 Burning 3t; after 5 turns hex becomes a Geothermal Vent | 1 | 4 | 12 |

  

Weights are per-ring columns of one table in data/events/breach.json; the telegraph system (§4.6) reports the *category* at 75% reliability.

### 8.3 Escalation — Wrath of the Deep + Ambient Timeline

**Per-player Wrath meter** (visible to its owner): +1 per turn per active Mithril extractor; +5 per Blast/Detonate/Sunder; +15 when a Wonder starts, +25 when it completes; +2 per turn holding the Ancient Throne; **−1 per turn decay**. At thresholds **30 / 60 / 90**: a Deep Swarm wave (small/medium/large: e.g., 3 / 6 + 1 Elemental / 10 + Magma Elementals) spawns from the nearest Core edge and hunts that player's units and extractors; the meter then resets −25.

  

**Ambient timeline (backstop):** Turn 50 — *Tremors*: lair respawn rate doubles, Core creeps upgrade one tier. Turn 100 — *The Eruption*: every 10 turns, a Magma wave targets the player with the highest current Wrath. Guarantees late games end and punishes uncontested greed — but only greed the player chose.

### 8.4 Ruins & The Ancient Throne

Ordinary Ruins: garrison 1 full turn → roll loot (Gold/ms/one-shot relic buffs; table in data/events/ruins.json); some contain lairs. **The Ancient Throne** (map center, elevation 0, permanently Dark until lit): the Deep Throne victory hex (§3.2); holding it feeds Wrath — the crown is a lightning rod.

  

## 9\. UX, Controls & Interface

### 9.1 Camera & Readability

Orbiting tactical camera (rotate 360°, tilt 15–80°, zoom 8–60 m); edge-pan + WASD; tap-select, drag-box multi-select (mobile-friendly hit targets). **Overlays (toggle):** support/stress, light, Noise pings, zone designations, elevation contours, threat (AI-visible enemy reach). Because the camera rotates, the HUD keeps a fixed north compass and a top-down minimap.

### 9.2 Screens & Widgets

Main HUD (resources + income deltas, turn, victory tracker), unit panel (stats, traits with tooltips, ability bar), build menu (validity ghosts — e.g., farm placement rule shown live), research screen (three branches per faction), event log (Noise pings, breaches, world announcements), and a **faction spike widget**: Waaagh meter / Scrap counter / Warp charges & ms / Granite-Pillar quickbar. Zone tools: Designate Mining (drag box), Set Rally (building → target).

### 9.3 Turn Flow QoL

"Next idle unit / idle worker" cycling; end-turn blockers list (idle workers, unspent research, unset production) that can be dismissed; batch move for selected groups; auto-explore toggle for Scouts (frontier-seeking).

## 10\. Art & Audio Direction (brief)

  - **Greybox first.** All MVP visuals are flat-shaded prisms and capsules with faction palette tints (Dwarf bronze/teal, Elf violet/black, Goblin lime/rust, Orc crimson/bone). Readability \> fidelity; silhouettes must differ per tier.
  - **Darkness is the art direction.** Unlit hexes render deep blue-black with faint fog; Lit hexes are warm pools. Implement lighting as a **shader tint driven by the sim's Lit/Dark state** plus a small pooled budget (≤16) of real point lights near the camera — never one engine light per brazier.
  - Rock rendered as chunked MultiMeshInstance3D (per-instance custom data = type/tint); dirty-chunk rebuilds on dig. Target: Medium map at 60 fps on mid-range hardware; SDFGI off.
  - Audio: pickaxe loops with completion "crack", muffled distant rumbles for Noise pings (directional), faction ambience beds, collapse = the biggest sound in the game.

  

# PART B — TECHNICAL SPECIFICATION & AGENT OPERATIONS

## 11\. Architecture

### 11.1 Layered Design (binding)

data/\*.json  ──►  Sim Core (engine-free)  ──►  EventBus  ──►  Renderer / UI

  

                     ▲            │

  

                Commands ◄── AI / Player input / Zone macros / Content CLI

  

  - **Sim Core** (scripts/core, scripts/sim): pure GDScript RefCounted classes. **No Node, no Scene Tree, no engine singletons, no rendering, no** **randi()** — the core must run headless byte-identically.
  - **GameState**: single serializable object — map (hex array: type, elevation, features, light, stress, knowledge per player), players (stockpiles, techs, meters), units, buildings, nodes, turn counters, and **one** **RandomNumberGenerator** **seeded at match start** (the only RNG in the program; every roll goes through state.rng).
  - **Commands** (command pattern): MoveUnit, AttackUnit, AttackHex, DigHex, CancelDig, BuildStructure, TrainUnit, ResearchTech, UseAbility, ConvertDepletedVein, SetZone, SetRally, GarrisonRuin, EndTurn. Each implements validate(state) -\> Error? and apply(state) -\> Array\[Event\]. **Every mutation of GameState goes through a Command** — the UI, the AI, zone macros, and tests all speak the same language, and a match is fully described by (seed, command\_log).
  - **EventBus**: typed events emitted by apply() (hex\_changed, unit\_moved, combat\_resolved, breach\_triggered, noise\_ping, collapse, research\_done, wave\_spawned, victory, ...). Renderer/UI subscribe; the sim never calls them.
  - **Determinism rules:** iterate collections in stable ID order; no float accumulation in rules (integers + fixed percent math, round-half-up at final step); no wall-clock or frame-time inputs. GameState.hash() (FNV over canonical serialization) must be reproducible.
  - **Save/load & replay:** save = JSON snapshot of GameState (+ ruleset version + seed + command log). Load→save must be byte-identical; replaying (seed, command\_log) must reproduce the hash.

### 11.2 Directory Structure

res://

  

├── scripts/

  

│   ├── core/        \# HexMath, Los, Pathfinder, CombatCalc, LightMap, StressMap, NoiseMap, Rng — pure & unit-tested

  

│   ├── sim/         \# GameState, TurnManager, commands/, systems/ (economy, breach, escalation, victory), RulesLoader, Serializer

  

│   ├── ai/          \# EconomyPlanner, MilitaryPlanner, TacticalResolver, personalities/

  

│   ├── render/      \# MapRenderer (chunked MultiMesh), UnitView, LightOverlay, CameraRig

  

│   └── ui/          \# HUD, panels, overlays, editors (Phase 2)

  

├── scenes/          \# Main.tscn, minimal base scenes; variants configured in code

  

├── data/            \# ruleset.json, factions/, units/, buildings/, techs/, events/, mapgen/, maps/, scenarios/

  

├── tools/           \# content\_cli.gd, sim\_smoke.gd, balance\_lab.gd, run\_tests.sh

  

├── tests/           \# GUT: unit/, sim/, golden/

  

└── docs/            \# this document, decisions.md, schema docs

### 11.3 Coding Conventions (binding)

Static typing everywhere (--warnings-as-errors in CI where feasible); class\_name PascalCase, files snake\_case, one class per file; core/sim classes extend RefCounted; public rule functions documented with the GDD section they implement (e.g., \#\# §6.1); no magic numbers — everything reads from the loaded ruleset; UI code may not import sim internals except read-only views + Command construction.

### 11.4 AI Opponent (heuristic, v1)

Three layers, all producing Commands: **EconomyPlanner** (scores dig targets by yield/distance/breach-risk, maintains worker saturation, build order per faction template, keeps housing/food ahead of training); **MilitaryPlanner** (influence/threat map from known enemies + Noise pings; postures Defend/Raid/Push; attacks when local power ratio \> 1.3; targets farms and extractors on raids); **TacticalResolver** (per-unit greedy action scoring: focus fire lowest-effective-HP, seek elevation/dark per faction, retreat below 30% HP, use abilities by scripted triggers). Faction **personalities** are weight profiles in data/ai/\*.json (e.g., Orc aggression floor tied to Waaagh decay; Elf raid preference at night… in Dark). Difficulty = resource handicap ±, not cheating vision.

## 12\. Data Schemas (the content contract)

All content is JSON validated by RulesLoader (also used by editors and the CLI — one validator, everywhere). Representative examples; full JSON-Schema files live in docs/schemas/.

### 12.1 ruleset.json (excerpt)

{

  

  "version": "2.0.0",

  

  "dig\_turns": {"soft": 1, "hard": 2, "granite": 4, "artificial\_granite": 3, "artificial\_granite\_owner": 1, "rubble": 1, "vein": 2, "mithril": 4},

  

  "dig\_yields": {"soft": {"food": 1}, "hard": {"stone": 2}, "granite": {"stone": 4}, "rubble": {"stone": 1}},

  

  "vein\_nodes": {"gold": {"lump": 25, "stock": 250, "rate": 10}, "iron": {"lump": 10, "stock": 120, "rate": 6}, "magestone": {"lump": 15, "stock": 150, "rate": 6}, "mithril": {"lump": 10, "stock": 60, "rate": 3}},

  

  "combat": {"armor\_factor": 10, "effective\_armor\_clamp": \[0, 200\], "counter\_ratio": 0.75, "min\_damage": 1},

  

  "modifiers": {"elevation\_per\_level": 0.15, "elevation\_max": 0.30, "dark\_penalty": 0.30, "cover\_arm": 2, "trench\_arm": 2},

  

  "light": {"brazier\_radius": 2, "hq\_radius": 3, "torch\_radius": 1},

  

  "structure": {"support\_radius": 2, "stress\_collapse\_threshold": 3, "collapse\_chance": 0.25, "collapse\_damage": 120},

  

  "noise": {"dig": 8, "blast": 16, "cave\_cost": 1, "solid\_cost": 2},

  

  "wrath": {"mithril\_per\_turn": 1, "blast": 5, "wonder\_start": 15, "wonder\_done": 25, "throne\_per\_turn": 2, "decay": 1, "thresholds": \[30, 60, 90\], "reset": 25},

  

  "upkeep\_deficit\_hp\_pct": 0.10, "housing": {"hq": 6},

  

  "train\_turns\_by\_tier": \[1, 2, 3, 4\], "tech\_cost\_by\_tier": \[30, 60, 120, 240\],

  

  "victory": {"throne\_hold\_turns": 10, "wonder\_survive\_turns": 8, "turn\_limit": 200}

  

}

### 12.2 Unit definition

{

  

  "id": "dwarf\_crossbow", "faction": "dwarves", "name": "Crossbow Gunner", "tier": 1,

  

  "cost": {"gold": 70, "iron": 25}, "upkeep": {"food": 1, "gold": 1},

  

  "hp": 70, "atk": 26, "pen": 10, "rng": 3, "arm": 1, "mov": 2, "vision": 4,

  

  "tags": \["infantry", "ranged"\], "traits": \[\], "actives": \[\],

  

  "trained\_at": \["dwarf\_iron\_forge"\], "requires\_tech": null,

  

  "model": "greybox/crossbow.tscn"

  

}

### 12.3 Building definition

{

  

  "id": "dwarf\_iron\_forge", "faction": "dwarves", "name": "Iron Forge",

  

  "cost": {"stone": 60, "iron": 20}, "hp": 500, "build\_turns": 2,

  

  "provides": {"trains": \["dwarf\_shield\_bearer", "dwarf\_crossbow", "dwarf\_vanguard"\]},

  

  "placement": {"min\_adjacent\_cave": 0, "on\_feature": null},

  

  "adjacency": \[{"feature": "geothermal\_vent", "effect": "train\_cost\_pct", "value": -20}\],

  

  "light\_radius": 0, "traits": \[\]

  

}

### 12.4 Tech definition

{

  

  "id": "dwarf\_blast\_mining", "faction": "dwarves", "branch": "industry", "tier": 3,

  

  "name": "Blast Mining", "cost\_ms": 120, "prereq": "dwarf\_geothermal\_tapping",

  

  "effects": \[{"type": "grant\_active", "unit\_tag": "worker", "active": {"key": "blast\_dig", "params": {"cost\_gold": 20, "max\_hardness": "hard", "noise": 16}}}\]

  

}

### 12.5 Faction definition

{

  

  "id": "goblins", "name": "Goblin Swarmers", "palette": \["\#8CCB3A", "\#8A4B2D"\],

  

  "passives": \[

  

    {"type": "dig\_speed\_mult", "value": 2.0},

  

    {"type": "unit\_cost\_pct", "resource": "gold", "value": -25},

  

    {"type": "building\_cost\_pct", "value": -30}, {"type": "building\_hp\_pct", "value": -30},

  

    {"type": "scrap\_system", "drop\_by\_tier": \[1, 2, 4, 8\], "hex\_cap": 8}

  

  \],

  

  "spike\_widget": "scrap\_counter",

  

  "roster": \["gob\_digger", "gob\_spear", "..."\], "buildings": \["gob\_warren", "..."\],

  

  "tech\_tree": "techs/goblins.json", "wonder": "gob\_mother\_drill",

  

  "start\_units": \["gob\_digger", "gob\_digger", "gob\_digger", "gob\_spear"\],

  

  "ai\_personality": "ai/goblins.json"

  

}

### 12.6 Map / scenario (authored or generated)

{

  

  "id": "the\_great\_bowl\_medium", "radius": 32, "seed": 1337,

  

  "generator": "mapgen/concentric\_bowl.json",

  

  "overrides": \[{"q": 0, "r": 0, "feature": "ancient\_throne"}\],

  

  "spawns": \[{"player": 0, "q": -20, "r": 4}\],

  

  "players": \[{"faction": "dwarves", "controller": "human"}, {"faction": "goblins", "controller": "ai"}\]

  

}

### 12.7 Trait & Active Primitives (the extensibility contract — binding)

Content composes behavior **only** from these keys. Adding a new key = code + tests + a row here.

  

**Traits (passive):**

  

|  |  |  |
| :-: | :-: | :-: |
| \*\*Key\*\* | \*\*Params\*\* | \*\*Meaning\*\* |
| worker | dig\\\_mult | Can Dig/Build; dig-speed multiplier |
| fly | — | Ignores terrain costs, chasms, water, ZOC |
| mechanical | — | No Food upkeep; no self-heal; repairable; immune Poison/Dread |
| large | — | Cosmetic scale ×2; cannot garrison ruins |
| silent | — | Actions emit no Noise |
| darkvision | — | Ignores Dark vision & damage penalties |
| torchbearer | radius | Emits light |
| mob | pct, cap | \\+dmg per adjacent same-tag ally |
| regeneration | hp | Heals at start of turn |
| demolisher | — | May attack Solid/buildings (§6.4) |
| drill | rate | Moves through Solid, converting to cave |
| hidden | — | Invisible until it acts or an enemy is adjacent |
| parry | pct | Reduces incoming melee damage |
| reckless | pct | Increases incoming damage |
| shield\\\_wall | arm, tag | \\+ARM when adjacent to tagged ally |
| ambusher | pct | Bonus damage when attacking from Dark |
| venom | dmg, dur | Applies Poison on hit |
| aura | status/bonus, radius, target | Constant area effect |
| splash | radius, pct | Attack splashes to area |
| stalwart | — | Immune Dread & Root |
| rampage | max\\\_extra | Extra attack on kill |
| beast / capturable | — | Tag hooks for Tame / Enslave |
| enslaver | chance | Convert killed workers |
| scrap\\\_eater | cost, heal | Consume Scrap to heal |
| pillage | pct | Damage vs. buildings returns Gold |
| warp | range, cd, cost\\\_ms | Teleport to known Dark cave hex |
| blood\\\_rush | pct | Bonus vs. wounded |
| steam\\\_charge | flat | Bonus after moving ≥2 |
| overwatch | — | Reaction shot (tech-granted) |

  

**Actives (targeted, cost/cooldown in params):** detonate(dmg, radius, max\_hardness), blast\_dig, sunder\_ceiling, raise\_solid(type, cost), place\_pillar, survey(radius), apply\_status(status, ...), heal(hp) / repair(hp), quench(max\_size) / darken(radius, dur), eclipse(radius, dmg, dur), void\_bolt(dmg) (ignores ARM), summon(unit\_id, cost), tame(max\_tier, hp\_pct, cd), goad, drain\_ally(hp, waaagh, heal), root(dur), hurl(atk, pen, rng, cd), earthshaker(dmg, radius, root), dissolve\_solid(cost), harvest\_scrap, convert\_vein.

## 13\. Testing & The Agent Loop

### 13.1 Commands the agent runs

bash tools/run\_tests.sh                \# GUT: godot --headless -s addons/gut/gut\_cmdln.gd -gdir=res://tests -gexit

  

godot --headless -s tools/sim\_smoke.gd -- seed=42 turns=60 map=small factions=dwarves,goblins

  

godot --headless -s tools/content\_cli.gd -- validate data/

  

godot --headless -s tools/balance\_lab.gd -- matches=100 out=reports/balance.csv   \# Phase 2+

### 13.2 Test pyramid

1.  **Unit tests** (tests/unit/): every core/ function and every Command's validate/apply — including edge cases named in this doc (armor clamp, min damage, cliff movement, farm placement, support BFS, Noise budgets, Warp legality).
2.  **System tests** (tests/sim/): scripted mini-scenarios — a collapse kills a stack; a breach table respects weights over 10k seeded draws (χ² tolerance); an upkeep deficit bleeds HP; Waaagh tiers apply and decay; instant-spawned unit is exhausted.
3.  **Golden tests** (tests/golden/): fixed seed + recorded command log ⇒ recorded GameState.hash() after N turns. Any rules change that legitimately alters the hash must re-record goldens **in the same commit** with a docs/decisions.md entry.
4.  **Smoke/integration:** AI vs. AI, 60 turns headless: no errors, invariants hold every turn — stockpiles ≥ 0, unit HP ∈ (0, max\], no unit on Solid, housing respected, hash stable across save→load→resave.
5.  **Perf guard:** full turn resolution \< 100 ms on a Medium map in headless (CI machine baseline; warn, don't fail, at \< 250 ms).

### 13.3 The loop itself

pick next milestone task → (re)read the relevant GDD section → write/extend tests first when the rule is tabular → implement → run 13.1 suite → fix until green → update docs/decisions.md if anything deviated → commit with task ID. Tasks should be ≤ \~300 LOC of change; split anything larger.

### 13.4 When blocked

If a rule is ambiguous: choose the simplest interpretation consistent with the pillars (§1.1), implement it, and log the choice in decisions.md. Never stall; never invent new resources, stats, or systems not in this document.

### 13.5 Content-pipeline rule

From milestone M6 onward, adding a unit/building/tech to data/ must require zero engine-code changes (only primitives from §12.7). CI includes a canary: a throwaway JSON unit is injected and must appear, train, fight, and serialize correctly.

### 13.6 Definition of Done (every task)

## Tests green headless · static typing clean · constants read from data, not code · events emitted for every state change · goldens re-recorded only with a logged reason · relevant doc table updated if numbers moved.

## 14\. Implementation Plan — Phase 1: MVP

**Goal:** every core mechanic exists and is testable; the game is *fun to play* against an AI with two max-contrast factions (**Dwarves vs. Goblins** — turtle-terraformer vs. fast swarm, exercising granite-shaping, collapse, blasting, scrap, and dig-speed asymmetry); and the **data import pipeline is proven** so later content requires no code. Warp/light/tame/etc. primitives are implemented and tested in MVP even though their signature factions arrive in Phase 3.

  

|  |  |  |  |
| :-: | :-: | :-: | :-: |
| \*\*ID\*\* | \*\*Milestone\*\* | \*\*Deliverables\*\* | \*\*Acceptance criteria (must pass headless)\*\* |
| \*\*M0\*\* | Bootstrap | Godot project, GUT wired, run\\\_tests.sh, EventBus, RulesLoader + ruleset.json, CI script, decisions.md | Empty suite runs green headless; invalid ruleset rejected with a line-numbered error |
| \*\*M1\*\* | World | HexMath (axial/cube, LOS, lines, rings), concentric-bowl generator, chunked MultiMesh renderer, camera rig, hex picking | Golden mapgen test (seed ⇒ terrain hash); 60 fps on Medium map greybox; LOS property tests |
| \*\*M2\*\* | Dig & Economy | Workers, Dig/Cancel commands, yields, vein nodes + Extractors, stockpiles/income/upkeep, housing, Mining Zones v0 | Scripted 20-turn dig scenario matches expected stockpiles exactly; deficit-bleed test; zone assigns nearest idle worker |
| \*\*M3\*\* | Build, Light, Structure | Build/Train commands & queues, placement validators (farm rule), Brazier/light BFS, Pillars, stress & collapse | Light overlay matches BFS oracle; collapse scenario golden; farm placement rejected/accepted correctly |
| \*\*M4\*\* | Units & Combat | Movement/pathfinding/ZOC/elevation costs, combat per §6 (clamps, counters, cover, dark, high ground), full trait/active primitive set (§12.7), statuses | Combat table test: 40 hand-computed cases match; Warp legality suite; Detonate/Drill vs. Solid tests |
| \*\*M5\*\* | Living World | Breach tables + telegraphs, Noise system, creeps + lairs + bounty, Wrath meter + waves, ambient timeline | Seeded breach distribution χ² test; Noise budget propagation cases; wave spawns at thresholds and hunts correctly |
| \*\*M6\*\* | Factions from Data | Dwarves & Goblins fully loaded from JSON (rosters, buildings, techs, passives, spikes), research system, victory conditions | \*\*Canary test (§13.5): a new JSON unit works with zero code changes.\*\* Both spikes verified (granite reshaping; scrap drop→harvest→instant spawn). All 3 victories reachable in scripted tests |
| \*\*M7\*\* | AI v0 + Persistence | Three-layer heuristic AI, save/load, replay from (seed, command log) | AI vs. AI 60-turn smoke green with invariants; save→load→resave byte-identical; replay hash matches |
| \*\*M8\*\* | Playable Alpha | HUD, overlays, tooltips, next-turn QoL, event log, spike widgets, audio stubs, first tuning pass | A human completes a full match vs. AI on Medium; fun checklist review (§14.1) recorded; perf guard green |

### 14.1 MVP fun checklist (human/agent playtest rubric)

First breach felt like a bet (telegraph read, outcome mattered) · a Noise ping changed a decision · a chokepoint was broken by dig/blast/collapse at least once per match · the wide farm chamber was attacked or defended · turns 1–15 contained ≥ 3 meaningful choices each · session ended by a victory condition, not fatigue. Failures here spawn tuning tasks before Phase 2 begins.

## 15\. Implementation Plan — Phase 2: Editors

**Goal:** anyone — including a headless agent — can create maps, factions, units, buildings, and tech trees **without writing code**, with the exact same validation the game uses.

  

|  |  |  |  |
| :-: | :-: | :-: | :-: |
| \*\*ID\*\* | \*\*Milestone\*\* | \*\*Deliverables\*\* | \*\*Acceptance criteria\*\* |
| \*\*E1\*\* | Editor Shell | In-app editor mode; \*\*schema-driven form generation\*\* (forms auto-built from docs/schemas/\\\*); shared RulesLoader validation with inline errors; JSON round-trip | Editing any existing entity and saving produces validated, diff-minimal JSON; invalid input cannot be saved |
| \*\*E2\*\* | Map Editor | Paint terrain/elevation/veins/features, ring-generator parameter panel, spawn placement, "Test Play" launches a match on the edit | An authored map saves, loads in-game, and passes generator invariants (spawn fairness report: resource access within ±10%) |
| \*\*E3\*\* | Entity Editors | Unit/building/tech/faction editors with live stat preview and an embedded \*\*combat calculator\*\* (pick attacker/defender/modifiers → damage per §6.1) | Recreating the Crossbow Gunner from scratch via UI yields JSON identical to the shipped file |
| \*\*E4\*\* | \*\*Headless ContentAPI (CLI)\*\* | content\\\_cli.gd verbs: validate, create \\\<type\\\> --from-json/-stdin, update, list, diff, export-pack, import-pack — same validators, scriptable | Agent creates a new unit via CLI in headless mode; it appears in game and passes the M6 canary; malformed input exits non-zero with actionable errors |
| \*\*E5\*\* | Balance Lab | balance\\\_lab.gd: batch AI-vs-AI matches (seeds, factions, maps) → CSV/JSON report (winrates, match length, resource curves, unit usage, cause-of-victory) | 100-match batch completes unattended; report renders in editor dashboard; results reproducible per seed set |

## 16\. Implementation Plan — Phase 3: Content

**Goal:** ship the full game — all four factions, the neutral world, map library, and a data-driven balance campaign — **authored exclusively through the Phase 2 editor CLI** (proving the pipeline; hand-edited JSON is a bug).

  

|  |  |  |  |
| :-: | :-: | :-: | :-: |
| \*\*ID\*\* | \*\*Milestone\*\* | \*\*Deliverables\*\* | \*\*Acceptance criteria\*\* |
| \*\*C1\*\* | Umbral Elves | Full roster/buildings/techs/passives from §7.2 via CLI; Elf AI personality (dark-seeking raids, lamp targeting) | All Elf entities pass validation & canary; Elf AI wins ≥ 1 of 20 smoke matches vs. each MVP faction |
| \*\*C2\*\* | Orcish Warbands | §7.4 via CLI; Waaagh widget; Orc AI (raid metronome keyed to meter decay) | Meter tiers observable in sim traces; Tame/Enslave/Pillage integration tests green |
| \*\*C3\*\* | Neutral World Pack | Creep roster (§8.1), lairs, ruins loot tables, full breach tables (§8.2), Great Worm boss, Throne behavior | Ring-weighted breach draws match spec; Worm drills correctly; Throne victory E2E test |
| \*\*C4\*\* | Map & Mode Library | 6 presets via map editor: Skirmish S/M/L, Deep Duel (1v1, thin Rim), Chasm Maze, The Great Bowl (4p showcase); scenario configs | Each map passes fairness report; all shipped scenarios complete AI-vs-AI without error |
| \*\*C5\*\* | Balance Campaign | Iterative tuning via Balance Lab: full faction matrix × 3 maps × 200 seeded matches per iteration; patch data via CLI; record baseline goldens | Targets: every matchup winrate 45–55%; median match 80–140 turns; each faction's T1 units ≥ 10% of armies at turn 60 (T1s stay relevant); no strategy \\\> 65% winrate across personalities |
| \*\*C6\*\* | Polish & RC | Faction VFX/SFX passes, UI theming, onboarding tips (first dig, first breach, spike explainer), settings, release candidate build | Fun checklist (§14.1) passes for all four factions; perf guard green on Large map; zero known invariant violations |

## 17\. Risks, Non-Goals & Extension Points

### 17.1 Risks & Mitigations

|  |  |
| :-: | :-: |
| \*\*Risk\*\* | \*\*Mitigation\*\* |
| Chokepoint meta collapses fun despite counters | Balance Lab tracks "siege stall" metric (turns with frontline contact but \\\< X damage); tune blast/collapse costs first, dig times second |
| Pathfinding/light/stress cost on Large maps | All three are bounded BFS with dirty-region recompute; hierarchical pathfinding is a known upgrade path — measure before adding |
| Godot headless quirks (GUT, no render server) | Sim core is render-free by construction; renderer tested only via manual smoke + screenshot diffs later |
| AI too weak/exploitable | Personalities are data; Balance Lab exposes exploit winrates; heuristic layers are independently improvable |
| Scope creep via "cool ideas" | §17.2 is binding; new systems require a decisions.md entry \*and\* a doc revision |
| Float non-determinism across platforms | Integer/percent math with single final rounding; hash tests run in CI on the target platform |

### 17.2 Non-Goals for v1 (binding)

Online multiplayer · story campaign · diplomacy/trade systems · hero units · fluid/lava simulation (floods are one-shot events) · multiple stacked depth strata · modding documentation (the data pipeline enables it later; not a v1 deliverable).

### 17.3 Extension Points (designed-for, not built)

Second depth stratum connected by shaft features (map gains a layer int; pathfinder already graph-based) · hotseat (sequential turns make it nearly free) · heroes as units with a hero trait + XP field · diplomacy as new Command types · seasonal "deep tides" events reusing the escalation spawner · Steam Workshop-style content packs via export-pack/import-pack.

## 18\. Glossary

**Breach** — event fired when a dig opens an undiscovered cavern. **Cave hex** — open, passable hex. **Dark/Lit** — light state of a cave hex (§4.7). **Deep Swarm / Wrath** — escalation system (§8.3). **Lump/Node** — instant vs. sustained vein yield (§4.2). **Noise** — dig/blast information leak (§4.8). **Primitive** — a trait/active key from §12.7. **Scrap** — Goblin corpse-resource. **Solid hex** — rock; blocks movement/LOS/light. **Spike** — a faction's rule-warping core mechanic. **Support/Stress** — structural integrity values (§4.5). **Waaagh** — Orc momentum meter. **Warp** — Elf teleport-through-rock. **WEGO/IGOUGO** — simultaneous vs. sequential turns; this game is IGOUGO.

  

  

*Document changelog: v2.0 — full agent-ready rewrite: added §0 usage contract, §2 design review & binding change log, §3 victory/turn spec, formalized world systems (§4), split resources & economy rules (§5), deterministic combat (§6), complete four-faction content bible (§7), neutral world & escalation (§8), UX (§9), art direction (§10), architecture & determinism rules (§11), data schemas & primitive contract (§12), test/agent loop (§13), and the three-phase plan with acceptance criteria (§14–§16).*

  