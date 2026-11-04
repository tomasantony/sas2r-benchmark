# sas2r-benchmark: layout, procedure and history

Repository created 2026-10-27 as the reference material for the sas2r-agent entry in the Meta
Global AI Developer Hackathon. Everything here is data, verbatim source programs, the SAS
reference outputs and the scripts that produced and audited them. No agent, translator or
model code lives here; that is the separate sas2r-agent repository.

## Current state

100 active programs, P001-P100: 90 clinical (67 public + 23 owner) and 10 general-purpose.
All 100 run on the reference install with no ERROR in the log (74 clean, 26 with warnings
only). 601 reference files are hashed in `benchmark/sas_output_hashes.csv`; the entry
repository froze 600 of them in `runs/reference_freeze.json` before any model ran. 49
programs that were tried and retired carry R001-R049 in `benchmark/retired.csv`.

| Folder | Contents |
|---|---|
| `benchmark/manifest.csv` | one row per program: id (P001-P100; old_id gives the pre-renumbering id, see id_map.csv), file, group, original corpus path, source repo, licence, data source, outputs, lines |
| `benchmark/retired.csv` | the same columns for R001-R049 and why each was retired |
| `benchmark/data_map.csv` | every libname, path macro, URL fetch, import and %include statement per program, redirected before the SAS reference run |
| `benchmark/candidates/` | the trial run (C001-C045 programs, `candidates.csv`, `results.csv`, logs; the work folders were dropped) used on 2026-10-27 to pick the 26 general-purpose replacement programs; not part of the scored set |
| `programs/sas/` | the 100 SAS programs, verbatim, named `Pnnn_<original name>.sas`; `retired/` holds R001-R049; `own_originals/` the owner's programs before patching; `macros/` the macro libraries |
| `programs/sas_run/` | the copies the runner executes: verbatim plus the minimal patches in `benchmark/patches.csv` (active programs only; retired sources stay under `programs/sas/retired/`) |
| `programs/r/human/` | 6 hand-written R counterparts from the source repositories (kbd0011 pilot ADSL pipeline, PHUSE WPCT figures, demo_summary.R), kept as human reference; no translations |
| `data/raw/` | inputs: CDISC pilot ADaM/SDTM xpt, clinical-data-to-cdisc raw CSVs, faijal-oncology raw xlsx, wxzhai sas7bdat, METABRIC csv, the owner's synthetic study. Read-only |
| `data/derived/` | data the pipeline steps produce and later steps read: the CDISC pilot loaded from xpt by `load_pilot.sas` (adam, sdtm, adam-split), the c2c and wxzhai pipeline outputs. 103 files committed; `sasuser/` and `saswork/` are scratch and ignored |
| `output/sas/{datasets,tlf,logs}` | frozen SAS reference outputs, hashed after the run; `logs/` holds `Pnnn.log` and `Pnnn.lst`; `logs/retired/` the logs of the retired programs |
| `output/sas/shipped/` | outputs the original authors published, for `benchmark/compare_shipped_summary.md` |
| `docs/licenses/` | licence or terms file of every source repository (see `docs/ATTRIBUTION.md`) |

Conventions: output files are named `Pnnn_<type>_<name>` with type t (table), l (listing),
f (figure); figures also write their plotted data as CSV; datasets are exported to CSV for
comparison. The entry repository's comparator pairs `output/sas/<path>` with the R run's
output of the same relative name.

## Macro dependencies (`programs/sas/macros/`)

- `phuse-utilities/`: the 24 PHUSE `util_*` and `assert_*` macros that the WPCT figure programs (R014-R019) call by autocall. Add this folder to SASAUTOS before running them.
- `phuse-jumpstart/`: `data_checks*.sas`, `sl_gs_output.sas`, `err_output.sas` that the FDA JumpStart scripts (R010-R013) `%include` via `&utilpath.` and `&saspath.`.
- `clinical-data-to-cdisc/00_setup.sas`: libnames and `&project_path.` for P-ids from that pipeline.
- `cdisc-pilot/`: setup for the original pilot programs (see data_map for P002).
- `own-tlf/`, `own-adam/`: the owner family's utilities (`u_setup.sas` with `%ods_on`).
- `morioka/`, `sgf2019-matange/`: companion macros for the five driver programs (below).

## Size

About 1 GB: 162 `.sas7bdat` (495 MB) and 52 `.xpt` (459 MB) plus the xls/xlsx inputs in
Git LFS; 95 PDF, 26 RTF, 117 PNG and the programs and logs as plain git objects (about 50 MB).
No file is over 100 MB. The CDISC pilot is present as the raw xpt files, as the loaded
sas7bdat library the programs read, and as the per-domain split some programs expect; the
duplication is deliberate so every program reads the path its author wrote.

## Running the SAS reference batch

`benchmark/run_sas_batch.ps1` runs every manifest row through `sas.exe` (9.4 TS1M3 on the
reference machine) with `benchmark/autoexec.sas`, which sets `&root`, the raw-data paths, an
`outds` libref per program, and SASAUTOS for the PHUSE macros. Each program runs in its own
working folder under `output/sas/datasets/Pnnn/`. Per program it writes `output/sas/logs/Pnnn.log`
and `Pnnn.lst`, and appends a row to `benchmark/run_summary.csv` (rc, seconds, ERROR and
WARNING counts). Use `-Ids`, `-From/-To`, `-DryRun`, `-Force`, `-TimeoutMin`.

`&root` in `autoexec.sas`, the SAS executable path in `run_sas_batch.ps1` and the root in the
`.sh` helpers are hard-wired to the reference machine's clone path; set them to yours first.

Logs are kept on purpose: they are the evidence that the reference outputs came from a
clean run, and the entry's comparator reads them (an ERROR count is a hard fail).

How the reference run was done: `benchmark/make_run_copies.sh` builds `programs/sas_run/`
(verbatim copies plus the minimal path patches listed in `benchmark/patches.csv`,
`patch_urls.pl`, `patch_jumpstart.pl`); `run_sas_batch.ps1` runs each program with `autoexec.sas`
and the family environment in `benchmark/env/`; the families whose programs depend on each other
(clinical-data-to-cdisc, faijal, wxzhai, own-adam) run as ordered pipelines from
`benchmark/pipelines/`. The CDISC pilot transport files were loaded once by `benchmark/load_pilot.sas`
into `data/derived/cdisc-pilot/`. Two PHUSE utility copies carry documented patches
(`util_access_test_data.sas`: read local pilot data; `util_resolve_sasautos.sas`: hyphenated paths).
Results: `benchmark/sas_reference_status.csv` (one row per program with status and reason) and
`benchmark/sas_output_hashes.csv` (md5 of every file under `output/sas`).

## Output capture, drivers and audit

- `benchmark/autoexec.sas` defines `%_bench_capture`: at the end of every program (runner `-termstmt`, or after
  each `%include` in a pipeline) it copies any permanent dataset created or modified during the program into
  `output/sas/datasets/<id>`. Pipeline families and programs with their own librefs therefore leave their
  result per program, while the shared derived libraries stay where the programs expect them.
- `benchmark/drivers/Pnnn.sas`: five programs only define a macro (P039 Supp2Par, P062 diagram_plot,
  P063 event_gant_excel, P098 WaterFall_3D_Macro) or leave their final step commented out (P050).
  `make_run_copies.sh` appends the driver (the author's own usage example, with companion macros from the
  same repository under `programs/sas/macros/morioka` and `programs/sas/macros/sgf2019-matange`) to the run copy
  so each produces an output. The verbatim program in `programs/sas` is unchanged.
- Page orientation: ODS RTF fixes the orientation when the destination opens. The owner's programs (P068-P082)
  and PHUSE disposition_a (P048) set landscape after that point or not at all, so wide tables were cut off at the
  right margin. Patched in `u_setup.sas` (`%ods_on`) and `patches.csv`; see `docs/own_program_patches.md`.
- `benchmark/audit_outputs.ps1` (+ `audit_datasets.sas` for row counts) checks every reference output: log free
  of errors, every file the log reports exists and is complete (RTF braces, PDF EOF, PNG IEND, HTML close),
  RTF tables no wider than the printable page, listings that hit the 132-column line size, datasets with zero
  rows, programs that produced nothing. Result: `benchmark/output_audit.csv`. Run order after a batch:
  scrub_logs, audit_datasets.sas, audit_outputs.ps1, then regenerate `sas_output_hashes.csv`.

## Scrubbing logs before publication

SAS writes the licence holder, site number and platform into every log. `benchmark/scrub_logs.ps1`
rewrites those lines in `output/`, `benchmark/` and `docs/` to `[licence holder removed]`,
`[site removed]` and `[platform removed]`; `scrub_logs.ps1 -Check` reports any file that still
carries an identifier and exits 1, so it can gate a push. Run the scrub after every SAS batch and
before regenerating `sas_output_hashes.csv`, because scrubbing changes the log bytes.

What remains by design: PROC CONTENTS listings and a few logs carry the reference machine's
host name and the `Host Created` platform tag, and two RTF outputs carry the operator name.
These files are among the ones the entry repository froze and hashed before the model runs, so
they are left byte-for-byte as run; rewriting them now would break that chain. For the same
reason the whole `output/sas` tree, including `shipped/retired/` and `logs/retired/`, is kept
exactly as frozen (600 files). The same host
name is recorded in every provenance entry of the entry repository.

## Program ids

Ids were renumbered on 2026-10-27 so the active set reads P001-P100 with no gaps: P001-P090 are
clinical, P091-P100 general-purpose. Retired programs carry R001-R049. `benchmark/id_map.csv`
maps every old id to its new one, and `manifest.csv` / `retired.csv` keep the old id in `old_id`.
Logs, hashes, patches and pipelines all use the new ids.

## History

- 2026-10-27, reference run: 74 of the first 100 programs ran (63 clean, 11 with warnings). The 26
  that did not fall into: SAS/QC not licensed (7), newer SAS release needed (3), PHUSE WPCT
  utility framework incompatible (6), FDA JumpStart needs PC Files Server/Excel (4), bugs in the
  published program (3), data mismatch with the pilot study (3).
- 2026-10-27, swap: those 26 were retired and replaced by 26 general-purpose programs that passed
  the candidates trial run cleanly (67 clinical + 33 general; all 100 ran, 88 clean).
- 2026-10-27, owner family: 23 of the owner's programs replaced 23 general fill-ins (now R027-R049):
  15 TLFs (P068-P082: 8 tables, 4 listings, 3 figures) and 8 ADaM derivations (P083-P090), on a
  synthetic study generated by `benchmark/make_synthetic_study.sas` (seeded; 240 subjects, 3 arms,
  11 ADaM datasets and SDTM DV) stored under `data/raw/own-synthetic/`. The TLFs are patched copies
  (originals in `programs/sas/own_originals/`, every change in `docs/own_program_patches.md`); the
  ADaM programs run as the `own-adam` pipeline. Active set since then: 90 clinical and 10 general,
  all 100 run with no ERROR (74 clean, 26 warnings only). Licence for the owner programs and the
  synthetic study: MIT (confirmed by the author on 2026-10-29).
- 2026-10-29, shipped-output comparison: `benchmark/compare_shipped_summary.md` compares every
  author-shipped output under `output/sas/shipped/` with what the reference run produced: 11
  identical, 2 equal up to an output-template detail or an unordered tie, 3 where the shipped file
  predates the committed program or data (P023, P024, P040), 1 where the shipped file is an R
  output (P001). Five faijal programs (P022, P024, P026, P027, P028) exported their xlsx to the
  drive root; `patches.csv` now redirects them to `&outds.` and the family was rerun. The hash list
  was regenerated after the usual scrub and audit chain (601 files).
- 2026-10-29, P024 (faijal DS): the committed raw sheet `edc_ds.xlsx` names its columns DS_TERM,
  DS_CAT, DS_DT while the program reads TERM, DECOD, CAT, STDT, so the program as written produced
  an all-blank disposition domain. The run copy carries a documented patch in `patches.csv` that
  maps the sheet columns to the names the program expects (DECOD from DS_TERM); the verbatim
  program is unchanged and the reference DS is populated. The remaining SUBJID length warning is
  the author's.
