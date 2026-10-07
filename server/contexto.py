"""O que existe em volta da coordenada.

Tudo por APIs livres, sem chave e sem cartão. Cada resposta é cacheada numa
grade de coordenadas: andar cem metros não dispara pedido novo, e o tempo e
o pôr do sol valem para a cidade inteira.

A leitura (`ao_redor`) nunca toca a rede: devolve só o que já está em cache.
Quem busca é `manter`, chamada pelo laço assíncrono do servidor. Assim uma
API lenta jamais atrasa o verso.
"""

import time
from datetime import datetime
from typing import Optional

import httpx

# Quem nos identifica para o Nominatim e o Overpass, como as políticas de
# uso pedem.
AGENTE = "eu-nao-consigo-tirar-voce-da-minha-cabeca/1.0 (projeto artistico)"

TEMPO_LIMITE = 8.0

# Validade de cada tipo de resposta, em segundos.
VALIDADE = {
    "endereco": 60 * 60,
    "clima": 15 * 60,
    "sol": 6 * 60 * 60,
    "arredores": 60 * 60,
}

# Casas decimais usadas para agrupar coordenadas no cache. 3 ≈ 110 metros.
GRADE = 3

_cache: dict = {}


def _chave(nome: str, lat: float, lon: float) -> tuple:
    return (nome, round(lat, GRADE), round(lon, GRADE))


def _valido(chave: tuple):
    """Devolve o valor se ainda estiver dentro da validade."""

    item = _cache.get(chave)

    if item is None:
        return None

    valor, quando = item

    if time.time() - quando > VALIDADE[chave[0]]:
        return None

    return valor


def _guardar(chave: tuple, valor) -> None:
    _cache[chave] = (valor, time.time())


def util(lat, lon) -> bool:
    return (
        lat is not None and lon is not None
        and not (lat == 0 and lon == 0)
    )


# ---------------------------------------------------------------- buscas

async def _json(cliente: httpx.AsyncClient, url: str, params: dict):

    try:
        r = await cliente.get(url, params=params)
        r.raise_for_status()
        return r.json()
    except Exception:
        return None


async def _endereco(cliente, lat, lon) -> Optional[str]:
    """Rua e bairro, via Nominatim (OpenStreetMap)."""

    dados = await _json(
        cliente,
        "https://nominatim.openstreetmap.org/reverse",
        {"lat": lat, "lon": lon, "format": "json", "zoom": 17,
         "accept-language": "pt-BR"}
    )

    if not dados:
        return None

    a = dados.get("address", {})

    partes = [
        a.get("road") or a.get("pedestrian") or a.get("footway"),
        a.get("suburb") or a.get("neighbourhood") or a.get("city_district"),
        a.get("city") or a.get("town") or a.get("village"),
    ]

    return ", ".join(p for p in partes if p) or None


async def _clima(cliente, lat, lon) -> Optional[dict]:
    """Temperatura, chuva, vento e nuvens agora, via Open-Meteo."""

    dados = await _json(
        cliente,
        "https://api.open-meteo.com/v1/forecast",
        {"latitude": lat, "longitude": lon,
         "current": "temperature_2m,precipitation,wind_speed_10m,cloud_cover,is_day",
         "timezone": "auto"}
    )

    if not dados or "current" not in dados:
        return None

    c = dados["current"]

    return {
        "temperatura": c.get("temperature_2m"),
        "chuva": c.get("precipitation"),
        "vento": c.get("wind_speed_10m"),
        "nuvens": c.get("cloud_cover"),
        "de_dia": bool(c.get("is_day")),
    }


async def _sol(cliente, lat, lon) -> Optional[dict]:
    """Nascer e pôr do sol de hoje, no fuso do lugar."""

    dados = await _json(
        cliente,
        "https://api.open-meteo.com/v1/forecast",
        {"latitude": lat, "longitude": lon,
         "daily": "sunrise,sunset", "timezone": "auto", "forecast_days": 1}
    )

    if not dados or "daily" not in dados:
        return None

    d = dados["daily"]

    return {
        "nascer": (d.get("sunrise") or [None])[0],
        "por": (d.get("sunset") or [None])[0],
        "deslocamento": dados.get("utc_offset_seconds", 0),
    }


# O que interessa a um seguidor: onde alguém pode entrar e sumir.
CATEGORIAS = (
    '["amenity"~"place_of_worship|bar|pub|cafe|restaurant|hospital|'
    'pharmacy|police|bank|cinema|theatre|library|school"]'
)


async def _arredores(cliente, lat, lon, raio: int = 120) -> Optional[list]:
    """O que existe num raio de poucos metros, via Overpass (OSM)."""

    consulta = (
        f"[out:json][timeout:{int(TEMPO_LIMITE)}];"
        f"node(around:{raio},{lat},{lon}){CATEGORIAS};"
        f"out body 20;"
    )

    try:
        r = await cliente.post(
            "https://overpass-api.de/api/interpreter",
            data={"data": consulta}
        )
        r.raise_for_status()
        dados = r.json()
    except Exception:
        return None

    tipos = []

    for elemento in dados.get("elements", []):
        tipo = elemento.get("tags", {}).get("amenity")
        if tipo and tipo not in tipos:
            tipos.append(tipo)

    return tipos


_BUSCADORES = {
    "endereco": _endereco,
    "clima": _clima,
    "sol": _sol,
    "arredores": _arredores,
}

_ROTULOS = {
    "endereco": "onde",
    "clima": "clima",
    "sol": "sol",
    "arredores": "ao_redor",
}


# ---------------------------------------------------------------- manutenção

async def manter(lat: float, lon: float) -> None:
    """Renova o que está vencido. Chamada pelo laço do servidor."""

    if not util(lat, lon):
        return

    vencidos = [
        nome for nome in _BUSCADORES
        if _valido(_chave(nome, lat, lon)) is None
    ]

    if not vencidos:
        return

    async with httpx.AsyncClient(
        timeout=TEMPO_LIMITE,
        headers={"User-Agent": AGENTE},
        follow_redirects=True
    ) as cliente:

        for nome in vencidos:
            try:
                valor = await _BUSCADORES[nome](cliente, lat, lon)
            except Exception:
                valor = None

            # Guarda mesmo quando vem vazio: evita insistir a cada seis
            # segundos numa API que não vai responder.
            _guardar(_chave(nome, lat, lon), valor)


# ---------------------------------------------------------------- leitura

def _minutos_do_sol(base: dict) -> dict:

    resultado = dict(base)

    try:
        offset = base.get("deslocamento", 0)
        agora = time.time()

        for campo in ("nascer", "por"):

            iso = base.get(campo)

            if not iso:
                continue

            # As horas vêm no fuso local do lugar, sem sufixo.
            t = datetime.fromisoformat(iso).timestamp() - offset

            resultado[f"minutos_desde_{campo}"] = round((agora - t) / 60)

    except Exception:
        pass

    resultado.pop("deslocamento", None)

    return resultado


def ao_redor(lat: float, lon: float) -> dict:
    """Só cache. Nunca toca a rede, nunca demora."""

    if not util(lat, lon):
        return {}

    reunido = {}

    for nome, rotulo in _ROTULOS.items():

        valor = _valido(_chave(nome, lat, lon))

        if not valor:
            continue

        if nome == "sol":
            valor = _minutos_do_sol(valor)

        reunido[rotulo] = valor

    return reunido
