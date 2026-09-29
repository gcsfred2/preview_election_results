# Projeção da apuração (Presidente)

Notebook que projeta o resultado final da eleição presidencial a partir dos resultados parciais publicados pelo TSE
durante a apuração. Em vez de ajustar uma curva ao horário, ele:

1. usa como eixo a **fração do eleitorado já apurado** em cada UF (o final é o valor em 100%);
2. estima como votarão as urnas que faltam pela **tendência dos lotes novos** de cada atualização;
3. projeta **cada UF separadamente** e soma, com faixa de incerteza (5%–95%) por bootstrap.

Só a eleição presidencial (cargo `0001`) é tratada.

## Como rodar localmente

Requer Python 3.9+ e acesso à internet. O JupyterLite (Jupyter no navegador) **não** funciona: ele não consegue
baixar os arquivos do TSE.

```bash
git clone https://github.com/gcsfred2/preview_election_results.git
cd preview_election_results
python3 -m venv .venv
source .venv/bin/activate
pip install notebook numpy matplotlib ipywidgets
jupyter notebook previsao_apuracao.ipynb
```

Ou, depois do `git clone`, use o script `rodar.sh` na raiz do repositório. Ele faz esses passos (cria o `.venv` se
ainda não existir e instala as dependências) e abre o notebook no modo ao vivo do simulado do TSE
(`MODO=ao_vivo CONFIG=simulado2026 INTERVALO_S=30`):

```bash
cd preview_election_results
./rodar.sh
CONFIG=2026_1turno ./rodar.sh   # as variáveis da tabela abaixo trocam os padrões
```

No Jupyter, rode todas as células (**Run → Run All Cells**). No modo ao vivo, a última célula consulta o TSE numa
thread em segundo plano. O registro de cada consulta (projeção, faixa, tabela por UF e falhas de download) vai para o
arquivo `apuracao.log` (ignorado pelo git), não para o notebook. O `rodar.sh` mostra esse registro no terminal, junto
com o log do Jupyter; sem ele, acompanhe com `tail -f apuracao.log`.

No notebook ficam só o gráfico e, acima dele:

- **Zoom X** e **Zoom Y**: multiplicadores (padrão 1, passo 0,2). Com zoom *z*, o gráfico mostra 1/*z* da largura ou
  da altura; o eixo x termina perto do ponto mais recente e o eixo y fica centrado nas curvas visíveis. O gráfico é
  redesenhado na hora, sem esperar a próxima consulta.
- **Parar**: encerra as consultas. Para recomeçar, rode a célula de novo.

Os controles usam o `ipywidgets`. Se o Jupyter já estava aberto quando ele foi instalado, reinicie o Jupyter.

### Parâmetros

A execução é controlada por variáveis de ambiente, lidas quando o kernel inicia (ou edite os valores na célula de
configuração):

| Variável | Valores | Padrão |
| --- | --- | --- |
| `MODO` | `sintetico` (teste offline, sem depender de eleição em andamento) ou `ao_vivo` (consulta o TSE) | `sintetico` |
| `CONFIG` | `2022_2turno`, `simulado2026`, `2026_1turno`, `2026_2turno` | `2022_2turno` |
| `ELEICAO` | código da eleição; substitui o da configuração (obrigatório em `2026_2turno`) | — |
| `INTERVALO_S` | segundos entre consultas no modo ao vivo | `30` |

O limite do TSE é de 100 requisições por segundo por IP (bloqueio de 10 minutos se excedido). Cada consulta do
notebook faz 28 requisições (27 UFs + exterior), bem abaixo disso.

Os snapshots baixados são gravados em `snapshots_<ambiente>_<ciclo>_<eleição>.jsonl` (ignorado pelo git). Reiniciar o
notebook retoma o histórico. Apague o arquivo para começar do zero.

### Teste offline (apuração sintética)

```bash
jupyter notebook previsao_apuracao.ipynb    # MODO=sintetico é o padrão
```

Baixa o resultado final do 2º turno de 2022 por UF e reconstrói uma apuração artificial, comparando a projeção com o
resultado real. Não confundir com o simulado do TSE abaixo.

### Simulado do TSE de hoje (28/09/2026, 14h–16h de Brasília)

O TSE publica apurações de teste com candidatos fictícios. Janelas de 2026: 15, 16 e 17/09 e 22, 23 e 24/09 (9h–12h e
14h–17h), e 28 e 29/09 (14h–16h).

```bash
MODO=ao_vivo CONFIG=simulado2026 INTERVALO_S=30 jupyter notebook previsao_apuracao.ipynb
# ou, equivalente:
./rodar.sh
```

Parâmetros usados (`CONFIG=simulado2026`):

| | |
| --- | --- |
| url base | `https://resultados-sim.tse.jus.br/simulado` |
| ambiente | `simulado2026` |
| ciclo | `ele2026` |
| pleito | `17801` |
| eleição (Presidente, 1º turno) | `21270` |
| cargo | `0001` |

Comece depois das 14h. Antes do início, os arquivos ainda trazem a apuração completa do teste anterior; o laço mostra
esse resultado e termina porque todas as seções já estão totalizadas. Quando o TSE zera a apuração, o notebook
descarta o histórico da UF e recomeça sozinho.

Nesse simulado há candidatos com situação "Anulado" e "Anulado sub judice". O notebook calcula percentuais sobre os
votos válidos (`vv`), enquanto o site do TSE usa `vvc`, que também inclui votos em candidatos sub judice. Por isso os
percentuais podem diferir dos do site do TSE; os votos absolutos são os mesmos.

### Dias da eleição

| Turno | Data | Comando |
| --- | --- | --- |
| 1º turno | 04/10/2026 (pleito 3220, eleição 6257) | `MODO=ao_vivo CONFIG=2026_1turno jupyter notebook previsao_apuracao.ipynb` |
| 2º turno | 25/10/2026 (código a publicar) | `MODO=ao_vivo CONFIG=2026_2turno ELEICAO=<código> jupyter notebook previsao_apuracao.ipynb` |

Nos dois casos: url base `https://resultados.tse.jus.br`, ambiente `oficial`, cargo `0001`. O ciclo `ele2026` é o que
o simulado usa; confirme no arquivo de configuração oficial (abaixo) antes da eleição. O código do 2º turno é o campo
`cdt2` da eleição 6257 nesse mesmo arquivo. No 2º turno, as UFs ainda sem votos usam o resultado do 1º turno como
estimativa.

## Comandos `curl` de exemplo

Os arquivos são JSON. Os exemplos usam `python3` para resumir a saída; `jq` também serve.

### Simulado 2026

```bash
SIM=https://resultados-sim.tse.jus.br/simulado/simulado2026

# Eleições com cargo Presidente: código, código do 2º turno, nome
curl -s "$SIM/comum/config/ele-c.json" | python3 -c '
import html, json, sys
for p in json.load(sys.stdin)["pl"]:
    for e in p["e"]:
        if any(c["cd"] == "1" for a in e["abr"] for c in a["cp"]):
            print(e["cd"], "2º turno:", e["cdt2"] or "-", html.unescape(e["nm"]))'

# Presidente, Brasil: horário, % de seções totalizadas, votos válidos e candidatos mais votados
curl -s "$SIM/ele2026/21270/dados/br/br-c0001-e021270-u.json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d["dt"], d["ht"], "seções", d["s"]["pst"] + "%", "válidos", d["v"]["vv"])
cands = [c for a in d["carg"][0]["agr"] for p in a["par"] for c in p["cand"]]
for c in sorted(cands, key=lambda c: -int(c["vap"]))[:5]:
    print(" ", c["n"], c["nmu"], c["vap"], c["dvt"])'

# Presidente, uma UF (sp); o notebook baixa este arquivo para cada UF e para o exterior (zz)
curl -s "$SIM/ele2026/21270/dados/sp/sp-c0001-e021270-u.json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("eleitorado", d["e"]["te"], "apurado", d["e"]["est"], "seções", d["s"]["st"], "/", d["s"]["ts"])'
```

### Eleição 2026 (oficial)

```bash
TSE=https://resultados.tse.jus.br/oficial

# Configuração oficial: ciclo atual e eleições com cargo Presidente (código, código do 2º turno, nome).
# Em 28/09/2026 ainda mostrava o ciclo ele2024, sem eleição presidencial.
curl -s "$TSE/comum/config/ele-c.json" | python3 -c '
import html, json, sys
d = json.load(sys.stdin)
print("ciclo", d["c"])
for p in d["pl"]:
    for e in p["e"]:
        if any(c["cd"] == "1" for a in e["abr"] for c in a["cp"]):
            print(e["cd"], "2º turno:", e["cdt2"] or "-", html.unescape(e["nm"]))'

# Presidente, Brasil, 1º turno (04/10/2026)
curl -s "$TSE/ele2026/6257/dados/br/br-c0001-e006257-u.json"

# Presidente, Brasil, 2º turno (25/10/2026): troque 6258 pelo cdt2 da eleição 6257
ELEICAO=6258
curl -s "$TSE/ele2026/$ELEICAO/dados/br/br-c0001-e$(printf %06d $ELEICAO)-u.json"
```

O código da eleição aparece com 6 dígitos no nome do arquivo (`e006257`). Muitos erros 404 seguidos podem bloquear
o IP temporariamente, então confira as URLs antes de automatizar.

### Eleição 2022 (leiaute antigo, usado no teste offline)

```bash
# Presidente, 2º turno de 2022, Brasil (dados-simplificados, arquivos *-r.json)
curl -s https://resultados.tse.jus.br/oficial/ele2022/545/dados-simplificados/br/br-c0001-e000545-r.json | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("seções", d["pst"] + "%", [(c["n"], c["pvap"]) for c in d["cand"]])'
```

## Referências

- [Informações técnicas sobre a divulgação de resultados (TSE)](https://www.tse.jus.br/eleicoes/informacoes-tecnicas-sobre-a-divulgacao-de-resultados):
  códigos das eleições, simulados, limites de acesso e leiaute dos arquivos (aba Documentos).
- [Resultados do simulado](https://resultados-sim.tse.jus.br/simulado/simulado2026/app/index.html), para conferir os
  números.
