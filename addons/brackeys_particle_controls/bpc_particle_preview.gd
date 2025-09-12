@tool
class_name BPC_ParticlePreview extends Node

signal property_changed(prop_name: String, value)

var original: Node
var dup: Node

var original_property_names: Array = []
var prev_properties: Dictionary = {}
var last_prop_update_time: float = 0.0
var stagger_offset: float = randf() * 0.15

func _init(og: Node):
	if not (og is GPUParticles2D or og is GPUParticles3D or og is CPUParticles2D or og is CPUParticles3D):
		print("Error: Node is not a Particles node")
		return

	original = og
	if dup:
		dup.queue_free()
	dup = og.duplicate()
	og.add_sibling(dup)
	save_properties()
	#print("Created preview for %s" % original.name)

func destroy():
	#print("Destroyed preview for %s" % original.name)
	if dup:
		dup.queue_free()
	original = null
	dup = null

func save_properties():
	prev_properties.clear()
	for prop in original.get_property_list():
		#print("Property: %s" % prop.name)
		#print("Value: %s" % original.get(prop.name))
		if can_skip_property(prop.name):
			continue
		prev_properties[prop.name] = original.get(prop.name)
	original_property_names = prev_properties.keys()

func update_properties():
	var prop_changed = false
	for prop_name in original_property_names:
		if can_skip_property(prop_name):
			continue
		var val = original.get(prop_name)
		if not prev_properties.has(prop_name ) or prev_properties[prop_name] != val:
			change_property(prop_name, val)
			prop_changed = true
			property_changed.emit(prop_name, val)
			#print("Property changed: %s" % prop_name)

func change_property(prop_name: String, value) -> void:
	prev_properties[prop_name] = value
	if prop_name != "one_shot" or prop_name != "emitting" or prop_name != "speed_scale":
		dup.set(prop_name, value)

func can_skip_property(prop_name: String) -> bool:
	# For some reason Godot throws errors if we try to get these properties
	# when the number of draw passes is lower 
	if prop_name == "draw_pass_2" and original.draw_passes < 2:
		return true
	if prop_name == "draw_pass_3" and original.draw_passes < 3:
		return	 true
	if prop_name == "draw_pass_4" and original.draw_passes < 4:
		return true

	return false

func _process(delta: float) -> void:
	if not (original and dup):
		return

	# A bit hacky to detect changes like this but works for now
	# I'm staggering the checks to avoid performance spikes
	# Since we might be previewing a bunch of neighbors and children
	var time = Time.get_ticks_msec() / 1000.0
	if time - last_prop_update_time > 0.15 + stagger_offset:
		last_prop_update_time = time
		update_properties()

func play():
	dup.restart()

func pause():
	dup.speed_scale = 0.0

func un_pause():
	dup.speed_scale = original.speed_scale

func stop():
	dup.emitting = false
	dup.request_particles_process(get_total_sim_time())

func scrub_to(t: float):
	dup.restart(true)
	dup.request_particles_process(t)

func get_total_sim_time() -> float:
	if original.speed_scale == 0:
		return 999999 
	var max_emission_time = original.lifetime * (1.0 - original.explosiveness)
	return (max_emission_time + original.lifetime - original.preprocess) / original.speed_scale

