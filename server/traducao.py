"""Tradução dos versos para o inglês, no instante em que nascem.

A tradução é gravada junto com o original no registro. Isso é deliberado:
se ela fosse feita na hora de ler, cada visita ao arquivo produziria um
inglês ligeiramente diferente, e numa obra cujo assunto é o registro a
documentação não pode mudar a cada leitura.

O português é o poema. O inglês é documentação do poema — como num
catálogo bilíngue, onde ninguém finge que a tradução é o original.

Usa Haiku, que é barato: cerca de dez centavos de dólar por hora de
performance, contra os dois dólares do Sonnet que escreve os versos.
"""

import os
from typing import Optional

from anthropic import Anthropic

MODELO = "claude-haiku-4-5"
MAX_TOKENS = 150

INSTRUCAO = """Você traduz versos do português para o inglês.

Os versos vêm de um poema sobre alguém que segue um homem sem saber por quê.
São curtos, banais, hesitantes, em minúsculas e sem ponto final.

Preserve exatamente: o tamanho, a hesitação, a banalidade, as minúsculas,
a ausência de pontuação final e a quebra de linhas.

Não melhore o verso. Não poetize. Não explique.
Se o verso for estranho em português, deve ficar estranho em inglês.

Responda apenas com a tradução. Nada antes, nada depois."""

_cliente = None


def cliente() -> Anthropic:

    global _cliente

    if _cliente is None:

        chave = os.getenv("ANTHROPIC_API_KEY")

        if not chave:
            raise RuntimeError("ANTHROPIC_API_KEY não está definida.")

        _cliente = Anthropic(api_key=chave)

    return _cliente


def traduzir(texto: str) -> Optional[str]:
    """Devolve a tradução, ou None se falhar.

    A falha é silenciosa de propósito: um verso sem tradução aparece em
    português na versão inglesa, o que é honesto. Derrubar a performance
    porque uma tradução falhou seria desproporcional.
    """

    if not texto or not texto.strip():
        return None

    try:
        resposta = cliente().messages.create(
            model=MODELO,
            max_tokens=MAX_TOKENS,
            temperature=1.0,
            system=INSTRUCAO,
            messages=[{"role": "user", "content": texto}]
        )

        traduzido = resposta.content[0].text.strip()

        # Mantém no máximo o mesmo número de linhas do original.
        limite = len([l for l in texto.split("\n") if l.strip()])
        linhas = [l.strip() for l in traduzido.split("\n") if l.strip()]

        return "\n".join(linhas[:limite]) or None

    except Exception as e:
        print("Erro na tradução:", e)
        return None
