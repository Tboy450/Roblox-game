extends CharacterBody3D
var camera: Camera3D
const SPEED := 4.2
var controls_enabled := true
var move_speed := SPEED
var sensitivity := 0.002
## Physical forward, back, left and right keys from the player's bindings.
var move_keys: Array = [KEY_W, KEY_S, KEY_A, KEY_D]

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.65
	camera.current = true
	add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func apply_look(relative: Vector2) -> void:
	if not controls_enabled:
		return
	rotate_y(-relative.x * sensitivity)
	camera.rotation.x = clampf(camera.rotation.x - relative.y * sensitivity, -1.3, 1.3)

func input_axis() -> Vector2:
	var held = move_keys.map(func(code): return float(Input.is_physical_key_pressed(code)))
	return Vector2(held[3] - held[2], held[1] - held[0]).normalized()

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = Vector3.ZERO
		return
	var axis := input_axis() if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Vector2.ZERO
	var direction := global_basis * Vector3(axis.x, 0, axis.y)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if position.y < -10:
		position = Vector3(0, 1, 8)
		velocity = Vector3.ZERO
