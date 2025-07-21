import requests

url = "http://127.0.0.1:8000/generate-and-send-bill/"
payload = {
    "customer": {
        "id": "cust_202507221430000000",  # use valid customer ID
        "name": "John Doe",
        "phone": "1234567890",
        "email": "johndoe@example.com"
    },
    "items": [
        {
            "id": "prod_202507221435000000",  # use valid product ID
            "name": "Pen",
            "price": 10.0,
            "billedQuantity": 2
        }
    ],
    "total": 20.0,
    "date": "2025-07-22",
    "time": "14:45:00"
}

print("POSTing this data to the server:\n", payload)
response = requests.post(url, json=payload)
print(response.status_code)
print(response.json())