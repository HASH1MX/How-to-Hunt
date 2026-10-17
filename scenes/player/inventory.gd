class_name Inventory
extends Node
## The player's inventory:
##   - 4 slots, chosen with the keys 1-4
##   - 1 hand slot: picked-up items go here and are held in the hand.
##     Pressing 1-4 while holding something stores it in that slot
##     (swapping with whatever was there). Q drops the item you're holding.

signal changed
signal item_dropped(item: ItemData)

const SLOT_COUNT := 4
## Items of the same kind stack up to this many in one slot (or in the hand).
const MAX_STACK := 5

var slots: Array[ItemData] = []
## How many items are in each slot (0 when empty).
var slot_counts: Array[int] = []
var hand_item: ItemData = null
var hand_count := 0
var selected_slot := 0


func _init() -> void:
	slots.resize(SLOT_COUNT)
	slot_counts.resize(SLOT_COUNT)


## Picks an item up. Returns false if there was no room (the item stays in the world).
## Same kind as the hand stack: joins it (or a matching slot stack once the hand stack
## is full). A different kind: the hand stack is put away in a slot first (or dropped
## if every slot is taken), then the new item goes in the hand.
func pick_up(item: ItemData) -> bool:
	if hand_item != null and hand_item.id == item.id:
		if hand_count < MAX_STACK:
			hand_count += 1
		else:
			var slot := _find_slot_with_room(item)
			if slot < 0:
				return false
			slot_counts[slot] += 1
		changed.emit()
		return true
	_stash_hand_stack()
	hand_item = item
	hand_count = 1
	changed.emit()
	return true


func _find_slot_with_room(item: ItemData) -> int:
	for i in SLOT_COUNT:
		if slots[i] != null and slots[i].id == item.id and slot_counts[i] < MAX_STACK:
			return i
	return -1


## Moves the hand stack into a slot with the same kind, or an empty slot.
## Whatever doesn't fit is dropped on the ground.
func _stash_hand_stack() -> void:
	if hand_item == null:
		return
	var slot := _find_slot_with_room(hand_item)
	while hand_item != null and slot >= 0:
		var moved := mini(hand_count, MAX_STACK - slot_counts[slot])
		slot_counts[slot] += moved
		hand_count -= moved
		if hand_count <= 0:
			hand_item = null
			hand_count = 0
		else:
			slot = _find_slot_with_room(hand_item)
	if hand_item != null:
		for i in SLOT_COUNT:
			if slots[i] == null:
				slots[i] = hand_item
				slot_counts[i] = hand_count
				hand_item = null
				hand_count = 0
				break
	while hand_item != null:
		drop_active_item()


## Key 1-4 pressed. With an item in the hand: joins the slot's stack if it is the same
## kind (anything over 5 stays in the hand), otherwise swaps with the slot.
## With an empty hand it just selects the slot.
func press_slot(index: int) -> void:
	index = clampi(index, 0, SLOT_COUNT - 1)
	if hand_item != null:
		var existing := slots[index]
		if existing != null and existing.id == hand_item.id:
			var moved := mini(hand_count, MAX_STACK - slot_counts[index])
			slot_counts[index] += moved
			hand_count -= moved
			if hand_count <= 0:
				hand_item = null
				hand_count = 0
		else:
			var previous := slots[index]
			var previous_count := slot_counts[index]
			slots[index] = hand_item
			slot_counts[index] = hand_count
			hand_item = previous
			hand_count = previous_count
	selected_slot = index
	changed.emit()


## Drops one item: from the hand stack, or else from the selected slot's stack.
func drop_active_item() -> void:
	var dropped: ItemData
	if hand_item != null:
		dropped = hand_item
		hand_count -= 1
		if hand_count <= 0:
			hand_item = null
			hand_count = 0
	elif slots[selected_slot] != null:
		dropped = slots[selected_slot]
		slot_counts[selected_slot] -= 1
		if slot_counts[selected_slot] <= 0:
			slots[selected_slot] = null
			slot_counts[selected_slot] = 0
	else:
		return
	item_dropped.emit(dropped)
	changed.emit()


## The inventory as plain data, for save files.
func to_dict() -> Dictionary:
	var saved_slots := []
	for i in SLOT_COUNT:
		saved_slots.append({} if slots[i] == null else {id = str(slots[i].id), count = slot_counts[i]})
	return {
		slots = saved_slots,
		hand = {} if hand_item == null else {id = str(hand_item.id), count = hand_count},
		selected = selected_slot,
	}


## Restores an inventory saved with to_dict(). Unknown items are skipped.
func from_dict(saved: Dictionary) -> void:
	for i in SLOT_COUNT:
		slots[i] = null
		slot_counts[i] = 0
	hand_item = null
	hand_count = 0
	var saved_slots: Array = saved.get("slots", [])
	for i in mini(saved_slots.size(), SLOT_COUNT):
		var entry: Dictionary = saved_slots[i]
		var item := _item_from(entry)
		if item != null:
			slots[i] = item
			slot_counts[i] = clampi(int(entry.get("count", 1)), 1, MAX_STACK)
	var hand: Dictionary = saved.get("hand", {})
	var held := _item_from(hand)
	if held != null:
		hand_item = held
		hand_count = clampi(int(hand.get("count", 1)), 1, MAX_STACK)
	selected_slot = clampi(int(saved.get("selected", 0)), 0, SLOT_COUNT - 1)
	changed.emit()


func _item_from(entry: Dictionary) -> ItemData:
	if not entry.has("id"):
		return null
	return ItemLibrary.get_item(StringName(entry.id))


## The item the player is currently holding: the hand item if there is one,
## otherwise the item in the selected slot (can be null).
func get_active_item() -> ItemData:
	return hand_item if hand_item != null else slots[selected_slot]
