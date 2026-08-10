# não consigo tirar você da minha cabeça

Um iPhone envia o fluxo contínuo dos seus sensores para um servidor. O servidor
entrega esse fluxo a um modelo de linguagem cuja única forma de perceber o
mundo são aqueles números. O texto que ele produz não volta para o telefone:
aparece numa página, para quem quiser ler.

```
iPhone  →  WebSocket  →  servidor  →  Claude  →  página pública
```

## Rodar

```bash
cd server
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # e coloque a sua chave da Anthropic
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Página em `http://localhost:8000`. O iPhone precisa apontar para o IP do Mac
na rede local — o endereço fica em `app/SensorApp/Networking/WebSocketManager.swift`.

## Ajustes rápidos

| O quê | Onde |
|---|---|
| Ritmo e custo do texto | `INTERVALO_CLAUDE` em `server/config.py` |
| Regime de linguagem | `PROMPT_ATIVO` em `server/llm.py` |
| Textos dos regimes | `prompts/*.txt` |
| Aparência da página | `web/` |

Detalhes em [`docs/arquitetura.md`](docs/arquitetura.md).
