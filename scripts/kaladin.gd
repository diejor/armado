extends RigidBody2D 

# === Exported Variables ===
@export var LINEAR_FORCE = 500
@export var MAX_SPEED = 200            # Maximum desired speed
@export var JUMP_FORCE = 100           # Base strength of the jump
@export var DEBUG_MODE = true          # Toggle debug visualization
@export var DRAW_SCALE = 1.0
@export var DAMPING_COEFFICIENT = 5.0 # Damping coefficient for velocity
@export var HORIZONTAL_TO_VERTICAL_RATIO = 0.9 # Ratio of horizontal to vertical velocity transfer on jump
@export var AIR_CONTROL_MULTIPLIER = 0.3  # Multiplier for air control (30% of ground force)

# === Hover Variables ===
@export var HOVER_RAY_LENGTH = 30.0          # Maximum distance for raycast
@export var HOVER_SPRING_CONSTANT = 1000.0    # Spring constant (k)
@export var HOVER_DAMPING = 50.0              # Damping coefficient (c)
@export var RIDE_HEIGHT = 30.0       # Desired hover height above ground
@export var HOVER_FORCE_MULTIPLIER = 1.0      # Multiplier for the hover force

# === Internal Variables ===
var applied_force = Vector2.ZERO
var gravity_force = Vector2.ZERO
var velocity_last_frame = Vector2.ZERO
var contact_points = []
var contact_normals = []
var normal_force_total = Vector2.ZERO
var normal = Vector2.ZERO
var jump_requested = false              # Flag to indicate a jump request
var on_ground = false                   # Flag to indicate if on the ground

# === Ready Function ===
func _ready() -> void:
	lock_rotation = true
	contact_monitor = true
	max_contacts_reported = 10  # Adjust as needed

# === Process Function ===
func _process(_delta: float) -> void:
	# Detect jump input
	if Input.is_action_just_pressed("jump") and on_ground:
		jump_requested = true

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	contact_points.clear()
	contact_normals.clear()# Retrieve the total gravity applied to the body
	gravity_force = state.get_total_gravity()

	var was_on_ground = on_ground
	on_ground = false  # Reset ground contact flag each frame

	for i in range(state.get_contact_count()):
		# Retrieve contact positions and normals in **local coordinates**
		var local_contact_point = self.to_local(state.get_contact_local_position(i))
		var local_contact_normal = state.get_contact_local_normal(i).normalized()

		contact_points.append(local_contact_point)
		contact_normals.append(local_contact_normal)
	

	# === Hover Implementation ===
	var from = transform.origin
	var to = from + Vector2.DOWN * HOVER_RAY_LENGTH
	var space_state = get_world_2d().direct_space_state
	var ray_params = PhysicsRayQueryParameters2D.create(from, to)
	var result = space_state.intersect_ray(ray_params)

	if result:
		on_ground = true
		contact_points.append(result.position)
		contact_normals.append(result.normal)  # Assume the ground is flat
		state.apply_central_force(-gravity_force)  # Neutralize gravity when hovering
		var hit_point = result.position
		var distance = (hit_point - from).length()
		var displacement = distance - RIDE_HEIGHT

		# Calculate velocity along the ray direction (downward)
		var velocity = state.get_linear_velocity()
		var ray_direction = Vector2.DOWN.normalized()
		var velocity_along_ray = velocity.dot(ray_direction)

		# Spring force: F = k * displacement
		var spring_force = HOVER_SPRING_CONSTANT * displacement

		# Damping force: F = -c * velocity
		var damping_force = -HOVER_DAMPING * velocity_along_ray

		# Total hover force
		var total_hover_force = (spring_force + damping_force) * ray_direction * HOVER_FORCE_MULTIPLIER

		# Apply the hover force
		state.apply_central_force(total_hover_force)

	var add = func(acc, a):
		if abs(a.x) > 0.1:
			return acc + a * 0.01
		return acc + a
	normal = contact_normals.reduce(add, Vector2.ZERO).normalized()

	# === Existing Movement and Jump Logic ===
	# Get current velocity
	var current_velocity = state.get_linear_velocity()
	var current_speed = current_velocity.length()

	# Calculate scaling factor based on current speed
	var factor = clamp(1.0 - (current_speed / MAX_SPEED), 0.0, 1.0)

	# Apply linear force based on user input, scaled by factor
	var move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_len = move_input.length_squared()
	
	if move_len > 0:
		var desired_direction = move_input.normalized()
		applied_force = desired_direction * LINEAR_FORCE * factor
	else:
		applied_force = Vector2.ZERO  # No input, no force applied

	# Apply air control multiplier if not grounded
	if not on_ground:
		applied_force *= AIR_CONTROL_MULTIPLIER

	# Apply the adjusted force
	if normal.length_squared() > 0:
		applied_force = applied_force.slide(normal)
	state.apply_central_force(applied_force)

	# === Apply Damping ===
	# Calculate damping force opposite to current velocity
	if current_speed > 0 and move_len == 0:
		var horizontal_velocity = Vector2(current_velocity.x, 0)
		var damping_force = -horizontal_velocity.normalized() * DAMPING_COEFFICIENT * current_speed
		state.apply_central_force(damping_force)

	if jump_requested and on_ground:
		state.apply_central_impulse(JUMP_FORCE * normal)

		# Get current velocity
		var velocity = state.get_linear_velocity()
		var normal_velocity = velocity.project(normal)
		var tangent_velocity =  velocity - normal_velocity

		# Calculate transfer amount based on the defined ratio
		var transfer_velocity = tangent_velocity * HORIZONTAL_TO_VERTICAL_RATIO
		velocity -= transfer_velocity
		velocity += normal_velocity.normalized() * transfer_velocity.length() * 0.2
		state.set_linear_velocity(velocity)

		# Reset the jump request
		jump_requested = false
	
	velocity_last_frame = state.get_linear_velocity()

	# Debugging
	if DEBUG_MODE:
		queue_redraw()

# === Draw Function for Debug Visualization ===
func _draw() -> void:
	if not DEBUG_MODE:
		return  # Skip drawing if debug mode is disabled
	
	# Visualize the applied linear force (Red)
	var force_color = Color(1, 0, 0)  # Red using RGB
	var scaled_applied_force = applied_force * 0.3  # Adjust scaling for visibility
	draw_arrow(Vector2.ZERO, scaled_applied_force, force_color)
	
	# Visualize gravity force (Blue)
	var gravity_color = Color(0, 0, 1)  # Blue using RGB
	var scaled_gravity = gravity_force * 0.3  # Adjust scaling for visibility
	draw_arrow(Vector2.ZERO, scaled_gravity, gravity_color)
	
	# Visualize contact normals (Green)
	var normal_color = Color(0, 1, 0)  # Green using RGB
	var scaled_normal = normal * 40 # Adjust length for visibility
	draw_arrow(Vector2.ZERO, scaled_normal, normal_color)
	
	# Optional: Visualize Jump Force and Velocity Transfer (Purple)
	if jump_requested and on_ground:
		var jump_color = Color(0.5, 0, 0.5)  # Purple using RGB
		var jump_force_vector = Vector2(0, -JUMP_FORCE) * 0.1  # Adjust scaling for visibility
		draw_arrow(Vector2.ZERO, jump_force_vector, jump_color)
	
	# === Hover Debug Visualization ===
	var transform = get_transform()
	var from = Vector2.ZERO
	var to = Vector2.DOWN * HOVER_RAY_LENGTH
	var hover_color = Color(1, 1, 0)  # Yellow for hover ray
	draw_line(from, to, hover_color, DRAW_SCALE)  # Draw the max hover ray

# === Helper Function to Draw Arrows ===
func draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	const ARROW_ANGLE_DEG = 90
	const ARROW_SIZE = 10
	draw_line(from, to, color, DRAW_SCALE)  # Draw the main line of the arrow
	
	if to.length() == 0:
		return  # Prevent division by zero
	
	var direction = (to - from).normalized()
	var arrow_angle = deg_to_rad(ARROW_ANGLE_DEG)  # Convert degrees to radians
	
	var left = direction.rotated(arrow_angle) * ARROW_SIZE 
	var right = direction.rotated(-arrow_angle) * ARROW_SIZE 
	
	draw_line(to, to - direction * ARROW_SIZE + left, color, DRAW_SCALE)  # Left side of arrowhead
	draw_line(to, to - direction * ARROW_SIZE + right, color, DRAW_SCALE)  # Right side of arrowhead
