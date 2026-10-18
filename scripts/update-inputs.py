#!/usr/bin/env python3
"""Follow the stable release linked by NixOS, then update both lock nodes."""

import re
import subprocess
import urllib.request
from pathlib import Path


def stable_branch(page):
    releases = re.findall(
        r'https://channels\.nixos\.org/nixos-(\d{2}\.\d{2})/latest-nixos-', page
    )
    if not releases:
        raise ValueError("No stable release found on the NixOS download page")
    return "nixos-" + max(releases)


def update():
    request = urllib.request.Request(
        "https://nixos.org/download", headers={"User-Agent": "llama-nix-bin"}
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        branch = stable_branch(response.read().decode("utf-8"))

    flake = Path("flake.nix")
    content, count = re.subn(
        r'(nixpkgs-stable\.url = "github:NixOS/nixpkgs/)nixos-\d{2}\.\d{2}(";)',
        rf"\g<1>{branch}\2",
        flake.read_text(),
    )
    if count != 1:
        raise ValueError("Expected exactly one stable input in flake.nix")
    flake.write_text(content)
    subprocess.run(["nix", "flake", "update"], check=True)


if __name__ == "__main__":
    update()
