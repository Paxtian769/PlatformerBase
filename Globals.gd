extends Node

# Global variables for tracking power ups.
# Useful for reloading the game if you die
# or if you want to change scenes and preserve
# powerups obtained.
var can_double_jump: bool
var jump_max: int
var can_swim: bool
var can_speed_run: bool
var can_wall_jump: bool
var can_coyote_jump: bool
var can_buffer_jump: bool


func _ready():
	jump_max = 1
	# Enabled by default, disable if you don't want them in your game.
	# Coyote jump: jump even if the player moves off of a platform slightly then jumps
	can_coyote_jump = true
	# Buffer jump: jump upon hitting the floor if the player presses the jump button while
	# still in the air
	can_buffer_jump = true
