# snake_nasm86

Snake game in NASM x86 assembly for DOS/DOSBox.

## Description

A classic Snake game written in x86 assembly language using NASM assembler. The game runs in DOS real mode (80x25 text mode) and uses BIOS interrupts for video and keyboard handling.

## Features

- Classic snake gameplay with arrow key controls
- Score tracking and high score persistence (per session)
- Victory condition when snake reaches maximum length (32 segments)
- Game over on collision with borders or self
- Clean number display without leading zeros
- Randomized food placement with collision avoidance
- Spanish language interface

## Building

Requires NASM assembler:

```bash
# Install NASM (Ubuntu/Debian)
sudo apt-get install nasm

# Build the game
make

# Or manually:
nasm -f bin snake.asm -o snake.com
```

## Running

The game produces a DOS COM executable. Run it in DOSBox or a compatible DOS environment:

```bash
dosbox snake.com
```

## Controls

- **Arrow keys**: Move the snake
- **ESC**: Exit to menu / Quit game
- **ENTER**: Start game from menu

## Game Rules

- Guide the snake to eat the food (*) to grow
- Avoid hitting the borders or your own body
- Reach 32 segments to win!
- Each food eaten increases your score by 1

## Technical Details

- Target: x86 real mode (COM file format)
- Display: 80x25 text mode (BIOS int 10h)
- Keyboard: BIOS int 16h
- Timer: BIOS int 1Ah for random seed
- Playable area: rows 4-22, columns 2-77
