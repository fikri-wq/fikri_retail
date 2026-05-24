import urllib.request
import json
import urllib.error

URL = "https://khurtsgzfviteinhbgcy.supabase.co/rest/v1/orders"
KEY = "sb_publishable_VdkAaVFbVyFJ2dFCw0t4pA_1qYnPiHh"

headers = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json"
}

def update_orders():
    req = urllib.request.Request(f"{URL}?status=eq.delivered", headers=headers, method='PATCH', data=json.dumps({"status": "cancelled"}).encode('utf-8'))
    try:
        with urllib.request.urlopen(req) as response:
            print(f"Update succeeded: {response.status}")
    except urllib.error.HTTPError as e:
        print(f"Failed with {e.code}: {e.read().decode('utf-8')}")
    except Exception as e:
        print(f"Failed to update orders: {e}")

if __name__ == '__main__':
    update_orders()
