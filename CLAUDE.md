# Dwarves: Reclaim Your Kingdom — Godot project

A personal digital version of *Dwarves: Reclaim Your Kingdom*, a co-op board game (1–6 players) by Pink Wizard Games (Ben Galea). Built for the owner's own use only; the artwork and rulebook belong to Pink Wizard Games. The owner has chosen to keep the assets in this repository.

Engine: **Godot 4, GDScript.**

## Read these first

| File | What it is |
|---|---|
| `docs/RULES.md` | The complete rules spec. The source of truth for game behaviour. Rulings for rulebook gaps are tagged **(R#)** and listed at the end. |
| `data/game_data.json` | Every number and piece of card text: tiles, actions (dice minimum, resource cost, effect id), titles, turn track, setup grid, limits, and `rule_decisions` flags matching the R# rulings. |
| `assets/` | Images for tiles, title cards, tokens and the turn track. Paths in `game_data.json` are relative to `res://assets/`. |
| `assets/rulebook.pdf` | The original rulebook, for checking anything the spec doesn't cover. |

When the spec and the rulebook disagree, the spec wins: its rulings were decided deliberately by the owner. If something is covered by neither, ask the owner instead of guessing, then add the answer to the Rulings table in `docs/RULES.md` and a flag under `rule_decisions` in `game_data.json`.

## Game in one paragraph

Players share a 5×5 grid of tiles. They start at the Hearth with a small pool of dice (d4/d6/d8). Each round, everyone rolls their dice and, acting at the same time, spends them on actions printed on their own or adjacent tiles (each action needs a minimum value; two dice can be added together). They move one tile per round, gather resources, train warriors, explore face-down Ruins, upgrade dice and claim titles. Then enemies move in a random direction, spawn from tunnels and the City Gate, and turn crowded buildings into new tunnels. Players win by exploring every ruin, collapsing every tunnel and securing the City Gate before the turn track runs out.

## Architecture

Keep the rules engine separate from anything visual. The engine must run and be testable without the scene tree.

```
res://
  data/game_data.json        # static game data (loaded once)
  assets/                    # images
  docs/RULES.md
  scripts/
    core/                    # pure logic, no Node dependencies
      game_data.gd           # loads and exposes game_data.json
      game_state.gd          # all mutable state; must be deep-copyable
      commands/              # one class per player action
      engine.gd              # validates and applies commands, runs the Enemy Phase
      undo_history.gd        # state snapshots and checkpoints
    ui/                      # scenes and scripts that draw state and send commands
  scenes/
  tests/
```

Key decisions:

- **Command pattern.** Every player action (move, spend dice on an action, pick up a warrior, mark done, etc.) is a command object with `player`, `can_apply(state) -> result` and `apply(state) -> events`. The UI only sends commands; it never edits state directly.
- **Events out.** `apply` returns a list of events (e.g. `enemy_moved`, `tile_flipped`, `noble_wounded`) that the UI uses to animate. The UI then redraws from state.
- **All state in one object.** `GameState` holds the grid, tokens, players, dice, resources, titles, turn marker and phase. It must deep-copy cleanly, because undo works by snapshots.
- **Undo (see RULES.md §6).**
  - Save a deep copy of `GameState` before every command. Undo restores the latest copy.
  - Snapshots taken just before a *reveal* (the Dwarf Phase roll, an Expedition, an Enemy Surge, the Enemy Phase) are checkpoints. In normal mode, undo can't go past the most recent checkpoint.
  - Setting `unlimited_undo` removes that limit.
  - History is shared by all players (R18). The UI shows whose action is being undone.
  - The random number generator lives **outside** `GameState` and is never restored by undo, so rolling again after an undo gives a new result (R19).
- **Concurrent players (R9).** There is no per-player turn order in the Dwarf Phase. Any player can act at any time; each marks themselves done, and the Enemy Phase runs when all are done. Assume one shared screen (hot-seat).
- **Data-driven actions.** Tile and title actions are described in `game_data.json` by an `effect` id. The engine maps each effect id to one handler function. Don't hard-code per-tile logic elsewhere.
- **Automatic combat.** Any time an enemy and a warrior end up on the same tile, resolve combat immediately (§5.6). Put this in one function called after every change that moves or creates tokens.

## Build plan

Work in this order. Each milestone should end with passing tests.

1. **Data and setup.** Load `game_data.json`. Build a `GameState` for 1–6 players following RULES.md §3: grid, shuffled ruins, dice pools, resources, turn marker.
2. **Dwarf Phase basics.** Rolling, spending dice, worker assistance, movement, resources, and the simple actions (Dig, Train Warrior, Recruit Worker).
3. **Enemies.** Enemy Phase (tunnels, movement, spawn, track), automatic combat, wounding, blocking, Enemy Surge.
4. **Everything else.** Expedition and tile flips, the remaining tile actions and passives, all six titles, win and loss checks.
5. **Undo.** Snapshots, checkpoints, the unlimited setting.
6. **Playable UI.** A plain 2D board: grid of tile images, tokens, dice tray per player, done buttons, undo button, a log of events. Function over looks.
7. **Polish.** Animations, sound, settings screen, save/load.

A text-only debug view (printing the grid and state) is worth building during milestones 1–4, before the real UI.

## Testing

Use a Godot unit-test addon (GUT or gdUnit4). Test the engine directly with a seeded random number generator so dice rolls are predictable. Every ruling in the R# table should have at least one test.

## Status

- Done: assets extracted from the Tabletop Simulator mod and renamed; rules spec written; all rulebook gaps decided (R1–R26); game data transcribed from the cards.
- Done: milestones 1–6. Engine in `scripts/core/`, plain UI in `scripts/ui/` + `scenes/main.tscn`. Save/load (one slot, `user://save.json`) and the unlimited-undo toggle are in the top bar. The layout is a fixed 1600×960 that scales to the window, keeping its aspect (`canvas_items` + `keep` stretch in `project.godot`); F11 or the top-bar button toggles fullscreen.
- Next: rest of milestone 7 (sound, a settings screen, more save slots). The enemy turn replay is done.

### Where things are

- `rules.gd` holds the effect handlers (`effects` maps effect id → check/apply), combat, wounds, surges and the Enemy Phase. Commands in `commands/` validate the player-side parts and call into it.
- `Rules.action_terms(player, action, tile)` gives an action's real minimum and cost for a player after titles (Messenger, Master Smith, …), with notes. Commands validate against it and every UI text (menus, hovers) is built from it; don't show a printed `min`/`cost` straight from the data. `Rules.movement_parts` does the same for movement.
- `engine.gd` runs the Enemy Phase when the last player is done. Any command during which `Rules.revealed` gets set is stored as a checkpoint in `undo_history.gd`.
- `random_player.gd` lists every legal command; the fuzz test and `tools/debug_game.gd` use it.
- UI: pick a player by clicking their name or a die in their tray, select dice, then click a tile for a menu of moves and actions. Actions that need a target ask for a tile click afterwards.
- UI pieces in `scripts/ui/`: `tile_view.gd` (board spaces), `dice_view.gd` (drawn dice, also blank mini dice for reserves), `track_view.gd` (turn-track art with the marker; cell positions are measured from `turn_track.jpg`), `card_thumb.gd` (title cards, full size on hover), `stat_chip.gd` + `icon_glyph.gd` (icon + value chips; resources and moves have drawn icons since the art has none). `assets/tokens/turn_marker.png` is the publisher logo, so the marker is drawn instead.
- `enemy_turn_animator.gd` replays the Enemy Phase from its events on a copy of the board taken before the command (banner per step, flying enemy tokens, Skip/Space/Esc). The engine state is already final; the screen redraws from it afterwards. `tests/test_enemy_replay.gd` checks the replayed board ends equal to the real one, so a new event type that changes the board needs a case in `EnemyTurnAnimator._apply`. The toggle is saved in `user://settings.cfg`.

## Running and testing

- Tests: `godot --headless --import` once, then `godot --headless -s addons/gut/gut_cmdln.gd` (config in `.gutconfig.json`; GUT 9.3.0 is vendored in `addons/gut`).
- Text-only random game: `godot --headless -s res://tools/debug_game.gd -- <players> <seed>`.
- Without `assets/`, tiles are drawn as labelled colour blocks.

## Getting the assets on a new machine

The images live in `assets/` in the repository. If they're ever missing, copy your backup `assets` folder into the project root. To download them again from scratch:

1. `python tools/download_assets.py tools/Dwarves_mod_links.txt` (downloads into `./assets` with temporary names)
2. `python tools/rename_assets.py` (renames them to match `game_data.json`)

Both scripts need only Python 3. The files are hosted on Steam and Dropbox, and the Steam workshop item has been removed, so the links may stop working. Keep a backup of `assets`.
