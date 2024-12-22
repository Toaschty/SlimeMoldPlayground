class_name BoidController
extends Node

# Settings
#@export var settings : Settings

# Internal
var rd : RenderingDevice
var flock : PackedByteArray = PackedByteArray()

@onready var display_texture : Texture2DRD = $"../HSplitContainer/RenderArea/RenderViewport/TrailMap".texture
@onready var boid_texture : Texture2DRD = $"../HSplitContainer/RenderArea/RenderViewport/Boids".texture

# Boid init shader
var boid_init_shader : RID
var boid_init_pipeline : RID

# Boids shader
var boid_shader : RID
var boid_pipeline : RID

var boid_boids_set : RID

var boid_position_texture : RID = RID()
var boid_position_set : RID

var boid_trail_texture : RID = RID()
var boid_trail_set : RID

# Decay shader
var decay_shader : RID
var decay_pipeline : RID

var decay_trail_set : RID

var decay_updated_trail_texture : RID = RID()
var decay_updated_trail_set : RID

func _initialize_flock() -> void:
	# Load boid init shader
	var boid_init_shader_file := load("res://Shader/boid_init.glsl")
	var boid_init_shader_spirv : RDShaderSPIRV = boid_init_shader_file.get_spirv()
	boid_init_shader = rd.shader_create_from_spirv(boid_init_shader_spirv)
	boid_init_pipeline = rd.compute_pipeline_create(boid_init_shader)
	
	# Setup flock
	flock.resize(Settings.count * 4 * 4) # BOIDCOUNT * 4 Byte Boid Data * 4 Byte per Float
	
	var boid_init_buffer = rd.storage_buffer_create(flock.size(), flock);
	var boid_init_uniform := RDUniform.new()
	boid_init_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	boid_init_uniform.binding = 0
	boid_init_uniform.add_id(boid_init_buffer)
	var boid_init_set = rd.uniform_set_create([boid_init_uniform], boid_init_shader, 0)
	
	# Get init settings
	var boid_init_settings = Settings.get_init_settings()
	
	# Run init shader
	var boid_init_compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(boid_init_compute_list, boid_init_pipeline)
	rd.compute_list_bind_uniform_set(boid_init_compute_list, boid_init_set, 0)
	rd.compute_list_set_push_constant(boid_init_compute_list, boid_init_settings, boid_init_settings.size())
	rd.compute_list_dispatch(boid_init_compute_list, ceil(Settings.count / 8.0), 1, 1)
	rd.compute_list_end()
	
	# Retrieve data
	flock = rd.buffer_get_data(boid_init_buffer)

func _initialize_shaders() -> void:
	# Load boids shader
	var boid_shader_file := load("res://Shader/boids.glsl")
	var boid_shader_spirv : RDShaderSPIRV = boid_shader_file.get_spirv()
	boid_shader = rd.shader_create_from_spirv(boid_shader_spirv)
	boid_pipeline = rd.compute_pipeline_create(boid_shader)
	
	# Setup boids buffer & set
	var boid_boids_buffer = rd.storage_buffer_create(flock.size(), flock)
	var boid_boids_uniform := RDUniform.new()
	boid_boids_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	boid_boids_uniform.binding = 0
	boid_boids_uniform.add_id(boid_boids_buffer)
	boid_boids_set = rd.uniform_set_create([boid_boids_uniform], boid_shader, 0)
	
	# Setup position texture & set
	boid_position_texture = _create_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT, Settings.map_size.x, Settings.map_size.y)
	var position_uniform := RDUniform.new()
	position_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	position_uniform.binding = 0
	position_uniform.add_id(boid_position_texture)
	boid_position_set = rd.uniform_set_create([position_uniform], boid_shader, 1)
	
	# Setup trail texture & set
	boid_trail_texture = _create_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT, Settings.map_size.x, Settings.map_size.y)
	var boid_trail_uniform := RDUniform.new()
	boid_trail_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	boid_trail_uniform.binding = 0
	boid_trail_uniform.add_id(boid_trail_texture)
	boid_trail_set = rd.uniform_set_create([boid_trail_uniform], boid_shader, 2)
	
	# Load decay shader
	var decay_shader_file := load("res://Shader/decay.glsl")
	var decay_shader_spirv : RDShaderSPIRV = decay_shader_file.get_spirv()
	decay_shader = rd.shader_create_from_spirv(decay_shader_spirv)
	decay_pipeline = rd.compute_pipeline_create(decay_shader)
	
	# Setup trail set
	var decay_trail_uniform := RDUniform.new()
	decay_trail_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	decay_trail_uniform.binding = 0
	decay_trail_uniform.add_id(boid_trail_texture)
	decay_trail_set = rd.uniform_set_create([decay_trail_uniform], decay_shader, 0)
	
	# Setup trail texture & set
	decay_updated_trail_texture = _create_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT, Settings.map_size.x, Settings.map_size.y)
	var decay_updated_trail_uniform := RDUniform.new()
	decay_updated_trail_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	decay_updated_trail_uniform.binding = 0
	decay_updated_trail_uniform.add_id(decay_updated_trail_texture)
	decay_updated_trail_set = rd.uniform_set_create([decay_updated_trail_uniform], decay_shader, 1)

func _create_texture(format : RenderingDevice.DataFormat, width : int, height : int) -> RID:
	var tf : RDTextureFormat = RDTextureFormat.new()
	tf.format = format
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.width = width
	tf.height = height
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	
	return rd.texture_create(tf, RDTextureView.new(), [])

func _ready() -> void:
	# Get rendering device
	rd = RenderingServer.get_rendering_device()
	
	# Setup flock
	_initialize_flock()
	
	# Init shader
	_initialize_shaders()
	
	# Set corresponding texture to display
	display_texture.texture_rd_rid = boid_trail_texture
	boid_texture.texture_rd_rid = boid_position_texture

func _process(delta: float) -> void:
	RenderingServer.call_on_render_thread(_render_process)

func _render_process() -> void:
	# Clear position texture
	rd.texture_clear(boid_position_texture, Color(0.0, 0, 0, 0.0), 0, 1, 0, 1)
	
	# Get current settings
	var boid_push_constant = Settings.get_boid_settings()
	
	# Setup boid pipeline
	var boid_compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(boid_compute_list, boid_pipeline)
	rd.compute_list_bind_uniform_set(boid_compute_list, boid_boids_set, 0)
	rd.compute_list_bind_uniform_set(boid_compute_list, boid_position_set, 1)
	rd.compute_list_bind_uniform_set(boid_compute_list, boid_trail_set, 2)
	rd.compute_list_set_push_constant(boid_compute_list, boid_push_constant, boid_push_constant.size())
	rd.compute_list_dispatch(boid_compute_list, ceil(Settings.count / 16.0), 1, 1)
	rd.compute_list_end()
	
	# Get decay settings
	var decay_push_constant = Settings.get_decay_settings()
	
	# Setup decay pipeline
	var decay_compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(decay_compute_list, decay_pipeline)
	rd.compute_list_bind_uniform_set(decay_compute_list, decay_trail_set, 0)
	rd.compute_list_bind_uniform_set(decay_compute_list, decay_updated_trail_set, 1)
	rd.compute_list_set_push_constant(decay_compute_list, decay_push_constant, decay_push_constant.size())
	rd.compute_list_dispatch(decay_compute_list, ceil(Settings.map_size.x / 16.0), ceil(Settings.map_size.y / 16.0), 1)
	rd.compute_list_end()
	
	# Apply updated trail map
	rd.texture_copy(decay_updated_trail_texture, boid_trail_texture, Vector3.ZERO, Vector3.ZERO, Vector3(Settings.map_size.x, Settings.map_size.y, 0.0), 0, 0, 0, 0)
