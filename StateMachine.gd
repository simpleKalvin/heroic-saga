class_name StateMachine
extends Node

var stateTime : float

var currentState : int = -1:
	set(v):
		# 调用子类中的transition_state方法并把当前的状态以及新状态传入
		owner.transition_state(currentState, v)
		currentState = v
		stateTime = 0
func _ready() -> void:
	# 由于godot必须子节点ready后父节点才ready，防止父节点未ready
	await owner.ready
	currentState = 0

func _physics_process(delta: float) -> void:
	while true:
		var next: int = owner.get_next_state(currentState) as int
		if currentState == next:
			# 状态不需要发生变化
			break
		currentState = next
	# 使用该状态机的子节点不需要重复实现物理效果
	owner.tick_physics(currentState, delta)
	stateTime += delta
