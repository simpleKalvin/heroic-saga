extends CharacterBody2D


enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
}

const GROUND_STATE :Array[State] = [State.IDLE, State.RUNNING, State.LANDING]
const AIR_STATE :Array[State] = [State.JUMP, State.FALL]

const runSpeed : float = 160.0
const FLOOR_ACCELERATION: float = runSpeed/0.2
const AIR_ACCELERATION: float = runSpeed/0.1
var default_gravity : float = ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick : bool = false

@export var jumpVelocity : float = -300.0
@export var wallJumpVelocity : Vector2 = Vector2(380, -280)
@export var faceDirection : int = 1
@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var state_machine: StateMachine = $StateMachine


func tick_physics(state:State, delta: float) -> void:
	match state:
		State.IDLE:
			move(default_gravity, delta)
		State.RUNNING:
			move(default_gravity, delta)
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
		State.FALL:
			move(default_gravity, delta)
		State.LANDING:
			stand(default_gravity, delta)
		State.WALL_SLIDING:
			move(default_gravity / 3, delta)
			graphics.scale.x = get_wall_normal().x
		State.WALL_JUMP:
			if state_machine.stateTime < 0.1:
				stand(0.0 if is_first_tick else default_gravity, delta)
				# 面朝方向就是墙面法线方向
				graphics.scale.x = get_wall_normal().x
			else:
				move(default_gravity, delta)
	is_first_tick = false

	
func move(gravity: float, delta:float)-> void:
	var direction : int = int(Input.get_axis("move_left", "move_right"))
	# 直接固定速率
	#velocity.x = direction * runSpeed
	var acceleration :float = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x,direction * runSpeed, acceleration * delta)
	velocity.y += gravity*delta
	move_and_slide()	
	# 翻转
	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction < 0 else +1
		
func stand (gravity:float, delta: float) -> void:
	var acceleration :float = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x,0.0, acceleration * delta)
	velocity.y += gravity*delta
	move_and_slide()
func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()
func is_just_jump() -> bool:
	var canJump: bool = is_on_floor() || coyote_timer.time_left > 0
	return canJump && jump_request_timer.time_left > 0
	
# 检测用户输入
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < (jumpVelocity / 2):
			velocity.y = jumpVelocity / 2


func get_next_state(state:State) -> State:
	var is_still_standing :int = getIsStanding()
	# 在任何时候只要能跳跃的时候都可以流转到JUMP
	if is_just_jump():
		return State.JUMP
	match state:
		State.IDLE:
			if not is_on_floor():
				return State.FALL
			if not is_still_standing:
				return State.RUNNING
		State.RUNNING:
			if not is_on_floor():
				return State.FALL
			if is_still_standing:
				return State.IDLE
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still_standing else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
		State.LANDING:
			if not is_still_standing:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
		State.WALL_SLIDING:
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
			if jump_request_timer.time_left > 0 and not is_first_tick:
				return State.WALL_JUMP
		State.WALL_JUMP:
			# 蹬墙跳
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
	return state
func getIsStanding() -> bool:
	var direction : int = int(Input.get_axis("move_left", "move_right"))
	return is_zero_approx(direction) && is_zero_approx(velocity.x)
	
func transition_state(from:State, to:State) -> void:
	print("[%s]%s => %s" % [
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to],
	])
	if from in GROUND_STATE && to in GROUND_STATE:
		coyote_timer.stop()
	match to:
		State.IDLE:
			animation_player.play("idle")
		State.RUNNING:
			animation_player.play("runing")
		State.JUMP:
			animation_player.play("jump")
			velocity.y = jumpVelocity
			coyote_timer.stop()
			jump_request_timer.stop()
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATE:
				coyote_timer.start()
		State.LANDING:
			animation_player.play("landing")
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = wallJumpVelocity
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
	#if to == State.WALL_JUMP:
		#Engine.time_scale = 0.3
	#if from == State.WALL_JUMP:
		#Engine.time_scale = 1.0
	is_first_tick = true
