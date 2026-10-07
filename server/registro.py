"""Registro em disco de cada performance.

Cada sessão é uma pasta em data/sessions/, com um arquivo de metadados e um
arquivo de linhas. Nada disso vive na memória: se o servidor cair, o que já
foi escrito continua lá.

Uma sessão começa quando o iPhone conecta e termina quando ele some por mais
do que o período de graça. Uma queda de rede de vinte segundos não parte a
performance em duas.
"""

import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

RAIZ = Path(__file__).resolve().parent.parent / "data" / "sessions"

# Quanto tempo o iPhone pode sumir sem que a sessão seja encerrada.
GRACA = 90.0


def agora_iso() -> str:
    """Horário local com fuso explícito, precisão de milissegundo."""
    return datetime.now().astimezone().isoformat(timespec="milliseconds")


def _id_de(momento: datetime) -> str:
    return momento.astimezone().strftime("%Y-%m-%d_%Hh%Mm%Ss")


class Sessao:

    def __init__(self, pasta: Path, meta: dict):
        self.pasta = pasta
        self.meta = meta
        self.arquivo_linhas = pasta / "linhas.jsonl"

    @property
    def id(self) -> str:
        return self.meta["id"]

    def escrever_meta(self) -> None:
        (self.pasta / "sessao.json").write_text(
            json.dumps(self.meta, indent=2, ensure_ascii=False),
            encoding="utf-8"
        )

    def anotar_linha(self, texto: str, estado: dict,
                     texto_en: str = None) -> None:

        agora = time.time()

        entrada = {
            "t": agora_iso(),
            "epoch": round(agora, 3),
            "desde_inicio": round(agora - self.meta["inicio_epoch"], 3),
            "texto": texto,
            "texto_en": texto_en,
            "estado": estado
        }

        with self.arquivo_linhas.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entrada, ensure_ascii=False) + "\n")

        self.meta["linhas"] += 1
        self.meta["fim"] = entrada["t"]
        self.meta["fim_epoch"] = entrada["epoch"]
        self.meta["duracao_segundos"] = entrada["desde_inicio"]

        self.escrever_meta()

    def contar_leitura(self) -> None:
        self.meta["leituras"] += 1


class Registro:
    """Controla qual sessão está aberta."""

    def __init__(self) -> None:
        self.atual: Optional[Sessao] = None
        self.visto_por_ultimo: Optional[float] = None
        RAIZ.mkdir(parents=True, exist_ok=True)

    # ---------------------------------------------------------- ciclo

    def iphone_apareceu(self, contexto: dict) -> None:
        """Chamado quando o iPhone conecta ou volta a mandar dados."""

        agora = time.time()

        if self.atual is not None:

            dentro_da_graca = (
                self.visto_por_ultimo is not None
                and agora - self.visto_por_ultimo <= GRACA
            )

            if dentro_da_graca:
                self.visto_por_ultimo = agora
                return

            self.encerrar()

        momento = datetime.now(timezone.utc)
        identificador = _id_de(momento)

        pasta = RAIZ / identificador
        pasta.mkdir(parents=True, exist_ok=True)

        meta = {
            "id": identificador,
            "inicio": agora_iso(),
            "inicio_epoch": round(agora, 3),
            "fim": None,
            "fim_epoch": None,
            "duracao_segundos": 0.0,
            "linhas": 0,
            "leituras": 0,
            "encerrada": False,
            **contexto
        }

        self.atual = Sessao(pasta, meta)
        self.atual.escrever_meta()
        self.visto_por_ultimo = agora

        print(f"\n>>> performance iniciada: {identificador}  ({meta['inicio']})\n")

    def iphone_falou(self) -> None:
        self.visto_por_ultimo = time.time()
        if self.atual is not None:
            self.atual.contar_leitura()

    def anotar(self, texto: str, estado: dict,
               texto_en: str = None) -> None:
        if self.atual is not None:
            self.atual.anotar_linha(texto, estado, texto_en)

    def encerrar(self) -> None:

        if self.atual is None:
            return

        meta = self.atual.meta
        meta["encerrada"] = True

        if meta["fim"] is None:
            meta["fim"] = agora_iso()
            meta["fim_epoch"] = round(time.time(), 3)
            meta["duracao_segundos"] = round(
                meta["fim_epoch"] - meta["inicio_epoch"], 3
            )

        self.atual.escrever_meta()

        print(
            f"\n>>> performance encerrada: {meta['id']}  "
            f"{meta['linhas']} linhas em {meta['duracao_segundos']:.0f}s\n"
        )

        self.atual = None
        self.visto_por_ultimo = None

    def vencida(self) -> bool:
        """A sessão aberta passou do período de graça sem sinal?"""

        if self.atual is None or self.visto_por_ultimo is None:
            return False

        return time.time() - self.visto_por_ultimo > GRACA

    # ---------------------------------------------------------- leitura

    @staticmethod
    def listar() -> list:
        """Todas as performances, da mais recente para a mais antiga."""

        sessoes = []

        for pasta in sorted(RAIZ.glob("*/"), reverse=True):

            arquivo = pasta / "sessao.json"

            if not arquivo.exists():
                continue

            try:
                sessoes.append(json.loads(arquivo.read_text(encoding="utf-8")))
            except json.JSONDecodeError:
                continue

        return sessoes

    @staticmethod
    def ler(identificador: str) -> Optional[dict]:

        pasta = RAIZ / identificador

        # Não deixa escapar da pasta de sessões.
        if not pasta.resolve().is_relative_to(RAIZ.resolve()):
            return None

        arquivo = pasta / "sessao.json"

        if not arquivo.exists():
            return None

        meta = json.loads(arquivo.read_text(encoding="utf-8"))

        linhas = []
        arquivo_linhas = pasta / "linhas.jsonl"

        if arquivo_linhas.exists():
            for linha in arquivo_linhas.read_text(encoding="utf-8").splitlines():
                if linha.strip():
                    try:
                        linhas.append(json.loads(linha))
                    except json.JSONDecodeError:
                        continue

        return {"sessao": meta, "linhas": linhas}

    @staticmethod
    def mais_recente_com_conteudo(minimo: int = 3) -> Optional[dict]:
        """A última performance que tem linhas suficientes para valer a pena."""

        for meta in Registro.listar():
            if meta.get("linhas", 0) >= minimo:
                return Registro.ler(meta["id"])

        return None


registro = Registro()
