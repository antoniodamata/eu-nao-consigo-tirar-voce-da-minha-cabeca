# não consigo tirar você da minha cabeça

Arquitetura técnica do projeto.

## Fluxo

```
iPhone (Swift / SwiftUI)
   │  sensores → DeviceState
   ▼
WebSocket  ws://<ip-do-mac>:8000/ws
   ▼
Servidor FastAPI  (server/)
   ├── state.current_device_state     último estado bruto
   ├── claude_loop()  ──► Claude API ──► state.current_text
   └── hub.broadcast()
          ▼
   WebSocket  /ws/web
          ▼
Página pública  (web/)  ─ texto + sensores
```

O iPhone nunca vê o texto. Ele apenas envia. A saída acontece na página.

## Componentes

### App iOS — `app/SensorApp/`

| Arquivo | Papel |
|---|---|
| `Managers/*.swift` | um manager por sensor, todos singletons |
| `Managers/SensorHub.swift` | junta os managers num `DeviceState` |
| `Models/SensorData.swift` | `SensorState` (só movimento) |
| `Models/DeviceState.swift` | estado completo, é o que vai pela rede |
| `Networking/WebSocketManager.swift` | conexão e envio |

O `MotionManager` dispara o ciclo: a cada leitura de movimento ele monta um
`SensorState` e chama `hub.update(motion:)`, que completa com os demais
sensores e envia.

### Servidor — `server/`

| Arquivo | Papel |
|---|---|
| `main.py` | rotas, os dois laços de fundo, monta a página estática |
| `state.py` | estado compartilhado e histórico curto de textos |
| `hub.py` | conjunto de navegadores conectados, broadcast |
| `llm.py` | chamada à Anthropic, carrega o prompt de `prompts/` |
| `config.py` | host, porta, intervalos |

Rotas:

- `GET /status` — diagnóstico em JSON
- `WS /ws` — o iPhone envia estado
- `WS /ws/web` — os navegadores recebem
- `GET /` — a página

Dois laços independentes:

- `claude_loop()` a cada `INTERVALO_CLAUDE` segundos, só chama o Claude se o
  timestamp mudou. Roda em thread separada porque o SDK da Anthropic é
  síncrono e travaria o WebSocket do iPhone.
- `sensor_loop()` a cada `INTERVALO_SENSORES` segundos, transmite o estado
  bruto para que os números da página fiquem vivos entre um texto e outro.

### Página — `web/`

Três arquivos sem dependências. O texto atual em destaque, os anteriores
esmaecidos abaixo, os sensores numa coluna à direita. Reconecta sozinha com
backoff exponencial se o servidor cair.

## Regimes de linguagem — `prompts/`

O prompt vai no campo `system` da chamada, separado dos dados. Trocar
`PROMPT_ATIVO` em `llm.py` muda o tipo de texto sem tocar em mais nada.

| Arquivo | Regime |
|---|---|
| `phenomenology.txt` | experiência presente, sem nomear a fonte |
| `technical.txt` | diário técnico, descritivo |
| `machine.txt` | registro sem sujeito |
| `assemic.txt` | leitura não-humana, sintaxe quebrada |

## Como rodar

```bash
cd server
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

A página fica em `http://localhost:8000`. O iPhone precisa apontar para o IP
do Mac na rede local, em `WebSocketManager.swift`.

Se aparecer `[Errno 48] Address already in use`, há outro servidor na 8000:

```bash
lsof -ti:8000 | xargs kill
```

## Estado atual

Funcionando: app iOS, servidor, Claude, broadcast, página local.

Pendente: colocar o servidor numa VPS para que o iPhone e o público não
dependam da mesma rede local. Hoje o app usa um endereço privado
(`ws://10.0.0.42:8000/ws`), então iPhone e Mac precisam estar na mesma rede.
