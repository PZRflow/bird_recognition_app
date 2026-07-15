# Bird Recognition App

This is a Flutter application designed to work completely offline, identifying bird species from audio recordings. The intelligence of the app comes from a custom TensorFlow Lite model trained on Xeno-Canto data.

## MLOps Pipeline (Google Colab)

To train or update the AI model, you do NOT need to run anything on your local computer. We have migrated the entire pipeline to a single Google Colab Notebook to leverage Cloud GPUs and infinite storage.

1. Go to [Google Colab](https://colab.research.google.com/).
2. Click **File > Upload Notebook** and select the `Bird_Recognition_Training.ipynb` file located at the root of this project.
3. In Colab, go to **Runtime > Change runtime type** and ensure a **T4 GPU** (Hardware accelerator) is selected.
4. Run the cells one by one. You will be prompted to enter your Xeno-Canto API Key.
5. Once the notebook finishes, it will generate a `bird_classifier.tflite` and `labels.json` file.
6. Download these two files and place them in the `assets/model/` folder of this Flutter project.

## Flutter Application

Once you have your `bird_classifier.tflite` model in the `assets/model/` directory, you can build and run the app normally:

```bash
flutter pub get
flutter run
```

### Architecture
This project follows a clean, feature-based architecture:
- `lib/core/` : Contains the heavy lifting services (`AudioProcessingService` for FFmpeg, and `RecognitionService` for TFLite inference).
- `lib/features/` : Modular UI screens (Home, Recorder, Import Audio, Prediction, Species Profiles, Credits).
- `assets/` : Contains the TFLite model and local mock JSON databases.
