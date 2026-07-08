from fastapi import FastAPI, WebSocket

app = FastAPI()


@app.get("/")
def home():
    return {"status": "ok"}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):

    await websocket.accept()

    print("iPhone conectado!")

    while True:

        message = await websocket.receive_text()

        print(message)
