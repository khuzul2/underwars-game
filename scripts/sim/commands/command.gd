## Command — GDD §11.1 (binding): "Commands (command pattern): MoveUnit, AttackUnit, AttackHex,
## DigHex, CancelDig, BuildStructure, TrainUnit, ResearchTech, UseAbility, ConvertDepletedVein,
## SetZone, SetRally, GarrisonRuin, EndTurn. Each implements validate(state) -> Error? and
## apply(state) -> Array[Event]. Every mutation of GameState goes through a Command ... and a
## match is fully described by (seed, command_log)."
##
## `execute` is THE ONE GATE: §11.1 gives `validate` and `apply` but composes them nowhere, so
## without a single composed entry point any caller could apply() past validation. Contract:
## call validate(state); on a non-null return, return it IMMEDIATELY having mutated nothing and
## emitted nothing; otherwise call apply(state), route the returned events through
## EventBus.emit_all when a bus is supplied (bus == null is a legal, silent, headless drop), and
## return null. execute never hands the events back — callers who want them subscribe to the bus,
## because the sim emits and never calls the renderer.
##
## The base validate REJECTS (with a code authored at its own call site) so a subclass that
## forgets to override validate fails closed rather than being silently applied.
##
## DELIBERATELY OUT OF SCOPE at M2-T2 (§13.4 — invent nothing ahead of its milestone): every
## other §11.1 command (MoveUnit, AttackUnit, AttackHex, DigHex, CancelDig, BuildStructure,
## TrainUnit, ResearchTech, UseAbility, ConvertDepletedVein, SetZone, SetRally, GarrisonRuin);
## Command.to_dict()/serialization and a CommandLog class (§11.1 save/load is M7).
class_name Command
extends RefCounted


## §11.1 — the command's stable name. The base correctly answers the empty name; a concrete
## command overrides this with one of the fourteen §11.1 printed command names.
func command_name() -> StringName:
	return &""


## §11.1 — the base REJECTS: an unoverridden subclass must fail closed rather than being applied
## by accident.
func validate(_state: GameState) -> CommandError:
	return CommandError.new(
		&"abstract_command", "Command.validate was not overridden by a concrete command"
	)


## §11.1 — the base emits nothing.
func apply(_state: GameState) -> Array[Event]:
	var out: Array[Event] = []
	return out


## §11.1 — THE ONE GATE: validate -> apply -> EventBus.emit_all, so nothing can apply without
## validating. Returns the rejection on an illegal command (mutating and emitting nothing), or
## null on success. `bus == null` is legal (headless) and is a silent drop.
func execute(state: GameState, bus: EventBus) -> CommandError:
	var rejection: CommandError = validate(state)
	if rejection != null:
		return rejection
	var events: Array[Event] = apply(state)
	if bus != null:
		bus.emit_all(events)
	return null
