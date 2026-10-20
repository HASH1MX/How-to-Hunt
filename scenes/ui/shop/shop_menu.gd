class_name ShopMenu
extends Control
## Trader Tomas's shop on Island 2: buy guns (shotgun, SMG, assault rifle, sniper rifle,
## and a pistol if you lost yours) and boxes of ammo with the money you earn hunting.
## In the same look as the other menus. Opened by talking to the trader.

signal closed

## Boxes of ammo for sale: [ammo type, rounds per box, price, name].
const AMMO_BOXES := [
	["pistol", 16, 20, "Pistol bullets"],
	["shells", 10, 30, "Shotgun shells"],
	["smg", 60, 35, "SMG bullets"],
	["rifle", 60, 45, "Rifle bullets"],
	["sniper", 10, 60, "Sniper bullets"],
]

var player: Node

var _money: Label
var _list: VBoxContainer
var _message: Label


func _ready() -> void:
	theme = UiStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	player.in_menu = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(0.9))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(620, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := UiStyle.label("Tomas's Trading Post", 34, Color(1.0, 0.95, 0.84))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_money = UiStyle.label("", 28, Color(0.6, 1.0, 0.6))
	header.add_child(_money)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_message = UiStyle.label("", 18, UiStyle.DIM_TEXT_COLOR)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	var back := Button.new()
	back.text = "Back"
	back.flat = true
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_color_override("font_color", UiStyle.DIM_TEXT_COLOR)
	back.add_theme_color_override("font_hover_color", UiStyle.TITLE_COLOR)
	back.pressed.connect(close)
	column.add_child(back)
	_refresh()


func close() -> void:
	player.in_menu = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_money.text = "$%d" % player.money
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_list.add_child(UiStyle.label("Weapons", 22, UiStyle.TITLE_COLOR))
	for weapon in ItemLibrary.weapons():
		if weapon.price <= 0:
			continue
		var owned: bool = player.inventory.has_item(weapon.id)
		var info := "%s damage, %s" % [_damage_text(weapon), "%d rounds" % weapon.magazine]
		_list.add_child(_row(weapon.display_name, info, weapon.price, "Owned" if owned else "Buy", not owned, _buy_weapon.bind(weapon)))
	_list.add_child(UiStyle.label("Ammo", 22, UiStyle.TITLE_COLOR))
	for box in AMMO_BOXES:
		var have: int = player.weapons.get_reserve(box[0])
		_list.add_child(_row(box[3], "%d per box   (you have %d)" % [box[1], have], box[2], "Buy", true, _buy_ammo.bind(box)))


func _damage_text(weapon: ItemData) -> String:
	if weapon.pellets > 1:
		return "%dx%d" % [weapon.pellets, int(weapon.damage)]
	return str(int(weapon.damage))


func _row(name: String, info: String, price: int, action: String, enabled: bool, on_buy: Callable) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.outline_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", -2)
	text.add_child(UiStyle.label(name, 22))
	text.add_child(UiStyle.label(info, 15, UiStyle.DIM_TEXT_COLOR))
	row.add_child(text)
	row.add_child(UiStyle.label("$%d" % price, 22, Color(0.6, 1.0, 0.6)))
	var button := Button.new()
	button.text = action
	button.custom_minimum_size = Vector2(90, 38)
	button.disabled = not enabled
	button.pressed.connect(on_buy)
	row.add_child(button)
	return box


func _buy_weapon(weapon: ItemData) -> void:
	if player.money < weapon.price:
		_say("Not enough money. Go hunt something!")
		Sfx.play("ui_error", -6.0, 0.02, "UI")
		return
	player.add_money(-weapon.price)
	player.inventory.pick_up(weapon)
	# A gun comes with one spare magazine.
	player.weapons.add_ammo(weapon.ammo, weapon.magazine)
	Sfx.play("coins", -2.0, 0.04)
	_say("Bought the %s. Pleasure doing business!" % weapon.display_name)
	_refresh()


func _buy_ammo(box: Array) -> void:
	if player.money < box[2]:
		_say("Not enough money. Go hunt something!")
		Sfx.play("ui_error", -6.0, 0.02, "UI")
		return
	player.add_money(-box[2])
	player.weapons.add_ammo(box[0], box[1])
	Sfx.play("coins", -2.0, 0.04)
	_say("Bought %d %s." % [box[1], String(box[3]).to_lower()])
	_refresh()


func _say(text: String) -> void:
	_message.text = text
