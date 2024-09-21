extends Node2D  # Replace with your debug node type

func _ready():
    # Neutralize inherited transformations
    set_position(Vector2.ZERO)
    set_rotation(0)
    set_scale(Vector2.ONE)

    if Engine.is_editor_hint():
        # Get the root node of the currently edited scene
        var edited_root = get_tree().edited_scene_root

        # Check if this DebugNode is part of the edited scene
        var is_under_edited_scene = false
        var current_node = self
        while current_node:
            if current_node == edited_root:
                is_under_edited_scene = true
                break
            current_node = current_node.get_parent()
        
        if not is_under_edited_scene:
            # If not part of the edited scene, hide it in the editor
            self.visible = false
            print("DebugNode hidden in the editor for non-character scenes.")
        else:
            # If part of the edited scene, ensure it's visible
            self.visible = true
            print("DebugNode active in the character scene.")
    else:
        # When running the project, remove the debug node
        if Globals.is_main_project_running:
            print("Main project is running. Removing DebugNode.")
            queue_free()
        else:
            print("DebugNode is active. Running in isolated scene.")

func _process(_delta):
    # Maintain independent transformation relative to the world
    global_position = Vector2.ZERO