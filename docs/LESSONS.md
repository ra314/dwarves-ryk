# Lessons learned

Mistakes already made on this project, written down so they aren't repeated. Add an entry whenever something costs real time to track down.

## GDScript and Godot 4.3

- `:=` needs a value whose type is known when the script is parsed. For values coming out of Dictionaries or Arrays, declare the type yourself (`var n: int = d["n"]`).
- Don't name variables after built-in functions (`exp`, `min`, `max`, …): the local shadows the built-in and the warning is easy to miss.
- A `match` inside a multi-line lambda that is itself an argument to a call doesn't parse. Use a named method instead.
- Godot's JSON parser returns every number as a float. `GameData._ints` and `ReplayLog.decode` turn whole numbers back into ints; anything new that reads JSON needs the same, or the UI shows "1.0".
- `JSON.stringify` sorts keys, so never assume which key comes first on a line (see `ReplayLog.summary`).
- PopupMenu: separators take up item ids, so always set ids explicitly (`main._add_entry`). A PopupMenu hides itself after `id_pressed`, so a follow-up choice needs its own menu (`choice_menu`), opened with `call_deferred`.
- Scaling images down on import (the web build's size limits) changes their pixel sizes. Code that uses pixel coordinates must scale by the texture's actual size (`TrackView.source_rect`).
- The browser build has no system fonts. Stick to Latin letters and `· × — …` in UI text: no ▶ ✓ ☠ or arrow symbols.

## Testing

- GUT doesn't count a script error as a test failure. Read the output for `SCRIPT ERROR` and `Parse Error`, not just the pass count.
- To check that a new test really guards a fix, put the old logic back temporarily and watch the test fail. Stashing whole files isn't enough, because the test disappears too.
- UI tests must point `main.recorder.dir` and `main.settings_path` at scratch locations, or they write into the real user folder.

## Tooling

- Don't rename identifiers with a blind global search-and-replace: renaming `_board` to `board` turned `draw_board` into `drawboard`.
- `pkill -f <pattern>` kills its own shell if the pattern appears in that same command line.
- Playwright: register `page.on('filechooser')` before the click that opens the file chooser, or the event can be missed.
