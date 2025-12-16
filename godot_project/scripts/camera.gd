extends Camera3D

@export var pan_speed = 10.0
@export var zoom_speed = 1.0

func _process(delta):
	var pan_direction = Vector3.ZERO
	if Input.is_action_pressed("camera_pan_up"):
		pan_direction -= transform.basis.y
	if Input.is_action_pressed("camera_pan_down"):
		pan_direction += transform.basis.y
	if Input.is_action_pressed("camera_pan_left"):
		pan_direction -= transform.basis.x
	if Input.is_action_pressed("camera_pan_right"):
		pan_direction += transform.basis.x
	
	global_transform.origin += pan_direction.normalized() * pan_speed * delta

func _input(event):
	if event is InputEventMouseButton:
		if event.is_action_pressed("camera_zoom_in"):
			size -= zoom_speed
		if event.is_action_pressed("camera_zoom_out"):
			size += zoom_speed
		size = clamp(size, 2.0, 20.0)
