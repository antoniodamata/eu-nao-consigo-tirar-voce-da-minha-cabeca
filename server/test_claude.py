from llm import comment

device = {
    "batteryLevel": 0.82,
    "brightness": 0.45,
    "latitude": -23.55,
    "longitude": -46.63,
    "accelerationX": 0.02,
    "accelerationY": -0.01,
    "accelerationZ": 0.98,
    "microphoneLevel": -38.4
}

print(comment(device))
