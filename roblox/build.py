#!/usr/bin/env python3
"""Génère un fichier .rbxlx (ouvrable dans Roblox Studio) pour chaque jeu de src/.

Usage : python3 roblox/build.py
Chaque place contient uniquement le Script du jeu dans ServerScriptService :
le script construit lui-même toute la carte au lancement.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
OUT = ROOT / "places"

GAMES = {
    "neon_rush_obby": "Neon Rush Obby",
    "force_legendaire_simulator": "Force Legendaire Simulator",
    "usine_a_bonbons_tycoon": "Usine a Bonbons Tycoon",
    "catastrophes_en_folie": "Catastrophes en Folie",
    "jardin_enchante": "Jardin Enchante",
}

TEMPLATE = """<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
	<Item class="ServerScriptService" referent="RBX0">
		<Properties>
			<string name="Name">ServerScriptService</string>
		</Properties>
		<Item class="Script" referent="RBX1">
			<Properties>
				<string name="Name">Jeu</string>
				<bool name="Disabled">false</bool>
				<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>
			</Properties>
		</Item>
	</Item>
</roblox>
"""


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for stem, title in GAMES.items():
        source = (SRC / f"{stem}.server.luau").read_text(encoding="utf-8")
        if "]]>" in source:
            raise SystemExit(f"{stem}: la séquence ]]> est interdite dans le code")
        target = OUT / f"{title}.rbxlx"
        target.write_text(TEMPLATE.replace("{source}", source), encoding="utf-8")
        print(f"OK  {target.relative_to(ROOT.parent)}")


if __name__ == "__main__":
    main()
