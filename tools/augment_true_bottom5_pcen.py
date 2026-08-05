import os
import glob
import numpy as np
import librosa
from scipy import signal
import json

DATASET_DIR = os.path.join(os.path.dirname(__file__), '..', 'dataset')
CACHE_DIR = os.path.join(DATASET_DIR, 'pcen_cache')
LABELS_FILE = os.path.join(DATASET_DIR, 'labels.json')

with open(LABELS_FILE, 'r') as f:
    safe_labels = json.load(f)

# The TRUE empirical bottom 5 species
TRUE_BOTTOM_5 = [
    "greater_racket_tailed_drongo",
    "little_spiderhunter",
    "black_crested_bulbul",
    "dark_necked_tailorbird",
    "yellow_vented_bulbul"
]

SR = 16000

def apply_bandpass_filter(data, fs=16000, lowcut=300.0, highcut=7999.0, order=5):
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

def extract_audio_segments_pcen(wav_path):
    try:
        y, sr = librosa.load(wav_path, sr=SR, mono=True)
        if len(y) < SR * 0.5:
            return None, None
        y = apply_bandpass_filter(y, SR)
        
        target_len = SR * 3
        if len(y) < target_len:
            y = np.pad(y, (0, target_len - len(y)), mode='constant')
            
        chunks = []
        hop = target_len // 2
        for start in range(0, len(y) - target_len + 1, hop):
            chunk = y[start:start + target_len]
            rms = np.sqrt(np.mean(chunk**2))
            chunks.append((rms, chunk))
            
        if not chunks:
            chunks.append((1.0, y[:target_len]))
            
        chunks.sort(key=lambda x: x[0], reverse=True)
        top_chunks = [c[1] for c in chunks[:5]]
        
        # Pitch Shift +1
        pcen_64_aug1, pcen_128_aug1 = [], []
        for c in top_chunks:
            c_aug1 = librosa.effects.pitch_shift(c, sr=SR, n_steps=1)
            pcen_64_aug1.append(extract_pcen(c_aug1, n_fft=1024, hop=160, n_mels=64, time_frames=300))
            pcen_128_aug1.append(extract_pcen(c_aug1, n_fft=512, hop=375, n_mels=128, time_frames=128))
            
        # Pitch Shift -1
        pcen_64_aug2, pcen_128_aug2 = [], []
        for c in top_chunks:
            c_aug2 = librosa.effects.pitch_shift(c, sr=SR, n_steps=-1)
            pcen_64_aug2.append(extract_pcen(c_aug2, n_fft=1024, hop=160, n_mels=64, time_frames=300))
            pcen_128_aug2.append(extract_pcen(c_aug2, n_fft=512, hop=375, n_mels=128, time_frames=128))
            
        return (np.array(pcen_64_aug1), np.array(pcen_128_aug1)), (np.array(pcen_64_aug2), np.array(pcen_128_aug2))
    except Exception as e:
        return None, None

def generate_augmented_tensors():
    print("Generating Targeted Pitch-Shifted (.npy) PCEN Tensors for TRUE REAL 5 Bottom Species...")
    for species in TRUE_BOTTOM_5:
        src_dir = os.path.join(DATASET_DIR, 'train', species)
        dst_dir = os.path.join(CACHE_DIR, 'train', species)
        wav_files = glob.glob(os.path.join(src_dir, '*.wav'))
        print(f"Processing species '{species}' ({len(wav_files)} files)...")
        
        count = 0
        for wav_path in wav_files:
            base_name = os.path.splitext(os.path.basename(wav_path))[0]
            npy_64_aug1 = os.path.join(dst_dir, f"{base_name}_64_aug1.npy")
            npy_128_aug1 = os.path.join(dst_dir, f"{base_name}_128_aug1.npy")
            npy_64_aug2 = os.path.join(dst_dir, f"{base_name}_64_aug2.npy")
            npy_128_aug2 = os.path.join(dst_dir, f"{base_name}_128_aug2.npy")
            
            if os.path.exists(npy_64_aug1) and os.path.exists(npy_64_aug2):
                continue
                
            aug1, aug2 = extract_audio_segments_pcen(wav_path)
            if aug1 is not None and aug2 is not None:
                np.save(npy_64_aug1, aug1[0])
                np.save(npy_128_aug1, aug1[1])
                np.save(npy_64_aug2, aug2[0])
                np.save(npy_128_aug2, aug2[1])
                count += 1
        print(f"  -> Generated {count*2} new augmented PCEN tensors for '{species}'")

if __name__ == '__main__':
    generate_augmented_tensors()
