extends Area2D

const RARITY_COLORS := {
	"common": Color(0.708, 0.708, 0.708, 1.0),
	"uncommon": Color(0.0, 0.688, 0.217, 1.0),
	"rare": Color(0.459, 0.001, 0.661, 1.0),
	"legendary": Color(0.442, 0.0, 0.012, 1.0)
}

const DEFAULT_PARTICLE_COLOR := Color(1.0, 1.0, 1.0)

var item_id: String = ""
var item_data: Dictionary = {}
var collected: bool = false
var spawn_position: Vector2 = Vector2.ZERO

@onready var particles: GPUParticles2D = $GPUParticles2D


func _ready() -> void:
	print_tree_pretty()
	_setup_particle_texture()
	_setup_particle_material(DEFAULT_PARTICLE_COLOR)


func setup(new_item_id: String) -> void:
	item_id = new_item_id
	item_data = GameData.get_item_data(item_id)
	spawn_position = global_position
	collected = false
	visible = true
	monitoring = true
	monitorable = true
	_update_visual()


func _update_visual() -> void:
	var rarity := str(item_data.get("rarity", "common")).to_lower()
	var color: Color = RARITY_COLORS.get(rarity, DEFAULT_PARTICLE_COLOR)

	_setup_particle_texture()
	_setup_particle_material(color)

	if particles != null:
		particles.visible = true
		particles.emitting = true


func collect() -> void:
	collected = true
	visible = false

	if particles != null:
		particles.emitting = false

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func respawn() -> void:
	collected = false
	global_position = spawn_position
	visible = true

	_update_visual()

	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func _setup_particle_texture() -> void:
	if particles == null:
		return

	if particles.texture != null:
		return

	particles.texture = _create_diamond_texture(18)


func _setup_particle_material(color: Color) -> void:
	if particles == null:
		return

	var material := ParticleProcessMaterial.new()

	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 10.0

	# Godot 2D uses +Y as down, so negative Y sends particles upward.
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 50.0
	material.gravity = Vector3(0.0, -18.0, 0.0)

	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 55.0
	material.angular_velocity_min = -120.0
	material.angular_velocity_max = 120.0
	material.scale_min = 0.55
	material.scale_max = 2.0

	material.color = color

	particles.process_material = material
	particles.amount = 10
	particles.lifetime = 2.0
	particles.preprocess = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.75
	particles.local_coords = false
	particles.emitting = not collected


func _create_diamond_texture(size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var center := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var radius := size * 0.45

	for y in range(size):
		for x in range(size):
			var p := Vector2(x, y)
			var diamond_distance = abs(p.x - center.x) + abs(p.y - center.y)

			if diamond_distance <= radius:
				var alpha := 1.0
				if diamond_distance > radius - 2.0:
					alpha = clamp((radius - diamond_distance) / 2.0, 0.0, 1.0)

				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(image)
