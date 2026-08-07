# ZamZam — Offline Bioacoustic Shazam for Malaysian Birds 🇲🇾🦅

ZamZam is an elite Flutter mobile application designed to operate **100% offline** (tailored for field research in Malaysian tropical rainforests and urban environments), allowing users to instantly identify bird species from real-time microphone recordings or imported audio files (MP3, WAV, FLAC, M4A, OGG).

The app's bioacoustic intelligence is powered by a **Quad-Ensemble of deep neural networks (MynaNet + Compact CNN + EfficientNet-B0 + ResNet34-Lite)** fused together to achieve an all-time record **`90.57%` validation accuracy** across 27 Malaysian bird species.

---

## 🏆 Quad-Ensemble Model Performance (27 Species, 2,322 Validation Files)

| Model Architecture | Input Spectrogram | Solo / Fusion Accuracy | Role in Ensemble |
| :--- | :---: | :---: | :--- |
| **1. MynaNet** (MobileNet-SE) | $64 \times 300$ PCEN | **84.32%** | High temporal resolution (captures short notes & trills) |
| **2. Compact CNN** (4-Block Swish) | $128 \times 128$ PCEN | **85.14%** | Balanced spectro-temporal feature representation |
| **3. EfficientNet-B0 Lite** | $128 \times 128$ PCEN | **82.17%** | Deep mobile convolutional feature extractor |
| **4. ResNet34-Lite** | $128 \times 128$ PCEN | **84.57%** | Residual shortcut connections for acoustic patterns |
| 👑 **QUAD-ENSEMBLE FUSION** | **Weighted Fusion** | **`90.57%`** | **Historic Project All-Time Record** |

$$\text{Final Prediction} = 0.30 \cdot P_{\text{Myna}} + 0.35 \cdot P_{\text{Compact}} + 0.15 \cdot P_{\text{EffNet}} + 0.20 \cdot P_{\text{ResNet}}$$

---

## 🚀 Quick Start Guide

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `>=3.0.0`)
* Android Emulator or physical device configured for USB debugging.

### Installation & Launch
1. Clone this repository to your machine:
   ```bash
   git clone https://github.com/PZRflow/bird_recognition_app.git
   cd bird_recognition_app
   ```
2. Install Flutter project dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application in debug mode:
   ```bash
   flutter run
   ```
4. Build the final distribution APK:
   ```bash
   flutter build apk --debug
   ```

---

## 🧠 MLOps Pipeline & Signal Processing (`/tools`)

1. **Audio Preprocessing & DSP Filtering**:
   * 16 kHz Mono PCM normalization.
   * 2nd-order Butterworth Bandpass Filter ($300\text{ Hz} - 8000\text{ Hz}$) eliminating wind noise and urban traffic rumble below 300 Hz.
   * Dynamic RMS Multi-Segmentation: Extracts top 5 active 3.0-second vocalization chunks.
2. **Per-Channel Energy Normalization (PCEN)**:
   * Replaces traditional Log-Mel Spectrograms with PCEN for robustness against microphone gain variations and caller distance.

---

## 🎨 Features & UI Highlights
* **Interactive User Confidence Threshold**: Dynamic slider UI in the app (30% to 80%) allowing low-confidence predictions to route gracefully to "Unknown Bird Species".
* **Universal Audio Import (FFmpegKit)**: Native support for uploading `.mp3`, `.wav`, `.flac`, `.m4a`, and `.ogg` files.
* **Real-time Audio Visualizer**: Animated sine wave (`SoundWaveVisualizer`) reacting live during microphone capture.
* **27 Species Profiles**: Comprehensive species descriptions featuring English, Malay, French, and scientific names alongside HD species photographs.
