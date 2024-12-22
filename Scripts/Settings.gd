extends Node

# Map Settings
@export_category("Map Settings")
@export var map_size : Vector2 = Vector2(512, 512)
@export var corners : float = 50.0

# Sensor Settings
@export_category("Sensor Settings")
@export var sensor_angle : float = 0.7853982
@export var sensor_distance : float = 10.0
@export var sensor_size : float = 3
@export var sensor_threshold : float = 0.0

# Boid Settings
@export_category("Boid Settings")
@export var centralizedSpawn : bool = true
@export var count : int = 1000000
@export var speed : float = 1.0
@export var depositRate : float = 1.0

# Decay Settings
@export_category("Decay Settings")
@export var blurSize : float = 1
@export var smoothing : float = 0.5
@export var decayRate : float = 0.6

func get_init_settings() -> PackedByteArray:
	var data := PackedFloat32Array()
	
	# Add data
	data.append(map_size.x)
	data.append(map_size.y)
	data.append(count)
	data.append(randf()) # Random seed
	data.append(centralizedSpawn)
	
	data.append(0.0) # Padding
	data.append(0.0) # Padding
	data.append(0.0) # Padding
	
	return data.to_byte_array()

func get_boid_settings() -> PackedByteArray:
	var data := PackedFloat32Array()
	
	# Add data
	data.append(map_size.x)
	data.append(map_size.y)
	data.append(corners)
	data.append(sensor_angle)
	data.append(sensor_distance)
	data.append(sensor_size)
	data.append(sensor_threshold)
	data.append(count)
	data.append(speed)
	data.append(depositRate)
	
	data.append(0.0) # Padding
	data.append(0.0) # Padding
	
	return data.to_byte_array()

func get_decay_settings() -> PackedByteArray:
	var data := PackedFloat32Array()
	
	# Add data
	data.append(map_size.x)
	data.append(map_size.y)
	data.append(blurSize)
	data.append(smoothing)
	data.append(decayRate)
	
	data.append(0.0) # Padding
	data.append(0.0) # Padding
	data.append(0.0) # Padding
	
	return data.to_byte_array()
