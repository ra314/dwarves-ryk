"""Install Godot's web export templates without downloading all ~1 GB of them.

The official template pack is a zip. This reads its table of contents with
HTTP Range requests and fetches only the web (no-threads) templates.

Usage: python tools/fetch_web_templates.py 4.3
Installs into ~/.local/share/godot/export_templates/<version>.stable/
Needs only Python 3.
"""
import io
import os
import sys
import urllib.request
import zipfile

WANTED = ("version.txt", "web_nothreads_release.zip", "web_nothreads_debug.zip")


class RangeFile(io.RawIOBase):
    """A read-only, seekable file backed by HTTP Range requests."""

    def __init__(self, url):
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD")) as r:
            self.url = r.geturl()  # follow GitHub's redirect once
            self.size = int(r.headers["Content-Length"])
        self.pos = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        self.pos = {0: offset, 1: self.pos + offset, 2: self.size + offset}[whence]
        return self.pos

    def readinto(self, buf):
        n = min(len(buf), self.size - self.pos)
        if n <= 0:
            return 0
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{self.pos + n - 1}"})
        with urllib.request.urlopen(req) as r:
            data = r.read()
        buf[: len(data)] = data
        self.pos += len(data)
        return len(data)


def main(version):
    url = (f"https://github.com/godotengine/godot/releases/download/{version}-stable/"
           f"Godot_v{version}-stable_export_templates.tpz")
    dest = os.path.expanduser(f"~/.local/share/godot/export_templates/{version}.stable")
    os.makedirs(dest, exist_ok=True)
    pack = zipfile.ZipFile(io.BufferedReader(RangeFile(url), buffer_size=1 << 20))
    for info in pack.infolist():
        name = info.filename.split("/")[-1]
        if name in WANTED:
            with pack.open(info) as src, open(os.path.join(dest, name), "wb") as out:
                out.write(src.read())
            print(f"installed {name} ({info.file_size // 1024} KB)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "4.3")
