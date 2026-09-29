# CLAUDE.md

Projects Brazil's presidential election result from TSE's partial counts. Everything lives in
`previsao_apuracao.ipynb` (Portuguese names and comments; keep it that way). `README.md` has run instructions,
election codes and sample `curl` commands. `rodar.sh` creates `.venv`, installs the dependencies and opens the notebook
in live mode (defaults `MODO=ao_vivo CONFIG=simulado2026 INTERVALO_S=30`, overridable by env vars). It assumes it
runs from the repo root. Keep it in sync with the README's run steps.

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
- The thread must not use `print()`/`redirect_stdout`: `sys.stdout` is shared with every cell. It writes to a
  `StringIO` shown in an `HTML` widget (`mostrar_tabela` takes `arquivo=`).
- Stop is a `threading.Event`, passed as an argument (re-running the cell rebinds the global and sets the old one).

## Notebook layout

1. Config cell: `CONFIGURACOES` (one entry per election: base URL, ambiente, ciclo, election code, prior election,
   file format), then `MODO` / `CONFIG` / `ELEICAO` / `INTERVALO_S` read from environment variables.
2. TSE data: `baixar_uf` fetches one UF and normalizes it into a snapshot
   `{uf, t, e, ea, s, st, vv, cand}`. `adicionar_snapshot` dedups and appends to `snapshots_*.jsonl`.
3. Model: `lotes` → `proporcao_restante` (per UF) → `projetar` (national sum) → `projetar_com_faixa` (bootstrap).
4. Charts: `grafico`, `mostrar_tabela`.
5. `simular_apuracao`: synthetic count built from the 2022 final results (offline test).
6. Execution cells for `MODO == "sintetico"` and `MODO == "ao_vivo"`.

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
