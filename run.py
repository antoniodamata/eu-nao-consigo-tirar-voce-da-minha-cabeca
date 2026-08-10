import os
import sys
from pathlib import Path

import uvicorn

# Os módulos do servidor se importam entre si de forma plana (import state,
# import config), então a pasta server precisa estar no path.
sys.path.insert(0, str(Path(__file__).resolve().parent / "server"))

if __name__ == "__main__":

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8000")),
        reload=False
    )
