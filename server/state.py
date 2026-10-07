import time
from typing import Optional

# Último estado bruto recebido do iPhone
current_device_state: Optional[dict] = None

# Último texto produzido pelo Claude
current_text: Optional[str] = None

# A tradução dele, gravada no mesmo instante
current_text_en: Optional[str] = None

# Momento (epoch) em que o texto foi gerado
last_update: Optional[float] = None

# Histórico curto dos textos anteriores, para quem chega no meio
history: list = []

# Agora cada resposta é uma linha só, então o histórico guarda muito mais.
HISTORY_MAX = 400

# Quantas linhas quem chega agora recebe de uma vez.
BOOTSTRAP_LINHAS = 40


def ultimas_linhas(n: int = 8) -> list:
    """As últimas linhas escritas, para devolver ao modelo como memória."""

    linhas = list(history)

    if current_text is not None:
        linhas.append({"text": current_text, "timestamp": last_update})

    return linhas[-n:]


def registrar_texto(texto: str, texto_en: str = None) -> None:
    """Guarda o verso novo e empurra o anterior para o histórico."""

    global current_text, current_text_en, last_update

    if current_text is not None:
        history.append(
            {
                "text": current_text,
                "text_en": current_text_en,
                "timestamp": last_update
            }
        )

        del history[:-HISTORY_MAX]

    current_text = texto
    current_text_en = texto_en
    last_update = time.time()


def snapshot() -> dict:
    """Payload enviado aos clientes web."""

    return {
        "type": "update",
        "text": current_text,
        "text_en": current_text_en,
        "state": current_device_state,
        "timestamp": last_update
    }


def bootstrap() -> dict:
    """Payload enviado a um cliente web que acabou de conectar."""

    return {
        "type": "bootstrap",
        "ao_vivo": current_device_state is not None,
        "text": current_text,
        "text_en": current_text_en,
        "state": current_device_state,
        "timestamp": last_update,
        "history": history[-BOOTSTRAP_LINHAS:]
    }
