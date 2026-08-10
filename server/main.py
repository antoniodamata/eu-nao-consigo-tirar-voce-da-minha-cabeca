import asyncio
import json

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles

import config
import state
from hub import hub
from registro import registro
from llm import comment, chave_configurada, enxugar, PROMPT_ATIVO, MODEL

app = FastAPI(title="não consigo tirar você da minha cabeça")

# Guarda o último erro do Claude para aparecer em /status, já que num
# servidor remoto ninguém está olhando o terminal.
ultimo_erro = None


@app.middleware("http")
async def sem_cache(request, call_next):
    """A página é uma peça viva e muda com frequência.

    Sem isto o navegador guarda o CSS antigo e você fica olhando para uma
    versão que não existe mais.
    """

    resposta = await call_next(request)
    resposta.headers["Cache-Control"] = "no-store, must-revalidate"
    return resposta


@app.get("/status")
def status():
    return {
        "status": "ok",
        "chave_anthropic": chave_configurada(),
        "prompt": PROMPT_ATIVO,
        "iphone_conectado": state.current_device_state is not None,
        "navegadores": len(hub.clients),
        "ultimo_texto": state.last_update,
        "ultimo_erro": ultimo_erro
    }


@app.get("/registro")
def listar_registro():
    """Índice de todas as performances gravadas."""
    return {"performances": registro.listar()}


@app.get("/registro/ultima")
def ultima_performance():
    """A última performance com conteúdo, para a página tocar em loop."""

    gravacao = registro.mais_recente_com_conteudo()

    if gravacao is None:
        return {"sessao": None, "linhas": []}

    return gravacao


@app.get("/registro/{identificador}")
def uma_performance(identificador: str):
    gravacao = registro.ler(identificador)

    if gravacao is None:
        return {"erro": "performance não encontrada"}

    return gravacao


# ---------------------------------------------------------------- iPhone

@app.websocket("/ws")
async def websocket_iphone(websocket: WebSocket):

    await websocket.accept()

    print("iPhone conectado.")

    registro.iphone_apareceu(
        {
            "prompt": PROMPT_ATIVO,
            "modelo": MODEL,
            "intervalo_segundos": config.INTERVALO_CLAUDE
        }
    )

    try:
        while True:

            message = await websocket.receive_text()

            try:
                state.current_device_state = json.loads(message)
                registro.iphone_falou()
            except json.JSONDecodeError:
                print("Mensagem inválida recebida do iPhone.")

    except WebSocketDisconnect:
        print("iPhone desconectado.")


# ---------------------------------------------------------------- navegador

@app.websocket("/ws/web")
async def websocket_web(websocket: WebSocket):

    await hub.connect(websocket)

    try:
        await websocket.send_json(state.bootstrap())

        while True:
            # O navegador não envia nada; isto mantém a conexão viva.
            await websocket.receive_text()

    except WebSocketDisconnect:
        pass

    finally:
        await hub.disconnect(websocket)


# ---------------------------------------------------------------- laços

async def claude_loop():
    """Chama o Claude em intervalos fixos e transmite o texto."""

    global ultimo_erro

    ultimo_timestamp = None
    estado_anterior = None

    while True:

        await asyncio.sleep(config.INTERVALO_CLAUDE)

        device_state = state.current_device_state

        if device_state is None:
            continue

        timestamp = device_state.get("timestamp")

        if timestamp is not None and timestamp == ultimo_timestamp:
            continue

        ultimo_timestamp = timestamp

        try:
            # A chamada da Anthropic é síncrona: sem a thread ela travaria
            # o WebSocket do iPhone enquanto o Claude responde.
            memoria = state.ultimas_linhas()

            texto = await asyncio.to_thread(
                comment, device_state, memoria, estado_anterior
            )

            estado_anterior = device_state

            state.registrar_texto(texto)
            registro.anotar(texto, enxugar(device_state))
            ultimo_erro = None

            print("\n================ CLAUDE ================\n")
            print(texto)
            print("\n========================================\n")

            await hub.broadcast(state.snapshot())

        except Exception as e:
            ultimo_erro = f"{type(e).__name__}: {e}"
            print("Erro Claude:", ultimo_erro)


async def sensor_loop():
    """Transmite o estado bruto dos sensores aos navegadores."""

    while True:

        await asyncio.sleep(config.INTERVALO_SENSORES)

        # O iPhone sumiu e passou do período de graça: a performance acabou.
        if registro.vencida():
            registro.encerrar()
            state.current_device_state = None
            await hub.broadcast({"type": "fim"})
            continue

        if state.current_device_state is None:
            continue

        if not hub.clients:
            continue

        await hub.broadcast(
            {
                "type": "sensors",
                "state": state.current_device_state
            }
        )


@app.on_event("startup")
async def startup():
    asyncio.create_task(claude_loop())
    asyncio.create_task(sensor_loop())


# A página pública fica por último para não capturar as rotas acima.
app.mount(
    "/",
    StaticFiles(directory=config.WEB_DIR, html=True),
    name="web"
)
