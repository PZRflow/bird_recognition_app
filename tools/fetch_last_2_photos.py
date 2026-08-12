import os
import json
import urllib.request
import urllib.parse
import ssl
import time

DATASET_DIR = r"C:\Users\Marc\bird_recognition"
IMAGES_DIR = os.path.join(DATASET_DIR, "assets", "images")

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
}

last_2 = [
    ("Pied_fantail", "rhipidura_javanica.jpg"),
    ("Yellow-vented_bulbul", "pycnonotus_goiavier.jpg")
]

print("Downloading last 2 unique HD bird photos...")

for wiki_title, fname in last_2:
    local_path = os.path.join(IMAGES_DIR, fname)
    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{wiki_title}"
    
    try:
        time.sleep(2.0)
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
                if len(content) > 10000:
                    with open(local_path, 'wb') as out_f:
                        out_f.write(content)
                    print(f"  ✓ Saved UNIQUE image: {fname} ({len(content)} bytes)")
    except Exception as e:
        print(f"Error fetching {wiki_title}: {e}")

print("\n--- Last 2 photos download complete! ---")
