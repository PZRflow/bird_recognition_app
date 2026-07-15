import tensorflow as tf
import os
import shutil
import json

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
MODEL_PATH = os.path.join(DATASET_DIR, 'saved_model_mynanet.keras')
FLUTTER_ASSETS_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'model')

if not os.path.exists(MODEL_PATH):
    raise Exception("Modèle MynaNet Keras introuvable. Veuillez d'abord lancer train_mynanet.py.")

print("Chargement du modèle MynaNet Keras...")

model = tf.keras.models.load_model(MODEL_PATH, compile=False)

print("Conversion en TFLite (Float16 + Select TF Ops)...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

os.makedirs(FLUTTER_ASSETS_DIR, exist_ok=True)
tflite_dest = os.path.join(FLUTTER_ASSETS_DIR, 'mynanet_classifier.tflite')

with open(tflite_dest, 'wb') as f:
    f.write(tflite_model)
    
print(f"Modèle MynaNet exporté vers {tflite_dest}")

# Labels are identical, no need to overwrite labels.txt

# Generate mynanet_metadata.json
metadata_dest = os.path.join(FLUTTER_ASSETS_DIR, 'mynanet_metadata.json')
metadata = {
    "model_file": "mynanet_classifier.tflite",
    "input_shape": [1, 64, 300, 1],
    "sample_rate_hz": 16000,
    "clip_length_s": 3.0,
    "n_mels": 64,
    "n_fft": 1024,
    "hop_length": 160,
    "win_length": 400,
    "fmin_hz": 300,
    "fmax_hz": 8000,
    "input_dtype": "float32",
    "normalisation": "none",
    "labels_file": "labels.txt"
}

with open(metadata_dest, 'w') as f:
    json.dump(metadata, f, indent=4)
print(f"Fichier mynanet_metadata.json généré vers {metadata_dest}")

print("\nOpération terminée avec succès. MynaNet est exporté pour Flutter !")
