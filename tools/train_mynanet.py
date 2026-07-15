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

# MynaNet audio parameters (optimal N_MELS = 64)
SR = 16000
N_FFT = 1024
HOP = 160
N_MELS = 64
TIME_FRAMES = 300
INPUT_SHAPE = (64, 300, 1)

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
                
            max_energy = -1.0
            best_chunk = y[:48000]
            step = 16000
            for i in range(0, len(y) - 48000 + 1, step):
                chunk = y[i:i+48000]
                energy = np.sum(chunk**2)
                if energy > max_energy:
                    max_energy = energy
                    best_chunk = chunk
                    
            max_amp = np.max(np.abs(best_chunk))
            if max_amp > 0.0:
                best_chunk = best_chunk / (max_amp + 1e-7)
                
            # Log-Mel Spectrogram computation (MynaNet settings)
            mel = librosa.feature.melspectrogram(
                y=best_chunk, sr=SR, n_fft=N_FFT,
                win_length=400, hop_length=HOP,
                n_mels=N_MELS, fmin=300, fmax=8000
            )
            
            # Ensure exact 300 frames
            if mel.shape[1] < TIME_FRAMES:
                mel = np.pad(mel, ((0, 0), (0, TIME_FRAMES - mel.shape[1])), constant_values=1e-10)
            else:
                mel = mel[:, :TIME_FRAMES]
                
            logmel = 10 * np.log10(mel + 1e-10)
            # Clip between -100 and 0
            logmel = np.clip(logmel, -100.0, 0.0)
            # Scale to [0, 1]
            logmel = (logmel + 100.0) / 100.0
            
            # Add channel (MynaNet shape: [nMels, nFrames, 1])
            logmel = logmel[..., np.newaxis]
                
            yield logmel, l
        except Exception:
            continue

def numpy_spec_augment(mel):
    # mel shape: (64, 300, 1)
    augmented = mel.copy()
    
    # Frequency masking (max 8 Mel bands out of 64)
    f = np.random.randint(0, 8)
    f0 = np.random.randint(0, 64 - f)
    augmented[f0:f0+f, :, :] = 0.0
    
    # Time masking (max 35 frames out of 300)
    t = np.random.randint(0, 35)
    t0 = np.random.randint(0, 300 - t)
    augmented[:, t0:t0+t, :] = 0.0
    
    return augmented

def tf_spec_augment(mel, label):
    augmented_mel = tf.numpy_function(numpy_spec_augment, [mel], tf.float32)
    augmented_mel.set_shape((64, 300, 1))
    return augmented_mel, label

def mixup_batch(images, labels, alpha=0.2):
    batch_size = tf.shape(images)[0]
    
    alpha_tensor = tf.fill([batch_size, 1, 1, 1], alpha)
    gamma_1 = tf.random.gamma(shape=[], alpha=alpha_tensor)
    gamma_2 = tf.random.gamma(shape=[], alpha=alpha_tensor)
    l = gamma_1 / (gamma_1 + gamma_2)
    
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
            tf.TensorSpec(shape=(64, 300, 1), dtype=tf.float32),
            tf.TensorSpec(shape=(), dtype=tf.int32)
        )
    )
    # Cache base dataset in memory
    ds = ds.cache()
    
    if shuffle:
        ds = ds.shuffle(buffer_size=1000)
        
    if augment:
        ds = ds.map(tf_spec_augment, num_parallel_calls=tf.data.AUTOTUNE)
        
    # One-Hot encoding to support Mixup and CategoricalCrossentropy
    ds = ds.map(lambda x, y: (x, tf.one_hot(y, depth=NUM_CLASSES)), num_parallel_calls=tf.data.AUTOTUNE)
    
    # Batch
    ds = ds.batch(32, drop_remainder=True if mixup else False)
    
    if mixup:
        ds = ds.map(lambda x, y: mixup_batch(x, y, alpha=0.2), num_parallel_calls=tf.data.AUTOTUNE)
        
    return ds.prefetch(tf.data.AUTOTUNE)

train_files, train_labels, class_counts = get_dataset_files('train', max_per_class=400)
train_ds = create_tf_dataset(train_files, train_labels, shuffle=True, augment=True, mixup=True)

val_files, val_labels, _ = get_dataset_files('val', max_per_class=100)
val_ds = create_tf_dataset(val_files, val_labels, shuffle=False, augment=False, mixup=False)

# Compute class weights
weights = compute_class_weight(
    class_weight="balanced",
    classes=np.arange(NUM_CLASSES),
    y=np.array(train_labels)
)
class_weight_dict = dict(enumerate(weights))

def se_block(x, filters, reduction=16, block_id=0):
    prefix = f'block{block_id}_se_'
    se = layers.GlobalAveragePooling2D(keepdims=True, name=prefix + 'squeeze')(x)
    se = layers.Conv2D(
        filters // reduction, (1, 1), activation='relu',
        use_bias=True, name=prefix + 'reduce'
    )(se)
    se = layers.Conv2D(
        filters, (1, 1),
        use_bias=True, name=prefix + 'expand'
    )(se)
    se = layers.Lambda(
        lambda t: tf.nn.relu6(t + 3.0) * (1.0 / 6.0),
        name=prefix + 'hard_sigmoid'
    )(se)
    return layers.Multiply(name=prefix + 'scale')([x, se])

def inverted_residual_se(x, filters, kernel_size=(3, 3), strides=(1, 1),
                          expand_ratio=6, block_id=0, se_reduction=16):
    prefix = f'block{block_id}_'
    input_channels = x.shape[-1]
    expanded = input_channels * expand_ratio
    shortcut = x

    x = layers.Conv2D(
        expanded, (1, 1), padding='same',
        use_bias=False, name=prefix + 'expand'
    )(x)
    x = layers.BatchNormalization(momentum=0.9, name=prefix + 'expand_bn')(x)
    x = layers.ReLU(6., name=prefix + 'expand_relu')(x)

    x = layers.DepthwiseConv2D(
        kernel_size, strides=strides, padding='same',
        use_bias=False, name=prefix + 'depthwise'
    )(x)
    x = layers.BatchNormalization(momentum=0.9, name=prefix + 'depthwise_bn')(x)
    x = layers.ReLU(6., name=prefix + 'depthwise_relu')(x)

    x = se_block(x, expanded, reduction=max(1, expand_ratio * se_reduction // 16),
                 block_id=block_id)

    x = layers.Conv2D(
        filters, (1, 1), padding='same',
        use_bias=False, name=prefix + 'project'
    )(x)
    x = layers.BatchNormalization(momentum=0.9, name=prefix + 'project_bn')(x)

    if input_channels == filters and strides == (1, 1):
        x = layers.Add(name=prefix + 'residual')([x, shortcut])

    return x

def build_mynanet(num_classes):
    inputs = keras.Input(shape=INPUT_SHAPE, name='input')

    # Stem
    x = layers.Conv2D(32, (3, 3), padding='same', use_bias=False, name='stem_conv')(inputs)
    x = layers.BatchNormalization(momentum=0.9, name='stem_bn')(x)
    x = layers.ReLU(6., name='stem_relu')(x)

    # Block 1: t=1, 32->16, dw=3x3
    x = inverted_residual_se(x, 16, kernel_size=(3, 3), block_id=1, expand_ratio=1, se_reduction=4)
    x = layers.MaxPooling2D((2, 2), name='pool1')(x)
    x = layers.Dropout(0.1, name='drop1')(x)

    # Block 2: t=6, 16->24, dw=3x3
    x = inverted_residual_se(x, 24, kernel_size=(3, 3), block_id=2, expand_ratio=6, se_reduction=8)
    x = layers.MaxPooling2D((2, 2), name='pool2')(x)
    x = layers.Dropout(0.1, name='drop2')(x)

    # Block 3: t=6, 24->48, dw=5x5
    x = inverted_residual_se(x, 48, kernel_size=(5, 5), block_id=3, expand_ratio=6, se_reduction=16)
    x = layers.MaxPooling2D((2, 2), name='pool3')(x)
    x = layers.Dropout(0.15, name='drop3')(x)

    # Block 4: t=6, 48->96, dw=5x5
    x = inverted_residual_se(x, 96, kernel_size=(5, 5), block_id=4, expand_ratio=6, se_reduction=16)
    x = layers.MaxPooling2D((2, 2), name='pool4')(x)
    x = layers.Dropout(0.2, name='drop4')(x)

    # Last-stage expansion
    x = layers.Conv2D(320, (1, 1), padding='same', use_bias=False, name='last_conv')(x)
    x = layers.BatchNormalization(momentum=0.9, name='last_bn')(x)
    x = layers.ReLU(6., name='last_relu')(x)

    # Head
    x = layers.GlobalAveragePooling2D(name='global_pool')(x)
    x = layers.Dense(128, name='fc1')(x)
    x = layers.BatchNormalization(momentum=0.9, name='fc1_bn')(x)
    x = layers.ReLU(6., name='fc1_relu')(x)
    x = layers.Dropout(0.3, name='fc_drop')(x)
    
    # Replaced by SIGMOID activation for multi-label / robust classification
    outputs = layers.Dense(num_classes, activation='sigmoid', name='output')(x)

    return keras.Model(inputs, outputs, name="MynaNet_MBV3_SE")

model = build_mynanet(NUM_CLASSES)

# Compilation (Use binary_crossentropy for multi-label Sigmoid)
# We use CategoricalAccuracy named 'accuracy' to preserve compatibility with metrics and callbacks
model.compile(
    optimizer=keras.optimizers.Adam(1e-3),
    loss="binary_crossentropy",
    metrics=[keras.metrics.CategoricalAccuracy(name='accuracy')]
)

reduce_lr = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=4, verbose=1, min_lr=1e-6)
early_stop = EarlyStopping(monitor='val_accuracy', patience=12, restore_best_weights=True)
checkpoint = ModelCheckpoint(os.path.join(DATASET_DIR, 'best_model_mynanet.keras'), save_best_only=True, monitor="val_accuracy")

print(f'\nEntraînement de MynaNet sur GPU Local avec Sigmoid + Binary Crossentropy pour {NUM_CLASSES} classes...')
history = model.fit(
    train_ds, 
    validation_data=val_ds, 
    epochs=50, 
    class_weight=class_weight_dict,
    callbacks=[early_stop, reduce_lr, checkpoint]
)

# Save full model
model.save(os.path.join(DATASET_DIR, 'saved_model_mynanet.keras'))

# Plot accuracy
plt.figure(figsize=(10, 6))
plt.plot(history.history['accuracy'], label='Train Accuracy')
plt.plot(history.history['val_accuracy'], label='Validation Accuracy')
plt.title('Learning Curve - MynaNet with Sigmoid + BCE')
plt.ylabel('Accuracy')
plt.xlabel('Epoch')
plt.legend()
plt.savefig(os.path.join(DATASET_DIR, 'mynanet_training_history.png'))
print("MynaNet model saved and curves generated.")
