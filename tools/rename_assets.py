"""Rename the downloaded Dwarves assets by what they are.

Run from the folder that contains 'assets':  python rename_assets.py
Moves files into assets/tiles, assets/titles, assets/components, assets/tokens,
assets/models and removes the old empty folders. Safe to run twice.
"""
import os

RENAMES = {
    "cards/card_sheet_1.jpg": "tiles/city_gate.jpg",
    "card_backs/card_back_1.jpg": "tiles/city_gate_secured.jpg",
    "cards/card_sheet_2.jpg": "components/enemy_movement.jpg",
    "card_backs/card_back_2.jpg": "components/enemy_movement_back.jpg",
    "cards/card_sheet_3.jpg": "tiles/barracks.jpg",
    "cards/card_sheet_4.jpg": "tiles/hearth.jpg",
    "cards/card_sheet_5.jpg": "tiles/living_quarters.jpg",
    "cards/card_sheet_6.jpg": "tiles/mine.jpg",
    "card_backs/card_back_3.png": "tiles/starter_back.png",
    "cards/card_sheet_7.jpg": "tiles/tunnel.jpg",
    "card_backs/card_back_4.jpg": "tiles/collapsed_tunnel.jpg",
    "cards/card_sheet_8.jpg": "components/turn_track.jpg",
    "card_backs/card_back_5.jpg": "components/turn_track_back.jpg",
    "cards/card_sheet_9.jpg": "tiles/empty_halls.jpg",
    "cards/card_sheet_10.jpg": "tiles/watchtower.jpg",
    "cards/card_sheet_11.jpg": "tiles/blacksmith.jpg",
    "cards/card_sheet_12.jpg": "tiles/encampment.jpg",
    "cards/card_sheet_13.jpg": "tiles/throne_room.jpg",
    "cards/card_sheet_14.jpg": "tiles/aviary.jpg",
    "card_backs/card_back_6.jpg": "tiles/ruins.jpg",
    "cards/messenger_card_1.png": "titles/messenger.png",
    "cards/messenger_card_2.png": "titles/master_miner.png",
    "cards/messenger_card_3.png": "titles/master_of_the_guard.png",
    "cards/messenger_card_4.png": "titles/workmaster.png",
    "cards/messenger_card_5.png": "titles/master_smith.png",
    "cards/messenger_card_6.png": "titles/regent.png",
    "card_backs/messenger_back.png": "titles/title_back.png",
    "board/main_board_front.png": "components/grid_base.png",
    "board/main_board_back.png": "components/grid_base_back.png",
    "board/table_surface.png": "components/table_surface.png",
    "tokens/enemy.png": "tokens/enemy.png",
    "tokens/warrior_token.png": "tokens/warrior.png",
    "tokens/turn_marker.png": "tokens/turn_marker.png",
    "rulebook/rulebook_pdf.pdf": "rulebook.pdf",
    "models/bag_texture.png": "models/bag_texture.png",
    "models/d6_tex_black_figures_png.png": "models/d6_tex_black_figures.png",
    "models/bag_model_obj.obj": "models/bag.obj",
    "models/d4_obj.obj": "models/d4.obj",
    "models/d4_tex_black_figures_png.png": "models/d4_tex_black_figures.png",
    "models/d6_collider_obj.obj": "models/d6_collider.obj",
    "models/d8_collider_obj.obj": "models/d8_collider.obj",
    "models/d4_collider_obj.obj": "models/d4_collider.obj",
    "models/d6_obj.obj": "models/d6.obj",
    "models/d8_obj.obj": "models/d8.obj",
    "models/d8_tex_black_figures_png.png": "models/d8_tex_black_figures.png"
}

moved = 0
for old, new in RENAMES.items():
    src, dst = os.path.join("assets", old), os.path.join("assets", new)
    if os.path.exists(src) and src != dst:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        os.replace(src, dst)
        moved += 1
for folder in ("cards", "card_backs", "board", "rulebook"):
    path = os.path.join("assets", folder)
    if os.path.isdir(path) and not os.listdir(path):
        os.rmdir(path)
print(f"Renamed {moved} files.")
