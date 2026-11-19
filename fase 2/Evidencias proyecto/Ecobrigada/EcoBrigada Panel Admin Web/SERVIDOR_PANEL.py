#!/usr/bin/env python3
"""Servidor estático local para EcoBrigada Admin.

Expone JavaScript con el MIME correcto para navegadores con comprobación estricta
 de módulos ES. No recibe contraseñas ni incorpora claves privadas.
"""
from __future__ import annotations

import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PORT = 8081


class PanelHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".css": "text/css",
        ".json": "application/json",
        ".svg": "image/svg+xml",
        ".html": "text/html; charset=utf-8",
    }

    def guess_type(self, path: str) -> str:
        suffix = Path(path).suffix.lower()
        if suffix in self.extensions_map:
            return self.extensions_map[suffix]
        return super().guess_type(path)


class ReusableHTTPServer(ThreadingHTTPServer):
    allow_reuse_address = True


def main() -> None:
    handler = functools.partial(PanelHandler, directory=str(ROOT))
    with ReusableHTTPServer(("127.0.0.1", PORT), handler) as server:
        print("EcoBrigada - Panel administrativo web", flush=True)
        print(f"Direccion: http://localhost:{PORT}", flush=True)
        print("JavaScript servido como text/javascript", flush=True)
        print("Mantener esta ventana abierta. Para detener: Ctrl+C.", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
