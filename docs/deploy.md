# Colocar no ar (Render)

O objetivo aqui é sair da rede local: o iPhone conecta de qualquer lugar e a
página fica pública.

O Render resolve de graça a parte mais chata — ele entrega um endereço com
HTTPS e certificado válido, que é exatamente o que o iOS exige para aceitar
`wss://`. Num VPS isso significaria apontar domínio, instalar Caddy e esperar
o Let's Encrypt.

## Antes de começar

**Revogue a chave antiga da Anthropic.** Ela apareceu escrita dentro do
`llm.py` e no histórico da conversa. Em console.anthropic.com → API Keys,
apague aquela e crie uma nova. Aproveite e defina um limite de gasto mensal em
*Billing → Usage limits* — o servidor vai chamar a API sozinho, e um laço mal
configurado gasta rápido.

Só a chave nova, e só no painel do Render. Nunca no código.

## 1. Mandar para o GitHub

O repositório já está limpo — o `.venv` e os 1085 `.pyc` que estavam
versionados foram destrackeados, e o `.env` está ignorado.

Crie um repositório vazio no GitHub (pode ser privado; o Render lê privados
também). Depois:

```bash
cd "zen demencia/iphone-monitor"
git add .
git commit -m "Servidor com broadcast, página pública e deploy"
git remote add origin git@github.com:SEU_USUARIO/SEU_REPO.git
git push -u origin main
```

Se o `push` reclamar do nome do ramo, veja qual você tem com `git branch` e
troque `main` pelo nome certo.

Confira no GitHub que **não existe** um arquivo `server/.env` lá.

## 2. Criar o serviço no Render

1. Entre em `render.com` e crie a conta (dá para entrar com o GitHub)
2. **New → Blueprint**
3. Escolha o repositório — ele acha o `render.yaml` sozinho
4. Ele vai pedir o valor de `ANTHROPIC_API_KEY`. Cole a chave nova.
5. **Apply**

O `render.yaml` já traz tudo: instala as dependências, sobe o uvicorn na porta
que o Render define, e usa `/status` como health check.

O primeiro build leva uns três minutos. No fim você recebe um endereço:

```
https://nao-consigo-tirar-voce-da-minha-cabeca.onrender.com
```

Abra `/status` nele. Deve responder com `"chave_anthropic": true`.

## 3. Apontar o iPhone

No campo de endereço do app, digite o mesmo domínio trocando `https` por
`wss`, sem barra no fim:

```
wss://nao-consigo-tirar-voce-da-minha-cabeca.onrender.com
```

O app completa o `/ws` sozinho. Toque em **Conectar**.

Agora o iPhone não precisa mais estar na sua rede — funciona no 5G, na rua,
em qualquer lugar.

A página pública é o mesmo endereço, sem o `wss`.

## O que esperar do plano gratuito

**Ele dorme.** Depois de 15 minutos sem ninguém acessando, o Render desliga o
serviço. O próximo acesso religa, e isso leva cerca de um minuto.

Na prática:

- Enquanto o app do iPhone estiver conectado, o serviço fica acordado
- Quando você fecha o app, ele adormece em 15 minutos
- Quem abrir a página depois disso espera o religamento

Ao religar, a memória zera: o texto atual e o histórico curto se perdem, e a
página começa vazia até o Claude falar de novo.

São 750 horas de instância por mês, o que dá aproximadamente um mês inteiro de
serviço ligado — o limite não vai te incomodar.

Se um dia o adormecer incomodar, o plano pago do Render é US$ 7/mês, ou você
migra para um VPS (a partir de ~R$ 22/mês na HostGator, ~€4,35 na Hetzner) e
monta Caddy + systemd. O código não muda.

## Diagnóstico

`/status` é a sua janela para o servidor, já que ninguém está olhando o
terminal:

```json
{
  "chave_anthropic": true,
  "prompt": "phenomenology",
  "iphone_conectado": true,
  "navegadores": 2,
  "ultimo_texto": 1786271936.6,
  "ultimo_erro": null
}
```

| Sintoma | Onde olhar |
|---|---|
| `chave_anthropic: false` | a variável não foi salva no painel do Render |
| `iphone_conectado: false` | o app não chegou — confira o `wss://` |
| `ultimo_erro` preenchido | a mensagem diz o que houve (crédito, modelo, chave) |
| tudo certo mas sem texto | espere o `INTERVALO_CLAUDE` (10 s) |

Os logs completos ficam em *Logs*, no painel do serviço.

## Uma decisão que vale tomar agora

A partir daqui a página é pública de verdade, e ela mostra `latitude` e
`longitude` com quatro casas decimais, atualizando duas vezes por segundo.
Isso localiza você num raio de uns 11 metros, para qualquer pessoa com o link.

O texto do Claude é uma camada de indireção — ele fala de sensação, não de
coordenada. Os números crus, não.

Três saídas, todas de uma linha:

1. Tirar as duas linhas de latitude e longitude do `web/index.html`
2. Arredondar na página para uma casa decimal (~11 km, uma cidade)
3. Não enviar as coordenadas exatas do iPhone, só a variação

Vale decidir antes de divulgar o endereço, não depois.
