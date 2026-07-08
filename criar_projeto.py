from pathlib import Path

# Estrutura do projeto
estrutura = {
    "app": [
        "SensorApp.xcodeproj",
        "SensorApp"
    ],
    "server": [
        "logs",
        "main.py",
        "websocket_server.py",
        "sensor_buffer.py",
        "logger.py",
        "config.py",
        "requirements.txt"
    ],
    "web": [
        "assets",
        "index.html",
        "style.css",
        "script.js"
    ],
    "data": [
        "raw",
        "interpreted"
    ],
    "prompts": [
        "interpretation.txt"
    ],
    "docs": [
        "arquitetura.md"
    ]
}

# Arquivos da raiz
arquivos_raiz = [
    ".gitignore",
    "README.md",
    "run.py"
]


def criar():
    raiz = Path(".")

    # Pastas e arquivos internos
    for pasta, conteudo in estrutura.items():
        pasta_path = raiz / pasta
        pasta_path.mkdir(parents=True, exist_ok=True)

        for item in conteudo:

            caminho = pasta_path / item

            # Se tiver extensão, é arquivo
            if "." in item:
                caminho.touch(exist_ok=True)

            # Caso contrário, é pasta
            else:
                caminho.mkdir(parents=True, exist_ok=True)

    # Arquivos da raiz
    for arquivo in arquivos_raiz:
        (raiz / arquivo).touch(exist_ok=True)

    print("\n✅ Projeto criado com sucesso!\n")


if __name__ == "__main__":
    criar()
