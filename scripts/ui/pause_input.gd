class_name PauseInput
extends Node
## Nimmt Eingaben an, solange das Spiel mit P pausiert ist (SceneTree.paused): Spielszenen selbst bekommen dann
## keine Eingaben mehr. on_event bekommt jedes unbehandelte Ereignis.

var on_event: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _unhandled_input(event: InputEvent) -> void:
	if on_event.is_valid():
		on_event.call(event)
