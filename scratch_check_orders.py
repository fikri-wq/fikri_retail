import urllib.request
import json

URL = "https://khurtsgzfviteinhbgcy.supabase.co/rest/v1/orders"
KEY = "sb_publishable_VdkAaVFbVyFJ2dFCw0t4pA_1qYnPiHh"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
}

def check_orders():
    req = urllib.request.Request(f"{URL}?select=*", headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            print(f"Found {len(data)} orders.")
            if len(data) > 0:
                print(data[0])
    except Exception as e:
        print(f"Failed to fetch orders: {e}")

if __name__ == '__main__':
    check_orders()
