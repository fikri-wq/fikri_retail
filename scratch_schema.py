import urllib.request
import json

URL = "https://khurtsgzfviteinhbgcy.supabase.co/rest/v1/?apikey=sb_publishable_VdkAaVFbVyFJ2dFCw0t4pA_1qYnPiHh"

def get_schema():
    req = urllib.request.Request(URL)
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            print(json.dumps(data['definitions']['orders'], indent=2))
    except Exception as e:
        print(f"Failed to fetch schema: {e}")

if __name__ == '__main__':
    get_schema()
