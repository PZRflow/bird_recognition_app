import os
import sys

# Load CUDA 11.2 DLLs installed via pip
try:
    site_packages = next(p for p in sys.path if 'site-packages' in p)
    nvidia_base = os.path.join(site_packages, 'nvidia')
    if os.path.exists(nvidia_base):
        for module in os.listdir(nvidia_base):
            bin_dir = os.path.join(nvidia_base, module, 'bin')
            if os.path.exists(bin_dir):
                os.environ['PATH'] = bin_dir + os.pathsep + os.environ['PATH']
                try:
                    os.add_dll_directory(bin_dir)
                except AttributeError:
                    pass
except Exception as e:
    pass

import tensorflow as tf
from tensorflow import keras
import json

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
ASSETS_MODEL_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'model')
os.makedirs(ASSETS_MODEL_DIR, exist_ok=True)

MODEL_PATH = os.path.join(DATASET_DIR, 'best_model_compact_27sp_pcen.keras')
TFLITE_PATH = os.path.join(ASSETS_MODEL_DIR, 'bird_classifier_v3.tflite')
METADATA_PATH = os.path.join(ASSETS_MODEL_DIR, 'model_metadata_v3.json')

if not os.path.exists(MODEL_PATH):
    raise Exception(f"Model file not found: {MODEL_PATH}")

print(f"Loading Compact CNN 27-Species PCEN Keras model from {MODEL_PATH}...")
model = keras.models.load_model(MODEL_PATH, compile=False)

print("Converting Compact CNN 27-Species PCEN to TFLite Float16...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]

tflite_model = converter.convert()

with open(TFLITE_PATH, 'wb') as f:
    f.write(tflite_model)

print(f"Successfully exported Compact CNN 27-Species PCEN TFLite to {TFLITE_PATH} ({len(tflite_model) / 1024:.1f} KB)")

metadata = {
    "model_name": "ZamZam_Compact_CNN_27Sp_PCEN_v3",
    "architecture": "Compact CNN + PCEN + Spectral Subtraction (27 Species)",
    "input_shape": [1, 128, 128, 1],
    "sample_rate": 16000,
    "num_classes": 27,
    "f_min": 300.0,
    "f_max": 8000.0,
    "n_mels": 128,
    "hop_length": 512,
    "win_length": 1024,
    "pcen_time_constant": 0.4,
    "pcen_gain": 0.8,
    "pcen_bias": 10.0,
    "pcen_power": 0.25,
    "quantization": "float16"
}

with open(METADATA_PATH, 'w') as f:
    json.dump(metadata, f, indent=2)

print(f"Successfully created metadata file at {METADATA_PATH}")
