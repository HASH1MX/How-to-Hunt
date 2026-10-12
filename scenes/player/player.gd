extends CharacterBody3D
## The player: first-person movement, like How to Fish.
## WASD = move, Mouse = look, Space = jump, Esc = free the mouse, Left click = capture it again.
##
## The body is on render layer 2, which this player's own camera does not draw,
## so you don't see the inside of your own body. Other players (later, in
## multiplayer) will still see it, and you still see your own shadow.

@export var walk_speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
## If the player falls below this height, they are sent back to the spawn point.
@export var fall_limit: float = -20.0

@onready var head: Node3D = $Head

var spawn_position: Vector3


func _ready() -> void:
	spawn_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Left/right turns the whole player, up/down tilts only the head.
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed)

	move_and_slide()

	if global_position.y < fall_limit:
		global_position = spawn_position
		velocity = Vector3.ZERO
