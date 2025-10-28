#!/usr/bin/env bash
# Build script: instala pacotes R necessários e renderiza o site
set -euo pipefail

# Diretório deste script (Tentativa3)
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "Base dir: $BASE_DIR"

echo "1) Instalando pacotes R (se necessário)..."
Rscript "$BASE_DIR/scripts/install_packages.R"

echo "2) Renderizando site..."
Rscript "$BASE_DIR/scripts/build_site.R" "$BASE_DIR"

echo "Build concluído. Saída em: $BASE_DIR/docs"
