@tool
extends EditorPlugin

var dock : Control

var director: BPC_PreviewDirector

var start_button: Button
var pause_button: Button
var stop_button: Button
var scrub: Slider
var loop_button: Button
var affect_neightbors_button: Button
var affect_children_button: Button

func _enter_tree() -> void:
	dock = preload("res://addons/brackeys_particle_controls/BrackeysParticleControlsUI.tscn").instantiate()
	var editor_main_screen = get_editor_interface().get_editor_main_screen()
	editor_main_screen.add_child(dock)
	
	pause_button = dock.get_node("%PauseButton")
	scrub = dock.get_node("%Scrub")
	
	start_button = dock.get_node("%StartButton")
	start_button.pressed.connect(_on_start_pressed)
	start_button.icon = editor_main_screen.get_theme_icon("PlayStart","EditorIcons")
	start_button.text = ""
	pause_button.pressed.connect(_on_pause_pressed)
	pause_button.icon = editor_main_screen.get_theme_icon("Pause","EditorIcons")
	pause_button.text = ""
	stop_button = dock.get_node("%StopButton")
	stop_button.pressed.connect(_on_stop_pressed)
	stop_button.icon = editor_main_screen.get_theme_icon("Stop","EditorIcons")
	stop_button.text = ""
	
	loop_button = dock.get_node("%LoopButton")
	loop_button.icon = editor_main_screen.get_theme_icon("Loop","EditorIcons")
	loop_button.text = ""
	loop_button.toggled.connect(_on_loop_toggled)
	
	affect_neightbors_button = dock.get_node("%AffectNeighborsButton")
	affect_neightbors_button.icon = editor_main_screen.get_theme_icon("AnimationTrackList","EditorIcons")
	affect_neightbors_button.text = ""
	affect_neightbors_button.toggled.connect(_on_affect_neighbors_toggled)
	
	affect_children_button = dock.get_node("%AffectChildrenButton")
	affect_children_button.icon = editor_main_screen.get_theme_icon("AnimationTrackGroup","EditorIcons")
	affect_children_button.text = ""
	affect_children_button.toggled.connect(_on_affect_children_toggled)
	
	scrub.value_changed.connect(_on_scrub_value_changed)
	
	director = BPC_PreviewDirector.new()
	director.play_processed.connect(_on_play_processed)
	director.state_changed.connect(_on_director_state_changed)
	get_editor_interface().get_editor_viewport_3d().add_child(director)
	
	_on_selection_changed()
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

func show():
	scrub.set_value_no_signal(0.0)
	#scrub.step = 1.0 / sel_gpu_part_3d.fixed_fps / scrub.max_value
	dock.visible = true

func hide():
	dock.visible = false

func _exit_tree() -> void:
	if dock:
		dock.queue_free()
	if director:
		director.clean_up_previews()
		director.queue_free()

func _on_start_pressed():
	director.play()

func _on_pause_pressed():
	if director.is_paused:
		director.un_pause()
	else:
		director.pause()

func _on_stop_pressed():
	director.stop()
	scrub.set_value_no_signal(0.0)

func _on_loop_toggled(pressed: bool):
	director.should_loop = pressed

func _on_affect_neighbors_toggled(pressed: bool):
	if director.is_paused:
		director.stop()
	director.affect_neighbors = pressed
	if pressed:
		director.clean_up_neighbor_previews()
		director.create_neighbor_previews()
	else:
		director.clean_up_neighbor_previews()
	if director.is_playing:
		director.play()

func _on_affect_children_toggled(pressed: bool):
	if director.is_paused:
		director.stop()
	director.affect_children = pressed
	if pressed:
		director.clean_up_children_previews()
		director.create_children_previews()
	else:
		director.clean_up_children_previews()
	if director.is_playing:
		director.play()

func _on_scrub_value_changed(value: float):
	director.scrub_to(value)

func _on_play_processed():
	scrub.set_value_no_signal(director.get_play_time())

func _on_director_state_changed():
	var can_play = director.can_play()
	start_button.disabled = !can_play
	pause_button.disabled = !can_play
	stop_button.disabled = !can_play

	if director.is_paused:
		pause_button.button_pressed = true
		scrub.editable = true
	else:
		pause_button.button_pressed = false
		scrub.editable = false

	loop_button.disabled = !director.can_loop()
	loop_button.button_pressed = director.should_loop
	
	scrub.max_value = director.get_longest_sim_sime()
	scrub.set_value_no_signal(director.get_play_time())

func _on_selection_changed():
	var was_playing: bool = director.is_playing
	if was_playing:
		director.stop()
	
	var selection: Array = get_editor_interface().get_selection().get_selected_nodes()
	
	var selection_good: bool = false
	
	if selection and selection.size() == 1:
		if director.node_is_particles(selection[0]):
			selection_good = true

	if selection_good:
		director.clean_up_previews()
		director.select_particles(selection[0])
		director.create_previews()
		if was_playing:
			director.play()
		else:
			_on_director_state_changed()
		show()
	else:
		director.clean_up_previews()
		director.deselect_particles()
		hide()
