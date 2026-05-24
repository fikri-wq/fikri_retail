import urllib.request
import urllib.parse
import json
import time

URL = "https://khurtsgzfviteinhbgcy.supabase.co/rest/v1/products"
FUNCTIONS_URL = "https://khurtsgzfviteinhbgcy.supabase.co/functions/v1/generate-embedding"
KEY = "sb_publishable_VdkAaVFbVyFJ2dFCw0t4pA_1qYnPiHh"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
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

def insert_product(product):
    req = urllib.request.Request(URL, headers=headers, method='POST', data=json.dumps(product).encode('utf-8'))
    with urllib.request.urlopen(req) as response:
        pass

new_products = [
  {"name": "Aqua Botol 600ml", "description": "Minuman ringan, air mineral murni siap minum", "price": 3500, "stock": 100},
  {"name": "Pocari Sweat 500ml", "description": "Minuman ringan, minuman isotonik pengganti ion", "price": 7500, "stock": 50},
  {"name": "Coca Cola 1.5 Liter", "description": "Minuman ringan, minuman bersoda botol besar", "price": 15000, "stock": 30},
  {"name": "Oreo Original 133g", "description": "Makanan ringan, biskuit coklat krim vanilla", "price": 9000, "stock": 60},
  {"name": "Roma Kelapa 300g", "description": "Makanan ringan, biskuit renyah rasa kelapa", "price": 12000, "stock": 45},
  {"name": "Kapal Api Special Mix", "description": "Minuman seduh, kopi bubuk hitam manis sachet", "price": 15000, "stock": 100},
  {"name": "Nescafe Classic 50g", "description": "Minuman seduh, kopi instan tanpa ampas", "price": 25000, "stock": 25},
  {"name": "Ultra Milk Coklat 1 Liter", "description": "Minuman susu, susu cair UHT rasa coklat", "price": 18500, "stock": 40},
  {"name": "Bear Brand 189ml", "description": "Minuman susu, susu sapi steril murni", "price": 10500, "stock": 80},
  {"name": "Lifebuoy Sabun Cair 450ml", "description": "Perawatan tubuh, sabun mandi cair antibakteri", "price": 22000, "stock": 35},
  {"name": "Pantene Shampoo Anti Dandruff 130ml", "description": "Perawatan tubuh, shampo rambut anti ketombe", "price": 24000, "stock": 20},
  {"name": "Indomie Goreng Original", "description": "Makanan instan, mie goreng instan favorit", "price": 3500, "stock": 200},
  {"name": "Sedaap Mie Goreng", "description": "Makanan instan, mie goreng instan dengan bawang kriuk", "price": 3300, "stock": 150},
  {"name": "Gula Pasir Gulaku 1kg", "description": "Sembako, gula pasir putih murni", "price": 16500, "stock": 80},
  {"name": "Garam Masak Kapal 250g", "description": "Bumbu dapur, garam dapur beryodium", "price": 3000, "stock": 100}
]

def main():
    print(f"Starting insertion of {len(new_products)} products...")
    
    for i, p in enumerate(new_products):
        text_to_embed = f"{p['name']} - {p['description']}"
        print(f"[{i+1}/{len(new_products)}] Generating AI Embedding for: {p['name']}")
        
        emb = generate_embedding(text_to_embed)
        if emb:
            p['embedding'] = emb
            print(f"[{i+1}/{len(new_products)}] Inserting into database...")
            insert_product(p)
            print("Success!")
        else:
            print("Embedding failed, skipping DB insert.")
        
        time.sleep(0.5)
            
    print("All products inserted successfully!")

if __name__ == '__main__':
    main()
