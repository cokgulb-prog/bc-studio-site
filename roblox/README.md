# Jeux Roblox

Huit jeux originaux dans les genres qui marchent le mieux sur Roblox. Chaque jeu
tient dans **un seul Script** : il construit toute la carte lui-même au lancement,
il n'y a rien à modéliser dans Studio.

| Jeu | Genre | Ce qui le fait durer |
| --- | --- | --- |
| Néon Rush Obby | Parcours | 200 étapes, 6 types d'obstacles, difficulté progressive |
| Force Légendaire | Simulateur de clics | 40 haltères, 10 familiers, 8 zones, renaissances sans limite, ascensions |
| Usine à Bonbons Tycoon | Tycoon | renaissances sans limite : revenus ×2 mais prix ×2,5 à chaque fois |
| Catastrophes en Folie | Survie par manches | 7 catastrophes, 2 améliorations à 20 niveaux, 7 rangs jusqu'à 1 500 victoires |
| Jardin Enchanté | Jardinage | 16 graines débloquées par niveau, pousse hors ligne, mutations |
| Mine des Profondeurs | Minage | 300 couches, 11 minerais, 30 pioches, 20 sacs, renaissances |
| Lames & Légendes | Combat | 20 zones avec boss, 50 épées, niveaux, renaissances |
| Pêche Paradis | Pêche et collection | 6 étangs, 36 espèces (mythiques à 1/1000), 25 cannes, prestiges |

Tous les jeux sauf l'obby ont une **récompense quotidienne** (série de 7 jours) pour
faire revenir les joueurs.

## Dossiers

- `places/` : un fichier `.rbxlx` par jeu, à ouvrir dans Roblox Studio.
- `scripts/` : le script complet de chaque jeu, à copier-coller si besoin.
- `src/` : les sources. Les trois derniers jeux (`.game.luau`) partagent le socle
  `_base.luau`, ajouté automatiquement par `build.py`.

## Lancer un jeu

1. Télécharge le fichier `.rbxlx` du jeu et ouvre-le dans **Roblox Studio**
   (Fichier → Ouvrir depuis un fichier).
2. Appuie sur **Jouer** (F5).

Si le fichier ne s'ouvre pas : crée une place vide (modèle *Baseplate*), ajoute un
`Script` dans `ServerScriptService` et colle dedans le fichier du dossier `scripts/`.

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
| Mine des Profondeurs | Minerais ×2, Sac sans fond | Coffre de pièces |
| Lames & Légendes | Dégâts ×2, Attaque automatique | Bourse d'or |
| Pêche Paradis | Chance ×2, Pêche automatique | Trésor englouti |

Pour les activer :

1. Publie le jeu, puis va sur create.roblox.com → ton expérience → Monétisation.
2. Crée chaque **passe** et chaque **produit développeur**, fixe son prix en Robux.
3. Copie les ID dans `PASS_IDS` et `PRODUCT_IDS` (section « contenu payant » du
   script), puis relance `python3 roblox/build.py` ou modifie le script dans Studio.

À savoir :

- Les œufs du simulateur s'achètent avec des pièces, elles-mêmes achetables en
  Robux : c'est un tirage au sort payant au sens des règles Roblox, d'où
  l'affichage des chances sur le stand. Même logique pour la pêche (panneau des
  chances à côté de chaque étang). Ne retire pas ces affichages.
- Convertir les Robux gagnés en argent réel (DevEx) est soumis aux conditions de
  Roblox (âge, seuil minimal de Robux gagnés, vérification d'identité) : vérifie
  les conditions en vigueur avant de compter dessus.

## Modifier

Les réglages (prix, nombre d'étapes, durées, courbes de progression…) sont
regroupés en haut de chaque source, dans la section « réglages ». Après
modification d'un fichier de `src/`, régénère `places/` et `scripts/` :

```
python3 roblox/build.py
```

## État

- Le code a été relu et sa structure vérifiée, mais il n'a **pas encore été lancé
  dans Roblox Studio** : prévois une session de test de chaque jeu avant de publier.
- La durée de vie repose sur des courbes de prix exponentielles et des prestiges
  sans plafond. Elle n'a pas été mesurée en jeu : l'équilibrage (trop lent, trop
  rapide) se règle en jouant, avec les nombres de la section « réglages ».
