# Shipped outputs vs this machine's SAS run

Shipped = output file committed by the program's author in the source repo (`output/sas/shipped/<id>`,
inventory in `shipped_outputs.csv`). Ours = produced here by the reference run (SAS 9.4 M3).
First pass 2026-10-27; full pass 2026-10-29 after the renumbering, output capture and orientation fixes.

## Result (2026-10-29)

| id | artifact | result |
|---|---|---|
| P002 | CDISC pilot ADAE re-derived by the original pilot adae.sas | identical to the pilot package ADAE (PROC COMPARE: all values equal) |
| P064 | wxzhai ADLB | identical |
| P065 | wxzhai ADLB_QC | identical |
| P067 | wxzhai AE | identical |
| P021 | clinical-data-to-cdisc tlf_table1.rtf | identical: every visible number and every text cell equal after stripping RTF metadata (author's locale date stamp, font name "Courier" vs "Courier New", page-break markers) |
| P020 | clinical-data-to-cdisc tlf_figure1.rtf | numbers identical except two survival estimates that this SAS prints at the last censored time (0.3598, 0.3954) where the author's SAS printed "."; same LIFETEST, newer output template. Embedded image present in both; byte-wise different as expected |
| P022 | faijal SDTM AE | identical |
| P025 | faijal SDTM EX | identical |
| P027 | faijal SDTM RS | identical |
| P028 | faijal SDTM TR | identical |
| P029 | faijal SDTM TU | identical |
| P030 | faijal SDTM VS | identical |
| P023 | faijal SDTM DM | 1 value differs: RFXENDTC for ONCO-2026-102, shipped 2026-01-20, ours 2026-02-10. The committed raw EX sheet has a CYCLE_2 dose on 10-FEB-2026 for that subject, so ours is correct for the data in the repo; the shipped file predates that row |
| P024 | faijal SDTM DS | DSTERM, DSDECOD, DSCAT, DSSTDTC, DSSTDY are blank in ours for all 5 rows. The program reads TERM, DECOD, CAT and STDT, but the committed raw sheet `edc_ds.xlsx` has columns DS_TERM, DS_CAT, DS_DT (and no DECOD), so SAS logs "Variable TERM is uninitialized". The author's shipped file was produced from an earlier raw layout. Ours is the faithful result of the committed program on the committed data; see note below |
| P026 | faijal SDTM LB | 6 rows both; all values equal set-wise, but LBSEQ 4 and 5 of one subject are swapped (HGB/ALT on the same LBDTC). The program sorts by USUBJID LBDTC and numbers LBSEQ in order, so ties keep input order, which is not fixed by the program |
| P001 | pilot-replication ADSL (shipped adsl.xpt vs ours) | 306 obs both; 36 of 39 variables equal. TRTSDTM/TRTEDTM populated in shipped, missing in ours; EFFFL differs for 2 subjects. Cause: the shipped `adsl.xpt` is the author's **R (admiral)** output, not the SAS program's output (the repo's SAS result `sas_adsl.xpt` is not committed). The SAS program derives TRTSDTM with `input(RFXSTDTC, ?? e8601dt19.)`, and the pilot DM carries date-only RFXSTDTC ("2014-01-02"), so SAS yields missing while admiral imputes midnight. EFFFL: subjects 01-701-1047 and 01-704-1025 have post-baseline ACTOT records (visit 6 / 201) that fall after TRTEDT; the SAS rule counts any post-baseline record (Y), the R rule evidently restricts the window (N). Known R-vs-SAS derivation differences, not an environment problem |
| P040 | kmplot.pdf | shipped 6 pages (dated 7 May 2012), ours 5 pages (no date/page header; `nodate nonumber` in autoexec). Numbers differ: shipped Arm 1 at risk 19, survival 0.9474; ours 17 / 0.9412. The committed program has the typo `227.230` in the Arm 1 DO list (one value 227.23 instead of two values 227, 230), and its header says it was edited for testing after the fact. The shipped PDF was produced before that edit. Ours is correct for the committed source |
| P039 | Supp2Par_v1.pdf | shipped file is the macro's 6-page user guide from `docs/`, not an output. Not comparable; ours is the AEFULL dataset produced by the driver call |
| P001, P002 | adsl_spec.xlsx, adae.json | metadata shipped next to the outputs; not outputs, not compared |

Summary: 11 artifacts identical, 2 equal up to a SAS output-template detail or an unordered tie, 3 differ
because the author's shipped file predates the committed program or data (P023, P024, P040), 1 differs
because the shipped file is an R output (P001). No difference is attributable to this machine or the
patched run copies.

Note on P024: as committed, the author's DS program produces an all-blank disposition domain on the
committed raw data. It stays in the benchmark as is (the reference output is what the program does), but
a translation that reproduces the blanks is a trivial pass; consider weighting it accordingly or patching
the raw column names in a documented run-copy patch.

Also fixed on 2026-10-29: P022/P024/P026/P027/P028 exported their xlsx to the D: root (author's path);
patched to `&outds.` in `patches.csv`, pipeline rerun, exports now under `output/sas/datasets/<id>/`.

Programs: `compare_shipped.sas` (datasets, PROC COMPARE), `compare_p001.sas` / `compare_p001b.sas`
(P001 detail); the 2026-10-29 faijal and RTF/PDF text comparisons were run from scratch scripts
(PROC COMPARE on WORK results keyed by USUBJID/--SEQ; RTF stripped to text; PDF text via PyMuPDF).
