# CLAUDE.md

Projects Brazil's presidential election result from TSE's partial counts. Everything lives in
`previsao_apuracao.ipynb` (Portuguese names and comments; keep it that way). `README.md` has run instructions,
election codes and sample `curl` commands.

## Scope

Presidential race only (cargo `0001`). Don't add other offices unless asked.

## Dependencies

numpy, matplotlib and the standard library only (`urllib`, `json`). No pandas or requests, so it runs on a bare
`pip install notebook numpy matplotlib`. It needs network access; JupyterLite can't reach TSE.

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

No test suite. To check changes, run the notebook's code outside Jupyter (see below). With `MPLBACKEND=Agg`,
`plt.show()` is a no-op, so replace it with `plt.savefig(...)` if you want to see the figures.

- `MODO=sintetico` (default): deterministic (seeded). Projection error for B22 should be around ±0.4 pp from ~30%
  counted and exactly 0 at 100%.
- `MODO=ao_vivo CONFIG=2022_2turno`: fetches the final 2022 data; must print L13 50.90% / B22 49.10% and exit.
- `MODO=ao_vivo CONFIG=simulado2026`: outside a simulation window it shows the last completed test count and exits.

The live cell imports `IPython.display`, so outside Jupyter stub `clear_output` or run through
`jupyter nbconvert --to notebook --execute`.

When editing the `.ipynb`, keep the saved outputs of the synthetic run so GitHub renders the chart.
