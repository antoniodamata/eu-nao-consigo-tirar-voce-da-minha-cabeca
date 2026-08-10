# Rodar no iPhone

## 1. Descobrir o endereço do Mac

No Terminal:

```bash
ipconfig getifaddr en0
```

Se não devolver nada, tente `en1` (algumas máquinas usam essa interface para
Wi-Fi). O resultado é algo como `192.168.0.17`.

Esse número muda quando o roteador reinicia. Por isso o app tem um campo —
quando mudar, é só digitar o novo, sem recompilar.

## 2. Subir o servidor

```bash
cd server
source venv/bin/activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

O `--host 0.0.0.0` é obrigatório. Com `127.0.0.1` o servidor só aceita
conexões do próprio Mac e o iPhone nunca chega.

Confira em `http://localhost:8000/status` — deve responder JSON.

## 3. Instalar no aparelho

Os sensores **não existem no simulador** — sem barômetro, sem magnetômetro,
sem proximidade. Precisa ser um iPhone de verdade.

1. Conecte o iPhone por cabo
2. No Xcode, escolha o aparelho na barra de cima (não um simulador)
3. Em *Signing & Capabilities*, selecione seu time em *Team*
4. ⌘R

Na primeira vez o iPhone vai reclamar do desenvolvedor não confiável:
Ajustes → Geral → VPN e Gerenciamento de Dispositivo → confiar.

## 4. Permissões

Ao abrir, o app pede quatro coisas. **Aceite todas** — cada recusa apaga um
sensor:

| Pedido | Sem ele |
|---|---|
| Localização | latitude, longitude, altitude, velocidade, rumo |
| Microfone | nível de som ambiente |
| Movimento e fitness | acelerômetro, giroscópio, orientação |
| Rede local | **nada funciona** — é a permissão da conexão |

A de rede local é a mais fácil de perder: aparece uma vez só. Se você negou,
vá em Ajustes → Privacidade e Segurança → Rede Local e ligue o SensorApp.

## 5. Conectar

Digite o endereço do passo 1 no campo do app — só `192.168.0.17:8000`, o resto
o app completa. Toque em **Conectar**.

A bolinha fica verde e o contador de enviados começa a subir. No Terminal do
Mac aparece "iPhone conectado." e, alguns segundos depois, o primeiro texto.

Abra `http://localhost:8000` no Mac.

## Quando não funciona

| O app diz | O que é |
|---|---|
| `servidor não responde` | IP errado, servidor parado, ou firewall do Mac |
| `bloqueado pelo ATS` | o Info.plist não entrou no build — *Product → Clean Build Folder* e rode de novo |
| `sem rede` | iPhone e Mac em redes diferentes |
| fica em `conectando…` | quase sempre a permissão de rede local negada |

Firewall do Mac: Ajustes do Sistema → Rede → Firewall. Se estiver ligado, ele
pode barrar conexões de entrada — libere o Python ou desligue enquanto testa.

Rede de trabalho, universidade ou hotel costuma isolar os aparelhos entre si
(*client isolation*). Nesse caso nada resolve pelo lado do software: use o
Wi-Fi de casa, ou o iPhone como ponto de acesso com o Mac conectado nele.

## Limites conhecidos

O app precisa ficar **aberto e em primeiro plano**. Quando vai para segundo
plano ou a tela apaga, o iOS suspende os sensores e o fluxo para. O botão
*Tela ligada* impede o bloqueio automático — o custo é bateria.

Para o fluxo continuar com a tela apagada seria preciso ativar modos de
segundo plano (o caminho usual é `location updates`), o que traz outras
implicações. Fica para quando o resto estiver estável.
