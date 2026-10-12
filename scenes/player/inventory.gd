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

var slots: Array[ItemData] = []
var hand_item: ItemData = null
var selected_slot := 0


func _init() -> void:
	slots.resize(SLOT_COUNT)


## Puts a picked-up item in the hand. Anything already in the hand is dropped first.
func pick_up(item: ItemData) -> void:
	if hand_item != null:
		drop_active_item()
	hand_item = item
	changed.emit()


## Key 1-4 pressed. With an item in the hand, stores it in that slot
## (the slot's old item, if any, moves to the hand). Otherwise just selects the slot.
func press_slot(index: int) -> void:
	index = clampi(index, 0, SLOT_COUNT - 1)
	if hand_item != null:
		var previous := slots[index]
		slots[index] = hand_item
		hand_item = previous
	selected_slot = index
	changed.emit()


## Drops the item being held: the hand item, or else the selected slot's item.
func drop_active_item() -> void:
	var dropped: ItemData
	if hand_item != null:
		dropped = hand_item
		hand_item = null
	elif slots[selected_slot] != null:
		dropped = slots[selected_slot]
		slots[selected_slot] = null
	else:
		return
	item_dropped.emit(dropped)
	changed.emit()


## The item the player is currently holding: the hand item if there is one,
## otherwise the item in the selected slot (can be null).
func get_active_item() -> ItemData:
	return hand_item if hand_item != null else slots[selected_slot]
