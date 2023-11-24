extends Node2D


@onready var player: Player = $".."

# Add states to allow the game to take control of the player
# and/or to allow the user to control other items
enum States {
	PLAYER_CONTROL,
}
var state: States


func _ready():
	# By default, the user has control of the player character
	state = States.PLAYER_CONTROL


func _process(_delta):
	if state == States.PLAYER_CONTROL:
		var jump = Input.is_action_just_pressed("jump")
		var run = Input.is_action_pressed("run")
		var direction = Input.get_axis("move_left", "move_right")
		var jump_cancel = Input.is_action_just_released("jump")
		# Input is provided to the player character once per frame
		# and handled in the player script itself
		player.receive_input(direction, run, jump, jump_cancel)
	else:
		# By default, no input given to the player if not being controlled
		player.receive_input(0, false, false, false)
