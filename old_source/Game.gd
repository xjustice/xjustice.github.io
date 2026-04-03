extends Node2D

# Board Properties
@export var board_width: int = 10
@export var board_height: int = 20

# Node References
@onready var board_layer: TileMapLayer = $GameContainer/BoardLayer
@onready var active_piece_layer: TileMapLayer = $GameContainer/ActivePieceLayer
@onready var ghost_piece_layer: TileMapLayer = $GameContainer/GhostPieceLayer
@onready var impact_particles: CPUParticles2D = $ImpactParticles
@onready var game_container: Node2D = $GameContainer
@onready var rotate_sound: AudioStreamPlayer = $RotateSound
@onready var clear_sound: AudioStreamPlayer = $ClearSound

# UI References
@export var score_label: Label
@export var next_piece_display: TileMapLayer
@export var pause_label: Label
@export var restart_message: Label
@export var confirm_popup: Panel

# Game State
var active_piece_type: int
var active_piece_pos: Vector2i
var active_piece_cells: Array[Vector2i] = []
var next_piece_type: int
var bag = TetroData.Bag.new()
var score: int = 0
var is_paused: bool = false

# Gravity Shift System
var gravity_dir: Vector2i = Vector2i(0, 1)
var gravity_angle: float = 0.0
var is_shifting: bool = false
@onready var border_node: ReferenceRect = $GameContainer/BoardBorder

# Visuals
const BG_TINTS = [
	Color(0, 0, 0, 0.4), Color(0.1, 0, 0.2, 0.4), Color(0, 0.1, 0.2, 0.4),
	Color(0.2, 0, 0.1, 0.4), Color(0, 0.2, 0.1, 0.4), Color(0.1, 0.1, 0.3, 0.5)
]
@onready var background_overlay: ColorRect = $ColorRectOverlay

# Gravity / Falling
@export var fall_speed: float = 1.0  # Seconds per fall
var fall_timer: float = 0.0

# Movement (DAS - Delayed Auto Shift)
@export var das_delay: float = 0.18     # Standard Tetris DAS (~180ms)
@export var das_interval: float = 0.04  # Standard Tetris ARR (~40ms)
var das_timer: float = 0.0
var das_direction: Vector2i = Vector2i.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("Tetris Game Started!")
	randomize()
	setup_procedural_tiles()
	change_random_background()
	next_piece_type = bag.get_next()
	spawn_piece()
	
	# Setup UI Connections with safety checks
	if confirm_popup:
		var restart_btn = confirm_popup.get_node_or_null("VBoxContainer/RestartBtn")
		if restart_btn: restart_btn.pressed.connect(_on_restart_confirmed)
		
		var cancel_btn = confirm_popup.get_node_or_null("VBoxContainer/CancelBtn")
		if cancel_btn: cancel_btn.pressed.connect(_on_cancel_pressed)
		
		var exit_btn = confirm_popup.get_node_or_null("VBoxContainer/ExitBtn")
		if exit_btn: exit_btn.pressed.connect(_on_exit_pressed)

func setup_procedural_tiles() -> void:
	# Create a 224x32 image (7 blocks of 32x32)
	var img = Image.create(224, 32, false, Image.FORMAT_RGBA8)
	
	# Draw 7 colored squares
	var colors = [
		Color.CYAN, Color.BLUE, Color.ORANGE, Color.YELLOW, 
		Color.GREEN, Color.PURPLE, Color.RED
	]
	
	for i in range(7):
		var rect = Rect2i(i * 32, 0, 32, 32)
		# Fill with color
		img.fill_rect(rect, colors[i])
		# Add a subtle border
		for x in range(32):
			img.set_pixel(i * 32 + x, 0, Color.WHITE.lerp(colors[i], 0.5))
			img.set_pixel(i * 32 + x, 31, Color.BLACK.lerp(colors[i], 0.5))
		for y in range(32):
			img.set_pixel(i * 32, y, Color.WHITE.lerp(colors[i], 0.5))
			img.set_pixel(i * 32 + 31, y, Color.BLACK.lerp(colors[i], 0.5))

	var tex = ImageTexture.create_from_image(img)
	
	# Update the TileSet for all layers
	var layers = [board_layer, active_piece_layer, ghost_piece_layer]
	if next_piece_display: layers.append(next_piece_display)
	
	for layer in layers:
		if layer and layer.tile_set:
			var source = layer.tile_set.get_source(0) as TileSetAtlasSource
			if source:
				source.texture = tex
				source.texture_region_size = Vector2i(32, 32)

func change_random_background() -> void:
	if background_overlay:
		background_overlay.color = BG_TINTS.pick_random()

func update_score(lines_cleared: int) -> void:
	var base_points = [0, 100, 300, 500, 800]
	score += base_points[lines_cleared]
	
	if lines_cleared > 0:
		apply_impact_effects()
	
	if score_label:
		score_label.text = "SCORE: " + str(score)

func apply_impact_effects() -> void:
	apply_shake()
	if border_node:
		var tween = create_tween()
		var original_color = border_node.border_color
		border_node.border_color = Color.WHITE
		border_node.border_width = 4.0
		tween.tween_property(border_node, "border_color", original_color, 0.2)
		tween.parallel().tween_property(border_node, "border_width", 2.0, 0.2)

func _process(delta: float) -> void:
	if is_paused or is_shifting: return
	
	# Handle DAS (Continuous Movement)
	if das_direction != Vector2i.ZERO:
		das_timer += delta
		if das_timer >= das_delay:
			# For DAS, we need to respect gravity relative movement
			# We rotate the input direction based on current gravity
			var move_dir = rotate_vector_by_gravity(das_direction)
			if das_timer >= das_delay + das_interval:
				das_timer = das_delay
				move_piece(move_dir)
	
	# Automatic Gravity
	fall_timer += delta
	if fall_timer >= fall_speed:
		fall_timer = 0.0
		if not move_piece(gravity_dir):
			lock_piece()

func rotate_vector_by_gravity(input_dir: Vector2i) -> Vector2i:
	# If gravity is Down(0,1), Right is (1,0)
	# If gravity is Right(1,0), Right (relative) is Down(0,1) in grid local
	# We can use a simple rotation matrix or match cases
	if gravity_dir == Vector2i(0, 1): return input_dir
	if gravity_dir == Vector2i(1, 0): return Vector2i(-input_dir.y, input_dir.x)
	if gravity_dir == Vector2i(0, -1): return Vector2i(-input_dir.x, -input_dir.y)
	if gravity_dir == Vector2i(-1, 0): return Vector2i(input_dir.y, -input_dir.x)
	return input_dir

func spawn_piece() -> void:
	active_piece_type = next_piece_type
	next_piece_type = bag.get_next()
	
	# Spawn at a location relative to gravity
	# Default: Top center. If gravity Right: Left center.
	var spawn_pos = Vector2i(board_width / 2, board_height / 2)
	spawn_pos -= gravity_dir * (board_width / 2 - 2)
	
	active_piece_pos = spawn_pos
	active_piece_cells = TetroData.get_cells_from_matrix(active_piece_type)
	
	if not can_move(active_piece_pos, active_piece_cells):
		game_over()
	else:
		draw_active_piece()
		draw_next_piece()
		# Change background occasionally on new piece
		if randf() < 0.1:
			change_random_background()

## Checks if the piece can be placed at the target position and orientation
func can_move(target_pos: Vector2i, cells: Array[Vector2i]) -> bool:
	for cell in cells:
		var grid_pos = target_pos + cell
		
		# 1. Boundary Check (upport all gravity directions)
		if grid_pos.x < 0 or grid_pos.x >= board_width:
			return false
		if grid_pos.y < 0 or grid_pos.y >= board_height:
			return false
		
		# 2. Collision with existing blocks on the TileMapLayer
		if board_layer.get_cell_source_id(grid_pos) != -1:
			return false
			
	return true

## Rotates the current piece cells 90 degrees clockwise
func rotate_piece() -> void:
	var new_cells: Array[Vector2i] = []
	for cell in active_piece_cells:
		# Mathematical rotation: (x, y) -> (-y, x)
		new_cells.append(Vector2i(-cell.y, cell.x))
	
	if can_move(active_piece_pos, new_cells):
		active_piece_cells = new_cells
		if rotate_sound: rotate_sound.play()
		draw_active_piece()
	else:
		# Basic 'wall kick' attempt
		if can_move(active_piece_pos + Vector2i(1, 0), new_cells):
			active_piece_pos += Vector2i(1, 0)
			active_piece_cells = new_cells
			if rotate_sound: rotate_sound.play()
			draw_active_piece()
		elif can_move(active_piece_pos + Vector2i(-1, 0), new_cells):
			active_piece_pos += Vector2i(-1, 0)
			active_piece_cells = new_cells
			if rotate_sound: rotate_sound.play()
			draw_active_piece()

## Draw the active piece and its ghost
func draw_active_piece() -> void:
	active_piece_layer.clear()
	ghost_piece_layer.clear()
	
	# 1. Calculate Ghost Position
	var ghost_pos = active_piece_pos
	while can_move(ghost_pos + gravity_dir, active_piece_cells):
		ghost_pos += gravity_dir
	
	# 2. Draw Ghost (semi-transparent)
	for cell in active_piece_cells:
		ghost_piece_layer.set_cell(ghost_pos + cell, 0, Vector2i(active_piece_type, 0))
	ghost_piece_layer.modulate = Color(1, 1, 1, 0.3)
	
	# 3. Draw Active Piece
	for cell in active_piece_cells:
		active_piece_layer.set_cell(active_piece_pos + cell, 0, Vector2i(active_piece_type, 0))

func draw_next_piece() -> void:
	if not next_piece_display: return
	next_piece_display.clear()
	var cells = TetroData.get_cells_from_matrix(next_piece_type)
	for cell in cells:
		next_piece_display.set_cell(Vector2i(2, 2) + cell, 0, Vector2i(next_piece_type, 0))

func move_piece(direction: Vector2i) -> bool:
	if can_move(active_piece_pos + direction, active_piece_cells):
		active_piece_pos += direction
		draw_active_piece()
		return true
	return false

func lock_piece() -> void:
	# Trigger Impact Particles
	if impact_particles:
		# Convert tile position to global position
		var local_tile_center = Vector2(active_piece_pos * 32) + Vector2(16, 16)
		impact_particles.global_position = active_piece_layer.to_global(local_tile_center)
		impact_particles.color = TetroData.COLORS.get(active_piece_type, Color.WHITE)
		impact_particles.restart()
		impact_particles.emitting = true

	for cell in active_piece_cells:
		board_layer.set_cell(active_piece_pos + cell, 0, Vector2i(active_piece_type, 0))
	
	active_piece_layer.clear()
	if not check_lines():
		spawn_piece()

func restart_game() -> void:
	get_tree().paused = false
	board_layer.clear()
	active_piece_layer.clear()
	ghost_piece_layer.clear()
	score = 0
	update_score(0)
	bag.refill()
	spawn_piece()
	
	if confirm_popup: confirm_popup.visible = false
	
	# Show restart message briefly
	if restart_message:
		restart_message.visible = true
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(func(): restart_message.visible = false)

func _on_restart_confirmed() -> void:
	restart_game()
	is_paused = false

func _on_cancel_pressed() -> void:
	if confirm_popup: confirm_popup.visible = false
	is_paused = false

func _on_exit_pressed() -> void:
	get_tree().quit()

func check_lines() -> bool:
	var lines_to_clear = []
	for y in range(board_height):
		var is_full = true
		for x in range(board_width):
			if board_layer.get_cell_source_id(Vector2i(x, y)) == -1:
				is_full = false
				break
		if is_full:
			lines_to_clear.append(y)
	
	if lines_to_clear.size() > 0:
		if clear_sound: clear_sound.play()
		# Clear the full lines (but don't shift them manually)
		for y in lines_to_clear:
			for x in range(board_width):
				board_layer.set_cell(Vector2i(x, y), -1)
		
		update_score(lines_to_clear.size())
		apply_shake()
		shift_gravity()
		return true
	return false

func shift_gravity() -> void:
	is_shifting = true
	# Toggle between DOWN and UP
	var new_dir = Vector2i(0, -1) if gravity_dir == Vector2i(0, 1) else Vector2i(0, 1)
	gravity_angle = 180.0 if new_dir == Vector2i(0, -1) else 0.0
	gravity_dir = new_dir
	
	var tween = create_tween()
	tween.tween_property(game_container, "rotation_degrees", gravity_angle, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# Ensure apply_cascade is called deferredly for stability
	tween.tween_callback(func(): call_deferred("apply_cascade"))

func apply_cascade() -> void:
	print("DEBUG: apply_cascade started. Gravity: ", gravity_dir)
	var moved_count = 0
	var max_iterations = board_height * 2 # Safety break for infinite loops
	var moved = true
	
	while moved and max_iterations > 0:
		moved = false
		max_iterations -= 1
		# Iterate in gravity direction order
		var y_range = range(board_height-1, -1, -1) if gravity_dir.y >= 0 else range(board_height)
		for y in y_range:
			for x in range(board_width):
				var pos = Vector2i(x, y)
				var source_id = board_layer.get_cell_source_id(pos)
				if source_id != -1:
					var target = pos + gravity_dir
					if is_within_bounds(target) and board_layer.get_cell_source_id(target) == -1:
						var atlas = board_layer.get_cell_atlas_coords(pos)
						board_layer.set_cell(pos, -1)
						board_layer.set_cell(target, source_id, atlas)
						moved = true
						moved_count += 1
	
	print("DEBUG: apply_cascade finished. Total moves: ", moved_count)
	
	# Check for new lines after cascade
	if not check_lines_any_orientation():
		is_shifting = false
		print("DEBUG: Shifting ended. Spawning piece.")
		call_deferred("spawn_piece")

func is_within_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < board_width and pos.y >= 0 and pos.y < board_height

func check_lines_any_orientation() -> bool:
	# Check Horizontal lines
	var h_lines = []
	for y in range(board_height):
		var full = true
		for x in range(board_width):
			if board_layer.get_cell_source_id(Vector2i(x, y)) == -1:
				full = false; break
		if full: h_lines.append(y)
	
	# Check Vertical lines
	var v_lines = []
	for x in range(board_width):
		var full = true
		for y in range(board_height):
			if board_layer.get_cell_source_id(Vector2i(x, y)) == -1:
				full = false; break
		if full: v_lines.append(x)
	
	if h_lines.size() > 0 or v_lines.size() > 0:
		for y in h_lines:
			for x in range(board_width): board_layer.set_cell(Vector2i(x, y), -1)
		for x in v_lines:
			for y in range(board_height): board_layer.set_cell(Vector2i(x, y), -1)
		
		update_score(h_lines.size() + v_lines.size())
		apply_shake()
		print("DEBUG: Lines found after cascade. Re-cascading.")
		call_deferred("apply_cascade") # Cascade again
		return true
	return false

func apply_shake() -> void:
	var camera = $Camera2D
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "offset", Vector2(5, 5), 0.05)
		tween.tween_property(camera, "offset", Vector2(-5, -5), 0.05)
		tween.tween_property(camera, "offset", Vector2(0, 0), 0.05)

# clear_line is no longer used, unified with cascade system


func game_over() -> void:
	print("Game Over!")
	is_paused = true
	if confirm_popup:
		confirm_popup.visible = true
		var title = confirm_popup.get_node_or_null("VBoxContainer/Title")
		if title: title.text = "GAME OVER"
		var restart_btn = confirm_popup.get_node_or_null("VBoxContainer/RestartBtn")
		if restart_btn: restart_btn.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		is_paused = true
		if confirm_popup:
			confirm_popup.visible = true
			confirm_popup.get_node("VBoxContainer/RestartBtn").grab_focus()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		is_paused = !is_paused
		if pause_label:
			pause_label.visible = is_paused
		return

	if is_paused or is_shifting: return

	# Movement Input (Arrows + WASD)
	var move_left = event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_A)
	var move_right = event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_D)
	var move_down = event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_S)
	var rotate = event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode == KEY_W or event.keycode == KEY_K))
	var hard_drop = event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE)
	
	if move_left:
		das_direction = Vector2i(-1, 0)
		das_timer = 0.0
		move_piece(rotate_vector_by_gravity(das_direction))
	elif move_right:
		das_direction = Vector2i(1, 0)
		das_timer = 0.0
		move_piece(rotate_vector_by_gravity(das_direction))
	
	# Release DAS
	var released_left = event.is_action_released("ui_left") or (event is InputEventKey and not event.pressed and event.keycode == KEY_A)
	var released_right = event.is_action_released("ui_right") or (event is InputEventKey and not event.pressed and event.keycode == KEY_D)
	
	if (released_left and das_direction == Vector2i(-1, 0)) or \
	   (released_right and das_direction == Vector2i(1, 0)):
		das_direction = Vector2i.ZERO

	if move_down:
		move_piece(gravity_dir)
	elif rotate:
		rotate_piece()
	elif hard_drop:
		while move_piece(gravity_dir):
			create_trail_ghost(active_piece_pos)
		lock_piece()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		restart_game()

func create_trail_ghost(pos: Vector2i) -> void:
	# Performance optimization: Don't create too many nodes on web
	if OS.get_name() == "Web" and randf() > 0.5: return 
	
	var trail = TileMapLayer.new()
	trail.tile_set = active_piece_layer.tile_set
	trail.position = game_container.position
	add_child(trail)
	
	# Ensure trail is behind everything else in GameContainer
	move_child(trail, 0)
	
	for cell in active_piece_cells:
		trail.set_cell(pos + cell, 0, Vector2i(active_piece_type, 0))
	
	trail.modulate = Color(1, 1, 1, 0.4)
	
	var tween = create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.3)
	tween.tween_callback(trail.queue_free)
