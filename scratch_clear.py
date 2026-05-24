import urllib.request
import json

URL = "https://khurtsgzfviteinhbgcy.supabase.co/rest/v1/products"
KEY = "sb_publishable_VdkAaVFbVyFJ2dFCw0t4pA_1qYnPiHh"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
}

def clear_products():
    # DELETE all products
    req = urllib.request.Request(f"{URL}?id=not.is.null", headers=headers, method='DELETE')
    try:
        with urllib.request.urlopen(req) as response:
            print("Successfully deleted all products.")
    except Exception as e:
        print(f"Failed to delete products: {e}")

if __name__ == '__main__':
    clear_products()
