import os
import sys

# Load CUDA DLLs
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
import shutil

DATASET_DIR = r"C:\Users\Marc\bird_recognition\dataset"
MODEL_KERAS = os.path.join(DATASET_DIR, 'best_model_resnet34_light.keras')
TFLITE_OUT = os.path.join(r"C:\Users\Marc\bird_recognition\assets\model", 'resnet34_classifier_v3.tflite')

print("Exporting ResNet34-Lite to Float16 TFLite model for Flutter...")
model = keras.models.load_model(MODEL_KERAS, compile=False)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]

tflite_model = converter.convert()

with open(TFLITE_OUT, 'wb') as f:
    f.write(tflite_model)

size_mb = os.path.getsize(TFLITE_OUT) / (1024 * 1024)
print(f"Successfully exported ResNet34 Float16 TFLite model to {TFLITE_OUT} ({size_mb:.2f} MB)")
