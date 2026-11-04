# sas2r-benchmark

A 100-program SAS-to-R translation benchmark for clinical trial programming:
the SAS programs, their input data, the reference outputs produced by SAS 9.4,
and the scripts that run, capture, scrub and audit them.

This repository is the **reference material** for the
[sas2r-agent](https://github.com/tomasantony/sas2r-agent) entry in the Meta
Global AI Developer Hackathon (26 October to 4 November 2026). It is kept
separate so the entry repository holds only the agent, and so the SAS side
(programs, data, reference outputs, SAS harness) can be frozen and hashed
independently of anything a model produces. It contains no agent, translator or
model code.

Timeline, so the two repositories read consistently: the corpus of public
programs and data was collected before the hackathon window; the SAS reference
run, the retire-and-replace of programs that do not run on the reference
install, the 23 owner programs on a synthetic study, and this repository itself
were made on 27 to 29 October 2026, inside the window. The reference outputs
were hashed (`benchmark/sas_output_hashes.csv`, and `runs/reference_freeze.json`
in the entry repository) before any model was run against them.

Full documentation, program ids, directory layout and the run procedure are in
[docs/README.md](docs/README.md). Program provenance and licences are in
[docs/ATTRIBUTION.md](docs/ATTRIBUTION.md), `benchmark/manifest.csv` and
`docs/licenses/`.

## Contents

```
programs/sas            100 active programs P001-P100, verbatim; retired/ holds R001-R049 (see retired.csv)
programs/sas/macros     macro libraries the programs need (PHUSE utilities, FDA JumpStart, family setups, owner macros)
programs/sas/own_originals  the owner's 23 programs before the documented path/orientation patches
programs/sas_run        patched copies the runner executes (patches listed in benchmark/patches.csv); retired/ as above
programs/r/human        6 hand-written R counterparts from the source repositories (kbd0011, PHUSE), kept as human reference
data/raw                public input data (CDISC pilot, PHUSE, three GitHub pipelines, the owner's synthetic study)
data/derived            data the pipeline steps produce and later steps read (CDISC pilot loaded from xpt, c2c, wxzhai)
output/sas              reference outputs per program: datasets/, tlf/, logs/ (log + listing); shipped/ holds the
                        outputs the original authors published, for the shipped-versus-produced comparison
benchmark/              manifest, retired list, id map, families, env files, pipelines, drivers, patches, runner,
                        scrub, audit and hash scripts; candidates/ is the trial run used to choose the replacement programs
docs/                   documentation, attribution and licences
```

## Size and cloning

About 1 GB. Datasets and transport files (`.sas7bdat`, `.xpt`, `.xls`, `.xlsx`)
are stored with Git LFS (about 1 GB in 254 objects); outputs, programs and
logs are plain git (about 50 MB). Run `git lfs install` before cloning. The
sas2r-agent harness reads only `programs/`, `data/` and `output/sas/`, and its
comparator needs `output/sas` and the data the R scripts read; the leaderboard
in the entry repository can be reproduced without SAS.

## Running the SAS reference batch

Reproducing the reference outputs needs SAS 9.4 on Windows; nothing else in the
entry depends on doing so. The harness paths are hard-wired to the reference
machine (`&root` in `benchmark/autoexec.sas`, the SAS path in
`benchmark/run_sas_batch.ps1`); set them to your clone before running.

```
benchmark/make_run_copies.sh           # programs/sas -> programs/sas_run with the documented patches
benchmark/run_sas_batch.ps1            # run every manifest row; logs, listings and outputs under output/sas
benchmark/scrub_logs.ps1               # remove licence holder, site and platform lines from logs
benchmark/audit_outputs.ps1            # every reported output exists and is complete; output_audit.csv
benchmark/scrub_logs.ps1 -Check        # publication gate: exits 1 if any identifier remains
```

Then regenerate `benchmark/sas_output_hashes.csv`. Details, the pipeline
families and the per-program status are in `docs/README.md`.

## Licence

Harness scripts, documentation, the author's own programs and the synthetic
study: MIT, see `LICENSE`. Third-party programs and data keep their original
licences, as recorded per program in `benchmark/manifest.csv`,
`benchmark/retired.csv`, `docs/ATTRIBUTION.md` and `docs/licenses/`.
