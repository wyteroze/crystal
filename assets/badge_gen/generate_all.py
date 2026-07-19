#!/usr/bin/env python3

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from make_badge import build_svg

def get_latest_tag(repo: Path) -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "describe", "--tags", "--abbrev=0"],
            capture_output=True, text=True, check=True,
        )
        return out.stdout.strip()
    except subprocess.CalledProcessError:
        return "v0.0.0-dev"


def get_zig_version(repo: Path) -> str:
    zon_path = repo / "build.zig.zon"
    text = zon_path.read_text(encoding="utf-8")
    match = re.search(r'\.minimum_zig_version\s*=\s*"([^"]+)"', text)
    if not match:
        raise ValueError("Could not find .minimum_zig_version in build.zig.zon")
    return match.group(1)


def write_badge(text, out_path, bg, fg="TEXT"):
    svg = build_svg(text, label_color=fg, bg_color=bg)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(svg, encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    badges_dir = repo / "assets" / "badges"

    version = get_latest_tag(repo)
    zig_version = get_zig_version(repo)

    # Danger while pre-1.0 because anything can change at any moment
    is_pre_1_0 = version.lstrip("v").split(".")[0] == "0"
    version_bg = "DANGER" if is_pre_1_0 else "SUCCESS"

    write_badge(version, badges_dir / "version.svg", bg=version_bg)
    write_badge(f"Zig {zig_version}", badges_dir / "zig.svg", bg="WARN")


if __name__ == "__main__":
    main()
