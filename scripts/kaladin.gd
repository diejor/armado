extends RigidBody2D

@export var LINEAR_FORCE = 1500

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	lock_rotation = true
	pass # Replace with function body.

func _integrate_forces(state: PhysicsDirectBodyState2D):
	var move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	state.apply_central_force(move*LINEAR_FORCE)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
