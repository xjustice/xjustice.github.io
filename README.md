# 🕹️ Reverse Tetris (Cyberpunk Edition)

A modern Tetris game built with Godot 4 and GDScript. It adheres to standard Tetris guidelines while adding vibrant cyberpunk visuals and smooth controls.

## 🌟 Key Features

- **Standard 7-Bag System**: Ensures fair piece distribution by generating all 7 tetrominoes in a shuffled pack.
- **DAS (Delayed Auto Shift)**: Holding left/right keys triggers high-speed movement after a 0.5s delay for fluid control.
- **Procedural Tile Generation**: High-quality neon block textures are generated at runtime via code, ensuring perfect resolution and colors.
- **Ghost Piece**: Shows a semi-transparent preview of where the block will land.
- **Dynamic Backgrounds**: Features a stunning space background with 10 random color tints that change during play.
- **UI System**: Includes real-time score tracking, next piece preview, and a keyboard-navigable ESC menu.
- **Impact Effects**: Screen shake, particle sparks, and motion trails for a high-impact feel.
- **Heavy Bass Audio**: Deep, immersive sound effects for rotation and line clears.

## ⌨️ Controls

| Key | Action |
| :--- | :--- |
| **Arrow Left/Right** | Move Piece (Hold for continuous movement) |
| **Arrow Up** | Rotate Piece |
| **Arrow Down** | Soft Drop |
| **Space** | Hard Drop (with trail effect) |
| **Enter** | Pause / Resume Game |
| **ESC** | Open Confirm Menu (Restart/Exit) |

## 🛠️ Technical Specs

- **Engine**: Godot 4.3+ (Forward+ renderer recommended)
- **Language**: GDScript 2.0
- **Core Nodes**: Utilizes `TileMapLayer` for efficient grid-based rendering.
- **Resolution**: Optimized for 600x800.

## 📁 File Structure

- `Game.gd`: Core game logic (Movement, collision, line clear, UI control).
- `TetroData.gd`: Tetromino data, matrix definitions, and the 7-Bag system.
- `Main.tscn`: Main scene node structure and HUD configuration.
- `TetroTileSet.tres`: TileSet configuration for grid rendering.

---

## 🚀 Getting Started

1. Open `project.godot` in the Godot 4 editor.
2. Ensure `Main.tscn` is set as the main scene.
3. Press **F5** to start the game!
