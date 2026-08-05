import os
import sys

# Force CPU execution for fast reliable grid search
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

import numpy as np
import tensorflow as tf
from tensorflow import keras
import json
import glob
from scipy.special import softmax

DATASET_DIR = r"C:\Users\Marc\bird_recognition\dataset"
CACHE_DIR = os.path.join(DATASET_DIR, 'pcen_cache')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

num_classes = len(safe_labels)

print("Loading 3 Record Models on CPU for Temperature & Weight Grid Search...")
myna = keras.models.load_model(os.path.join(DATASET_DIR, 'best_model_mynanet_27sp_pcen.keras'), compile=False)
compact = keras.models.load_model(os.path.join(DATASET_DIR, 'best_model_compact_27sp_pcen.keras'), compile=False)
effnet = keras.models.load_model(os.path.join(DATASET_DIR, 'best_model_efficientnet_27sp_pcen.keras'), compile=False)

val_files_64 = []
val_files_128 = []
val_labels = []

for i, label_name in enumerate(safe_labels):
    pattern_64 = os.path.join(CACHE_DIR, 'val', label_name, '*_64.npy')
    files_64 = glob.glob(pattern_64)
    for f64 in files_64:
        f128 = f64.replace('_64.npy', '_128.npy')
        if os.path.exists(f128):
            val_files_64.append(f64)
            val_files_128.append(f128)
            val_labels.append(i)

print(f"Extracting raw logit predictions for {len(val_files_64)} validation files...")

raw_preds_myna = []
raw_preds_compact = []
raw_preds_effnet = []
y_true = []

for f64, f128, true_label in zip(val_files_64, val_files_128, val_labels):
    try:
        specs_64 = np.load(f64)
        specs_128 = np.load(f128)
        
        p_myna = myna.predict(specs_64[..., np.newaxis], verbose=0)
        p_compact = compact.predict(np.transpose(specs_128, (0, 2, 1))[..., np.newaxis], verbose=0)
        p_effnet = effnet.predict(np.transpose(specs_128, (0, 2, 1))[..., np.newaxis], verbose=0)
        
        avg_myna = np.max(p_myna, axis=0)
        avg_compact = np.max(p_compact, axis=0)
        avg_effnet = np.max(p_effnet, axis=0)
        
        raw_preds_myna.append(avg_myna)
        raw_preds_compact.append(avg_compact)
        raw_preds_effnet.append(avg_effnet)
        y_true.append(true_label)
    except Exception:
        continue

raw_preds_myna = np.array(raw_preds_myna)
raw_preds_compact = np.array(raw_preds_compact)
raw_preds_effnet = np.array(raw_preds_effnet)
y_true = np.array(y_true)

# Baseline Tri-Ensemble
base_p = 0.35 * raw_preds_myna + 0.40 * raw_preds_compact + 0.25 * raw_preds_effnet
base_acc = np.mean(y_true == np.argmax(base_p, axis=1)) * 100
print(f"\nBaseline Tri-Ensemble Accuracy (0.35/0.40/0.25, tau=1.0): {base_acc:.2f}%\n")

best_acc = base_acc
best_w = (0.35, 0.40, 0.25)
best_tau = 1.0

# Temperature Scaling Grid Search
print("Starting 3D Weight & Temperature Scaling Grid Search...")

weights = []
for w1 in np.linspace(0.1, 0.6, 11):
    for w2 in np.linspace(0.1, 0.6, 11):
        w3 = 1.0 - w1 - w2
        if 0.1 <= w3 <= 0.6:
            weights.append((w1, w2, w3))

temperatures = [0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0]

for tau in temperatures:
    # Apply Temperature Scaling via Softmax logits
    eps = 1e-7
    myna_scaled = softmax(np.log(np.clip(raw_preds_myna, eps, 1.0)) / tau, axis=1)
    compact_scaled = softmax(np.log(np.clip(raw_preds_compact, eps, 1.0)) / tau, axis=1)
    effnet_scaled = softmax(np.log(np.clip(raw_preds_effnet, eps, 1.0)) / tau, axis=1)
    
    for w1, w2, w3 in weights:
        tri = w1 * myna_scaled + w2 * compact_scaled + w3 * effnet_scaled
        acc = np.mean(y_true == np.argmax(tri, axis=1)) * 100
        
        if acc > best_acc:
            best_acc = acc
            best_w = (w1, w2, w3)
            best_tau = tau

print(f"\n=======================================================")
print(f"OPTIMIZATION COMPLETE!")
print(f"Baseline Tri-Ensemble Accuracy : {base_acc:.2f}%")
print(f"OPTIMIZED Tri-Ensemble Accuracy: {best_acc:.2f}%  (Gain: +{best_acc - base_acc:.2f}%)")
print(f"Optimal Weights   : MynaNet={best_w[0]:.2f}, Compact={best_w[1]:.2f}, EffNet={best_w[2]:.2f}")
print(f"Optimal Temperature: tau={best_tau}")
print(f"=======================================================\n")
