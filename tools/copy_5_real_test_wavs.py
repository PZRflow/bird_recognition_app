import os
import glob
import shutil

DATASET_DIR = r"C:\Users\Marc\bird_recognition\dataset"
TEST_OUT_DIR = os.path.join(DATASET_DIR, "test_samples_mobile")

os.makedirs(TEST_OUT_DIR, exist_ok=True)

species_selection = [
    ("asian_koel", "1_Asian_Koel_Test.wav"),
    ("yellow_vented_bulbul", "2_Yellow_Vented_Bulbul_Test.wav"),
    ("collared_kingfisher", "3_Collared_Kingfisher_Test.wav"),
    ("greater_racket_tailed_drongo", "4_Greater_Racket_Tailed_Drongo_Test.wav"),
    ("spotted_dove", "5_Spotted_Dove_Test.wav")
]

print("Copying 5 distinct audio samples from 27-species dataset...")

for sp_folder, out_name in species_selection:
    search_path = os.path.join(DATASET_DIR, "train", sp_folder, "*.wav")
    wav_files = glob.glob(search_path)
    if not wav_files:
        search_path_val = os.path.join(DATASET_DIR, "val", sp_folder, "*.wav")
        wav_files = glob.glob(search_path_val)
        
    if wav_files:
        src = wav_files[0]
        dst = os.path.join(TEST_OUT_DIR, out_name)
        shutil.copyfile(src, dst)
        print(f"Copied sample for {sp_folder} -> {out_name}")
    else:
        print(f"No WAV found for {sp_folder}")

print("\nFinal verified files in dataset/test_samples_mobile:")
for f in sorted(os.listdir(TEST_OUT_DIR)):
    print(f" - {f}")
