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

active_labels = []
for label_name in safe_labels:
    pattern = os.path.join(DATASET_DIR, 'train', label_name, '*.wav')
    if len(glob.glob(pattern)) > 0:
        active_labels.append(label_name)

print(f"Found {len(active_labels)} species with data out of {len(safe_labels)}.")
safe_labels = active_labels
NUM_CLASSES = len(safe_labels)

# Audio parameters for Compact CNN PCEN
SR = 16000
N_FFT = 1024
HOP = 512
N_MELS = 128
TIME_FRAMES = 128
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

def apply_bandpass_filter(data, fs, lowcut=300.0, highcut=7999.0, order=5):
    nyq = 0.5 * fs
    low = lowcut / nyq
    high = highcut / nyq
    sos = signal.butter(order, [low, high], btype='band', output='sos')
    return signal.sosfiltfilt(sos, data)

def audio_generator(files, labels):
    for f, l in zip(files, labels):
        try:
            y, sr = librosa.load(f, sr=SR, mono=True, dtype=np.float32)
            y = apply_bandpass_filter(y, sr).astype(np.float32)
            if len(y) < 48000: 
                y = np.pad(y, (0, 48000 - len(y)))
                
            chunks_energy = []
            step = 8000
            for i in range(0, len(y) - 48000 + 1, step):
                chunk = y[i:i+48000]
                energy = np.sum(chunk**2)
                chunks_energy.append((energy, i))
                
            chunks_energy.sort(key=lambda x: x[0], reverse=True)
            if not chunks_energy:
                continue
                
            max_energy = chunks_energy[0][0]
            energy_threshold = max_energy * 0.1
            
            selected_indices = []
            for energy, idx in chunks_energy:
                if len(selected_indices) >= 5:
                    break
                if energy < energy_threshold:
                    continue
                    
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
                    
                mel = librosa.feature.melspectrogram(
                    y=best_chunk, sr=SR, n_fft=N_FFT,
                    win_length=N_FFT, hop_length=HOP,
                    n_mels=N_MELS, fmin=300, fmax=8000
                )
                
                noise_floor = np.median(mel, axis=1, keepdims=True)
                mel_clean = np.maximum(mel - 0.8 * noise_floor, 1e-10)

                pcen_spec = librosa.pcen(
                    mel_clean, sr=SR, hop_length=HOP,
                    time_constant=0.4, gain=0.8, bias=10.0, power=0.25, eps=1e-6
                )
                
                if pcen_spec.shape[1] < TIME_FRAMES:
                    pcen_spec = np.pad(pcen_spec, ((0, 0), (0, TIME_FRAMES - pcen_spec.shape[1])), constant_values=0.0)
                else:
                    pcen_spec = pcen_spec[:, :TIME_FRAMES]
                    
                pcen_spec = pcen_spec.T[..., np.newaxis].astype(np.float32)
                    
                yield pcen_spec, l
        except Exception:
            continue

def tf_spec_augment(mel, label):
    mel = tf.cast(mel, tf.float32)
    num_mel_mask = 1
    for _ in range(num_mel_mask):
        f = tf.random.uniform([], minval=0, maxval=16, dtype=tf.int32)
        f0 = tf.random.uniform([], minval=0, maxval=N_MELS - f, dtype=tf.int32)
        mask = tf.concat([
            tf.ones([TIME_FRAMES, f0, 1]),
            tf.zeros([TIME_FRAMES, f, 1]),
            tf.ones([TIME_FRAMES, N_MELS - f0 - f, 1])
        ], axis=1)
        mel = mel * mask

    num_time_mask = 1
    for _ in range(num_time_mask):
        t = tf.random.uniform([], minval=0, maxval=16, dtype=tf.int32)
        t0 = tf.random.uniform([], minval=0, maxval=TIME_FRAMES - t, dtype=tf.int32)
        mask = tf.concat([
            tf.ones([t0, N_MELS, 1]),
            tf.zeros([t, N_MELS, 1]),
            tf.ones([TIME_FRAMES - t0 - t, N_MELS, 1])
        ], axis=0)
        mel = mel * mask
        
    return mel, label

def mixup_batch(images, labels, alpha=0.2):
    batch_size = tf.shape(images)[0]
    l = tf.random.gamma([batch_size, 1, 1, 1], alpha, beta=1.0)
    l = tf.maximum(l, 1.0 - l)
    l_labels = tf.reshape(l, [batch_size, 1])
    
    indices = tf.random.shuffle(tf.range(batch_size))
    shuffled_images = tf.gather(images, indices)
    shuffled_labels = tf.gather(labels, indices)
    
    mixed_images = l * images + (1.0 - l) * shuffled_images
    mixed_labels = l_labels * labels + (1.0 - l_labels) * shuffled_labels
    
    return mixed_images, mixed_labels

def create_tf_dataset(files, labels, shuffle=False, augment=False, mixup=False):
    ds = tf.data.Dataset.from_generator(
        lambda: audio_generator(files, labels),
        output_signature=(
            tf.TensorSpec(shape=(128, 128, 1), dtype=tf.float32),
            tf.TensorSpec(shape=(), dtype=tf.int32)
        )
    )
    ds = ds.cache()
    if shuffle:
        ds = ds.shuffle(buffer_size=1000)
    if augment:
        ds = ds.map(tf_spec_augment, num_parallel_calls=tf.data.AUTOTUNE)
    ds = ds.map(lambda x, y: (x, tf.one_hot(y, depth=NUM_CLASSES)), num_parallel_calls=tf.data.AUTOTUNE)
    ds = ds.batch(32, drop_remainder=True if mixup else False)
    if mixup:
        ds = ds.map(lambda x, y: mixup_batch(x, y, alpha=0.2), num_parallel_calls=tf.data.AUTOTUNE)
    return ds.prefetch(tf.data.AUTOTUNE)

train_files, train_labels, class_counts = get_dataset_files('train', max_per_class=400)
train_ds = create_tf_dataset(train_files, train_labels, shuffle=True, augment=True, mixup=True)

val_files, val_labels, _ = get_dataset_files('val', max_per_class=100)
val_ds = create_tf_dataset(val_files, val_labels, shuffle=False, augment=False, mixup=False)

weights = compute_class_weight(
    class_weight="balanced",
    classes=np.arange(NUM_CLASSES),
    y=np.array(train_labels)
)
class_weight_dict = dict(enumerate(weights))

def build_compact_cnn(num_classes):
    inputs = keras.Input(shape=INPUT_SHAPE, name='input')
    
    x = layers.Conv2D(32, (3, 3), padding='same', use_bias=False, name='conv1')(inputs)
    x = layers.BatchNormalization(name='bn1')(x)
    x = layers.ReLU(name='relu1')(x)
    x = layers.MaxPooling2D((2, 2), name='pool1')(x)
    
    x = layers.Conv2D(64, (3, 3), padding='same', use_bias=False, name='conv2')(x)
    x = layers.BatchNormalization(name='bn2')(x)
    x = layers.ReLU(name='relu2')(x)
    x = layers.MaxPooling2D((2, 2), name='pool2')(x)
    
    x = layers.Conv2D(128, (3, 3), padding='same', use_bias=False, name='conv3')(x)
    x = layers.BatchNormalization(name='bn3')(x)
    x = layers.ReLU(name='relu3')(x)
    x = layers.MaxPooling2D((2, 2), name='pool3')(x)
    x = layers.Dropout(0.2, name='drop3')(x)
    
    x = layers.Conv2D(256, (3, 3), padding='same', use_bias=False, name='conv4')(x)
    x = layers.BatchNormalization(name='bn4')(x)
    x = layers.ReLU(name='relu4')(x)
    x = layers.GlobalAveragePooling2D(name='gap')(x)
    x = layers.Dropout(0.3, name='drop4')(x)
    
    outputs = layers.Dense(num_classes, activation='sigmoid', name='output')(x)
    return keras.Model(inputs, outputs, name="zamzam_compact_cnn_pcen")

model = build_compact_cnn(NUM_CLASSES)

model.compile(
    optimizer=keras.optimizers.Adam(1e-3),
    loss="binary_crossentropy",
    metrics=['accuracy']
)

reduce_lr = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=4, verbose=1, min_lr=1e-6)
early_stop = EarlyStopping(monitor='val_accuracy', patience=12, restore_best_weights=True)

save_path = os.path.join(DATASET_DIR, 'best_model_compact_pcen.keras')
checkpoint = ModelCheckpoint(save_path, save_best_only=True, monitor="val_accuracy")

print(f"\n--- Lancement de l'Entraînement de Compact CNN PCEN + Égalisation ---")
print(f"Modèle sauvegardé séparément sous: {save_path}")

history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=40,
    class_weight=class_weight_dict,
    callbacks=[reduce_lr, early_stop, checkpoint]
)

best_val_acc = max(history.history['val_accuracy'])
print(f"\n==========================================")
print(f"Meilleure Précision de Validation Compact CNN PCEN: {best_val_acc * 100:.2f}%")
print(f"==========================================")
