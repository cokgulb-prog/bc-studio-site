#!/usr/bin/env python3
"""Génère un fichier .rbxlx (ouvrable dans Roblox Studio) pour chaque jeu de src/.

Usage : python3 roblox/build.py
Chaque place contient uniquement le Script du jeu dans ServerScriptService :
le script construit lui-même toute la carte au lancement. Le même script est
aussi écrit dans scripts/ pour pouvoir le copier-coller dans Studio.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
OUT = ROOT / "places"  # fichiers à ouvrir dans Roblox Studio
SCRIPTS = ROOT / "scripts"  # script complet de chaque jeu, à copier-coller si besoin

GAMES = {  # fichier source -> nom du jeu
    "neon_rush_obby.server.luau": "Neon Rush Obby",
    "force_legendaire_simulator.server.luau": "Force Legendaire Simulator",
    "usine_a_bonbons_tycoon.server.luau": "Usine a Bonbons Tycoon",
    "catastrophes_en_folie.server.luau": "Catastrophes en Folie",
    "jardin_enchante.server.luau": "Jardin Enchante",
    # les fichiers .game.luau sont précédés du socle commun _base.luau
    "mine_des_profondeurs.game.luau": "Mine des Profondeurs",
    "lames_et_legendes.game.luau": "Lames et Legendes",
    "peche_paradis.game.luau": "Peche Paradis",
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
    SCRIPTS.mkdir(exist_ok=True)
    base = (SRC / "_base.luau").read_text(encoding="utf-8")
    for filename, title in GAMES.items():
        source = (SRC / filename).read_text(encoding="utf-8")
        if filename.endswith(".game.luau"):
            source = base + source
        if "]]>" in source:
            raise SystemExit(f"{filename}: la séquence ]]> est interdite dans le code")
        (SCRIPTS / f"{title}.luau").write_text(source, encoding="utf-8")
        target = OUT / f"{title}.rbxlx"
        target.write_text(TEMPLATE.replace("{source}", source), encoding="utf-8")
        print(f"OK  {target.relative_to(ROOT.parent)}")


if __name__ == "__main__":
    main()
