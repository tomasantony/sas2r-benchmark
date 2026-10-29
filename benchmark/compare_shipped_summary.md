# Shipped outputs vs this machine's SAS run (2026-10-27)

Shipped = output file committed by the program's author in the source repo (output/sas/shipped/<id>).
Ours = produced here by the reference run (SAS 9.4 M3).

| id | artifact | result |
|---|---|---|
| P002 | pilot ADAE re-derived by the original CDISC pilot adae.sas | identical to the pilot package ADAE (PROC COMPARE: all values equal) |
| P064 | wxzhai ADLB | identical |
| P065 | wxzhai ADLB_QC | identical |
| P067 | wxzhai AE | identical |
| P021 | clinical-data-to-cdisc tlf_table1.rtf | every visible number identical; only RTF metadata differs (locale, font name, paper size, cell widths) |
| P020 | clinical-data-to-cdisc tlf_figure1.rtf | text identical in the same way; the embedded figure image differs byte-wise (EMF rendering), as expected |
| P001 | pilot-replication ADSL (shipped adsl.xpt vs ours) | 306 obs both; 35 of 39 variables equal everywhere; TRTSDTM/TRTEDTM are populated in the shipped file (254/252 non-missing) but all missing in ours; EFFFL differs for 2 subjects (01-701-1047, 01-704-1025: shipped N, ours Y). Likely a data-version or derivation-input difference in the author's environment; to investigate |
| P040 | kmplot.pdf | shipped has 6 pages, ours 1 page; not comparable without PDF text extraction |
| P039 | Supp2Par_v1.pdf shipped; ours is listing-only | not compared |
| P022-P030 | faijal SDTM domains shipped as xlsx; ours only as listings | comparable after exporting ours to xlsx; not done |

Programs: compare_shipped.sas, compare_p001.sas, compare_p001b.sas (outputs in the .lst files beside them).
