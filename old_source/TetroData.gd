extends Node
class_name TetroData

# Standard 7 Tetromino types
enum Type { I, J, L, O, S, T, Z }

# Shapes defined as Matrices (2D Arrays)
# 1 represents a block, 0 represents empty space
const MATRICES = {
	Type.I: [
		[0, 0, 0, 0],
		[1, 1, 1, 1],
		[0, 0, 0, 0],
		[0, 0, 0, 0]
	],
	Type.J: [
		[1, 0, 0],
		[1, 1, 1],
		[0, 0, 0]
	],
	Type.L: [
		[0, 0, 1],
		[1, 1, 1],
		[0, 0, 0]
	],
	Type.O: [
		[1, 1],
		[1, 1]
	],
	Type.S: [
		[0, 1, 1],
		[1, 1, 0],
		[0, 0, 0]
	],
	Type.T: [
		[0, 1, 0],
		[1, 1, 1],
		[0, 0, 0]
	],
	Type.Z: [
		[1, 1, 0],
		[0, 1, 1],
		[0, 0, 0]
	]
}

# Function to convert Matrix to Vector2i offsets (useful for Godot TileMap)
static func get_cells_from_matrix(type: Type) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var matrix = MATRICES[type]
	var size = matrix.size()
	var offset = size / 2
	
	for y in range(size):
		for x in range(size):
			if matrix[y][x] == 1:
				cells.append(Vector2i(x - offset, y - offset))
	return cells

# Colors for each type (matching standard colors)
const COLORS = {
	Type.I: Color(0, 1, 1),      # Cyan
	Type.J: Color(0, 0, 1),      # Blue
	Type.L: Color(1, 0.5, 0),    # Orange
	Type.O: Color(1, 1, 0),      # Yellow
	Type.S: Color(0, 1, 0),      # Green
	Type.T: Color(0.5, 0, 0.5),  # Purple
	Type.Z: Color(1, 0, 0)       # Red
}

# Helper to get a random tetromino type
static func get_random_type() -> Type:
	return Type.values().pick_random()

# 7-Bag System for fairer distribution
class Bag:
	var contents: Array[Type] = []

	func get_next() -> Type:
		if contents.is_empty():
			refill()
		return contents.pop_back()

	func refill() -> void:
		contents.assign(Type.values())
		contents.shuffle()
