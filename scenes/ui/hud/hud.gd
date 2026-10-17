class_name HUD
extends CanvasLayer
## On-screen info for the local player, styled after How to Fish:
##   - top left: quest tip (what to do next), J shows/hides it
##   - middle: aiming dot, and "Pick up Stone / [E]" when looking at an item
##   - bottom left: round health / food icons (and breath while underwater)
##   - bottom middle: hint text, stamina bar, inventory slots 1-4,
##     and the hand slot (only while holding something)
##   - bottom right: money
##   - blue tint while the head is under water, red flash when taking damage
## Set `player` before adding the HUD to the scene.

const HEALTH_COLOR := Color(0.95, 0.42, 0.4)
const FOOD_COLOR := Color(0.97, 0.75, 0.4)
const BREATH_COLOR := Color(0.45, 0.78, 1.0)
const STAMINA_COLOR := Color(0.65, 0.9, 0.45)
const TIRED_COLOR := Color(0.95, 0.5, 0.3)
const SLOT_SIZE := Vector2(52, 52)
## How quickly the stamina bar slides to its new value (higher = faster).
const BAR_SMOOTHING := 14.0

var player: Node

var _money: Label
var _quest_tip: QuestTip
var _health_ring: StatRing
var _food_ring: StatRing
var _breath_ring: StatRing
var _stamina_bar: ProgressBar
var _stamina_fill: StyleBoxFlat
var _stamina_target := 100.0
var _pickup_name: Label
var _pickup_key: Label
var _hint: Label
var _slots: Array[Dictionary] = []
var _hand_slot: Dictionary
var _hand_gap: Control
var _dialogue: DialogueBox
var _underwater_tint: ColorRect
var _damage_flash: ColorRect


func _ready() -> void:
	add_to_group("hud")
	_build()
	if player == null:
		return
	player.dialogue_requested.connect(_dialogue.open)
	player.health_changed.connect(_health_ring.set_value)
	player.food_changed.connect(_food_ring.set_value)
	player.breath_changed.connect(_on_breath_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.damaged.connect(_on_damaged)
	player.inventory.changed.connect(_refresh_inventory)
	_health_ring.set_value(player.health, player.max_health)
	_food_ring.set_value(player.food, player.max_food)
	for ring in [_health_ring, _food_ring]:
		ring.snap()
	_on_breath_changed(player.breath, player.breath_time)
	_on_stamina_changed(player.stamina, player.max_stamina)
	_stamina_bar.value = player.stamina
	_refresh_inventory()


## Shows a quest tip in the top left corner.
func show_tip(title: String, body: String, seconds: float = 20.0) -> void:
	_quest_tip.show_tip(title, body, seconds)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tip"):
		_quest_tip.toggle()
	elif event.is_action_pressed("interact") and _dialogue.is_open() and not player.in_menu:
		_dialogue.advance()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_damage_flash.color.a = move_toward(_damage_flash.color.a, 0.0, delta * 0.8)
	# Slide the stamina bar quickly instead of jumping.
	_stamina_bar.value = lerpf(_stamina_bar.value, _stamina_target, 1.0 - exp(-BAR_SMOOTHING * delta))
	if player == null:
		return
	_underwater_tint.visible = player.is_head_underwater
	var target: Node = player.get_interact_target()
	_pickup_name.visible = target != null
	_pickup_key.visible = target != null
	if target != null:
		_pickup_name.text = target.get_interact_text()
	_pickup_key.text = "[%s]" % Settings.get_binding_text("interact")
	if player.inventory.hand_item != null and not _dialogue.is_open():
		_hint.text = "[%s-%s] Store     [%s] Drop" % [Settings.get_binding_text("slot_1"),
				Settings.get_binding_text("slot_4"), Settings.get_binding_text("drop")]
	else:
		_hint.text = ""


# --- Building the layout ---------------------------------------------------

func _build() -> void:
	_underwater_tint = _full_screen_rect(Color(0.05, 0.28, 0.48, 0.5))
	_underwater_tint.visible = false
	_damage_flash = _full_screen_rect(Color(0.8, 0.05, 0.05, 0.0))

	var crosshair := ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.85)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -2
	crosshair.offset_top = -2
	crosshair.offset_right = 2
	crosshair.offset_bottom = 2
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	# "Pick up Stone" with "[E]" underneath, just below the aiming dot.
	var pickup := VBoxContainer.new()
	pickup.add_theme_constant_override("separation", -4)
	pickup.set_anchors_preset(Control.PRESET_CENTER)
	pickup.offset_left = -200
	pickup.offset_right = 200
	pickup.offset_top = 24
	pickup.offset_bottom = 110
	pickup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pickup)
	_pickup_name = UiStyle.label("", 30)
	_pickup_key = UiStyle.label("[E]", 28)
	for l in [_pickup_name, _pickup_key]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pickup.add_child(l)

	_quest_tip = QuestTip.new()
	_quest_tip.position = Vector2(22, 22)
	add_child(_quest_tip)

	_build_stats()
	_build_hotbar()
	_build_money()

	# Conversations appear just above the inventory.
	_dialogue = DialogueBox.new()
	_dialogue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialogue.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialogue.offset_top = -120
	_dialogue.offset_bottom = -120
	add_child(_dialogue)


func _full_screen_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


## Bottom left: round stat icons.
func _build_stats() -> void:
	var rings := HBoxContainer.new()
	rings.add_theme_constant_override("separation", 8)
	rings.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	rings.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rings.offset_left = 22
	rings.offset_top = -22
	rings.offset_bottom = -22
	add_child(rings)
	_health_ring = StatRing.new(StatRing.Kind.HEART, HEALTH_COLOR)
	_food_ring = StatRing.new(StatRing.Kind.FOOD, FOOD_COLOR)
	_breath_ring = StatRing.new(StatRing.Kind.BREATH, BREATH_COLOR)
	for ring in [_health_ring, _food_ring, _breath_ring]:
		rings.add_child(ring)


## Bottom right: money in a rounded outline box.
func _build_money() -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.outline_style())
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = -22
	box.offset_right = -22
	box.offset_top = -26
	box.offset_bottom = -26
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_money = UiStyle.label("$0", 26) # Cash comes in a later stage.
	box.add_child(_money)


## Bottom middle: hint text, stamina bar, then the slots.
func _build_hotbar() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_top = -18
	column.offset_bottom = -18
	add_child(column)

	_hint = UiStyle.label("", 17, UiStyle.DIM_TEXT_COLOR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)

	var slots_width := SLOT_SIZE.x * 4 + 6 * 3
	_stamina_bar = ProgressBar.new()
	_stamina_bar.show_percentage = false
	_stamina_bar.step = 0.0 # Allow smooth in-between values.
	_stamina_bar.custom_minimum_size = Vector2(slots_width, 6)
	_stamina_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.35)
	background.set_corner_radius_all(3)
	_stamina_fill = StyleBoxFlat.new()
	_stamina_fill.bg_color = STAMINA_COLOR
	_stamina_fill.set_corner_radius_all(3)
	_stamina_bar.add_theme_stylebox_override("background", background)
	_stamina_bar.add_theme_stylebox_override("fill", _stamina_fill)
	column.add_child(_stamina_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for i in 4:
		var slot := _make_slot(str(i + 1))
		_slots.append(slot)
		row.add_child(slot.root)
	_hand_gap = Control.new()
	_hand_gap.custom_minimum_size = Vector2(12, 0)
	row.add_child(_hand_gap)
	_hand_slot = _make_slot("")
	row.add_child(_hand_slot.root)


## One inventory slot box. Returns its parts in a Dictionary.
func _make_slot(key_text: String) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = SLOT_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var icon := ItemIcon.new()
	icon.position = Vector2(4, 4)
	icon.size = SLOT_SIZE - Vector2(8, 8)
	panel.add_child(icon)

	var key := UiStyle.label(key_text, 13)
	key.position = Vector2(5, -1)
	panel.add_child(key)

	# Stack size, bottom right (only shown for 2 or more).
	var count := UiStyle.label("", 18)
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count.offset_right = -6
	count.offset_bottom = -2
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(count)
	return {root = panel, style = style, icon = icon, count = count}


# --- Updating ----------------------------------------------------------------

func _on_breath_changed(current: float, maximum: float) -> void:
	_breath_ring.set_value(current, maximum)
	# Only show breath while it matters: under water or still refilling.
	_breath_ring.visible = current < maximum or player.is_head_underwater


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.max_value = maximum
	_stamina_target = current
	# Faded when full, solid while being used.
	_stamina_bar.modulate.a = 0.45 if current >= maximum else 1.0
	_stamina_fill.bg_color = TIRED_COLOR if player.is_exhausted else STAMINA_COLOR


func _on_damaged(_amount: float) -> void:
	_damage_flash.color.a = maxf(_damage_flash.color.a, 0.18)


func _refresh_inventory() -> void:
	var inventory: Inventory = player.inventory
	for i in _slots.size():
		var selected: bool = inventory.hand_item == null and inventory.selected_slot == i
		_show_slot(_slots[i], inventory.slots[i], selected, inventory.slot_counts[i])
	# The hand slot only appears while holding something.
	var holding: bool = inventory.hand_item != null
	_hand_slot.root.visible = holding
	_hand_gap.visible = holding
	_show_slot(_hand_slot, inventory.hand_item, true, inventory.hand_count)
	_hand_slot.style.border_color = Color(1.0, 0.82, 0.4, 0.95)


func _show_slot(slot: Dictionary, item: ItemData, selected: bool, count: int = 1) -> void:
	slot.count.text = "x%d" % count if count > 1 else ""
	slot.style.bg_color = Color(0, 0, 0, 0.45) if selected else Color(0, 0, 0, 0.28)
	slot.style.border_color = Color(1, 1, 1, 0.95) if selected else Color(1, 1, 1, 0.3)
	slot.style.set_border_width_all(2 if selected else 1)
	slot.icon.set_item(item)
