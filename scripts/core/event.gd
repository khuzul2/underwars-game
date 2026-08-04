## Typed event base — GDD §11.1: "EventBus: typed events emitted by apply() ... Renderer/UI
## subscribe; the sim never calls them", and §11.1 Commands: "apply(state) -> Array[Event]".
##
## §11.3 conventions: pure RefCounted (no Node, no scene tree, no engine singletons), static
## typing everywhere, one class per file, PascalCase class_name in a snake_case file.
##
## §13.4 note: the event names §11.1 lists are ILLUSTRATIVE and open-ended, so this file defines
## no vocabulary and no concrete event subclasses — those arrive with the milestones that emit
## them. A subclass adds typed payload fields and appends them in to_dict().
class_name Event
extends RefCounted

## §11.1 — the event's type name. Write-once: set at construction, never reassigned afterwards.
var type: StringName = &""


## §11.1 — construct a typed event; p_type is the event name chosen by the emitting Command.
func _init(p_type: StringName) -> void:
	type = p_type


## §11.1 — canonical Dictionary form for deterministic logging/serialization. "type" is inserted
## FIRST so subclass payload keys follow it in declaration order and key order stays stable.
func to_dict() -> Dictionary:
	return {"type": String(type)}
