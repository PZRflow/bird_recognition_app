# ZamZam — Shazam for Malaysian Birds 🇲🇾🦅

ZamZam est une application mobile Flutter d'élite conçue pour fonctionner **100% hors-ligne** (adaptée pour le travail de terrain dans les forêts tropicales malaisiennes), permettant d'identifier instantanément les espèces d'oiseaux à partir d'enregistrements audio au micro ou d'importation de fichiers (MP3, WAV, FLAC, M4A, OGG).

L'intelligence de l'application repose sur un **Quad-Ensemble de réseaux de neurones profonds (MynaNet + Compact CNN + EfficientNet-B0 + ResNet34-Lite)** fusionnés avec un score record historique de **`90.57%`** de précision sur 27 espèces d'oiseaux de Malaisie.

---

## 🏆 Performances du Modèle Quad-Ensemble (27 Espèces, 2 322 Fichiers de Validation)

| Modèle / Architecture | Entrée Spectrogramme | Précision Solo / Fusion | Rôle dans l'Ensemble |
| :--- | :---: | :---: | :--- |
| **1. MynaNet** (MobileNet-SE) | $64 \times 300$ PCEN | **84,32%** | Résolution temporelle fine (capter les notes courtes) |
| **2. Compact CNN** (4-Block Swish) | $128 \times 128$ PCEN | **85,14%** | Représentation spectro-temporelle équilibrée |
| **3. EfficientNet-B0 Lite** | $128 \times 128$ PCEN | **82,17%** | Extracteur de caractéristiques convolutives profondes |
| **4. ResNet34-Lite** | $128 \times 128$ PCEN | **84,57%** | Bloc résiduel à connexions raccourcies |
| 👑 **QUAD-ENSEMBLE FUSION** | **Fusion Pondérée** | **`90,57%`** | **Record Historique Absolue du Projet** |

$$\text{Prédiction Finale} = 0,30 \cdot P_{\text{Myna}} + 0,35 \cdot P_{\text{Compact}} + 0,15 \cdot P_{\text{EffNet}} + 0,20 \cdot P_{\text{ResNet}}$$

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

## 🧠 Pipeline MLOps & Signal Processing (Dossier `/tools`)

1. **Prétraitement Audio & Filtrage DSP** :
   * Normalisation PCM 16 kHz Mono.
   * Filtre Passe-Bande Butterworth 2nd ordre ($300\text{ Hz} - 8000\text{ Hz}$) pour éliminer le vent et le bruit urbain sous 300 Hz.
   * Multi-segmentation RMS dynamique : découpage en segments de 3,0s axés sur les pics d'énergie acoustique du chant.
2. **Normalisation de l'Énergie par Canal (PCEN)** :
   * Remplacement du Log-Mel classique par le PCEN pour une insensibilité aux variations de distance et de gain du microphone.

---

## 🎨 Caractéristiques & UI Flutter
* **Curseur de Seuil Dynamique ("Oiseau Inconnu")** : Curseur interactif dans l'application (30% à 80%) permettant de basculer les détections incertaines en "Oiseau Inconnu".
* **Support Multi-Format (FFmpegKit)** : Importation universelle de fichiers audio (`.mp3`, `.wav`, `.flac`, `.m4a`, `.ogg`).
* **Visualiseur d'ondes audio** : Animation temps réel lors de l'enregistrement micro.
* **Profils des 27 Espèces** : Noms vernaculaires en Anglais, Malais, Français et noms scientifiques accompagnés de photos HD.
