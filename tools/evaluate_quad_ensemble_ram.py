import os
import sys

# Load CUDA 11.2 DLLs installed via pip for GPU execution
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

import numpy as np
import tensorflow as tf
from tensorflow import keras
import json
import glob

DATASET_DIR = r"C:\Users\Marc\bird_recognition\dataset"
CACHE_DIR = os.path.join(DATASET_DIR, 'pcen_cache')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

num_classes = len(safe_labels)

print("Step 1: Loading 4 Models on GPU...")
myna = keras.models.load_model(os.path.join(DATASET_DIR, 'best_model_mynanet_27sp_pcen.keras'), compile=False)
compact = keras.models.load_model(os.path.join(DATASET_DIR, 'best_model_compact_27sp_pcen.keras'), compile=False)
effnet = keras.models.load_model(os.path.join(DATASET_DIR, 'best_model_efficientnet_27sp_pcen.keras'), compile=False)
resnet = keras.models.load_model(os.path.join(DATASET_DIR, 'best_model_resnet34_light.keras'), compile=False)

print("Step 2: Pre-loading all validation tensors into RAM...")

val_64_list = []
val_128_list = []
y_true_list = []

for i, label_name in enumerate(safe_labels):
    pattern_64 = os.path.join(CACHE_DIR, 'val', label_name, '*_64.npy')
    files_64 = glob.glob(pattern_64)
    for f64 in files_64:
        f128 = f64.replace('_64.npy', '_128.npy')
        if os.path.exists(f128):
            try:
                s64 = np.load(f64)   # (5, 64, 300)
                s128 = np.load(f128) # (5, 128, 128)
                val_64_list.append(s64)
                val_128_list.append(s128)
                y_true_list.append(i)
            except Exception:
                continue

y_true = np.array(y_true_list)
print(f"Loaded {len(val_64_list)} validation audio files into RAM.")

print("Step 3: Vectorized GPU Predictions for all 4 Models...")
p_myna_files = []
p_compact_files = []
p_effnet_files = []
p_resnet_files = []

for s64, s128 in zip(val_64_list, val_128_list):
    pm = myna(s64[..., np.newaxis], training=False).numpy()
    pc = compact(np.transpose(s128, (0, 2, 1))[..., np.newaxis], training=False).numpy()
    pe = effnet(np.transpose(s128, (0, 2, 1))[..., np.newaxis], training=False).numpy()
    pr = resnet(np.transpose(s128, (0, 2, 1))[..., np.newaxis], training=False).numpy()
    
    p_myna_files.append(np.max(pm, axis=0))
    p_compact_files.append(np.max(pc, axis=0))
    p_effnet_files.append(np.max(pe, axis=0))
    p_resnet_files.append(np.max(pr, axis=0))

p_myna = np.array(p_myna_files)
p_compact = np.array(p_compact_files)
p_effnet = np.array(p_effnet_files)
p_resnet = np.array(p_resnet_files)

# Quad-Ensemble weights (0.30 Myna + 0.35 Compact + 0.15 EffNet + 0.20 ResNet)
p_quad = 0.30 * p_myna + 0.35 * p_compact + 0.15 * p_effnet + 0.20 * p_resnet
quad_acc = np.mean(y_true == np.argmax(p_quad, axis=1)) * 100

print(f"\n=======================================================")
print(f"Quad-Ensemble (4 Models) Validation Accuracy: {quad_acc:.2f}%")
print(f"Previous Tri-Ensemble Record Accuracy        : 89.23%")
print(f"=======================================================\n")
