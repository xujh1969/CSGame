extends Node3D

var remaining := 0.0

func trigger() -> void:
	remaining = 0.05
	visible = true

func _process(delta: float) -> void:
	remaining = maxf(0, remaining - delta)
	visible = remaining > 0
