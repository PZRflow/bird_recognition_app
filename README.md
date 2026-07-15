# ZamZam — Shazam for Malaysian Birds 🇲🇾🦅

ZamZam est une application mobile Flutter conçue pour fonctionner **100% hors-ligne** (adaptée pour le travail de terrain dans les forêts tropicales malaisiennes), permettant d'identifier instantanément les espèces d'oiseaux à partir d'enregistrements audio.

L'intelligence de l'application repose sur un **Ensemble de réseaux de neurones profonds Double Sigmoid (MynaNet + Compact CNN)** entraînés sur les données Xeno-Canto.

---

## 🚀 Guide de Démarrage Rapide

### Prérequis
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `>=3.0.0`)
* Un émulateur Android ou un appareil physique configuré pour le débogage USB.

### Installation et Lancement
1. Clonez ce dépôt sur votre machine :
   ```bash
   git clone https://github.com/PZRflow/bird_recognition_app.git
   cd bird_recognition_app
   ```
2. Installez les dépendances du projet Flutter :
   ```bash
   flutter pub get
   ```
3. Exécutez l'application en mode debug :
   ```bash
   flutter run
   ```
4. Pour compiler l'APK finale distribuable :
   ```bash
   flutter build apk --debug
   ```

---

## 🧠 Pipeline MLOps & Entraînement (Dossier `/tools`)

Le projet contient un pipeline complet d'apprentissage automatique dans le dossier `tools/` pour réentraîner les modèles localement.

### Configuration Locale
1. Installez Python 3.10+ et créez un environnement virtuel :
   ```bash
   cd tools
   python -m venv .venv
   source .venv/bin/activate  # Sur Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```
2. **Entraîner les modèles** :
   * Pour le modèle principal MynaNet : `python train_mynanet.py`
   * Pour le modèle complémentaire Compact CNN : `python train_local.py`
3. **Exporter au format TFLite pour Flutter** :
   * `python export_mynanet_to_flutter.py`
   * `python export_to_flutter.py`
   * Les fichiers `.tflite` et métadonnées générés seront automatiquement copiés dans le dossier `assets/model/` de l'application.

---

## 🎨 Caractéristiques & UI
* **Ensemble Double Sigmoid** : Utilisation conjointe de MynaNet (64x300) et du Compact CNN (128x128) avec calcul de confiance multi-label et TTA (Test-Time Augmentation) par fenêtre glissante.
* **Visualiseur d'ondes audio** : Une onde sinusoïdale dynamique (`SoundWaveVisualizer` sous forme de CustomPainter) s'anime en temps réel lors de l'enregistrement.
* **Base de données de profils d'espèces** : Fiche descriptive de chaque oiseau avec des photos HD récupérées dynamiquement de Wikimedia Commons et embarquées localement.
* **Historique des détections** : Stockage local persistant SQLite (`sqflite`) avec horodatage pour enregistrer vos observations.
* **Localisation multilingue** : Support complet du Français, de l'Anglais et du Malais.

