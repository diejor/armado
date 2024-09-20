extends RigidBody2D 

# === Exported Variables ===
@export var LINEAR_FORCE = 500
@export var MAX_SPEED = 200            # Maximum desired speed
@export var JUMP_FORCE = 100           # Base strength of the jump
@export var DEBUG_MODE = true          # Toggle debug visualization
@export var DRAW_SCALE = 0.5
@export var DAMPING_COEFFICIENT = 0.5 # Damping coefficient for velocity
@export var HORIZONTAL_TO_VERTICAL_RATIO = 0.2 # Ratio of horizontal to vertical velocity transfer on jump
@export var AIR_CONTROL_MULTIPLIER = 0.3  # Multiplier for air control (30% of ground force)

# === Internal Variables ===
var applied_force = Vector2.ZERO
var gravity_force = Vector2.ZERO
var contact_points = []
var contact_normals = []
var normal_force_total = Vector2.ZERO
var jump_requested = false              # Flag to indicate a jump request
var on_ground = false                   # Flag to indicate if on the ground

# === Ready Function ===
func _ready() -> void:
	lock_rotation = true
	contact_monitor = true
	max_contacts_reported = 10  # Adjust as needed

# === Process Function ===
func _process(delta: float) -> void:
	# Detect jump input
	if Input.is_action_just_pressed("jump"):
		jump_requested = true

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	contact_points.clear()
	contact_normals.clear()

	# Retrieve the total gravity applied to the body
	gravity_force = state.get_total_gravity()

	# Initialize normal force accumulator
	normal_force_total = Vector2.ZERO
	on_ground = false  # Reset ground contact flag each frame

	# Retrieve contact information
	var contact_count = state.get_contact_count()
	
	for i in range(contact_count):
		# Retrieve contact positions and normals in **local coordinates**
		var local_contact_point = self.to_local(state.get_contact_local_position(i))
		var local_contact_normal = state.get_contact_local_normal(i).normalized()
		
		contact_points.append(local_contact_point)
		contact_normals.append(local_contact_normal)
		
		# Project gravity onto the contact normal to get the normal force component
		var projected_normal = gravity_force.project(local_contact_normal)
		normal_force_total += projected_normal
		
		# Check if the contact normal indicates ground contact
		if local_contact_normal.y < 0:
			on_ground = true

	# Apply the total normal force to counteract gravity
	state.apply_central_force(-normal_force_total * 0.5)

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

	var add = func(acc, a):
		if a.project(Vector2.UP).length_squared() < 0.1:
			return acc
		return acc + a
	var res = contact_normals.reduce(add, Vector2.ZERO).normalized()
	if res != Vector2.ZERO:
		applied_force = applied_force.slide(res)
		

	# Apply the adjusted force
	state.apply_central_force(applied_force)

	# === Apply Damping ===
	# Calculate damping force opposite to current velocity
	if current_speed > 0 and move_len == 0:
		var horizontal_velocity = Vector2(current_velocity.x, 0)
		var damping_force = -horizontal_velocity.normalized() * DAMPING_COEFFICIENT * current_speed
		state.apply_central_force(damping_force)

	if jump_requested and on_ground:
		# Calculate the jump impulse based on JUMP_FORCE and factor
		var jump_impulse = res * JUMP_FORCE

		# Apply the vertical jump impulse
		state.apply_central_impulse(jump_impulse)

		# Get current velocity
		var velocity = state.get_linear_velocity()

		# Extract horizontal velocity component (perpendicular to res)
		var horizontal_velocity = velocity.x  # Velocity perpendicular to res

		# Calculate transfer amount based on the defined ratio
		var transfer_amount = abs(horizontal_velocity) * HORIZONTAL_TO_VERTICAL_RATIO
		velocity.x -= transfer_amount * sign(horizontal_velocity) * (2 - HORIZONTAL_TO_VERTICAL_RATIO)
		state.set_linear_velocity(velocity)

		# Apply the transfer as an impulse along res
		var transfer_impulse = res * transfer_amount
		state.apply_central_impulse(transfer_impulse)

		# Reset the jump request
		jump_requested = false

	# Debugging
	if DEBUG_MODE:
		queue_redraw()


# === Draw Function for Debug Visualization ===
func _draw() -> void:
	
	if not DEBUG_MODE:
		return  # Skip drawing if debug mode is disabled
	
	# Visualize the applied linear force (Red)
	var force_color = Color(1, 0, 0)  # Red using RGB
	var scaled_applied_force = applied_force * 0.1  # Adjust scaling for visibility
	draw_arrow(Vector2.ZERO, scaled_applied_force, force_color)
	
	# Visualize gravity force (Blue)
	var gravity_color = Color(0, 0, 1)  # Blue using RGB
	var scaled_gravity = gravity_force * 0.1  # Adjust scaling for visibility
	draw_arrow(Vector2.ZERO, scaled_gravity, gravity_color)
	
	# Visualize contact normals (Green)
	var normal_color = Color(0, 1, 0)  # Green using RGB
	for i in range(contact_points.size()):
		var contact_point = contact_points[i]
		var normal = contact_normals[i]
		var scaled_normal = normal * 20  # Adjust length for visibility
		draw_arrow(contact_point, contact_point + scaled_normal, normal_color)
	
	# Visualize contact points (Yellow)
	var contact_point_color = Color(1, 1, 0)  # Yellow using RGB
	for contact_point in contact_points:
		draw_circle(contact_point, DRAW_SCALE, contact_point_color)
	
	# Optional: Visualize Jump Force and Velocity Transfer (Purple)
	if jump_requested and on_ground:
		var jump_color = Color(0.5, 0, 0.5)  # Purple using RGB
		var jump_force_vector = Vector2(0, -JUMP_FORCE) * 0.1  # Adjust scaling for visibility
		draw_arrow(Vector2.ZERO, jump_force_vector, jump_color)

# === Helper Function to Draw Arrows ===
func draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	const ARROW_ANGLE_DEG = 90
	const ARROW_SIZE = 2
	draw_line(from, to, color, DRAW_SCALE)  # Draw the main line of the arrow
	
	if to.length() == 0:
		return  # Prevent division by zero
	
	var direction = (to - from).normalized()
	var arrow_angle = deg_to_rad(ARROW_ANGLE_DEG)  # Convert degrees to radians
	
	var left = direction.rotated(arrow_angle) * ARROW_SIZE 
	var right = direction.rotated(-arrow_angle) * ARROW_SIZE 
	
	draw_line(to, to - direction * ARROW_SIZE + left, color, DRAW_SCALE)  # Left side of arrowhead
	draw_line(to, to - direction * ARROW_SIZE + right, color, DRAW_SCALE)  # Right side of arrowhead
