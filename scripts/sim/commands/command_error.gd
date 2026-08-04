## CommandError — one rejection produced by a [Command].validate (GDD §11.1: "Each implements
## validate(state) -> Error? and apply(state) -> Array[Event]").
##
## Deliberately NOT [RulesError]: that type's `line` is 1-based over a DOCUMENT with 0 reserved
## for file-level failures (M0-T2 item 2) and its `path` is a dotted JSON key path. A command
## rejection has neither a document nor a line, so reuse would either abuse the reserved 0
## forever or carry a permanently dead field. Same SHAPE (a plain RefCounted of public data
## fields plus a `format_for(source)` renderer), command-appropriate contents.
##
## Codes are OPAQUE StringNames authored by each Command at its own call site — there is NO enum,
## NO const list and NO whitelist here (the (AU)(iv) / (T) / (AH) precedent).
class_name CommandError
extends RefCounted

## §11.1 — opaque rejection code, authored by the rejecting Command.
var code: StringName = &""

## §11.1 — human-actionable description of why the command was rejected.
var message: String = ""


func _init(p_code: StringName, p_message: String) -> void:
	code = p_code
	message = p_message


## §11.1 — renders "<source>: <code>: <message>", where source is the caller's own label (a
## command name, a test name) — never a file path, because a command rejection has no document.
func format_for(source: String) -> String:
	return "%s: %s: %s" % [source, String(code), message]
