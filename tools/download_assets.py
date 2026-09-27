"""Download every file referenced by the Dwarves: Reclaim a Kingdom TTS mod.

Usage:  python download_assets.py Dwarves_mod_links.txt
Needs only Python 3 (no extra packages). Files land in ./assets/<group>/.
"""
import os
import re
import sys
import time
import urllib.request

EXT_BY_MAGIC = [
    (b"\x89PNG", ".png"),
    (b"\xff\xd8\xff", ".jpg"),
    (b"GIF8", ".gif"),
    (b"%PDF", ".pdf"),
    (b"RIFF", ".webp"),
]
FOLDERS = {
    "Board & table": "board",
    "Rulebook": "rulebook",
    "Card sheets (fronts)": "cards",
    "Card backs": "card_backs",
    "Tokens": "tokens",
    "3D models & textures": "models",
}


def slug(text):
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


def guess_ext(data, url):
    for magic, ext in EXT_BY_MAGIC:
        if data.startswith(magic):
            return ext
    m = re.search(r"\.(obj|png|jpg|jpeg)(\?|$)", url)
    if m:
        return "." + m.group(1)
    if data.lstrip()[:2] in (b"v ", b"# ", b"o ", b"mt", b"g "):
        return ".obj"
    return ".bin"


def main(links_path):
    ok, failed = 0, []
    with open(links_path, encoding="utf-8") as f:
        rows = [line.rstrip("\n").split("\t") for line in f if line.strip()]
    for group, label, url in rows:
        folder = os.path.join("assets", FOLDERS.get(group, slug(group)))
        os.makedirs(folder, exist_ok=True)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            path = os.path.join(folder, slug(label) + guess_ext(data, url))
            with open(path, "wb") as out:
                out.write(data)
            print(f"ok    {path}  ({len(data) // 1024} KB)")
            ok += 1
        except Exception as e:  # keep going if one link is dead
            print(f"FAIL  {label}: {e}")
            failed.append((label, url))
        time.sleep(0.3)
    print(f"\n{ok} downloaded, {len(failed)} failed")
    for label, url in failed:
        print(f"  {label}: {url}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Dwarves_mod_links.txt")
