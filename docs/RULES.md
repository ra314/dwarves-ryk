# Dwarves: Reclaim Your Kingdom — Rules Spec

Implementation spec for a personal Godot version. Sources: the rulebook PDF, the tiles and title cards, and the TTS mod layout. All numbers live in `game_data.json`; this file explains how they fit together.

Where the rulebook was unclear, the answer chosen is written into the rule and tagged **(R#)**; see [Rulings](#rulings). 

---

## 1. Goal

Co-op, 1–6 players, everyone wins or loses together.

**Win:** use *Secure the Gate (14+)* on the City Gate. Only allowed when:
- no Ruins tiles remain face-down, and
- no open Tunnels remain (all collapsed).

**Lose** (any one):
1. The turn marker reaches the last cell of the turn track.
2. Enemies would create a tunnel and 5 tunnels (open or collapsed) already exist.
3. Enemies create a tunnel on the Hearth.

---

## 2. Components

| Item | Count | Notes |
|---|---|---|
| Map tiles | 28 | 5 Tunnel, 1 Hearth, 2 Living Quarters, 2 Barracks, 3 Mine, 2 Aviary, 2 Watchtower, 4 Empty Halls, 3 Encampment, 2 Blacksmith, 1 Throne Room, 1 City Gate |
| Ruin stack | 18 | Every tile with a Ruins back: 1 LQ, 1 Barracks, 2 Mine, 2 Aviary, 2 Watchtower, 4 Empty Halls, 3 Encampment, 2 Blacksmith, 1 Throne Room |
| Title cards | 6 | Messenger, Master Miner, Master of the Guard, Workmaster, Master Smith, Regent |
| Player dice | 10 per colour | 3 d4, 4 d6, 3 d8 |
| Special dice | 2 | d10 (Workmaster), d12 (Regent) |
| Enemy die | 1 | d4, used for movement direction and spawn counts |
| Enemy tokens | 40 | Hard cap |
| Warrior tokens | 20 | Hard cap |
| Resource tokens | 60 | Only 10 per player go in the supply |
| Nobles | 6 | One per player colour |
| Turn track + marker | 1 | 32 cells, one-sided |

---

## 3. Setup

1. **Grid.** Build the 5×5 grid from `setup_grid.layout`: Tunnels in the NW and SE corners, City Gate in the NE corner, and the four starters face up in the centre-left 2×2 (Barracks, Mine / Hearth, Living Quarters). Shuffle the 18 ruin tiles and fill the other 18 spaces ruin side up.
2. **Nobles.** Each player picks a colour and places their Noble on the Hearth.
3. **Dice.** Each player's *active pool* is 2 d4, 1 d6, 1 d8. With 1–2 players, add 1 more d6. The rest of their dice go to their *reserve*.
4. **Resources.** Supply = 10 × players (solo: 20). Each player then takes 3 from the supply (solo: 5). **(R2)**
5. **Titles.** Put all six title cards in a shared area.
6. **Turn track.** Place the marker on the start cell for the player count: 1P and 2P → cell 0, 3P → 1, 4P → 2, 5P → 3, 6P → 4. **(R1)**

---

## 4. Turn structure

Each round has a Dwarf Phase then an Enemy Phase.

### 4.1 Dwarf Phase
1. **Revive.** Wounded Nobles who have already missed a Dwarf Phase return to the Hearth. If the Hearth has enemies on it, they stay out and try again next round.
2. **Roll.** Each player rolls every die in their active pool.
3. **Act.** All players act at the same time, in any order, interleaving freely. **(R9)** A player may:
   - spend dice on actions (see §5.1),
   - move (see §5.3),
   - pick up or drop off warriors while moving (see §5.5).

   The phase ends when every player has marked themselves done. Unspent dice are lost.

### 4.2 Enemy Phase
1. **Tunnels.** Every destructible tile with 6 or more enemies becomes a Tunnel (see §5.10).
2. **Move.** Roll the enemy die: 1 = N, 2 = E, 3 = S, 4 = W. Every enemy moves one tile that way. An enemy at the edge that can't move that way moves the opposite way instead.
3. **Spawn.** Place enemies on every spawn point (open Tunnels and the City Gate). Each spawn point gets the full number shown on the marker's current cell. **(R3)**
4. **Track.** Move the marker one cell forward. If it reaches the final cell, the players lose.

Players can't act during the Enemy Phase. **(R6)**

---

## 5. Core rules

### 5.1 Actions and dice
- An action shows a minimum, e.g. *Dig (4+)*. To use it, spend one unused die showing at least that value.
- Each die is spent once per round.
- You can use actions on your own tile or on an orthogonally adjacent tile, but not diagonally.
- If an action has a resource cost, pay it too. You can't take the action if you can't pay.
- A tile with any enemy on it is **blocked**: its actions and passives don't work. This includes Collapse Tunnel, and it also switches off Empty Halls' *Lost*, so an enemy on Empty Halls lets you walk out. **(R10)** The one exception is Watchtower's *Garrison*. **(R21)**

### 5.2 Worker assistance
- You may combine up to 2 dice and add their values to meet one action's minimum. The Workmaster title raises this to 3.
- Noble Combat (§5.7) and Regent's Bodyguard require a single die. Assistance isn't allowed there.
- Mine example: two dice showing 2 each add to 4, which meets Dig (4+) and gains 3 resources.

### 5.3 Movement
- Base movement is 1 tile per round, orthogonal only, and can happen at any point in your turn.
- Bonuses stack: +1 if you started the round on an unblocked Hearth, +1 with the Messenger title.
- Nobles can move onto face-down Ruins. **(R4)** The only action there is Expedition, which you can also use from an adjacent tile.
- Empty Halls: once on it, you can't leave until you use *Discover the Path (5+)* that same round. Doing so frees all of your remaining movement for the round. **(R11)** You must be standing on that Empty Halls to use it, and entering another Empty Halls makes you lost again. **(R24)**
- Master Miner: moving between any two Mines is free (it doesn't use movement), even if either Mine is blocked. **(R26)**

### 5.4 Resources
- You can hold any number of resources, but gains come from the shared supply.
- If the supply is empty, nobody can gain resources until some are spent.
- Spent resources go back to the supply.

### 5.5 Warriors
- Warriors sit on tiles. While moving, you can carry warriors up to a limit that depends on player count: 1P → 5, 2–3P → 4, 4–5P → 3, 6P → 2.
- Pick up or drop off anywhere along your path.
- Warriors never move on their own.

### 5.6 Combat (automatic, any time)
- Whenever an enemy and a warrior share a tile, both are removed. Pair them 1-for-1 until one side runs out. Leftover enemies stay and can still wound Nobles there. **(R5)**
- This triggers during either phase, including enemy movement, spawning and surges.

### 5.7 Noble combat
- Dwarf Phase only. Spend a **single** die showing 6 or more to remove one enemy on your tile or an adjacent tile. **(R6)**
- Use it before moving onto an occupied tile to avoid being wounded. You can't react during the Enemy Phase or during a surge.

### 5.8 Wounded
- If your Noble shares a tile with an enemy and no warrior is there to fight it, you are **wounded**.
- Exception: nobles can't be wounded on a Watchtower. Garrison is the one passive that keeps working while the tile is blocked. **(R21)**
- When wounded: remove your Noble from the board and move the turn marker forward 1 cell.
- You skip the next Dwarf Phase, then return at the following Revive step.
- Master of the Guard (*Tough*): the turn marker still moves forward, but your Noble stays on its tile and plays normally next round. The enemies that wounded you don't wound you again this round, but each new enemy that arrives (or that you move onto) wounds you again and moves the marker again. **(R7, R23)**

### 5.9 Expedition (exploring Ruins)
- The Ruins back has *Expedition (3+)*: pay 2 resources, then flip the tile.
- Roll the enemy die and spawn that many enemies on the newly revealed tile.
- Encampment instead spawns exactly 6 and you don't roll. This applies even with the Messenger title. **(R8)**
- Messenger title: expeditions cost 0 resources and spawn exactly 1 enemy (except on an Encampment).

### 5.10 Tunnels
- In the Enemy Phase, a destructible tile with 6 or more enemies becomes a Tunnel. The building is gone for good, and the enemies stay on the new Tunnel. **(R12)**
- Indestructible: City Gate, Tunnels (open or collapsed) and face-down Ruins.
- Open Tunnels are spawn points. *Collapse the Tunnel (12+)* flips it, and a collapsed tunnel no longer spawns.
- A game has at most 5 tunnels. Needing a sixth loses the game. So does a tunnel forming on the Hearth.

### 5.11 Enemy surge
- If enemies need to spawn and the 40-token pool is empty, every enemy on the map immediately moves: roll the enemy die and move them all (§4.2 step 2).
- The surge replaces the spawn: enemies that couldn't be placed are not placed afterwards. **(R13)**
- This can happen during the Dwarf Phase, e.g. from an expedition. Pause all player actions, resolve the surge, then carry on.

### 5.12 Upgrading and recruiting dice
- *Promote Worker* (Blacksmith): pay 3 resources and swap a die for the next size up (d4→d6, d6→d8). The old die goes to your reserve. The new die comes from your reserve and joins your active pool from the **next** round. You need a die of the higher size in your reserve. **(R14)**
- *Recruit Worker* (Living Quarters): pay 2 resources and move a d4 from your reserve to your active pool. It can be used from the **next** round. **(R20)**

---

## 6. Undo

Players can undo their actions. A settings toggle, **Unlimited undo**, controls how far back.

**Normal mode (default):** you can undo any action back to the most recent *reveal*. A reveal is anything that shows new random or hidden information:
- the Dwarf Phase roll,
- an Expedition (flips a tile and may roll the enemy die),
- an Enemy Surge,
- the whole Enemy Phase.

Everything else can be undone: moving, carrying warriors, Dig, Train Warrior, Recruit Worker, Promote Worker, Collapse Tunnel, Axe Throwers, False Commands, Architect, Noble Combat, claiming titles, and marking yourself done.

**Unlimited mode:** undo can go back past reveals, as far as the start of the game. Redoing an action after undoing past a roll rolls again with fresh randomness. **(R19)**

History is shared by all players: undo reverses the most recent action, whoever took it, and the screen shows whose action it was. **(R18)**

Implementation note: the full game state is small, so the simplest approach is to save a copy of it before each action and restore it on undo. Mark copies taken just before a reveal as checkpoints; in normal mode, undo stops at the most recent checkpoint. Keep the random number generator outside the saved copies, so undoing never rewinds it (R19).

---

## 7. Tile reference

`min` is the dice needed; `cost` is resources.

| Tile | Action / passive | Min | Cost | Effect |
|---|---|---|---|---|
| **Ruins** (back) | Expedition | 3 | 2 | Flip; spawn d4 enemies here |
| **Hearth** | Motivated (passive) | – | – | +1 movement if you started the round here |
| **Mine** | Dig | 1 | – | +1 resource |
| | Dig | 4 | – | +3 resources |
| | Master Miner | 12 | – | Gain the Master Miner title |
| **Living Quarters** | Recruit Worker | 4 | 2 | Move a d4 from reserve to active pool |
| | Workmaster | 14 | – | Gain the Workmaster title |
| **Barracks** | Train Warrior | 3 | 3 | Place 1 warrior on **your** tile |
| | Master of the Guard | 14 | – | Gain the Master of the Guard title |
| **City Gate** | Endless Tide (passive) | – | – | Spawn point |
| | Secure the Gate | 14 | – | Win (if all ruins explored and no open tunnels) |
| **Tunnel** | More Enemies! (passive) | – | – | Spawn point |
| | Collapse the Tunnel | 12 | – | Flip to Collapsed Tunnel (no longer spawns) |
| **Empty Halls** | Lost (passive) | – | – | Can't move off |
| | Discover the Path | 5 | – | Free all remaining movement this round |
| **Watchtower** | Garrison (passive) | – | – | Nobles can't be wounded here |
| | Axe Throwers | 4 | – | Remove 1 enemy on an adjacent tile |
| **Blacksmith** | Promote Worker | 5 | 3 | Upgrade a die: d4→d6 or d6→d8 |
| | Master Smith | 13 | – | Gain the Master Smith title |
| **Encampment** | More and More! (on flip) | – | – | +6 enemies here, no roll |
| | False Commands | 3 | – | Move 1 enemy anywhere up to 2 tiles |
| **Throne Room** | Coronation | 14 | – | Gain the Regent title |
| **Aviary** | Reinforcements | 13 | 3 | +3 warriors on the Hearth |
| | Messenger | 10 | – | Gain the Messenger title |

The printed Mine tile says "Expert Miner" and the Living Quarters says "trait". Both are corrected here and in `game_data.json` to match the title cards. **(R17)**

## 8. Title reference

Each player holds at most 1 title (solo: 2). Gaining another returns your current one to the shared area, along with any die it gave you. **(R15)** In solo, at the 2-title limit, you choose which one to return. **(R25)** A title's die (d10, d12) joins your active pool from the **next** round. **(R22)** You can take a title another player holds only if they agree.

| Title | From | Abilities |
|---|---|---|
| Messenger | Aviary | Expeditions cost 0 and spawn exactly 1 enemy; +1 movement |
| Master Miner | Mine | +3 to each die used at a Mine; move between Mines for free |
| Master of the Guard | Barracks | Tough: wounds don't skip a round or send you to the Hearth. Personal Guard (4+): remove 1 enemy on your tile or an adjacent tile |
| Workmaster | Living Quarters | Worker assistance limit 3; gain the d10 |
| Master Smith | Blacksmith | Promote Worker is 1+ for you; Architect (6+): swap two adjacent tiles, tokens and nobles stay put |
| Regent | Throne Room | Gain the d12; Bodyguard (7+, single die): remove 2 enemies on your tile or an adjacent tile **(R16)** |

---

## Rulings

Decisions made where the rulebook is unclear. The matching flags are in `game_data.json` under `rule_decisions`.

| # | Ruling |
|---|---|
| R1 | The turn track is one-sided (true of the physical game too). Solo starts on cell 0, like 2P. |
| R2 | Each player's starting resources come out of the supply. |
| R3 | Every spawn point gets the full turn-track number of enemies. |
| R4 | Nobles can stand on face-down Ruins. |
| R5 | Warriors and enemies cancel 1-for-1; leftovers remain. |
| R6 | Noble Combat is Dwarf Phase only; no reacting during the Enemy Phase or a surge. |
| R7 | *Tough* still moves the turn marker forward; the Noble stays on its tile. |
| R8 | Encampment's 6 enemies override Messenger's "spawn 1". |
| R9 | All players act concurrently during the Dwarf Phase. |
| R10 | Blocked tiles lose their passives, including Empty Halls' *Lost*. |
| R11 | *Discover the Path* frees all remaining movement for the round. |
| R12 | Enemies stay on a tile that becomes a Tunnel. |
| R13 | A surge replaces the spawn that triggered it. |
| R14 | A promoted die is usable from next round. |
| R15 | A title's die goes back with the title card. |
| R16 | Bodyguard's range is your tile or an adjacent tile. |
| R17 | Mine and Living Quarters wording corrected to match the title cards. |
| R18 | Undo history is shared; undo reverses the most recent action by anyone. |
| R19 | In unlimited-undo mode, redoing an action after undoing past a roll gives a fresh random result. |
| R20 | A recruited d4 is usable from next round. |
| R21 | Garrison works even while enemies block the Watchtower (otherwise it could never apply). |
| R22 | A title's die (d10, d12) is usable from next round. |
| R23 | *Tough* doesn't stop new enemies wounding you; it only stops the return to the Hearth and the missed round. |
| R24 | *Discover the Path* only works while standing on that Empty Halls. |
| R25 | Solo: at the 2-title limit you choose which title to return. |
| R26 | The minecart works even if either Mine is blocked. |
