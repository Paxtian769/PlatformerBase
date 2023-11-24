extends CanvasLayer


# This UI is only used to display the player's current state.
# This was used for debug purposes. 
# You probably want to remove that from your game. 


func _ready():
	$"../Player".state_changed.connect(_on_state_changed)


func _on_state_changed(state: String):
	$HBoxContainer/ActualLabel.text = state
