import os
import sys
import glob

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

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint
from sklearn.utils.class_weight import compute_class_weight
import numpy as np
import json

# Enable GPU Memory Growth to prevent OOM
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
    except RuntimeError as e:
        pass

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
CACHE_DIR = os.path.join(DATASET_DIR, 'pcen_cache')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

NUM_CLASSES = len(safe_labels)

print("Pre-loading cached PCEN tensors directly into RAM...")

def load_all_into_ram(split, suffix='_128.npy'):
    X_list = []
    y_list = []
    for i, label_name in enumerate(safe_labels):
        pattern = os.path.join(CACHE_DIR, split, label_name, f'*{suffix}')
        files = glob.glob(pattern)
        for f in files:
            try:
                specs = np.load(f)
                for spec in specs:
                    X_list.append(spec.T[..., np.newaxis])
                    y_list.append(i)
            except Exception:
                continue
    X = np.array(X_list, dtype=np.float32)
    y = keras.utils.to_categorical(np.array(y_list), num_classes=NUM_CLASSES)
    return X, y

X_train, y_train = load_all_into_ram('train', '_128.npy')
X_val, y_val = load_all_into_ram('val', '_128.npy')

print(f"RAM Pre-load Complete! Train shape: {X_train.shape}, Val shape: {X_val.shape}")

y_train_indices = np.argmax(y_train, axis=1)
class_weights_arr = compute_class_weight('balanced', classes=np.unique(y_train_indices), y=y_train_indices)
class_weights_dict = dict(enumerate(class_weights_arr))

def resnet_block_light(input_tensor, filters, stride=1):
    x = layers.SeparableConv2D(filters, (3, 3), strides=stride, padding='same', use_bias=False)(input_tensor)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('swish')(x)
    
    x = layers.SeparableConv2D(filters, (3, 3), strides=1, padding='same', use_bias=False)(x)
    x = layers.BatchNormalization()(x)
    
    shortcut = input_tensor
    if stride != 1 or input_tensor.shape[-1] != filters:
        shortcut = layers.Conv2D(filters, (1, 1), strides=stride, padding='same', use_bias=False)(input_tensor)
        shortcut = layers.BatchNormalization()(shortcut)
        
    x = layers.add([x, shortcut])
    x = layers.Activation('swish')(x)
    return x

def build_resnet34_light(input_shape=(128, 128, 1), num_classes=27):
    inputs = keras.Input(shape=input_shape)
    
    x = layers.Conv2D(32, (3, 3), strides=1, padding='same', use_bias=False)(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.Activation('swish')(x)
    
    # Stage 1
    x = resnet_block_light(x, 32, stride=1)
    x = resnet_block_light(x, 32, stride=1)
    
    # Stage 2
    x = resnet_block_light(x, 64, stride=2)
    x = resnet_block_light(x, 64, stride=1)
    
    # Stage 3
    x = resnet_block_light(x, 128, stride=2)
    x = resnet_block_light(x, 128, stride=1)
    
    # Stage 4
    x = resnet_block_light(x, 256, stride=2)
    x = resnet_block_light(x, 256, stride=1)
    
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation='swish')(x)
    outputs = layers.Dense(num_classes, activation='sigmoid')(x)
    
    model = keras.Model(inputs, outputs, name="ResNet34_Light_RAM")
    return model

model = build_resnet34_light(input_shape=(128, 128, 1), num_classes=NUM_CLASSES)

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-3),
    loss='binary_crossentropy',
    metrics=['accuracy']
)

MODEL_SAVE_PATH = os.path.join(DATASET_DIR, 'best_model_resnet34_light.keras')

callbacks = [
    EarlyStopping(monitor='val_accuracy', patience=12, restore_best_weights=True, verbose=1),
    ModelCheckpoint(MODEL_SAVE_PATH, monitor='val_accuracy', save_best_only=True, verbose=1),
    keras.callbacks.ReduceLROnPlateau(monitor='val_accuracy', factor=0.5, patience=4, min_lr=1e-5, verbose=1)
]

print("\n--- Training Light ResNet34 In-Memory (Batch Size 32 + GPU Memory Growth) ---")

history = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    batch_size=32,
    epochs=40,
    callbacks=callbacks,
    class_weight=class_weights_dict
)

val_acc = max(history.history['val_accuracy'])
print(f"\n==========================================")
print(f"ResNet34-Light RAM Validation Accuracy: {val_acc*100:.2f}%")
print(f"==========================================")
