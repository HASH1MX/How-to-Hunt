class_name Inventory
extends Node
## The player's inventory:
##   - 4 slots, chosen with the keys 1-4 or the scroll wheel
##   - 1 hand slot: picked-up items go here and are held in the hand.
##     Pressing 1-4 while holding something stores it in that slot
##     (swapping with whatever was there). Q drops the item you're holding.

signal changed
signal item_dropped(item: ItemData)
## An item was picked up from the world (for the pick-up sound).
signal item_picked_up(item: ItemData)

const SLOT_COUNT := 4
## Most items stack up to this many in one slot (or in the hand); weapons and keys
## (ItemData.max_stack) only one.
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
		if hand_count < item.max_stack:
			hand_count += 1
		else:
			var slot := _find_slot_with_room(item)
			if slot < 0:
				return false
			slot_counts[slot] += 1
		changed.emit()
		item_picked_up.emit(item)
		return true
	_stash_hand_stack()
	hand_item = item
	hand_count = 1
	changed.emit()
	item_picked_up.emit(item)
	return true


## False if picking this item up would fail (same kind as the hand stack, which is
## full, and no slot has room).
func can_pick_up(item: ItemData) -> bool:
	if hand_item != null and hand_item.id == item.id and hand_count >= item.max_stack:
		return _find_slot_with_room(item) >= 0
	return true


func _find_slot_with_room(item: ItemData) -> int:
	for i in SLOT_COUNT:
		if slots[i] != null and slots[i].id == item.id and slot_counts[i] < item.max_stack:
			return i
	return -1


## Moves the hand stack into a slot with the same kind, or an empty slot.
## Whatever doesn't fit is dropped on the ground.
func _stash_hand_stack() -> void:
	if hand_item == null:
		return
	var slot := _find_slot_with_room(hand_item)
	while hand_item != null and slot >= 0:
		var moved := mini(hand_count, hand_item.max_stack - slot_counts[slot])
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
			var moved := mini(hand_count, hand_item.max_stack - slot_counts[index])
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


## Scroll wheel: selects the next (+1) or previous (-1) slot, wrapping around.
## Something just picked up (in the hand) is put away into the slots first, but only
## if it fits: scrolling never drops anything. Returns true if the selection changed.
func scroll(direction: int) -> bool:
	if hand_item != null:
		if not _hand_fits_in_slots():
			return false
		_stash_hand_stack()
	selected_slot = wrapi(selected_slot + direction, 0, SLOT_COUNT)
	changed.emit()
	return true


func _hand_fits_in_slots() -> bool:
	var room := 0
	for i in SLOT_COUNT:
		if slots[i] == null:
			return true
		if slots[i].id == hand_item.id:
			room += hand_item.max_stack - slot_counts[i]
	return room >= hand_count


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


## How many of the active item there are (see get_active_item).
func get_active_count() -> int:
	return hand_count if hand_item != null else slot_counts[selected_slot]


## Takes the whole active stack out of the inventory (to sell it). Returns
## {item, count}, or an empty dictionary if nothing is held.
func remove_active_stack() -> Dictionary:
	var item := get_active_item()
	if item == null:
		return {}
	var count := get_active_count()
	if hand_item != null:
		hand_item = null
		hand_count = 0
	else:
		slots[selected_slot] = null
		slot_counts[selected_slot] = 0
	changed.emit()
	return {item = item, count = count}


## Takes up to `count` of the active item out of the inventory (to hand it over).
## Returns how many were taken.
func take_from_active(count: int) -> int:
	var item := get_active_item()
	if item == null:
		return 0
	var taken := mini(count, get_active_count())
	if hand_item != null:
		hand_count -= taken
		if hand_count <= 0:
			hand_item = null
			hand_count = 0
	else:
		slot_counts[selected_slot] -= taken
		if slot_counts[selected_slot] <= 0:
			slots[selected_slot] = null
			slot_counts[selected_slot] = 0
	changed.emit()
	return taken


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
			slot_counts[i] = clampi(int(entry.get("count", 1)), 1, item.max_stack)
	var hand: Dictionary = saved.get("hand", {})
	var held := _item_from(hand)
	if held != null:
		hand_item = held
		hand_count = clampi(int(hand.get("count", 1)), 1, held.max_stack)
	selected_slot = clampi(int(saved.get("selected", 0)), 0, SLOT_COUNT - 1)
	changed.emit()


func _item_from(entry: Dictionary) -> ItemData:
	if not entry.has("id"):
		return null
	return ItemLibrary.get_item(StringName(entry.id))


## True if the player has this item anywhere (hand or slots).
func has_item(id: StringName) -> bool:
	if hand_item != null and hand_item.id == id:
		return true
	for item in slots:
		if item != null and item.id == id:
			return true
	return false


## The item the player is currently holding: the hand item if there is one,
## otherwise the item in the selected slot (can be null).
func get_active_item() -> ItemData:
	return hand_item if hand_item != null else slots[selected_slot]
