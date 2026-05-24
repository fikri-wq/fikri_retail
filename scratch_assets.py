import os
import urllib.request
import urllib.parse
import json
import time
import random

FUNCTIONS_URL = "https://khurtsgzfviteinhbgcy.supabase.co/functions/v1/generate-embedding"
KEY = "sb_publishable_VdkAaVFbVyFJ2dFCw0t4pA_1qYnPiHh"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json"
}

def generate_embedding(text):
    req = urllib.request.Request(FUNCTIONS_URL, headers=headers, method='POST', data=json.dumps({"input": text}).encode('utf-8'))
    try:
        with urllib.request.urlopen(req) as response:
            res = json.loads(response.read().decode())
            return res.get("embedding")
    except Exception as e:
        print(f"Error generating embedding for {text}: {e}")
        return None

def smart_desc(name):
    n = name.lower()
    if 'indomie' in n or 'sarimi' in n or 'supermi' in n or 'pop mie' in n:
        return "Makanan instan, mie rebus atau goreng siap saji"
    elif 'chitato' in n or 'lays' in n or 'qtela' in n or 'cheetos' in n or 'trenz' in n:
        return "Makanan ringan, snack keripik cemilan santai"
    elif 'bumbu' in n or 'kecap' in n or 'sambal' in n or 'garam' in n:
        return "Bumbu dapur, pelengkap rasa masakan masakan nusantara"
    elif 'bimoli' in n or 'beras' in n or 'gula' in n or 'tepung' in n or 'simas' in n:
        return "Sembako, kebutuhan pokok masak dapur sehari-hari"
    elif 'air' in n or 'teh' in n or 'syrup' in n or 'ocha' in n or 'club' in n:
        return "Minuman ringan, pelepas dahaga botol siap minum"
    elif 'susu' in n or 'kental manis' in n or 'uht' in n:
        return "Minuman susu, asupan gizi sehat untuk keluarga"
    elif 'tissue' in n or 'paseo' in n:
        return "Perlengkapan rumah, tissue pembersih serbaguna"
    else:
        return "Produk kebutuhan harian"

def get_price(name):
    n = name.lower()
    if 'indomie' in n or 'sarimi' in n or 'supermi' in n or 'pop mie' in n: return 3500
    if 'bumbu' in n: return 2500
    if 'kecap' in n or 'sambal' in n: return 12000
    if 'minyak' in n or 'bimoli' in n: return 35000
    if 'beras' in n: return 65000
    if 'tepung' in n or 'gula' in n: return 15000
    if 'chitato' in n or 'lays' in n or 'cheetos' in n or 'trenz' in n: return 10000
    if 'air' in n or 'club' in n: return 3500
    if 'teh' in n or 'syrup' in n: return 8000
    if 'susu' in n or 'kental manis' in n: return 14000
    if 'tissue' in n: return 16000
    return 15000

def main():
    assets_dir = r"C:\flutter project\fikriretailproject\assets"
    files = os.listdir(assets_dir)
    
    # Filter out non-products
    ignore = ['an', 'bca', 'bni', 'bri', 'dana', 'mandiri', 'iklan', 'logo', 'sea']
    products = []
    for f in files:
        if f.endswith('.jpg') or f.endswith('.png'):
            if any(f.lower().startswith(ig) for ig in ignore):
                continue
            name = os.path.splitext(f)[0]
            products.append({
                'name': name,
                'image_url': f"assets/{f}",
                'description': smart_desc(name),
                'price': get_price(name),
                'stock': random.randint(20, 100)
            })

    print(f"Found {len(products)} product images in assets/")
    
    dart_code = "final List<Map<String, dynamic>> seedProducts = [\n"
    
    for i, p in enumerate(products):
        text_to_embed = f"{p['name']} - {p['description']}"
        print(f"[{i+1}/{len(products)}] Embedding: {p['name']}")
        emb = generate_embedding(text_to_embed)
        if not emb:
            emb = "[]"
            
        dart_code += "  {\n"
        dart_code += f"    'name': '{p['name']}',\n"
        dart_code += f"    'description': '{p['description']}',\n"
        dart_code += f"    'price': {p['price']}.0,\n"
        dart_code += f"    'stock': {p['stock']},\n"
        dart_code += f"    'image_url': '{p['image_url']}',\n"
        dart_code += f"    'embedding': {emb},\n"
        dart_code += "  },\n"
        time.sleep(0.5)
        
    dart_code += "];\n"
    
    with open('lib/seed_data.dart', 'w') as f:
        f.write(dart_code)
        
    print("Done generating lib/seed_data.dart")

if __name__ == '__main__':
    main()
