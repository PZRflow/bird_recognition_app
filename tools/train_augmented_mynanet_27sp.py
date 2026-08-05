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

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
CACHE_DIR = os.path.join(DATASET_DIR, 'pcen_cache')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

NUM_CLASSES = len(safe_labels)
INPUT_SHAPE_64 = (64, 300, 1)

def get_cached_dataset_files(split, suffix='_64.npy', max_per_class=1200):
    all_files_by_class = []
    for i, label_name in enumerate(safe_labels):
        pattern = os.path.join(CACHE_DIR, split, label_name, f'*{suffix}')
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
    return list(selected_files), list(selected_labels)

train_files_64, train_labels_64 = get_cached_dataset_files('train', '_64.npy', max_per_class=1200)
val_files_64, val_labels_64 = get_cached_dataset_files('val', '_64.npy', max_per_class=400)

print(f"Loaded {len(train_files_64)} training PCEN tensors (including Pitch-Shifted data for 5 bottom species).")

class_weights_arr = compute_class_weight('balanced', classes=np.unique(train_labels_64), y=train_labels_64)
class_weights_dict = dict(enumerate(class_weights_arr))

def cached_generator(files, labels, is_training=True):
    indices = list(range(len(files)))
    if is_training:
        random.shuffle(indices)
        
    for i in indices:
        f = files[i]
        l = labels[i]
        try:
            specs = np.load(f)
            label_vec = keras.utils.to_categorical(l, num_classes=NUM_CLASSES)
            for spec in specs:
                yield spec[..., np.newaxis], label_vec
        except Exception:
            continue

train_ds = tf.data.Dataset.from_generator(
    lambda: cached_generator(train_files_64, train_labels_64, is_training=True),
    output_signature=(
        tf.TensorSpec(shape=INPUT_SHAPE_64, dtype=tf.float32),
        tf.TensorSpec(shape=(NUM_CLASSES,), dtype=tf.float32)
    )
).batch(32).prefetch(tf.data.AUTOTUNE)

val_ds = tf.data.Dataset.from_generator(
    lambda: cached_generator(val_files_64, val_labels_64, is_training=False),
    output_signature=(
        tf.TensorSpec(shape=INPUT_SHAPE_64, dtype=tf.float32),
        tf.TensorSpec(shape=(NUM_CLASSES,), dtype=tf.float32)
    )
).batch(32).prefetch(tf.data.AUTOTUNE)

def se_block(input_tensor, ratio=16):
    channels = input_tensor.shape[-1]
    se = layers.GlobalAveragePooling2D()(input_tensor)
    se = layers.Dense(channels // ratio, activation='relu')(se)
    se = layers.Dense(channels, activation='sigmoid')(se)
    se = layers.Reshape((1, 1, channels))(se)
    return layers.Multiply()([input_tensor, se])

def build_mynanet_aug(input_shape=(64, 300, 1), num_classes=27):
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
    
    model = keras.Model(inputs, outputs, name="MynaNet_27Sp_Augmented")
    return model

model = build_mynanet_aug(input_shape=INPUT_SHAPE_64, num_classes=NUM_CLASSES)

initial_lr = 1e-3
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=initial_lr),
    loss='binary_crossentropy',
    metrics=['accuracy']
)

MODEL_SAVE_PATH = os.path.join(DATASET_DIR, 'best_model_mynanet_27sp_augmented.keras')

callbacks = [
    EarlyStopping(monitor='val_accuracy', patience=12, restore_best_weights=True, verbose=1),
    ModelCheckpoint(MODEL_SAVE_PATH, monitor='val_accuracy', save_best_only=True, verbose=1),
    keras.callbacks.ReduceLROnPlateau(monitor='val_accuracy', factor=0.5, patience=4, min_lr=1e-5, verbose=1)
]

print("\n--- Training MynaNet on Pitch-Shifted Dataset Cache ---")
history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=40,
    callbacks=callbacks,
    class_weight=class_weights_dict
)

val_acc = max(history.history['val_accuracy'])
print(f"\n==========================================")
print(f"MynaNet Augmented Validation Accuracy: {val_acc*100:.2f}%")
print(f"Baseline MynaNet PCEN Solo Record: 84.32%")
print(f"==========================================")
