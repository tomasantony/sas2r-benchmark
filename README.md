# sas2r-benchmark

A 100-program SAS-to-R translation benchmark for clinical trial programming:
the SAS programs, their input data, the reference outputs produced by SAS 9.4,
and the scripts that run, capture and audit them.

This repository is the **pre-existing / reference material** for the
[sas2r-agent](https://github.com/tomasantony/sas2r-agent) entry in the Meta
Global AI Developer Hackathon (October to November 2026). The agent repository
contains only work done inside the hackathon window; this one holds the corpus
it is scored against.

Full documentation, program ids, directory layout and the run procedure are in
[docs/README.md](docs/README.md). Program provenance and licences are in
[docs/ATTRIBUTION.md](docs/ATTRIBUTION.md), `benchmark/manifest.csv` and
`docs/licenses/`.

## Contents

```
programs/sas       100 active programs P001-P100 (verbatim) + retired R001-R049
programs/sas_run   patched copies the runner executes (patches listed in benchmark/)
programs/r         R reference translations (held out for scoring)
data/raw           public input data (CDISC pilot, PHUSE, synthetic study)
data/derived       data produced by the pipeline steps
output/sas         reference outputs, logs and listings per program
benchmark/         manifest, families, env files, runner, audit and hash scripts
docs/              documentation and licences
```

Datasets and transport files (`.sas7bdat`, `.xpt`, `.xls`, `.xlsx`) are stored
with Git LFS; run `git lfs install` before cloning.

## Licence

Harness scripts, documentation and the author's own programs: MIT, see
`LICENSE`. Third-party programs and data keep their original licences, as
recorded per program in `benchmark/manifest.csv` and `docs/licenses/`.
