import json

with open('android/app/google-services.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for client in data.get('client', []):
    for oauth in client.get('oauth_client', []):
        if oauth.get('client_type') == 3:
            oauth['client_id'] = "193200636263-02mmqpu8fa9urq35p46432bdinilc29l.apps.googleusercontent.com"

with open('android/app/google-services.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
