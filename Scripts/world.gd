extends Node2D

@onready var camera_2d: Camera2D = $Player/Camera2D
@onready var tile_map_layer: TileMapLayer = %Geometry

@export var camerSmoothLimit : bool = true

func _ready() -> void:
	var used := tile_map_layer.get_used_rect().grow(-1)
	var tile_size := tile_map_layer.tile_set.tile_size
	# 设置camer2D
	camera_2d.limit_top = used.position.y * tile_size.y
	camera_2d.limit_bottom = used.end.y * tile_size.y
	camera_2d.limit_left = (used.position.x) * tile_size.x
	camera_2d.limit_right = used.end.x * tile_size.x
	camera_2d.reset_smoothing()
