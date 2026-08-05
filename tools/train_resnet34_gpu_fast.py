import os
import sys
import glob

# Load CUDA DLLs installed via pip for GPU execution
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

# Check GPU availability
gpus = tf.config.list_physical_devices('GPU')
print(f"GPUs detected by TensorFlow: {gpus}")

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
CACHE_DIR = os.path.join(DATASET_DIR, 'pcen_cache')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

NUM_CLASSES = len(safe_labels)
INPUT_SHAPE_128 = (128, 128, 1)

def get_cached_dataset_files(split, suffix='_128.npy', max_per_class=800):
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

train_files_128, train_labels_128 = get_cached_dataset_files('train', '_128.npy', max_per_class=800)
val_files_128, val_labels_128 = get_cached_dataset_files('val', '_128.npy', max_per_class=400)

print(f"Loaded {len(train_files_128)} GPU cached train tensors, {len(val_files_128)} val tensors.")

class_weights_arr = compute_class_weight('balanced', classes=np.unique(train_labels_128), y=train_labels_128)
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
                yield spec.T[..., np.newaxis], label_vec
        except Exception:
            continue

train_ds = tf.data.Dataset.from_generator(
    lambda: cached_generator(train_files_128, train_labels_128, is_training=True),
    output_signature=(
        tf.TensorSpec(shape=INPUT_SHAPE_128, dtype=tf.float32),
        tf.TensorSpec(shape=(NUM_CLASSES,), dtype=tf.float32)
    )
).batch(32).prefetch(tf.data.AUTOTUNE)

val_ds = tf.data.Dataset.from_generator(
    lambda: cached_generator(val_files_128, val_labels_128, is_training=False),
    output_signature=(
        tf.TensorSpec(shape=INPUT_SHAPE_128, dtype=tf.float32),
        tf.TensorSpec(shape=(NUM_CLASSES,), dtype=tf.float32)
    )
).batch(32).prefetch(tf.data.AUTOTUNE)

def resnet_block(input_tensor, filters, stride=1):
    x = layers.Conv2D(filters, (3, 3), strides=stride, padding='same', use_bias=False)(input_tensor)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('swish')(x)
    
    x = layers.Conv2D(filters, (3, 3), strides=1, padding='same', use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    
    shortcut = input_tensor
    if stride != 1 or input_tensor.shape[-1] != filters:
        shortcut = layers.Conv2D(filters, (1, 1), strides=stride, padding='same', use_bias=False)(input_tensor)
        shortcut = layers.BatchNormalization()(shortcut)
        
    x = layers.add([x, shortcut])
    x = layers.Activation('swish')(x)
    return x

def build_resnet34_gpu(input_shape=(128, 128, 1), num_classes=27):
    inputs = keras.Input(shape=input_shape)
    
    x = layers.Conv2D(32, (3, 3), strides=1, padding='same', use_bias=False)(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('swish')(x)
    
    # Stage 1
    x = resnet_block(x, 32, stride=1)
    x = resnet_block(x, 32, stride=1)
    
    # Stage 2
    x = resnet_block(x, 64, stride=2)
    x = resnet_block(x, 64, stride=1)
    
    # Stage 3
    x = resnet_block(x, 128, stride=2)
    x = resnet_block(x, 128, stride=1)
    
    # Stage 4
    x = resnet_block(x, 256, stride=2)
    x = resnet_block(x, 256, stride=1)
    
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation='swish')(x)
    outputs = layers.Dense(num_classes, activation='sigmoid')(x)
    
    model = keras.Model(inputs, outputs, name="ResNet34_GPU_27Sp")
    return model

model = build_resnet34_gpu(input_shape=INPUT_SHAPE_128, num_classes=NUM_CLASSES)

initial_lr = 1e-3
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=initial_lr),
    loss='binary_crossentropy',
    metrics=['accuracy']
)

MODEL_SAVE_PATH = os.path.join(DATASET_DIR, 'best_model_resnet34_27sp_pcen.keras')

callbacks = [
    EarlyStopping(monitor='val_accuracy', patience=12, restore_best_weights=True, verbose=1),
    ModelCheckpoint(MODEL_SAVE_PATH, monitor='val_accuracy', save_best_only=True, verbose=1),
    keras.callbacks.ReduceLROnPlateau(monitor='val_accuracy', factor=0.5, patience=4, min_lr=1e-5, verbose=1)
]

print("\n--- Starting Fast GPU Training of ResNet34-Lite PCEN ---")
history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=40,
    callbacks=callbacks,
    class_weight=class_weights_dict
)

val_acc = max(history.history['val_accuracy'])
print(f"\n==========================================")
print(f"ResNet34-Lite GPU Validation Accuracy: {val_acc*100:.2f}%")
print(f"==========================================")
