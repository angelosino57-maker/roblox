#!/usr/bin/env python3
"""Erzeugt manifest.json: welche lokale Datei als welches Skript in Studio landet.

Ersetzt Rojo: Studio holt sich die Dateien per HttpService vom lokalen Server
(python3 -m http.server 34999) und legt sie anhand dieses Manifests an.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# lokaler Ordner -> Instanz-Pfad in Studio
MAPPING = {
    "src/shared": "ReplicatedStorage.Shared",
    "src/server": "ServerScriptService.Server",
    "src/vendor": "ServerScriptService.Vendor",
    "src/client": "StarterPlayer.StarterPlayerScripts.Client",
    "tests": "ServerStorage.Tests",
}


def entry(path: Path, base: Path, target: str) -> dict:
    rel = path.relative_to(base)
    name = rel.name
    if name.endswith(".server.luau"):
        class_name, name = "Script", name[: -len(".server.luau")]
    elif name.endswith(".client.luau"):
        class_name, name = "LocalScript", name[: -len(".client.luau")]
    else:
        class_name, name = "ModuleScript", name[: -len(".luau")]
    parent = ".".join([target, *rel.parent.parts]) if rel.parent.parts else target
    return {
        "file": path.relative_to(ROOT).as_posix(),
        "parent": parent,
        "name": name,
        "className": class_name,
    }


def main() -> None:
    entries = []
    for folder, target in MAPPING.items():
        base = ROOT / folder
        for path in sorted(base.rglob("*.luau")):
            entries.append(entry(path, base, target))
    manifest = {"roots": list(MAPPING.values()), "scripts": entries}
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
    print(f"{len(entries)} Skripte im Manifest")


if __name__ == "__main__":
    main()
