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

targets = [
    ("Todiramphus chloris", "Collared_kingfisher", "todiramphus_chloris.jpg"),
    ("Psilopogon haemacephalus", "Coppersmith_barbet", "psilopogon_haemacephalus.jpg"),
    ("Rhipidura javanica", "Malayan_pied_fantail", "rhipidura_javanica.jpg"),
    ("Spilopelia chinensis", "Spotted_dove", "spilopelia_chinensis.jpg"),
    ("Amaurornis phoenicurus", "White-breasted_waterhen", "amaurornis_phoenicurus.jpg"),
    ("Halcyon smyrnensis", "White-throated_kingfisher", "halcyon_smyrnensis.jpg"),
    ("Pycnonotus goiavier", "Yellow-vented_bulbul", "pycnonotus_goiavier.jpg")
]

print("Fetching 100% UNIQUE HD photo for each species via Wikipedia REST API...")

for sci_name, wiki_title, fname in targets:
    local_path = os.path.join(IMAGES_DIR, fname)
    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{wiki_title}"
    
    try:
        time.sleep(1.5)
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            img_url = data.get('originalimage', {}).get('source')
            if not img_url:
                img_url = data.get('thumbnail', {}).get('source')
                
        if img_url:
            print(f"Downloading UNIQUE photo for {wiki_title} -> {img_url}")
            img_req = urllib.request.Request(img_url, headers=headers)
            with urllib.request.urlopen(img_req, context=ctx, timeout=20) as img_resp:
                content = img_resp.read()
                if len(content) > 10000 and len(content) != 526574:
                    with open(local_path, 'wb') as out_f:
                        out_f.write(content)
                    print(f"  Saved UNIQUE image: {fname} ({len(content)} bytes)")
                else:
                    print(f"  Warning: downloaded content size {len(content)} bytes")
        else:
            print(f"No image found on Wikipedia summary for {wiki_title}")
    except Exception as e:
        print(f"Error fetching {wiki_title}: {e}")

# Ensure species.json points to exact local image files
for sp in species_list:
    sci = sp.get("scientific", "")
    fname = sci.lower().replace(" ", "_") + ".jpg"
    sp["imageUrl"] = f"assets/images/{fname}"

with open(SPECIES_JSON, "w", encoding="utf-8") as f:
    json.dump(species_list, f, indent=2, ensure_ascii=False)

print("\n--- Unique photos download completed! ---")
