import os
import sys
import glob

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
from tensorflow.keras import layers
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint
from sklearn.utils.class_weight import compute_class_weight
import random
import numpy as np
import json
import matplotlib.pyplot as plt

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
CACHE_DIR = os.path.join(DATASET_DIR, 'pcen_cache')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

active_labels = []
for label_name in safe_labels:
    pattern = os.path.join(CACHE_DIR, 'train', label_name, '*_128.npy')
    if len(glob.glob(pattern)) > 0:
        active_labels.append(label_name)

safe_labels = active_labels
NUM_CLASSES = len(safe_labels)

INPUT_SHAPE = (128, 128, 1)

def get_cached_dataset_files(split, max_per_class=800):
    all_files_by_class = []
    for i, label_name in enumerate(safe_labels):
        pattern = os.path.join(CACHE_DIR, split, label_name, '*_128.npy')
        files = glob.glob(pattern)
        if len(files) > 0:
            all_files_by_class.append((i, files))
        
    selected_files = []
    selected_labels = []
    
    for i, files in all_files_by_class:
        random.shuffle(files)
        chosen = files[:max_per_class]
        for f in chosen:
            selected_files.append(f)
            selected_labels.append(i)
            
    combined = list(zip(selected_files, selected_labels))
    random.shuffle(combined)
    selected_files, selected_labels = zip(*combined)
    selected_files = list(selected_files)
    selected_labels = list(selected_labels)
            
    print(f'Cached Set "{split}" - Total fichiers : {len(selected_files)}')
    return selected_files, selected_labels

def cached_generator(files, labels, is_training=True):
    indices = list(range(len(files)))
    if is_training:
        random.shuffle(indices)
        
    for i in indices:
        f = files[i]
        l = labels[i]
        try:
            specs = np.load(f) # shape: (num_segments, 128, 128)
            label_vec = keras.utils.to_categorical(l, num_classes=NUM_CLASSES)
            for spec in specs:
                # spec shape: (128, 128) -> transpose to (128, 128, 1)
                yield spec.T[..., np.newaxis], label_vec
        except Exception:
            continue

train_files, train_labels = get_cached_dataset_files('train', max_per_class=800)
val_files, val_labels = get_cached_dataset_files('val', max_per_class=400)

class_weights_arr = compute_class_weight('balanced', classes=np.unique(train_labels), y=train_labels)
class_weights_dict = dict(enumerate(class_weights_arr))

train_ds = tf.data.Dataset.from_generator(
    lambda: cached_generator(train_files, train_labels, is_training=True),
    output_signature=(
        tf.TensorSpec(shape=INPUT_SHAPE, dtype=tf.float32),
        tf.TensorSpec(shape=(NUM_CLASSES,), dtype=tf.float32)
    )
).batch(32).prefetch(tf.data.AUTOTUNE)

val_ds = tf.data.Dataset.from_generator(
    lambda: cached_generator(val_files, val_labels, is_training=False),
    output_signature=(
        tf.TensorSpec(shape=INPUT_SHAPE, dtype=tf.float32),
        tf.TensorSpec(shape=(NUM_CLASSES,), dtype=tf.float32)
    )
).batch(32).prefetch(tf.data.AUTOTUNE)

def build_efficientnet_lite_27sp(input_shape=(128, 128, 1), num_classes=27):
    # Construct 3-channel input by repeating PCEN channel
    inputs = keras.Input(shape=input_shape)
    x_3ch = layers.Concatenate(axis=-1)([inputs, inputs, inputs])
    
    base_model = keras.applications.EfficientNetB0(
        include_top=False,
        weights=None, # Train from scratch on PCEN
        input_tensor=x_3ch,
        pooling='avg'
    )
    
    x = base_model.output
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation='sigmoid')(x)
    
    model = keras.Model(inputs, outputs, name="EfficientNetB0_27Sp_PCEN")
    return model

model = build_efficientnet_lite_27sp(input_shape=INPUT_SHAPE, num_classes=NUM_CLASSES)

initial_lr = 1e-3
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=initial_lr),
    loss='binary_crossentropy',
    metrics=['accuracy']
)

MODEL_SAVE_PATH = os.path.join(DATASET_DIR, 'best_model_efficientnet_27sp_pcen.keras')

callbacks = [
    EarlyStopping(monitor='val_accuracy', patience=12, restore_best_weights=True, verbose=1),
    ModelCheckpoint(MODEL_SAVE_PATH, monitor='val_accuracy', save_best_only=True, verbose=1),
    keras.callbacks.ReduceLROnPlateau(monitor='val_accuracy', factor=0.5, patience=4, min_lr=1e-5, verbose=1)
]

print("\n--- Lancement de l'Entraînement EfficientNet-B0 Lite 27-Espèces PCEN (ÉCLAIR VIA CACHE) ---")
print(f"Modèle sauvegardé sous: {MODEL_SAVE_PATH}")

history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=40,
    callbacks=callbacks,
    class_weight=class_weights_dict
)

val_acc = max(history.history['val_accuracy'])
print(f"\n==========================================")
print(f"Meilleure Précision de Validation EfficientNet-B0 27-Espèces PCEN: {val_acc*100:.2f}%")
print(f"==========================================")

plt.figure(figsize=(10, 4))
plt.subplot(1, 2, 1)
plt.plot(history.history['accuracy'], label='Train Accuracy')
plt.plot(history.history['val_accuracy'], label='Val Accuracy')
plt.title('EfficientNet-B0 27-Espèces PCEN Accuracy')
plt.legend()

plt.subplot(1, 2, 2)
plt.plot(history.history['loss'], label='Train Loss')
plt.plot(history.history['val_loss'], label='Val Loss')
plt.title('EfficientNet-B0 27-Espèces PCEN Loss')
plt.legend()

plot_path = os.path.join(DATASET_DIR, 'efficientnet_27sp_pcen_history.png')
plt.savefig(plot_path)
print(f"Graphique sauvegardé sous: {plot_path}")
