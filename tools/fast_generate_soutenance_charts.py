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

import numpy as np
import json
import glob
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix, classification_report

DATASET_DIR = r"C:\Users\Marc\bird_recognition\dataset"
CACHE_DIR = os.path.join(DATASET_DIR, 'pcen_cache')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')
CHARTS_DIR = os.path.join(DATASET_DIR, 'soutenance_charts')
os.makedirs(CHARTS_DIR, exist_ok=True)

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

species_display_names = [name.replace('_', ' ').title() for name in safe_labels]

print("Fast generating 3 presentation charts...")

import tensorflow as tf
from tensorflow import keras

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

y_true = []
y_pred = []

for f64, f128, true_label in zip(val_files_64, val_files_128, val_labels):
    try:
        specs_64 = np.load(f64)   # (num_seg, 64, 300)
        specs_128 = np.load(f128) # (num_seg, 128, 128)
        
        p_myna = myna.predict(specs_64[..., np.newaxis], verbose=0)
        p_compact = compact.predict(np.transpose(specs_128, (0, 2, 1))[..., np.newaxis], verbose=0)
        p_effnet = effnet.predict(np.transpose(specs_128, (0, 2, 1))[..., np.newaxis], verbose=0)
        
        tri_p = 0.35 * p_myna + 0.40 * p_compact + 0.25 * p_effnet
        avg_tri = np.max(tri_p, axis=0)
        
        y_true.append(true_label)
        y_pred.append(np.argmax(avg_tri))
    except Exception:
        continue

y_true = np.array(y_true)
y_pred = np.array(y_pred)

acc = np.mean(y_true == y_pred) * 100
print(f"Tri-Ensemble Validation Accuracy: {acc:.2f}%")

# 1. Confusion Matrix
plt.figure(figsize=(16, 14))
cm = confusion_matrix(y_true, y_pred)
cm_norm = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]

im = plt.imshow(cm_norm, interpolation='nearest', cmap=plt.cm.Blues)
plt.colorbar(im, label='Normalized Accuracy')

tick_marks = np.arange(len(species_display_names))
plt.xticks(tick_marks, species_display_names, rotation=45, ha='right', fontsize=9)
plt.yticks(tick_marks, species_display_names, fontsize=9)

for i in range(cm_norm.shape[0]):
    for j in range(cm_norm.shape[1]):
        val = cm_norm[i, j]
        color = "white" if val > 0.5 else "black"
        plt.text(j, i, f"{val:.2f}", ha="center", va="center", color=color, fontsize=6)

plt.title(f'Matrice de Confusion Normalisée - Tri-Ensemble PCEN ({len(safe_labels)} Espèces: {acc:.2f}%)', fontsize=16, pad=20, fontweight='bold')
plt.xlabel('Prédiction du Modèle', fontsize=14, labelpad=10)
plt.ylabel('Vraie Espèce (Ground Truth)', fontsize=14, labelpad=10)
plt.tight_layout()

cm_path = os.path.join(CHARTS_DIR, 'confusion_matrix_27sp.png')
plt.savefig(cm_path, dpi=300)
plt.close()
print(f"Saved: {cm_path}")

# 2. Per-Class F1-Scores
report = classification_report(y_true, y_pred, target_names=species_display_names, output_dict=True)
f1_scores = [report[name]['f1-score'] * 100 for name in species_display_names]

plt.figure(figsize=(14, 8))
bars = plt.barh(species_display_names, f1_scores, color='#1E88E5', edgecolor='#1565C0')
plt.axvline(x=np.mean(f1_scores), color='#D32F2F', linestyle='--', linewidth=2, label=f'F1-Score Moyen: {np.mean(f1_scores):.1f}%')
plt.xlim(50, 100)
plt.xlabel('F1-Score (%)', fontsize=12, fontweight='bold')
plt.title('Performance F1-Score par Espèce D\'Oiseau (27 Espèces)', fontsize=14, pad=15, fontweight='bold')
plt.legend(loc='lower right', fontsize=11)
plt.gca().invert_yaxis()

for bar in bars:
    width = bar.get_width()
    plt.text(width + 0.5, bar.get_y() + bar.get_height()/2, f'{width:.1f}%', ha='left', va='center', fontsize=9)

plt.tight_layout()
f1_path = os.path.join(CHARTS_DIR, 'f1_score_27sp.png')
plt.savefig(f1_path, dpi=300)
plt.close()
print(f"Saved: {f1_path}")

# 3. Evolution Chart
phases = [
  'Phase 1: Baseline Log-Mel\n(20 Espèces Solo)',
  'Phase 2: Multi-Segment\nLog-Mel (20 Espèces)',
  'Phase 3: PCEN + Slaney\n(20 Espèces Record)',
  'Phase 4: Expansion Urbaine\nInitial (27 Espèces)',
  'Phase 5: Dual Ensemble\n(27 Espèces)',
  'Phase 6: Tri-Ensemble PCEN\n(27 Espèces Record Absolu)'
]
accuracies = [73.00, 84.58, 87.41, 84.32, 87.55, 89.06]

plt.figure(figsize=(12, 6))
colors = ['#B0BEC5', '#90A4AE', '#42A5F5', '#AB47BC', '#26A69A', '#43A047']
bars_prog = plt.bar(phases, accuracies, color=colors, width=0.55, edgecolor='#37474F')

plt.ylim(60, 95)
plt.ylabel('Précision de Validation (%)', fontsize=12, fontweight='bold')
plt.title('Évolution Historique de la Précision du Projet (De 73.00% à 89.06%)', fontsize=14, pad=15, fontweight='bold')
plt.grid(axis='y', linestyle=':', alpha=0.6)

for bar in bars_prog:
    height = bar.get_height()
    plt.text(bar.get_x() + bar.get_width()/2., height + 0.8, f'{height:.2f}%', ha='center', va='bottom', fontsize=11, fontweight='bold')

plt.tight_layout()
evo_path = os.path.join(CHARTS_DIR, 'model_evolution_benchmark.png')
plt.savefig(evo_path, dpi=300)
plt.close()
print(f"Saved: {evo_path}")

print("Done! All 3 charts created instantly!")
