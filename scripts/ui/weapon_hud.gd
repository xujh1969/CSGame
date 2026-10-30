extends CanvasLayer

@onready var weapon = $"../WeaponController"
var flow: Node
var presentation: Node
var previous_health := 100
var damage_time := 0.0
var hit_time := 0.0

func _ready() -> void:
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_changed.connect(_on_reload_changed)
	weapon.hit.connect(_on_hit)
	$Reset.pressed.connect(_reset)
	$Pause.pressed.connect(_pause)
	$Overlay/Panel/Margin/Column/Resume.pressed.connect(_pause)
	$Overlay/Panel/Margin/Column/Retry.pressed.connect(_reset)
	$Overlay/Panel/Margin/Column/Next.pressed.connect(_next)
	$Overlay/Panel/Margin/Column/Quality.item_selected.connect(_quality)
	_on_ammo_changed(weapon.magazine, weapon.reserve)
	var health := get_node("../HealthComponent")
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current_health, health.max_health)
	_bind_flow.call_deferred()

func _bind_flow() -> void:
	flow = get_tree().get_first_node_in_group("game_flow")
	presentation = get_tree().get_first_node_in_group("battle_presentation")
	$Pause.visible = flow != null
	$Reset.visible = flow == null
	if flow != null:
		flow.state_changed.connect(_flow_state)
		flow.objective_changed.connect(_objective)
		_objective(flow.get_objective())
		_flow_state(flow.State.keys()[flow.state])
	else:
		_objective("武器测试场")

func _on_health_changed(current: int, maximum: int) -> void:
	if current < previous_health:
		damage_time = 0.2
	previous_health = current
	$Health.text = "生命  %d" % current
	$HealthBar.max_value = maximum
	$HealthBar.value = current

func _on_ammo_changed(magazine: int, reserve: int) -> void:
	$Ammo.text = "%02d  /  %02d" % [magazine, reserve]
	_on_reload_changed(weapon.reloading)

func _on_reload_changed(active: bool) -> void:
	$State.text = "装填中…" if active else ("按 R 装填" if weapon.magazine == 0 and weapon.reserve > 0 else "")
	if weapon.magazine == 0 and weapon.reserve == 0:
		$State.text = "弹药耗尽"

func _on_hit(_target: Node, _damage: int) -> void:
	hit_time = 0.12

func _process(delta: float) -> void:
	damage_time = maxf(0, damage_time - delta)
	hit_time = maxf(0, hit_time - delta)
	$DamageFlash.color.a = damage_time * 0.8
	$Hitmark.visible = hit_time > 0

func _objective(text: String) -> void:
	$Objective.text = text

func _flow_state(state: StringName) -> void:
	var column := $Overlay/Panel/Margin/Column
	var next_available: bool = state == &"WON" and flow.has_next_level()
	$Overlay/Panel.offset_top = -190.0 if state == &"PAUSED" else (-170.0 if next_available else -135.0)
	$Overlay/Panel.offset_bottom = 210.0 if state == &"PAUSED" else (170.0 if next_available else 135.0)
	$Overlay.visible = state != &"RUNNING"
	column.get_node("Resume").visible = state == &"PAUSED"
	column.get_node("Quality").visible = state == &"PAUSED"
	column.get_node("QualityLabel").visible = state == &"PAUSED"
	column.get_node("Next").visible = next_available
	if state == &"PAUSED":
		column.get_node("Title").text = "已暂停"
		column.get_node("Description").text = "战斗与装填计时已冻结"
		column.get_node("Resume").grab_focus()
	elif state == &"FAILED":
		column.get_node("Title").text = "行动失败"
		column.get_node("Description").text = "利用实体掩体，注意高窗与换弹时机。"
		column.get_node("Retry").grab_focus()
	elif state == &"WON":
		var in_campaign: bool = is_instance_valid(flow.session)
		column.get_node("Title").text = "验证战役完成" if in_campaign and not next_available else "街段已清除"
		column.get_node("Description").text = "威胁解除 · 已抵达本关终点"
		column.get_node("Next" if next_available else "Retry").grab_focus()

func _next() -> void:
	if is_instance_valid(flow):
		flow.advance()

func _pause() -> void:
	if is_instance_valid(flow):
		flow.toggle_pause()

func _reset() -> void:
	if is_instance_valid(flow):
		flow.restart()
	else:
		get_tree().reload_current_scene()

func _quality(index: int) -> void:
	if is_instance_valid(presentation):
		presentation.set_low_quality(index == 1)
