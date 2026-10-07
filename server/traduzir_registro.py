"""Traduz, uma vez, os versos de uma performance já gravada.

Use quando um registro antigo não tem tradução — por exemplo o de 10 de
agosto, escrito antes de o tradutor existir.

    python traduzir_registro.py 2026-08-10_22h19m35s
    python traduzir_registro.py --lista

O arquivo original é copiado para .bak antes de qualquer escrita, e o novo é
montado inteiro num temporário e só então colocado no lugar. Se o processo
morrer no meio, o registro continua íntegro: é a única cópia da obra.

É idempotente: rodar duas vezes não traduz de novo o que já tem tradução.
"""

import json
import shutil
import sys
import time
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

from registro import RAIZ
from traducao import traduzir

PAUSA = 0.15


def listar() -> None:

    for pasta in sorted(RAIZ.glob("*/"), reverse=True):

        arquivo = pasta / "sessao.json"

        if not arquivo.exists():
            continue

        meta = json.loads(arquivo.read_text(encoding="utf-8"))

        linhas = pasta / "linhas.jsonl"
        faltam = 0

        if linhas.exists():
            for linha in linhas.read_text(encoding="utf-8").splitlines():
                if linha.strip():
                    try:
                        if not json.loads(linha).get("texto_en"):
                            faltam += 1
                    except json.JSONDecodeError:
                        pass

        print(f"  {meta['id']}  {meta['linhas']:>4} versos  "
              f"{faltam:>4} sem tradução")


def traduzir_sessao(identificador: str) -> None:

    pasta = RAIZ / identificador
    arquivo = pasta / "linhas.jsonl"

    if not arquivo.exists():
        print(f"Não encontrei {arquivo}")
        return

    entradas = []

    for linha in arquivo.read_text(encoding="utf-8").splitlines():
        if linha.strip():
            try:
                entradas.append(json.loads(linha))
            except json.JSONDecodeError:
                print("Linha ilegível, mantida como está.")

    pendentes = [e for e in entradas if e.get("texto") and not e.get("texto_en")]

    print(f"{len(entradas)} versos, {len(pendentes)} sem tradução.")

    if not pendentes:
        print("Nada a fazer.")
        return

    backup = arquivo.with_suffix(".jsonl.bak")
    shutil.copy2(arquivo, backup)
    print(f"Cópia de segurança em {backup.name}")

    feitos = 0
    falhas = 0

    for i, entrada in enumerate(entradas):

        if not entrada.get("texto") or entrada.get("texto_en"):
            continue

        traducao = traduzir(entrada["texto"])

        if traducao:
            entrada["texto_en"] = traducao
            feitos += 1
        else:
            falhas += 1

        if (feitos + falhas) % 25 == 0:
            print(f"  {feitos + falhas}/{len(pendentes)}...", flush=True)

        time.sleep(PAUSA)

    # Monta inteiro no temporário e só então substitui.
    temporario = arquivo.with_suffix(".jsonl.tmp")

    with temporario.open("w", encoding="utf-8") as f:
        for entrada in entradas:
            f.write(json.dumps(entrada, ensure_ascii=False) + "\n")

    temporario.replace(arquivo)

    print(f"\nPronto. {feitos} traduzidos, {falhas} falharam.")
    print(f"Se algo parecer errado, o original está em {backup.name}")


if __name__ == "__main__":

    if len(sys.argv) < 2 or sys.argv[1] == "--lista":
        print("Performances gravadas:\n")
        listar()
        print("\nPara traduzir:  python traduzir_registro.py <id>")
    else:
        traduzir_sessao(sys.argv[1])
