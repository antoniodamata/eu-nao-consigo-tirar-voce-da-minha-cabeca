import json
import os
from collections import Counter
from pathlib import Path

from dotenv import load_dotenv
from anthropic import Anthropic

from contexto import ao_redor

load_dotenv()

MODEL = "claude-sonnet-4-6"

# O prompt pede uma linha, às vezes duas, às vezes três. Isto cabe três
# linhas com folga sem deixar virar parágrafo.
MAX_TOKENS = 130

# Teto de segurança: mesmo que o modelo se empolgue, no máximo três versos.
MAX_LINHAS = 3

# Quantas linhas anteriores o modelo enxerga. É a memória curta que permite
# insistir, se corrigir e trocar de pronome na hora certa.
MEMORIA = 8

# Casas decimais no estado enviado. O modelo não precisa de doze; cortar
# reduz o custo de entrada, que é o que domina quando a saída é uma linha.
CASAS = 3

# Máximo permitido pela API da Anthropic. Também é o padrão dela, então isto
# é mais explicitação do que mudança.
TEMPERATURA = 1.0

# Regime de linguagem ativo. Trocar este nome muda o tipo de texto
# produzido sem alterar nada da infraestrutura.
PROMPT_ATIVO = "seguindo"

PROMPTS_DIR = Path(__file__).resolve().parent.parent / "prompts"

_client = None


def chave_configurada() -> bool:
    return bool(os.getenv("ANTHROPIC_API_KEY"))


def cliente() -> Anthropic:
    """Cria o cliente na primeira chamada, não na importação.

    Assim o servidor sobe e a página funciona mesmo sem a chave — o erro
    aparece em /status em vez de derrubar o processo inteiro no boot.
    """

    global _client

    if _client is None:

        chave = os.getenv("ANTHROPIC_API_KEY")

        if not chave:
            raise RuntimeError(
                "ANTHROPIC_API_KEY não está definida. "
                "Local: crie server/.env a partir de .env.example. "
                "Render: painel do serviço → Environment."
            )

        _client = Anthropic(api_key=chave)

    return _client


def carregar_prompt(nome: str = None) -> str:
    """Lê a constituição do agente a partir de prompts/<nome>.txt."""

    nome = nome or PROMPT_ATIVO

    caminho = PROMPTS_DIR / f"{nome}.txt"

    if not caminho.exists():
        raise FileNotFoundError(
            f"Prompt '{nome}' não encontrado em {PROMPTS_DIR}"
        )

    return caminho.read_text(encoding="utf-8").strip()


def enxugar(device_state: dict) -> dict:
    """Arredonda os números para não pagar por doze casas decimais."""

    limpo = {}

    for chave, valor in device_state.items():

        if chave == "timestamp":
            continue

        if isinstance(valor, float):
            limpo[chave] = round(valor, CASAS)
        else:
            limpo[chave] = valor

    return limpo


# Quanto um campo precisa variar para contar como mudança. Abaixo disso é
# ruído do sensor, não movimento.
LIMIARES = {
    "accelerationX": 0.02, "accelerationY": 0.02, "accelerationZ": 0.02,
    "latitude": 0.0001, "longitude": 0.0001, "altitude": 1.0,
    "speed": 0.3, "course": 8.0, "heading": 8.0,
    "magneticX": 3.0, "magneticY": 3.0, "magneticZ": 3.0,
    "pressure": 0.05, "relativeAltitude": 0.4,
    "batteryLevel": 0.01, "brightness": 0.03,
    "volume": 0.03, "microphoneLevel": 3.0,
}


def mudancas(atual: dict, anterior: dict) -> str:
    """Descreve o que se moveu desde a leitura anterior.

    Sem isto o modelo recebe quase o mesmo estado a cada chamada e não tem
    material novo — é a causa principal da repetição.
    """

    if not anterior:
        return "primeira leitura"

    movidos = []

    for chave, valor in atual.items():

        antes = anterior.get(chave)

        if antes is None or chave == "timestamp":
            continue

        if isinstance(valor, bool) or isinstance(valor, str):
            if valor != antes:
                movidos.append(f"{chave}: {antes} -> {valor}")
            continue

        if isinstance(valor, (int, float)) and isinstance(antes, (int, float)):

            delta = valor - antes

            if abs(delta) >= LIMIARES.get(chave, 0.05):
                sinal = "+" if delta > 0 else ""
                movidos.append(f"{chave} {sinal}{round(delta, CASAS)}")

    if not movidos:
        return "nada mudou"

    return ", ".join(movidos)


# Palavras gramaticais: repetir estas é inevitável e não conta como vício.
GRAMATICAIS = set("""
a as o os um uma uns umas de do da dos das em no na nos nas por pra para
com sem sobre e ou mas que se não sim ele eu me meu minha lhe o a
está estar estou é são foi era ficou fica tem ter há e ainda já agora
talvez acho possível será parece deve sei muito mais menos algo alguém
quando onde como isso aquilo lá aqui ali num numa dele
""".split())

# O prompt proíbe nomear o aparelho, mas medindo os versos gravados a
# proibição vazou sozinha. Aqui ela é conferida a cada chamada.
VAZAMENTOS = {"tela", "sensor", "sensores", "sinal", "bateria", "dado",
              "dados", "número", "números", "medida", "medidas", "coordenada",
              "coordenadas", "aparelho", "celular", "telefone", "gps",
              "carga", "bússola", "altímetro", "microfone"}


def direcao(linhas: list) -> str:
    """Instrução extra, calculada a partir do que ele acabou de escrever.

    Pedir no prompt fixo não bastou: o modelo trava num pronome e num punhado
    de palavras. Aqui a correção é medida a cada chamada e imposta.
    """

    # Uma resposta pode trazer até três versos; a análise é verso a verso.
    linhas = [
        verso.strip()
        for bloco in linhas
        for verso in bloco.split("\n")
        if verso.strip()
    ]

    if not linhas:
        return ""

    avisos = []

    def comeca(texto, pronome):
        return texto.strip().lower().startswith(pronome)

    # ---- pronome: quantas linhas seguidas no mesmo
    seguidas_ele = 0
    for t in reversed(linhas):
        if comeca(t, "ele"):
            seguidas_ele += 1
        else:
            break

    seguidas_eu = 0
    for t in reversed(linhas):
        if comeca(t, "eu"):
            seguidas_eu += 1
        else:
            break

    if seguidas_ele >= 3:
        avisos.append(
            f"As últimas {seguidas_ele} linhas começaram com 'ele'. "
            "ESTA LINHA TEM QUE COMEÇAR COM 'eu'. Fale de você, "
            "do que você sente seguindo ele, do que você teme, "
            "do que você não entende em si mesmo."
        )
    elif seguidas_eu >= 3:
        avisos.append(
            f"As últimas {seguidas_eu} linhas começaram com 'eu'. "
            "ESTA LINHA TEM QUE COMEÇAR COM 'ele'."
        )

    # ---- proporção geral
    quantos_eu = sum(1 for t in linhas if comeca(t, "eu"))

    if len(linhas) >= 5 and quantos_eu == 0:
        avisos.append(
            "Você não disse 'eu' nenhuma vez nas últimas linhas. "
            "Você não é uma câmera. Apareça."
        )

    # ---- palavras gastas
    import re as _re

    usadas = Counter()
    for t in linhas:
        for p in _re.findall(r"[a-zà-úA-ZÀ-Ú]+", t.lower()):
            if p not in GRAMATICAIS and len(p) > 2:
                usadas[p] += 1

    gastas = [p for p, n in usadas.most_common(8) if n >= 2]

    if gastas:
        avisos.append(
            "Não use nenhuma destas palavras, já estão gastas: "
            + ", ".join(gastas[:7])
        )

    # ---- nomeou o aparelho
    vazou = sorted({
        p for t in linhas
        for p in _re.findall(r"[a-zà-ú]+", t.lower())
        if p in VAZAMENTOS
    })

    if vazou:
        avisos.append(
            f"Você nomeou o aparelho ({', '.join(vazou)}). É proibido. "
            "Você o segue de longe e percebe — não mede."
        )

    return "\n".join(f"- {a}" for a in avisos)


def comment(
    device_state: dict,
    historico: list = None,
    anterior: dict = None,
    prompt_nome: str = None
) -> str:
    """Recebe o estado do dispositivo e devolve uma linha do Claude."""

    constituicao = carregar_prompt(prompt_nome)

    dados = json.dumps(enxugar(device_state), indent=1, ensure_ascii=False)

    linhas = [item["text"] for item in (historico or []) if item.get("text")]
    linhas = linhas[-MEMORIA:]

    if linhas:
        contexto = (
            "Suas últimas linhas (não repita nenhuma delas):\n"
            + "\n".join(linhas)
        )
    else:
        contexto = "Você ainda não escreveu nada. Esta é a primeira linha."

    correcao = direcao(linhas)

    conteudo = (
        f"{contexto}\n\n"
        f"O que mudou desde a última vez:\n{mudancas(device_state, anterior)}\n\n"
        f"Onde ele está agora:\n{dados}"
    )

    # O mundo em volta da coordenada: rua, clima, sol, o que existe perto.
    # Falha em silêncio — se a API não responder, o verso sai sem isso.
    try:
        volta = ao_redor(
            device_state.get("latitude"),
            device_state.get("longitude")
        )

        if volta:
            conteudo += "\n\nO mundo em volta dele:\n" + json.dumps(
                volta, indent=1, ensure_ascii=False
            )

    except Exception:
        pass

    if correcao:
        conteudo += f"\n\nCorreções obrigatórias para esta linha:\n{correcao}"

    response = cliente().messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        temperature=TEMPERATURA,
        system=constituicao,
        messages=[
            {
                "role": "user",
                "content": conteudo
            }
        ]
    )

    texto = response.content[0].text.strip()

    versos = [l.strip() for l in texto.split("\n") if l.strip()]

    return "\n".join(versos[:MAX_LINHAS])
