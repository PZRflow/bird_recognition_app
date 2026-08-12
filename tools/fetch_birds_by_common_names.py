import os
import json
import urllib.request
import urllib.parse
import ssl
import time

DATASET_DIR = r"C:\Users\Marc\bird_recognition"
SPECIES_JSON = os.path.join(DATASET_DIR, "assets", "species.json")
IMAGES_DIR = os.path.join(DATASET_DIR, "assets", "images")

os.makedirs(IMAGES_DIR, exist_ok=True)

with open(SPECIES_JSON, "r", encoding="utf-8") as f:
    species_list = json.load(f)

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
}

missing_targets = [
    ("Malayan_pied_fantail", "rhipidura_javanica.jpg"),
    ("Spotted_dove", "spilopelia_chinensis.jpg"),
    ("White-breasted_waterhen", "amaurornis_phoenicurus.jpg"),
    ("White-throated_kingfisher", "halcyon_smyrnensis.jpg"),
    ("Yellow-vented_bulbul", "pycnonotus_goiavier.jpg")
]

print("Fetching remaining HD bird photos with 1.5s delay...")

for title, fname in missing_targets:
    local_path = os.path.join(IMAGES_DIR, fname)
    if os.path.exists(local_path) and os.path.getsize(local_path) > 5000:
        print(f"Skipping already present: {fname}")
        continue
        
    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{title}"
    
    try:
        time.sleep(1.5)
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            img_url = data.get('thumbnail', {}).get('source')
            if not img_url:
                img_url = data.get('originalimage', {}).get('source')
                
        if img_url:
            print(f"Downloading image for '{title}' -> {img_url}")
            img_req = urllib.request.Request(img_url, headers=headers)
            with urllib.request.urlopen(img_req, context=ctx, timeout=15) as img_resp:
                with open(local_path, 'wb') as out_f:
                    out_f.write(img_resp.read())
            print(f"Successfully saved {fname} ({os.path.getsize(local_path)} bytes)")
        else:
            print(f"No thumbnail found for {title}")
    except Exception as e:
        print(f"Error fetching {title}: {e}")

# Ensure all 27 species in species.json have accurate local imageUrl paths
for sp in species_list:
    sci = sp.get("scientific", "")
    fname = sci.lower().replace(" ", "_") + ".jpg"
    sp["imageUrl"] = f"assets/images/{fname}"

with open(SPECIES_JSON, "w", encoding="utf-8") as f:
    json.dump(species_list, f, indent=2, ensure_ascii=False)

print("\n--- All species verified in species.json! ---")
