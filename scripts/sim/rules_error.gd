## One validation failure produced by [RulesLoader] (GDD §12, §14 M0 acceptance:
## "invalid ruleset rejected with a line-numbered error").
##
## Pure [RefCounted]: no Node, no SceneTree, no engine singletons (§11.1).
class_name RulesError
extends RefCounted

## 1-based line in the source document (first line == 1). 0 means "no line" and is reserved
## for file-level failures (missing / unreadable file) — the only permitted 0.
var line: int = 0

## Dotted key path the failure belongs to ("dig_turns.soft"), or "" for whole-document
## failures such as a JSON syntax error.
var path: String = ""

## Human-actionable description of what is wrong.
var message: String = ""


## §14 M0 — renders the error as "<source>:<line>: <message>" so the loop's output is
## actionable.
func format_for(source: String) -> String:
	return "%s:%d: %s" % [source, line, message]
