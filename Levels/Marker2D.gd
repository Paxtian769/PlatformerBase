extends Marker2D


@onready var player: Player = $".."
var max_x = 200 # Change this if you change your horizontal window size

# This is used to set the camera position based on player movement.
# It's intended to keep the player positioned along the 2/3rds line vertically
# and near the 1/3rds line horizontally for the "rule of thirds" 
# composition rule in photography/videography. 
func _process(_delta):
	var speed = player.velocity.x
	var max_speed = player.max_run_speed
	var speed_ratio = speed / max_speed
	
	# Consider clamping this to max_x / -max_x
	position.x = lerp(position.x, float(speed_ratio * max_x), .025)
