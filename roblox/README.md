# Jeux Roblox

Cinq jeux originaux dans les genres qui marchent le mieux sur Roblox. Chaque jeu
tient dans **un seul Script** : il construit toute la carte lui-même au lancement,
il n'y a rien à modéliser dans Studio.

| Jeu | Genre | Fichier Studio | Code |
| --- | --- | --- | --- |
| Néon Rush Obby | Obby (parcours) — 40 étapes, checkpoints, victoires | `places/Neon Rush Obby.rbxlx` | `src/neon_rush_obby.server.luau` |
| Force Légendaire | Simulateur de clics — haltères, familiers, renaissances, zones | `places/Force Legendaire Simulator.rbxlx` | `src/force_legendaire_simulator.server.luau` |
| Usine à Bonbons Tycoon | Tycoon — machines, tapis roulant, améliorations, renaissance | `places/Usine a Bonbons Tycoon.rbxlx` | `src/usine_a_bonbons_tycoon.server.luau` |
| Catastrophes en Folie | Survie par manches — lave, météores, pluie acide, tornade, sol électrique | `places/Catastrophes en Folie.rbxlx` | `src/catastrophes_en_folie.server.luau` |
| Jardin Enchanté | Jardinage — pousse hors ligne, mutations, pluie | `places/Jardin Enchante.rbxlx` | `src/jardin_enchante.server.luau` |

## Lancer un jeu

1. Télécharge le fichier `.rbxlx` du jeu et ouvre-le dans **Roblox Studio**
   (Fichier → Ouvrir depuis un fichier).
2. Appuie sur **Jouer** (F5).

Si le fichier ne s'ouvre pas : crée une place vide (modèle *Baseplate*), ajoute un
`Script` dans `ServerScriptService` et colle dedans le contenu du fichier `.luau`.

## Publier

1. Fichier → **Publier sur Roblox**.
2. Paramètres du jeu → Sécurité → active **l'accès des services API aux Studio**
   pour que la sauvegarde (DataStore) fonctionne aussi en test.
3. Paramètres du jeu → Places → nombre maximum de joueurs : **6** pour le tycoon,
   **8** pour le jardin (un terrain par joueur).

## Contenu payant (Robux)

Chaque jeu contient une boutique Robux (stands verts) déjà codée mais **désactivée**
tant que les ID valent 0.

| Jeu | Passes (achat unique) | Produits (rachetables) |
| --- | --- | --- |
| Néon Rush Obby | Vitesse turbo | Passer l'étape |
| Force Légendaire | Énergie ×2, Clic automatique | Sac de pièces |
| Usine à Bonbons Tycoon | Revenus ×2 | Valise d'argent |
| Catastrophes en Folie | VIP (pièces ×2) | 100 pièces |
| Jardin Enchanté | Engrais magique (pousse ×2) | Bourse de pièces |

Pour les activer :

1. Publie le jeu, puis va sur create.roblox.com → ton expérience → Monétisation.
2. Crée chaque **passe** et chaque **produit développeur**, fixe son prix en Robux.
3. Copie les ID dans `PASS_IDS` et `PRODUCT_IDS` (section « contenu payant » du
   script), puis relance `python3 roblox/build.py` ou modifie le script dans Studio.

À savoir :

- Les œufs du simulateur s'achètent avec des pièces, elles-mêmes achetables en
  Robux : c'est un tirage au sort payant au sens des règles Roblox, d'où
  l'affichage des chances sur le stand. Ne retire pas cet affichage.
- Convertir les Robux gagnés en argent réel (DevEx) est soumis aux conditions de
  Roblox (âge, seuil minimal de Robux gagnés, vérification d'identité) : vérifie
  les conditions en vigueur avant de compter dessus.

## Modifier

Les réglages (prix, nombre d'étapes, durées…) sont regroupés en haut de chaque
script, dans la section « réglages ». Après modification d'un `.luau`, régénère les
fichiers Studio :

```
python3 roblox/build.py
```

## État

Le code a été relu et sa structure vérifiée, mais il n'a **pas encore été lancé
dans Roblox Studio** : prévois une session de test de chaque jeu avant de publier.
