# Dwarves: Reclaim Your Kingdom

A digital version of *Dwarves: Reclaim Your Kingdom*, the co-op board game for 1–6 players by Pink Wizard Games (Ben Galea), built in Godot 4.

**Play it in your browser: https://ra314.github.io/dwarves-ryk/**

This is a personal fan project. The artwork and rules belong to Pink Wizard Games; if you enjoy it, buy the physical game.

## The game

Players share a 5×5 grid of tiles and start at the Hearth with a few dice. Each round, everyone rolls and, at the same time, spends dice on the actions printed on their own or neighbouring tiles: dig for resources, train warriors, explore face-down ruins, upgrade dice and claim titles. Then the enemies move, spawn from tunnels and the City Gate, and overrun crowded buildings. You win together by exploring every ruin, collapsing every tunnel and securing the City Gate before the turn track runs out.

The full rules as implemented, including rulings for gaps in the rulebook, are in [`docs/RULES.md`](docs/RULES.md).

## How to play

It's hot-seat: everyone shares one screen.

- **Pick a player** by clicking their name or one of their dice.
- **Select dice**, then **click a tile** for a menu of moves and actions. Two dice can be added together (three with the Workmaster title). Actions you can't take are greyed out with the reason.
- Actions that need a target (Axe Throwers, False Commands, Architect) ask you to click a tile afterwards.
- **Hover** over a tile or title card to see it full size, with each action's real cost for the acting player.
- Press **Done** when you've finished. The Enemy Phase plays out step by step once everyone is done (turn this off, or change its speed, in the right-hand column; Space or Esc skips it).
- **Undo** (Ctrl+Z) takes back the last action, whoever made it. Dice rolls and other reveals can't be undone unless "Unlimited undo" is on.
- **F11** toggles fullscreen.

## Saves and replays

- **Save / Load** in the top bar keep one saved game. In the browser it's stored in that browser only.
- Every game is **recorded automatically** as a replay.
- The **Files** window lets you download your save and load it on another device, and lists every replay with Watch, Download and Delete. "Open a replay from file…" watches one someone sent you.
- To share a replay by link, commit the `.dwreplay` file to the [`replays/`](replays) folder. Once the site rebuilds it opens at `https://ra314.github.io/dwarves-ryk/?replay=replays/<file>.dwreplay`.

## Running it locally

1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET).
2. Open `project.godot` in Godot and press Play, or run `godot` in this folder.

The tests use [GUT](https://github.com/bitwes/Gut), which is included:

```
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd
```

## Building the web version

Every push rebuilds and publishes the site with GitHub Actions ([`.github/workflows/pages.yml`](.github/workflows/pages.yml)), but only if all the tests pass. To build it yourself:

```
python3 tools/fetch_web_templates.py 4.3
godot --headless --export-release "Web" build/web/index.html
```

then serve `build/web` with any static file server, e.g. `python3 -m http.server -d build/web`.

## Project layout

| Path | What's there |
|---|---|
| `scripts/core/` | The rules engine: game state, commands, the Enemy Phase, undo and replay recording. No UI code. |
| `scripts/ui/` | The board, dice, menus, animations, replay viewer and Files window. |
| `data/game_data.json` | Every number and piece of card text: tiles, actions, titles, turn track, setup and rulings. |
| `docs/RULES.md` | The rules spec the engine follows. |
| `tests/` | Engine, UI and replay tests, including full random games checked for rule invariants. |
| `assets/` | Art from the Tabletop Simulator mod of the game. |

Notes for anyone working on the code, human or AI, are in [`CLAUDE.md`](CLAUDE.md). Plans and ideas are in [`docs/ROADMAP.md`](docs/ROADMAP.md).
