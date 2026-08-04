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
import librosa
import numpy as np
import json
import matplotlib.pyplot as plt
from scipy import signal

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

active_labels = []
for label_name in safe_labels:
    pattern = os.path.join(DATASET_DIR, 'train', label_name, '*.wav')
    if len(glob.glob(pattern)) > 0:
        active_labels.append(label_name)

safe_labels = active_labels
NUM_CLASSES = len(safe_labels)

SR = 16000
N_FFT = 1024
HOP = 160
N_MELS = 64
TIME_FRAMES = 300
INPUT_SHAPE = (64, 300, 1)

def get_dataset_files(split, max_per_class=800):
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

def apply_bandpass_filter(data, fs, lowcut=300.0, highcut=7999.0, order=5):
    nyq = 0.5 * fs
    low = lowcut / nyq
    high = highcut / nyq
    sos = signal.butter(order, [low, high], btype='band', output='sos')
    return signal.sosfiltfilt(sos, data)

def extract_pcen_spec(y):
    max_amp = np.max(np.abs(y))
    if max_amp > 0:
        y = y / (max_amp + 1e-7)
    mel = librosa.feature.melspectrogram(
        y=y, sr=SR, n_fft=N_FFT, win_length=400, hop_length=HOP, n_mels=N_MELS, fmin=300, fmax=8000
    )
    noise_floor = np.median(mel, axis=1, keepdims=True)
    mel_clean = np.maximum(mel - 0.8 * noise_floor, 1e-10)
    pcen = librosa.pcen(
        mel_clean, sr=SR, hop_length=HOP, time_constant=0.4, gain=0.8, bias=10.0, power=0.25, eps=1e-6
    )
    if pcen.shape[1] < TIME_FRAMES:
        pcen = np.pad(pcen, ((0,0),(0, TIME_FRAMES - pcen.shape[1])), constant_values=0.0)
    else:
        pcen = pcen[:, :TIME_FRAMES]
    return pcen[..., np.newaxis].astype(np.float32)

def audio_generator(files, labels, is_training=True):
    indices = list(range(len(files)))
    if is_training:
        random.shuffle(indices)
        
    for i in indices:
        f = files[i]
        l = labels[i]
        try:
            y, sr = librosa.load(f, sr=SR, mono=True, dtype=np.float32)
            y = apply_bandpass_filter(y, sr).astype(np.float32)
            
            if len(y) < 48000:
                y = np.pad(y, (0, 48000 - len(y)))
                
            chunks_energy = []
            step = 8000
            for idx in range(0, len(y) - 48000 + 1, step):
                c = y[idx:idx+48000]
                # Combined score: Energy * (1 - Spectral Flatness) for bird call clarity
                flatness = np.mean(librosa.feature.spectral_flatness(y=c, n_fft=512, hop_length=256))
                score = np.sum(c**2) * (1.0 - flatness)
                chunks_energy.append((score, idx))
                
            if not chunks_energy:
                chunks_energy.append((np.sum(y[:48000]**2), 0))
                
            chunks_energy.sort(key=lambda x: x[0], reverse=True)
            max_e = chunks_energy[0][0]
            
            selected_indices = []
            for e, idx in chunks_energy:
                if len(selected_indices) >= 5:
                    break
                if e < max_e * 0.1:
                    continue
                if not any(abs(idx - sel) < 48000 for sel in selected_indices):
                    selected_indices.append(idx)
                    
            if not selected_indices:
                selected_indices = [chunks_energy[0][1]]
                
            for idx in selected_indices:
                chunk = y[idx:idx+48000]
                spec = extract_pcen_spec(chunk)
                
                label_vec = keras.utils.to_categorical(l, num_classes=NUM_CLASSES)
                yield spec, label_vec
        except Exception:
            continue

train_files, train_labels, train_counts = get_dataset_files('train', max_per_class=800)
val_files, val_labels, val_counts = get_dataset_files('val', max_per_class=400)

class_weights_arr = compute_class_weight('balanced', classes=np.unique(train_labels), y=train_labels)
class_weights_dict = dict(enumerate(class_weights_arr))

train_ds = tf.data.Dataset.from_generator(
    lambda: audio_generator(train_files, train_labels, is_training=True),
    output_signature=(
        tf.TensorSpec(shape=INPUT_SHAPE, dtype=tf.float32),
        tf.TensorSpec(shape=(NUM_CLASSES,), dtype=tf.float32)
    )
).cache().shuffle(2000).batch(16).prefetch(tf.data.AUTOTUNE)

val_ds = tf.data.Dataset.from_generator(
    lambda: audio_generator(val_files, val_labels, is_training=False),
    output_signature=(
        tf.TensorSpec(shape=INPUT_SHAPE, dtype=tf.float32),
        tf.TensorSpec(shape=(NUM_CLASSES,), dtype=tf.float32)
    )
).cache().batch(16).prefetch(tf.data.AUTOTUNE)

def se_block(input_tensor, ratio=16):
    channels = input_tensor.shape[-1]
    se = layers.GlobalAveragePooling2D()(input_tensor)
    se = layers.Dense(channels // ratio, activation='relu')(se)
    se = layers.Dense(channels, activation='sigmoid')(se)
    se = layers.Reshape((1, 1, channels))(se)
    return layers.Multiply()([input_tensor, se])

def build_mynanet_hnr(input_shape=(64, 300, 1), num_classes=27):
    inputs = keras.Input(shape=input_shape)
    
    # Block 1
    x = layers.Conv2D(32, (3, 3), padding='same', use_bias=False)(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('swish')(x)
    x = layers.MaxPooling2D((2, 2))(x)
    
    # Block 2
    x = layers.SeparableConv2D(64, (3, 3), padding='same', use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('swish')(x)
    x = se_block(x)
    x = layers.MaxPooling2D((2, 2))(x)
    
    # Block 3
    x = layers.SeparableConv2D(128, (3, 3), padding='same', use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('swish')(x)
    x = se_block(x)
    x = layers.MaxPooling2D((2, 2))(x)
    
    # Block 4
    x = layers.SeparableConv2D(256, (3, 3), padding='same', use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('swish')(x)
    x = se_block(x)
    x = layers.GlobalAveragePooling2D()(x)
    
    # Head
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation='sigmoid')(x)
    
    model = keras.Model(inputs, outputs, name="MynaNet_27Sp_HNR")
    return model

model = build_mynanet_hnr(input_shape=INPUT_SHAPE, num_classes=NUM_CLASSES)

initial_lr = 1e-3
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=initial_lr),
    loss='binary_crossentropy',
    metrics=['accuracy']
)

MODEL_SAVE_PATH = os.path.join(DATASET_DIR, 'best_model_mynanet_27sp_hnr.keras')

callbacks = [
    EarlyStopping(monitor='val_accuracy', patience=12, restore_best_weights=True, verbose=1),
    ModelCheckpoint(MODEL_SAVE_PATH, monitor='val_accuracy', save_best_only=True, verbose=1),
    keras.callbacks.ReduceLROnPlateau(monitor='val_accuracy', factor=0.5, patience=4, min_lr=1e-5, verbose=1)
]

print("\n--- Lancement de l'Entraînement MynaNet 27-Espèces HNR (Sélection d'Harmonicité Acoustique) ---")
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
print(f"Meilleure Précision de Validation MynaNet 27-Espèces HNR: {val_acc*100:.2f}%")
print(f"==========================================")

plt.figure(figsize=(10, 4))
plt.subplot(1, 2, 1)
plt.plot(history.history['accuracy'], label='Train Accuracy')
plt.plot(history.history['val_accuracy'], label='Val Accuracy')
plt.title('MynaNet 27-Espèces HNR Accuracy')
plt.legend()

plt.subplot(1, 2, 2)
plt.plot(history.history['loss'], label='Train Loss')
plt.plot(history.history['val_loss'], label='Val Loss')
plt.title('MynaNet 27-Espèces HNR Loss')
plt.legend()

plot_path = os.path.join(DATASET_DIR, 'mynanet_27sp_hnr_history.png')
plt.savefig(plot_path)
print(f"Graphique sauvegardé sous: {plot_path}")
