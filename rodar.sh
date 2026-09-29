#!/usr/bin/env bash
# Cria o ambiente virtual, instala as dependências e abre o notebook no modo ao vivo.
# Rode na raiz do repositório. Padrão: simulado do TSE de 2026. Troque com variáveis de ambiente, por exemplo:
#   CONFIG=2026_1turno ./rodar.sh
#   MODO=sintetico ./rodar.sh
set -euo pipefail

[ -d .venv ] || python3 -m venv .venv
source .venv/bin/activate
pip install -q --disable-pip-version-check notebook numpy matplotlib ipywidgets

export MODO="${MODO:-ao_vivo}" CONFIG="${CONFIG:-simulado2026}" INTERVALO_S="${INTERVALO_S:-30}"
echo "MODO=$MODO CONFIG=$CONFIG INTERVALO_S=$INTERVALO_S"
exec jupyter notebook previsao_apuracao.ipynb
