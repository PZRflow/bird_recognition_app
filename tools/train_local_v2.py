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
    print("Info: Unable to add CUDA DLLs:", e)

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
from sklearn.utils.class_weight import compute_class_weight
import random
import librosa
import numpy as np
import json
import matplotlib.pyplot as plt
from scipy import signal

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

if not os.path.exists(LABELS_FILE):
    raise Exception(f"Labels file not found: {LABELS_FILE}. Please prepare the dataset first.")

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

# Auto-detect valid labels (ignoring empty folders)
active_labels = []
for label_name in safe_labels:
    pattern = os.path.join(DATASET_DIR, 'train', label_name, '*.wav')
    if len(glob.glob(pattern)) > 0:
        active_labels.append(label_name)

print(f"Found {len(active_labels)} species with data out of {len(safe_labels)}.")
safe_labels = active_labels
NUM_CLASSES = len(safe_labels)

# Compact CNN audio parameters
SR = 16000
N_FFT = 1024
HOP = 512
N_MELS = 128
INPUT_SHAPE = (128, 128, 1)

def get_dataset_files(split, max_per_class=400):
    all_files_by_class = []
    for i, label_name in enumerate(safe_labels):
        pattern = os.path.join(DATASET_DIR, split, label_name, '*.wav')
        files = glob.glob(pattern)
        if len(files) > 0:
            all_files_by_class.append((i, files))
        
    selected_files = []
    selected_labels = []
    class_counts = {}
    
    for i, files in all_files_by_class:
        random.shuffle(files)
        chosen = files[:max_per_class]
        class_counts[i] = len(chosen)
        for f in chosen:
            selected_files.append(f)
            selected_labels.append(i)
            
    combined = list(zip(selected_files, selected_labels))
    random.shuffle(combined)
    selected_files, selected_labels = zip(*combined)
    selected_files = list(selected_files)
    selected_labels = list(selected_labels)
            
    print(f'Set "{split}" - Total fichiers : {len(selected_files)}')
    return selected_files, selected_labels, class_counts

def apply_bandpass_filter(data, fs, lowcut=300.0, highcut=5000.0, order=5):
    nyq = 0.5 * fs
    low = lowcut / nyq
    high = highcut / nyq
    sos = signal.butter(order, [low, high], btype='band', output='sos')
    y = signal.sosfiltfilt(sos, data)
    return y

def audio_generator(files, labels):
    for f, l in zip(files, labels):
        try:
            y, sr = librosa.load(f, sr=SR, mono=True, dtype=np.float32)
            y = apply_bandpass_filter(y, sr).astype(np.float32)
            if len(y) < 48000: 
                y = np.pad(y, (0, 48000 - len(y)))
                
            chunks_energy = []
            step = 8000 # 0.5s step for finer scan
            for i in range(0, len(y) - 48000 + 1, step):
                chunk = y[i:i+48000]
                energy = np.sum(chunk**2)
                chunks_energy.append((energy, i))
                
            chunks_energy.sort(key=lambda x: x[0], reverse=True)
            if not chunks_energy:
                continue
                
            max_energy = chunks_energy[0][0]
            energy_threshold = max_energy * 0.1 # Must be at least 10% of max energy
            
            selected_indices = []
            for energy, idx in chunks_energy:
                if len(selected_indices) >= 5: # Max 5 segments per file
                    break
                if energy < energy_threshold:
                    continue
                    
                # Non-overlapping check
                overlap = False
                for sel_idx in selected_indices:
                    if abs(idx - sel_idx) < 48000:
                        overlap = True
                        break
                
                if not overlap:
                    selected_indices.append(idx)
                    
            for idx in selected_indices:
                best_chunk = y[idx:idx+48000]
                max_amp = np.max(np.abs(best_chunk))
                if max_amp > 0.0:
                    best_chunk = best_chunk / (max_amp + 1e-7)
                    
                # Log-Mel Spectrogram computation
                stfts = librosa.stft(best_chunk, n_fft=N_FFT, hop_length=HOP)
                power = np.abs(stfts)**2
                mel = librosa.feature.melspectrogram(S=power, sr=SR, n_mels=N_MELS, fmin=300, fmax=8000)
                
                # Pad to 128 frames (it's 94 normally)
                if mel.shape[1] < 128:
                    mel = np.pad(mel, ((0, 0), (0, 128 - mel.shape[1])), constant_values=1e-10) 
                else:
                    mel = mel[:, :128]
                    
                logmel = 10 * np.log10(mel + 1e-10)
                # Transpose to (time, mel) and add channel
                logmel = logmel.T[..., np.newaxis]
                    
                yield logmel, l
        except Exception:
            continue

def create_tf_dataset(files, labels, shuffle=False):
    ds = tf.data.Dataset.from_generator(
        lambda: audio_generator(files, labels),
        output_signature=(
            tf.TensorSpec(shape=(128, 128, 1), dtype=tf.float32),
            tf.TensorSpec(shape=(), dtype=tf.int32)
        )
    )
    # Cache in RAM to speed up training
    ds = ds.cache()
    if shuffle:
        ds = ds.shuffle(buffer_size=1000)
    # One-Hot encoding for Sigmoid
    ds = ds.map(lambda x, y: (x, tf.one_hot(y, depth=NUM_CLASSES)), num_parallel_calls=tf.data.AUTOTUNE)
    return ds.batch(32).prefetch(tf.data.AUTOTUNE)

train_files, train_labels, class_counts = get_dataset_files('train', max_per_class=400)
train_ds = create_tf_dataset(train_files, train_labels, shuffle=True)

val_files, val_labels, _ = get_dataset_files('val', max_per_class=100)
val_ds = create_tf_dataset(val_files, val_labels, shuffle=False)

# Compute class weights
weights = compute_class_weight(
    class_weight="balanced",
    classes=np.arange(NUM_CLASSES),
    y=np.array(train_labels)
)
class_weight_dict = dict(enumerate(weights))

def build_model():
    inputs = keras.Input(shape=INPUT_SHAPE)
    x = layers.Conv2D(32, 3, activation="relu", padding="same")(inputs)
    x = layers.MaxPooling2D(2)(x)
    x = layers.Conv2D(64, 3, activation="relu", padding="same")(x)
    x = layers.MaxPooling2D(2)(x)
    x = layers.Conv2D(128, 3, activation="relu", padding="same")(x)
    x = layers.MaxPooling2D(2)(x)
    x = layers.Conv2D(128, 3, activation="relu", padding="same")(x)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    # Sigmoid activation for Compact CNN
    outputs = layers.Dense(NUM_CLASSES, activation="sigmoid")(x)
    return keras.Model(inputs, outputs, name="zamzam_compact_cnn")

model = build_model()

# Compile with Binary Crossentropy
model.compile(
    optimizer=keras.optimizers.Adam(1e-3),
    loss="binary_crossentropy",
    metrics=[keras.metrics.CategoricalAccuracy(name='accuracy')]
)

reduce_lr = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=4, verbose=1, min_lr=1e-6)
early_stop = EarlyStopping(monitor='val_accuracy', patience=8, restore_best_weights=True)
checkpoint = ModelCheckpoint(os.path.join(DATASET_DIR, 'best_model_v2.keras'), save_best_only=True, monitor="val_accuracy")

print(f'\nEntraînement de Compact CNN avec Sigmoid + BCE sur GPU Local pour {NUM_CLASSES} classes...')
history = model.fit(
    train_ds, 
    validation_data=val_ds, 
    epochs=50, 
    class_weight=class_weight_dict,
    callbacks=[early_stop, reduce_lr, checkpoint]
)

model.save(os.path.join(DATASET_DIR, 'saved_model_v2.keras'))

# Plot accuracy
plt.figure(figsize=(10, 6))
plt.plot(history.history['accuracy'], label='Train Accuracy')
plt.plot(history.history['val_accuracy'], label='Validation Accuracy')
plt.title('Courbe d\'apprentissage - Compact CNN v2 avec Sigmoid + BCE')
plt.ylabel('Accuracy')
plt.xlabel('Epoch')
plt.legend()
plt.savefig(os.path.join(DATASET_DIR, 'training_history_v2.png'))
print("Modèle Compact CNN v2 sauvegardé.")
