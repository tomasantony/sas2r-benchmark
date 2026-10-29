# sas2r-agent benchmark tree

Created 2026-10-27 as preparation for the Meta Global AI Developer Hackathon. Everything
here is data and verbatim source programs; the agent code goes in `agent/` and is written
inside the hackathon window.

| Folder | Contents |
|---|---|
| `benchmark/manifest.csv` | one row per program: id (P001-P100: P001-P090 clinical, P091-P100 general; old_id gives the pre-renumbering id, see id_map.csv), file, group, original corpus path, source repo, licence, data source, outputs, lines |
| `benchmark/data_map.csv` | every libname, path macro, URL fetch, import and %include statement per program, to redirect before the SAS reference run |
| `programs/sas/` | the 100 SAS programs, verbatim, named `Pnnn_<original name>.sas` |
| `programs/r/<model>/` | final R translation per program and model (muse-spark, muse-spark-open) |
| `programs/r/human/` | hand-written R references for P-ids that have them (WPCT-F.07.01/02, demo_summary, pilot ADSL) |
| `data/raw/` | inputs: CDISC pilot ADaM/SDTM xpt, clinical-data-to-cdisc raw CSVs, faijal-oncology raw xlsx, wxzhai sas7bdat, METABRIC csv. Read-only |
| `data/derived/` | nothing committed; programs write to output/ |
| `output/sas/{datasets,tlf,logs}` | frozen SAS reference outputs, hashed after the run |
| `output/r/<model>/{datasets,tlf,logs}` | R outputs, same relative filenames as output/sas |
| `compare/<model>/` | one diff report per program (Pnnn.json, Pnnn.md) plus leaderboard.json / leaderboard.md |
| `docs/licenses/` | licence file of every source repo |

Conventions: output files are named `Pnnn_<type>_<name>` with type t (table), l (listing),
f (figure); figures also write their plotted data as CSV; datasets are exported to CSV for
comparison. The comparator pairs `output/sas/<path>` with `output/r/<model>/<path>`.

## Macro dependencies (`programs/sas/macros/`)

- `phuse-utilities/`: the 24 PHUSE `util_*` and `assert_*` macros that the WPCT figure programs (R014-R019) call by autocall. Add this folder to SASAUTOS before running them.
- `phuse-jumpstart/`: `data_checks*.sas`, `sl_gs_output.sas`, `err_output.sas` that the FDA JumpStart scripts (R010-R013) `%include` via `&utilpath.` and `&saspath.`.
- `clinical-data-to-cdisc/00_setup.sas`: libnames and `&project_path.` for P-ids from that pipeline.
- `cdisc-pilot/`: setup for the original pilot programs (see data_map for P002).

## Data size note

`data/raw/cdisc-pilot` is 332 MB because of the large lab, questionnaire and PK xpt files.
GitHub's practical limit is 100 MB per file (all are under it) but a 350 MB repo is slow to
clone. Options before publishing: keep only the xpt files the 100 programs read, or attach
the data as a release asset / Git LFS and document the download step.

## Running the SAS reference batch

`benchmark/run_sas_batch.ps1` runs every manifest row through `sas.exe` (9.4, this machine)
with `benchmark/autoexec.sas`, which sets `&root`, the raw-data paths, an `outds` libref per
program, and SASAUTOS for the PHUSE macros. Each program runs in its own working folder
under `output/sas/datasets/Pnnn/`. Per program it writes `output/sas/logs/Pnnn.log` and
`Pnnn.lst`, and appends a row to `benchmark/run_summary.csv` (rc, seconds, ERROR and
WARNING counts). Use `-Ids`, `-From/-To`, `-DryRun`, `-Force`, `-TimeoutMin`.

Logs are kept on purpose: they are the evidence that the reference outputs came from a
clean run, they feed the comparator (ERROR count is a hard fail), and the R side keeps the
same `Pnnn.log` convention under `output/r/<model>/logs/`.

## SAS reference run (2026-10-27, SAS 9.4 M3 on this machine)

How it was run: `benchmark/make_run_copies.sh` builds `programs/sas_run/` (verbatim copies plus the
minimal path patches listed in `benchmark/patches.csv`, `patch_urls.pl`, `patch_jumpstart.pl`);
`benchmark/run_sas_batch.ps1` runs each program with `benchmark/autoexec.sas` and the family
environment in `benchmark/env/`; the three families whose programs depend on each other
(clinical-data-to-cdisc, faijal, wxzhai) run as ordered pipelines from `benchmark/pipelines/`.
The CDISC pilot transport files were loaded once by `benchmark/load_pilot.sas` into
`data/derived/cdisc-pilot/`. Two PHUSE utility copies carry documented patches
(`util_access_test_data.sas`: read local pilot data; `util_resolve_sasautos.sas`: hyphenated paths).

Results: `benchmark/sas_reference_status.csv` (one row per program with status and reason) and
`benchmark/sas_output_hashes.csv` (md5 of every file under `output/sas`). 74 of 100 programs run
(63 clean, 11 with warnings). The 26 that do not run on this install fall into: SAS/QC not
licensed (7), newer SAS release needed (3), PHUSE WPCT utility framework incompatible (6), FDA
JumpStart needs PC Files Server/Excel (4), bugs in the published program (3), data mismatch with
the pilot study (3). See the status file for each id.

Update 2026-10-27 (swap): the 26 programs that could not run on this install were retired to
`benchmark/retired.csv` (sources in `programs/sas/retired/`, logs in `output/sas/logs/retired/`)
and replaced by 26 general-purpose programs (then numbered P101-P126) that passed a trial run cleanly. The active
set is 67 clinical + 33 general; all 100 now run (88 clean, 12 with warnings only).
`benchmark/sas_reference_status.csv` and `sas_output_hashes.csv` cover the active set.

## Owner family added (2026-10-27)

23 of the owner's programs replaced 23 general fill-ins (23 of those general fill-ins, now R027-R049, retired): 15 TLFs (P068-P082:
8 tables, 4 listings, 3 figures) and 8 ADaM derivations (P083-P090). They run on a synthetic study
generated by `benchmark/make_synthetic_study.sas` (seeded; 240 subjects, 3 arms, 11 ADaM datasets
and SDTM DV) stored under `data/raw/own-synthetic/`. The TLFs are patched copies (originals in
`programs/sas/own_originals/`, every change listed in `docs/own_program_patches.md`); the ADaM
programs carry their data inline and run as the `own-adam` pipeline, which keeps each program's
WORK datasets under `output/sas/datasets/Pnnn/`. Family macros live in `programs/sas/macros/own-tlf`
and `own-adam`. Active set: 90 clinical (67 public + 23 owner) and 10 general; all 100 run with no
ERROR in the log (74 clean, 26 warnings only). Licence for the owner programs and the synthetic
study: MIT, as stated in the repo LICENSE (confirmed by the author on 2026-10-29).

## Scrubbing logs before publication

SAS writes the licence holder, site number and platform into every log. `benchmark/scrub_logs.ps1`
rewrites those lines in `output/`, `benchmark/` and `docs/` to `[licence holder removed]`,
`[site removed]` and `[platform removed]`; `scrub_logs.ps1 -Check` reports any file that still
carries an identifier and exits 1, so it can gate a push. Run the scrub after every SAS batch and
before regenerating `sas_output_hashes.csv`, because scrubbing changes the log bytes.

## Program ids

Ids were renumbered on 2026-10-27 so the active set reads P001-P100 with no gaps: P001-P090 are
clinical, P091-P100 general-purpose. Retired programs carry R001-R049. `benchmark/id_map.csv`
maps every old id to its new one, and `manifest.csv` / `retired.csv` keep the old id in `old_id`.
Logs, hashes, patches and pipelines all use the new ids.

## Output capture, drivers and audit (2026-10-27)

- `benchmark/autoexec.sas` defines `%_bench_capture`: at the end of every program (runner `-termstmt`, or after
  each `%include` in a pipeline) it copies any permanent dataset created or modified during the program into
  `output/sas/datasets/<id>`. Pipeline families (clinical-data-to-cdisc, wxzhai, faijal) and programs with their
  own librefs therefore leave their result per program, while the shared derived libraries stay where the
  programs expect them.
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

## Shipped-output comparison and faijal export fix (2026-10-29)

`benchmark/compare_shipped_summary.md` compares every author-shipped output under `output/sas/shipped/`
with what the reference run produced: 11 identical, 2 equal up to an output-template detail or an
unordered tie, 3 where the shipped file predates the committed program or data (P023, P024, P040),
1 where the shipped file is an R output (P001). Five faijal programs (P022, P024, P026, P027, P028)
exported their xlsx to the D: root; `patches.csv` now redirects them to `&outds.` and the family was
rerun. The hash list was regenerated after the usual scrub and audit chain (601 files).

P024 (faijal DS) addendum, 2026-10-29: the committed raw sheet `edc_ds.xlsx` names its columns DS_TERM, DS_CAT,
DS_DT (no DECOD) while the program reads TERM, DECOD, CAT, STDT, so the program as written produced an all-blank
disposition domain. The run copy now carries a documented patch in `patches.csv` that maps the sheet columns to the
names the program expects (DECOD taken from DS_TERM); the verbatim program is unchanged and the reference DS is
populated. Remaining warning in the log (SUBJID length) is the author's.
