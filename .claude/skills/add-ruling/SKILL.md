---
name: add-ruling
description: Record a new rules decision (R#) made by the owner. Use when the owner decides how a rule should work where the rulebook is silent or ambiguous, or changes an existing ruling.
---

# Adding a ruling

A ruling is only complete when every one of these places agrees:

1. **`docs/RULES.md`**
   - Change the rule text in its section and tag it **(R#)**, using the next free number.
   - Add a row to the Rulings table at the end.
2. **`data/game_data.json`**: add a flag under `rule_decisions`, named for what the rule allows (e.g. `pending_dice_can_be_promoted`).
3. **`tests/test_setup.gd`**: add the flag to `test_every_ruling_has_a_flag`.
4. **The engine**: implement it in `scripts/core/rules.gd` (or in the command), with a `# R#` comment where the ruling applies.
5. **Tests**
   - Write at least one test named `test_r#_...` in the matching `tests/test_*.gd`.
   - Check that it fails when the old logic is put back temporarily.
6. **`random_player.gd`**: if the ruling makes new moves legal, have it generate them so the fuzz test covers them.
7. **UI text**: menus and hovers come from `Rules.action_terms`. Check that they still describe the rule correctly.
8. Update the rulings count (R1–R#) in `docs/ROADMAP.md`.

Never make up a ruling. If neither the spec nor the rulebook covers a case, ask the owner first.
