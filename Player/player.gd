class_name Player
extends CharacterBody2D

# Player character states.
# Add new states to handle new power ups if needed.
enum States {
		IDLING,
		WALKING,
		RUNNING,
		SPEED_RUNNING,
		JUMPING,
		FALLING,
}
var state: States

var height: float = 30

# Variables for forces and velocities
var walk_force: float
var max_walk_speed: float
var run_force: float
var max_run_speed: float
var max_speed_run_speed: float
var initiate_speed_run: bool
var speed_run_timer: Timer
var speed_run_time: float
var jump_height = height * 1.5 # Tailor to your liking
var time_to_jump_peak:float = 0.35 # Tailor to your liking
var jump_velocity: float
var jump_count: int
var wall_jump_speed: float
var gravity: float
var gravity_multiplier: float = 2.5 # Tailor to your liking
var friction: float

# Current forces and velocities affecting the player
var target_velocity_x: float
var acceleration_x: float
var gravity_force: float

# Inputs for the current frame
var direction_input: float
var run_input: bool
var jump_input: bool
var jump_cancel_input: bool

# Quality of life / player intention variables
var coyote_jump_timer: Timer
var coyote_jump_time: float = 0.1
var buffer_jump_timer: Timer
var buffer_jump_time: float = 0.1
var buffer_jump: bool

# Used to indicate the current state of the player.
# Just used for debug purposes for now, but could be used
# for other things in your game.
# Currently emitted every frame, not just when the state changes.
signal state_changed


# Initiating values based on defaults. 
# Adjust to your preferences in your game to make the game feel right.
func _ready():
	jump_count = Globals.jump_max
	
	# Jump velocity and gravity are set based on an intended jump height
	# and time to the peak of the jump. 
	# For more info, see GDC "Building a Better Jump": https://www.youtube.com/watch?v=hG9SzQxaCm8
	jump_velocity = -2*jump_height / time_to_jump_peak
	gravity = 2*height / (time_to_jump_peak * time_to_jump_peak)
	
	# Used to set jump velocity away from the wall if wall jumps are enabled.
	# Tailor to your liking
	wall_jump_speed = -jump_velocity
	
	# Walking values, tailor to your liking
	walk_force = 200
	max_walk_speed = 150
	
	# Running values, tailor to your liking
	run_force = 500
	max_run_speed = 400
	
	# Friction is used to slow the player toward velocity.x = 0
	# when no input is received or when changing directions.
	friction = 750
	
	# Speed running is a power up triggered by a timer.
	# If the player runs in the same direction until the timer expires,
	# and the speed run powerup is collected, speed running will trigger.
	# Consider adding its own force if you like, currently using
	# the same force as used to get to max running speed.
	max_speed_run_speed = 600
	speed_run_timer = Timer.new()
	speed_run_time = 5
	speed_run_timer.one_shot = true
	speed_run_timer.timeout.connect(_on_speed_run_timer_timeout)
	add_child(speed_run_timer)
	
	coyote_jump_timer = Timer.new()
	coyote_jump_timer.one_shot = true
	add_child(coyote_jump_timer)
	
	buffer_jump_timer = Timer.new()
	buffer_jump_timer.one_shot = true
	buffer_jump_timer.timeout.connect(_on_buffer_jump_timer_timeout)
	add_child(buffer_jump_timer)
	
	state = States.IDLING


func _process(_delta):
	var state_name: String
	
	# Check the current state and execute corresponding state handling function
	if state == States.IDLING:
		_do_idling()
		state_name = "Idling"
	elif state == States.WALKING:
		_do_walking()
		state_name = "Walking"
	elif state == States.RUNNING:
		_do_running()
		state_name = "Running"
	elif state == States.JUMPING:
		_do_jumping()
		state_name = "Jumping"
	elif state == States.FALLING:
		_do_falling()
		state_name = "Falling"
	elif state == States.SPEED_RUNNING:
		_do_speed_running()
		state_name = "Speed Running"
	state_changed.emit(state_name)


# State handling functions

# Idling state: 
#    Slow down and stop horizontal motion
#    Can transition to: walking, running, jumping, or falling
func _do_idling() -> void:
	jump_count = Globals.jump_max
	initiate_speed_run = false
	if direction_input and run_input:
		state = States.RUNNING
	elif direction_input:
		state = States.WALKING
	else:
		target_velocity_x = 0
		if abs(velocity.x) > 0:
			_set_idle_force()
	
	if jump_input or (Globals.can_buffer_jump and buffer_jump):
		_jump()
		state = States.JUMPING
	elif not is_on_floor():
		if Globals.can_coyote_jump:
			coyote_jump_timer.start(coyote_jump_time)
		state = States.FALLING


# Walking state: 
#    Approach target walking speed
#    Can transition to: idling, running, jumping, or falling
func _do_walking() -> void:
	jump_count = Globals.jump_max
	initiate_speed_run = false
	if direction_input and run_input:
		state = States.RUNNING
	elif direction_input:
		_set_target_speed_and_acceleration(max_walk_speed, walk_force)
	else:
		state = States.IDLING
	
	if jump_input or (Globals.can_buffer_jump and buffer_jump):
		_jump()
		state = States.JUMPING
	elif not is_on_floor():
		if Globals.can_coyote_jump:
			coyote_jump_timer.start(coyote_jump_time)
		state = States.FALLING


# Running state: 
#    Approach target running speed
#    If speed running power up is enabled, check for whether to speed run
#    Can transition to: walking, speed running, jumping, or falling
func _do_running() -> void:
	jump_count = Globals.jump_max
	if direction_input and run_input:
		if Globals.can_speed_run:
			if initiate_speed_run:
				state = States.SPEED_RUNNING
			else:
				_check_for_speed_run()
		_set_target_speed_and_acceleration(max_run_speed, run_force)
	elif direction_input:
		initiate_speed_run = false
		speed_run_timer.stop()
		state = States.WALKING
	else:
		initiate_speed_run = false
		speed_run_timer.stop()
		state = States.IDLING
	
	if jump_input or (Globals.can_buffer_jump and buffer_jump):
		_jump()
		state = States.JUMPING
	elif not is_on_floor():
		if Globals.can_coyote_jump:
			coyote_jump_timer.start(coyote_jump_time)
		state = States.FALLING


# Speed running state: 
#    Approach maximum speed running speed
#    Can transition to: idling, walking, running, jumping, or falling
func _do_speed_running() -> void:
	jump_count = Globals.jump_max
	if direction_input and run_input:
		if (direction_input > 0 and velocity.x > 0) or (direction_input < 0 and velocity.x < 0):
			_set_target_speed_and_acceleration(max_speed_run_speed, run_force)
		else:
			initiate_speed_run = false
			state = States.RUNNING
	elif direction_input:
		initiate_speed_run = false
		state = States.WALKING
	else:
		initiate_speed_run = false
		state = States.IDLING
	
	if jump_input:
		_jump()
		state = States.JUMPING
	elif not is_on_floor():
		if Globals.can_coyote_jump:
			coyote_jump_timer.start(coyote_jump_time)
		state = States.FALLING


# Jumping state: 
#    After an initial jump impulse, decelerate due to gravity.
#    Can also change horizontal velocity according to walking, running, or speed running.
#    Will maintain current horizontal moving state upon landing on ground.
#    Can transition to: falling
func _do_jumping() -> void:
	if direction_input and run_input:
		if Globals.can_speed_run and (initiate_speed_run or (abs(velocity.x) > max_run_speed * 1.05 and direction_input * velocity.x > 0)):
			_set_target_speed_and_acceleration(max_speed_run_speed, run_force)
		else:
			if Globals.can_speed_run:
				_check_for_speed_run()
			_set_target_speed_and_acceleration(max_run_speed, run_force)
	elif direction_input:
		_set_target_speed_and_acceleration(max_walk_speed, walk_force)
	else:
		target_velocity_x = 0
		if abs(velocity.x) > 0:
			_set_idle_force()
	
	gravity_force = gravity
	
	if velocity.y >= 0:
		state = States.FALLING
	
	if jump_cancel_input:
		velocity.y = velocity.y * .1
		state = States.FALLING
	
	if jump_input:
		_jump()


# Falling state: 
#    After reaching jump peak, decelerate due to gravity and a gravity multiplier.
#    Can also change horizontal velocity according to walking, running, or speed running.
#    Will maintain current horizontal moving state upon landing on ground.
#    Can transition to: idling, walking, running, or speed running.
func _do_falling() -> void:
	gravity_force = gravity * gravity_multiplier
	
	if direction_input and run_input:
		if Globals.can_speed_run and (initiate_speed_run or (abs(velocity.x) > max_run_speed * 1.05 and direction_input * velocity.x > 0)):
			_set_target_speed_and_acceleration(max_speed_run_speed, run_force)
			if is_on_floor():
				state = States.SPEED_RUNNING
		else:
			if Globals.can_speed_run:
				_check_for_speed_run()
			_set_target_speed_and_acceleration(max_run_speed, run_force)
			if is_on_floor():
				state = States.RUNNING
	elif direction_input:
		_set_target_speed_and_acceleration(max_walk_speed, walk_force)
		if is_on_floor():
			state = States.WALKING
	else:
		target_velocity_x = 0
		if abs(velocity.x) > 0:
			_set_idle_force()
		if is_on_floor():
			state = States.IDLING
	
	if jump_input:
		_jump()
		buffer_jump = true
		buffer_jump_timer.start(buffer_jump_time)


# Handle jump input. 
# No jump will occur if jumping isn't permitted (no jumps remaining, not on floor, etc.)
func _jump() -> void:
	if is_on_floor() or (Globals.can_coyote_jump and coyote_jump_timer.time_left > 0):
		jump_count -= 1
		velocity.y = jump_velocity
		state = States.JUMPING
	# Handle wall jumping power up
	elif Globals.can_wall_jump and is_on_wall_only():
		jump_count = Globals.jump_max-1
		velocity.y = jump_velocity
		var collision_normal = get_last_slide_collision().get_normal()
		if collision_normal.x > 0:
			velocity.x = wall_jump_speed
		elif collision_normal.x < 1:
			velocity.x = -wall_jump_speed
		state = States.JUMPING
	elif Globals.can_double_jump and jump_count > 0:
		velocity.y = jump_velocity
		jump_count -= 1
		state = States.JUMPING


# Used to handle weird oscillations when speed approaches 0.
func _set_idle_force() -> void:
	if velocity.x > 1:
		acceleration_x = -friction
	elif velocity.x < -1:
		acceleration_x = friction
	else:
		velocity.x = 0


# Determine whether to reset the speed run timer, e.g.,
# if the player changes direction. 
# Add conditions if needed, such as if not is_on_floor() if you
# want to only enter speed running state if the player is on the floor.
func _check_for_speed_run() -> void:
	if speed_run_timer.is_stopped():
		speed_run_timer.start(speed_run_time)
	if direction_input < 0:
		if not target_velocity_x == -max_run_speed:
			speed_run_timer.stop()
	else:
		if not target_velocity_x == max_run_speed:
			speed_run_timer.stop()


# Set the target speed and the acceleration used to reach that speed.
# Divided into sections: 
#     1. Currently moving faster than target speed (slow down using friction)
#     2. Currently moving slower than target speed but faster than 0 (accelerate using appropriate acceleration)
#     3. Currently moving opposite direction (slow down using both friction and corresponding acceleration)
func _set_target_speed_and_acceleration(target_speed: float, acceleration: float) -> void:
	if direction_input < 0:
		if velocity.x < -target_speed:
			target_velocity_x = -target_speed
			acceleration_x = friction
		elif velocity.x > -target_speed and velocity.x <= 0:
			target_velocity_x = -target_speed
			acceleration_x = -acceleration
		elif velocity.x > 0:
			target_velocity_x = -target_speed
			acceleration_x = -friction - acceleration
	else:
		if velocity.x > target_speed:
			target_velocity_x = target_speed
			acceleration_x = -friction
		elif velocity.x < target_speed and velocity.x >= 0:
			target_velocity_x = target_speed
			acceleration_x = acceleration
		elif velocity.x < 0:
			target_velocity_x = target_speed
			acceleration_x = friction + acceleration


func _physics_process(delta):
	_fall(delta)
	
	if not abs(velocity.x) == abs(target_velocity_x):
		velocity.x += acceleration_x * delta
	
	move_and_slide()


func _fall(delta) -> void:
	if not is_on_floor():
		velocity.y += gravity_force * delta


func receive_input(direction: float, run: bool, jump: bool, jump_cancel: bool) -> void:
	direction_input = direction
	run_input = run
	jump_input = jump
	jump_cancel_input = jump_cancel


# Used to collect power ups. 
# Make sure to reference the proper power up item name.
# To create new collectible items, create an inherited scene from 
# base scene collectible_item.
func collect_item(item_name: String) -> void:
	if item_name == "DoubleJump":
		Globals.can_double_jump = true
		Globals.jump_max = 2
	elif item_name == "SpeedRun":
		Globals.can_speed_run = true
	elif item_name == "WallJump":
		Globals.can_wall_jump = true


func _on_speed_run_timer_timeout() -> void:
	initiate_speed_run = true


func _on_buffer_jump_timer_timeout() -> void:
	buffer_jump = false
