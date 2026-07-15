import tensorflow as tf
import os
import shutil
import json

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
MODEL_PATH = os.path.join(DATASET_DIR, 'saved_model.keras')
FLUTTER_ASSETS_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'model')

if not os.path.exists(MODEL_PATH):
    raise Exception("Keras model not found. Please run train_local.py first.")

print("Loading Keras model...")

model = tf.keras.models.load_model(MODEL_PATH, compile=False)

print("Converting to TFLite (Float16 + Select TF Ops)...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

os.makedirs(FLUTTER_ASSETS_DIR, exist_ok=True)
tflite_dest = os.path.join(FLUTTER_ASSETS_DIR, 'bird_classifier.tflite')

with open(tflite_dest, 'wb') as f:
    f.write(tflite_model)
    
print(f"Model exported to {tflite_dest}")

# Convert labels.json to labels.txt (one per line)
labels_src = os.path.join(DATASET_DIR, 'labels.json')
labels_dest = os.path.join(FLUTTER_ASSETS_DIR, 'labels.txt')
if os.path.exists(labels_src):
    with open(labels_src, 'r') as f:
        labels = json.load(f)
    with open(labels_dest, 'w') as f:
        f.write('\n'.join(labels))
    print(f"File labels.txt generated to {labels_dest}")
else:
    print("File labels.json not found in dataset/")

# Generate model_metadata.json
metadata_dest = os.path.join(FLUTTER_ASSETS_DIR, 'model_metadata.json')
metadata = {
    "model_file": "bird_classifier.tflite",
    "input_shape": [1, 92, 128, 1],
    "output_shape": [1, len(labels) if 'labels' in locals() else 24],
    "sample_rate_hz": 16000,
    "clip_length_s": 3.0,
    "n_mels": 128,
    "n_fft": 1024,
    "hop_length": 512,
    "fmin_hz": 300,
    "fmax_hz": 8000,
    "input_dtype": "float32",
    "normalisation": "none",
    "labels_file": "labels.txt"
}

with open(metadata_dest, 'w') as f:
    json.dump(metadata, f, indent=4)
print(f"File model_metadata.json generated to {metadata_dest}")

print("\nOperation completed successfully. You can now run `flutter run`!")
