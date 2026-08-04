import os
import sys
import glob
import numpy as np
import librosa
from scipy import signal
import json

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

CACHE_DIR = os.path.join(DATASET_DIR, 'pcen_cache')
os.makedirs(CACHE_DIR, exist_ok=True)

SR = 16000

def apply_bandpass_filter(data, fs, lowcut=300.0, highcut=7999.0, order=5):
    nyq = 0.5 * fs
    low = lowcut / nyq
    high = highcut / nyq
    sos = signal.butter(order, [low, high], btype='band', output='sos')
    return signal.sosfiltfilt(sos, data)

def extract_pcen(y, n_fft, hop, n_mels, time_frames):
    max_amp = np.max(np.abs(y))
    if max_amp > 0:
        y = y / (max_amp + 1e-7)
    mel = librosa.feature.melspectrogram(
        y=y, sr=SR, n_fft=n_fft, win_length=400 if n_fft==1024 and hop==160 else n_fft,
        hop_length=hop, n_mels=n_mels, fmin=300, fmax=8000
    )
    noise_floor = np.median(mel, axis=1, keepdims=True)
    mel_clean = np.maximum(mel - 0.8 * noise_floor, 1e-10)
    pcen = librosa.pcen(
        mel_clean, sr=SR, hop_length=hop, time_constant=0.4, gain=0.8, bias=10.0, power=0.25, eps=1e-6
    )
    if pcen.shape[1] < time_frames:
        pcen = np.pad(pcen, ((0,0),(0, time_frames - pcen.shape[1])), constant_values=0.0)
    else:
        pcen = pcen[:, :time_frames]
    return pcen.astype(np.float32)

print("Starting Offline PCEN Pre-computation into dataset/pcen_cache/...")

for split in ['train', 'val']:
    split_dir = os.path.join(CACHE_DIR, split)
    os.makedirs(split_dir, exist_ok=True)
    
    total_files = 0
    processed_files = 0
    
    for label_idx, label_name in enumerate(safe_labels):
        src_dir = os.path.join(DATASET_DIR, split, label_name)
        dst_dir = os.path.join(split_dir, label_name)
        os.makedirs(dst_dir, exist_ok=True)
        
        wav_files = glob.glob(os.path.join(src_dir, '*.wav'))
        total_files += len(wav_files)
        
        for wav_path in wav_files:
            base_name = os.path.splitext(os.path.basename(wav_path))[0]
            npy_path_64 = os.path.join(dst_dir, f"{base_name}_64.npy")
            npy_path_128 = os.path.join(dst_dir, f"{base_name}_128.npy")
            
            if os.path.exists(npy_path_64) and os.path.exists(npy_path_128):
                processed_files += 1
                continue
                
            try:
                y, sr = librosa.load(wav_path, sr=SR, mono=True, dtype=np.float32)
                y = apply_bandpass_filter(y, sr).astype(np.float32)
                
                if len(y) < 48000:
                    y = np.pad(y, (0, 48000 - len(y)))
                    
                chunks_energy = []
                step = 8000
                for idx in range(0, len(y) - 48000 + 1, step):
                    c = y[idx:idx+48000]
                    chunks_energy.append((np.sum(c**2), idx))
                    
                if not chunks_energy:
                    chunks_energy.append((np.sum(y[:48000]**2), 0))
                    
                chunks_energy.sort(key=lambda x: x[0], reverse=True)
                max_e = chunks_energy[0][0]
                
                selected_indices = []
                for e, idx in chunks_energy:
                    if len(selected_indices) >= 5: break
                    if e < max_e * 0.1: continue
                    if not any(abs(idx - sel) < 48000 for sel in selected_indices):
                        selected_indices.append(idx)
                        
                if not selected_indices:
                    selected_indices = [chunks_energy[0][1]]
                    
                specs_64 = []
                specs_128 = []
                
                for idx in selected_indices:
                    chunk = y[idx:idx+48000]
                    pcen_64 = extract_pcen(chunk, n_fft=1024, hop=160, n_mels=64, time_frames=300)
                    pcen_128 = extract_pcen(chunk, n_fft=1024, hop=512, n_mels=128, time_frames=128)
                    specs_64.append(pcen_64)
                    specs_128.append(pcen_128)
                    
                np.save(npy_path_64, np.array(specs_64, dtype=np.float32))
                np.save(npy_path_128, np.array(specs_128, dtype=np.float32))
                processed_files += 1
            except Exception as e:
                continue
                
    print(f"Finished split '{split}': Processed {processed_files}/{total_files} audio files into PCEN .npy cache.")

print("\nAll PCEN features successfully pre-computed into dataset/pcen_cache/!")
