from pathlib import Path

HOST = "0.0.0.0"
PORT = 8000

# Diretório da página pública
WEB_DIR = Path(__file__).resolve().parent.parent / "web"

# Segundos entre duas chamadas ao Claude.
# Este é o parâmetro que controla o custo do projeto: 1 segundo significa
# até 3600 chamadas por hora. Aumentar deixa o texto mais lento e mais barato.
INTERVALO_CLAUDE = 6.0

# Frequência com que o estado bruto dos sensores é enviado aos navegadores.
INTERVALO_SENSORES = 0.5

# Com que frequência o servidor confere se rua, clima e sol venceram.
# Não é a frequência das buscas: cada uma tem validade própria e a grade de
# coordenadas evita repetir pedido para o mesmo lugar.
INTERVALO_CONTEXTO = 20.0
