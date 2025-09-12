@tool
class_name BPC_PreviewDirector extends Node

signal play_processed
signal state_changed

var sel_particles: Node
var sel_neighbors: Array[Node] = []
var sel_children: Array[Node] = []

var sel_preview: BPC_ParticlePreview
var sel_neighbor_previews: Array[BPC_ParticlePreview] = []
var sel_children_previews: Array[BPC_ParticlePreview] = []

var is_playing: bool = false
var is_paused: bool = false
var should_loop: bool = false

var start_time_msec: float = 0.0
var play_time_msec: float = 0.0

var affect_neighbors: bool = false
var affect_children: bool = false

func _exit_tree() -> void:
	clean_up_previews()

func _process(delta: float) -> void:
	if is_playing and not is_paused:
		if play_processed:
			play_processed.emit()
		if get_play_time() >= get_longest_sim_sime():
			if should_loop and can_loop():
				play()

func play():
	if not can_play():
		if is_playing:
			stop()
		return

	is_playing = true
	start_time_msec = Time.get_ticks_msec()
	play_time_msec = 0.0

	sel_preview.play()
	if affect_neighbors:
		for p in sel_neighbor_previews:
			p.play()
	if affect_children:
		for p in sel_children_previews:
			p.play()

	state_changed.emit()

func stop():
	if is_paused:
		un_pause()
	is_playing = false
	play_time_msec = 0.0
	sel_preview.stop()
	if affect_neighbors:
		for p in sel_neighbor_previews:
			p.stop()
	if affect_children:
		for p in sel_children_previews:
			p.stop()
	state_changed.emit()

func pause():
	is_paused = true
	sel_preview.pause()
	play_time_msec = get_play_time() * 1000

	if affect_neighbors:
		for p in sel_neighbor_previews:
			p.pause()
	if affect_children:
		for p in sel_children_previews:
			p.pause()
	state_changed.emit()


func un_pause():
	is_paused = false
	start_time_msec = Time.get_ticks_msec() - play_time_msec
	sel_preview.un_pause()

	if affect_neighbors:
		for p in sel_neighbor_previews:
			p.un_pause()
	if affect_children:
		for p in sel_children_previews:
			p.un_pause()
	state_changed.emit()

func scrub_to(t: float):
	sel_preview.scrub_to(t)
	
	if affect_neighbors:
		for p in sel_neighbor_previews:
			p.scrub_to(t)
	if affect_children:
		for p in sel_children_previews:
			p.scrub_to(t)

	play_time_msec = t * 1000

func select_particles(particles: Node):
	sel_particles = particles
	sel_neighbors = get_neighbor_particles(particles)
	sel_children = get_children_particles(particles)

func deselect_particles():
	sel_particles = null
	sel_neighbors.clear()
	sel_children.clear()

func get_neighbor_particles(node: Node) -> Array[Node]:
	var neighbors: Array[Node] = []
	var parent = node.get_parent()
	if not parent:
		return neighbors
	for child in parent.get_children():
		# A bit of a hack to avoid picking up the preview node itself
		# since it's also a sibling of the selected node
		if child != node and node_is_particles(child) and not child.name.begins_with("@"):
			neighbors.append(child)
	return neighbors

func get_children_particles(node: Node) -> Array[Node]:
	var children: Array[Node] = []
	for child in node.get_children():
		# A bit of a hack to avoid picking up the preview node itself
		# since it's also a sibling of the selected node
		if node_is_particles(child) and not child.name.begins_with("@"):
			children.append(child)
	return children

func node_is_particles(node: Node) -> bool:
	return node is GPUParticles2D or node is GPUParticles3D or node is CPUParticles2D or node is CPUParticles3D

func can_play() -> bool:
	if not sel_preview or sel_preview.original.emitting:
		return false
	if affect_children:
		for p in sel_children_previews:
			if p.original.emitting:
				return false
	if affect_neighbors:
		for p in sel_neighbor_previews:
			if p.original.emitting:
				return false
	return true

func can_loop() -> bool:
	if not sel_preview or not sel_preview.original.one_shot:
		return false
	if affect_children:
		for p in sel_children_previews:
			if not p.original.one_shot:
				return false
	if affect_neighbors:
		for p in sel_neighbor_previews:
			if not p.original.one_shot:
				return false
	return true

func create_previews():
	is_playing = false
	is_paused = false
	play_time_msec = 0.0

	sel_preview = BPC_ParticlePreview.new(sel_particles)
	sel_preview.property_changed.connect(_on_property_changed)
	add_child(sel_preview)
	
	if affect_neighbors:
		create_neighbor_previews()
	if affect_children:
		create_children_previews()

func create_neighbor_previews():
	for neighbor in sel_neighbors:
		var preview = BPC_ParticlePreview.new(neighbor)
		preview.property_changed.connect(_on_property_changed)
		add_child(preview)
		sel_neighbor_previews.append(preview)

func create_children_previews():
	for child in sel_children:
		var preview = BPC_ParticlePreview.new(child)
		preview.property_changed.connect(_on_property_changed)
		add_child(preview)
		sel_children_previews.append(preview)

func clean_up_previews():
	if sel_preview:
		sel_preview.destroy()
		sel_preview = null
	clean_up_neighbor_previews()
	clean_up_children_previews()

func clean_up_neighbor_previews():
	for p in sel_neighbor_previews:
		p.destroy()
	sel_neighbor_previews.clear()

func clean_up_children_previews():
	for p in sel_children_previews:
		p.destroy()
	sel_children_previews.clear()

func get_play_time() -> float:
	if not is_playing:
		return 0.0
	return min((Time.get_ticks_msec() - start_time_msec) / 1000, get_longest_sim_sime())

func get_longest_sim_sime() -> float:
	var max_time: float = sel_preview.get_total_sim_time()
	if affect_neighbors:
		for p in sel_neighbor_previews:
			var t = p.get_total_sim_time()
			if t > max_time:
				max_time = t
	if affect_children:
		for p in sel_children_previews:
			var t = p.get_total_sim_time()
			if t > max_time:
				max_time = t
	return max_time

func _on_property_changed(prop_name: String, value):
	#print("Property changed: %s to %s" % [prop_name, value])
	if prop_name == "explosiveness" or prop_name == "lifetime" or prop_name == "preprocess" or prop_name == "amount" or prop_name == "speed_scale":
		if is_playing:
			if is_paused:
				stop()
			else:
				play()
			state_changed.emit()
	if prop_name == "emitting":
		state_changed.emit()
	if prop_name == "one_shot":
		state_changed.emit()