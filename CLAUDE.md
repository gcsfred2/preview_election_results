# CLAUDE.md

Projects Brazil's presidential election result from TSE's partial counts. Everything lives in
`previsao_apuracao.ipynb` (Portuguese names and comments; keep it that way). `README.md` has run instructions,
election codes and sample `curl` commands. `rodar.sh` creates `.venv`, installs the dependencies and opens the notebook
in live mode (defaults `MODO=ao_vivo CONFIG=simulado2026 INTERVALO_S=30`, overridable by env vars). It assumes it
runs from the repo root. It also runs `tail -F apuracao.log` in the background (killed on exit) so the live loop's log
shows in the same terminal as the Jupyter server log. Keep it in sync with the README's run steps.

## Scope

Presidential race only (cargo `0001`). Don't add other offices unless asked.

## Dependencies

numpy, matplotlib, ipywidgets (live-mode controls only) and the standard library (`urllib`, `json`). No pandas or
requests, so it runs on a bare `pip install notebook numpy matplotlib ipywidgets`. It needs network access; JupyterLite
can't reach TSE.

## Live mode threading

The `ao_vivo` cell starts the polling loop in a daemon thread and returns, so the widgets (Zoom X, Zoom Y, Parar) get
events; a running cell would block them. Consequences:

- `grafico` builds a `matplotlib.figure.Figure` (not pyplot) and returns it; the thread renders it to PNG into an
  `ipywidgets.Image`. `evolucao` is appended and drawn under `trava`.
- The thread must not use `print()`/`redirect_stdout`: `sys.stdout` is shared with every cell. It writes each round
  to a `StringIO` (`mostrar_tabela` takes `arquivo=`) and appends it to `ARQUIVO_LOG` (`apuracao.log`), not to the
  notebook. Writing to the kernel's terminal instead is unreliable: ipykernel captures fd 1/2 and may send it back to
  a cell. The notebook shows only the widgets, the chart and a waiting message that hides on the first draw.
- Stop is a `threading.Event`, passed as an argument (re-running the cell rebinds the global and sets the old one).
- Candidate checkboxes are created by the thread (`atualizar_caixas`) as candidates appear. `estado["automatico"]`
  marks changes made by code (they neither redraw nor count as a user choice); after the first user change
  (`estado["manual"]`) the top-`N_EXIBIDOS` auto-selection stops. `grafico(candidatos=...)` draws the ticked ones.
- `desenhar` errors are caught and logged: an exception in the thread would otherwise end polling silently.

## Chart gotchas

- The bootstrap band (p5–p95) does not always contain the point projection (`final`), so draw it as a segment
  (`vlines`), never as `errorbar` (negative `yerr` raises).
- Colours: `cor(c)` caches per candidate. `CORES_FIXAS` (13/"lula" red, 22/"flávio"/"bolsonaro" blue, case-insensitive
  on the ballot name) win; others take the next `PALETA` colour (tab10 minus blue/red) in order of first appearance.

## Notebook layout

1. Config cell: `CONFIGURACOES` (one entry per election: base URL, ambiente, ciclo, election code, prior election,
   file format), then `MODO` / `CONFIG` / `ELEICAO` / `INTERVALO_S` read from environment variables.
2. TSE data: `baixar_uf` fetches one UF and normalizes it into a snapshot
   `{uf, t, e, ea, s, st, vv, cand}`. `adicionar_snapshot` dedups and appends to `snapshots_*.jsonl`.
3. Model: `lotes` → `proporcao_restante` (per UF) → `projetar` (national sum) → `projetar_com_faixa` (bootstrap).
4. Charts: `grafico`, `mostrar_tabela`.
5. Map (cells `c08a`/`c08b`): `mapa(historico, atualizacao)` draws `ufs.geojson` (IBGE state borders, source in the
   README) with plain matplotlib `fill` in lon/lat (aspect `1/cos(15°)`). Fill = UF leader by counted votes; an inset
   bar chart per UF with the national top 2 (fixed, ignores the checkboxes). Insets sit at the largest polygon's
   centroid, or at `POSICAO_FORA` (small NE/SE states, DF/GO/PI, and `zz`). Only exterior rings are drawn: GO's hole is
   DF, drawn last. The live thread redraws it each round into a second `Image` (`desenhar_mapa`).
6. Highlighted local (`LOCAL`, `URL_LOCAL` in the config cell; `baixar_local` in the TSE data cell; `resumo_local`
   and `tabela_local` in the chart cell): top 3 valid candidates of one municipality zone, shown in an `HTML` widget
   below the map (live mode, "u" layout only) and logged. TSE publishes per zone
   (`dados/{uf}/{uf}{mun:05}-z{zona:04}-c0001-e{ele:06}-u.json`), not per section; per-section data is only in the
   ballot-box files (`arquivo-urna/{pleito}/dados/{uf}/{mun}/{zona}/{secao}/…-aux.json` → binary ASN.1 BU), which the
   simulation left empty. Municipality codes: `{ele}/config/mun-e{ele:06}-cm.json`; sections per zone:
   `arquivo-urna/{pleito}/config/{uf}/{uf}-p{pleito:06}-cs.json`.
   In `consultar`, don't name a local `rotulo`: it would shadow the `rotulo()` function for the whole function.
7. `simular_apuracao`: synthetic count built from the 2022 final results (offline test).
8. Execution cells for `MODO == "sintetico"` and `MODO == "ao_vivo"`.

## TSE file formats

Two layouts, chosen by the config's `formato`:

- `"r"` (2022 and earlier): `{base}/{ambiente}/{ciclo}/{ele}/dados-simplificados/{uf}/{uf}-c0001-e{ele:06}-r.json`.
  Flat fields: `e`, `ea`, `s`, `st`, `vv`, `cand[].n/vap`.
- `"u"` (2026): `{base}/{ambiente}/{ciclo}/{ele}/dados/{uf}/{uf}-c0001-e{ele:06}-u.json`.
  Nested: electorate `e.te`/`e.est`, sections `s.ts`/`s.st`, votes `v.vv`, candidates under
  `carg[0].agr[].par[].cand[]`. Keep only candidates whose `dvt` starts with `"Válido"`; their `vap` sums to `v.vv`.

`dados-simplificados` does not exist for 2026 (404). Codes come from `{base}/{ambiente}/comum/config/ele-c.json`; the
2nd-round code is the `cdt2` field of the 1st-round election.

Percentages are over `vv`. TSE's own `pvap` divides by `vvc`, which also counts votes for "Anulado sub judice"
candidates. The TSE simulations include such candidates, so there the notebook's percentages differ from TSE's by
design.

## Gotchas

- Progress is `ea / e` (electorate of totalized sections). It may never reach 1: abroad (`zz`) has uninstalled
  sections. Completion is `st >= s` for every UF; the live loop stops on that, not on `p >= 1`.
- The TSE simulation resets to zero votes at the start of each window. `adicionar_snapshot` discards a UF's history
  when its `vv` goes down.
- TSE blocks IPs over 100 requests/s, and after many 404s. Build URLs carefully (6-digit election code in the file
  name, lowercase UF) and don't add tight retry loops.
- `www.tse.jus.br` returns 403 to scripted clients. The `resultados*.tse.jus.br` hosts work with plain `curl`/`urllib`.

## Testing

No test suite. To check changes, run the notebook's code outside Jupyter (see below). `grafico` returns a figure;
call `.savefig(...)` on it to see it. The live cell calls `display`; outside Jupyter, stub it, and the widgets work
headless (set `.value`, call `parar.click()`).

As of 29/09/2026 TSE returns 404 for the 2022 files, so `MODO=sintetico` and `CONFIG=2022_2turno` fail at download.
Build the per-UF `finais` by hand and feed them to `simular_apuracao` instead.

- `MODO=sintetico` (default): deterministic (seeded). Projection error for B22 should be around ±0.4 pp from ~30%
  counted and exactly 0 at 100%.
- `MODO=ao_vivo CONFIG=2022_2turno`: fetches the final 2022 data; must print L13 50.90% / B22 49.10% and exit.
- `MODO=ao_vivo CONFIG=simulado2026`: outside a simulation window it shows the last completed test count and exits.

When editing the `.ipynb`, keep the saved outputs of the synthetic run so GitHub renders the chart.
