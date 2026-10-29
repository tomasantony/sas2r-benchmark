# Patches applied to the TLF test copies (originals kept as *.sas.orig)

- t_ae_soc_pt, t_ae_sum, t_cm, t_disp, t_dm, t_exposure: PROC TRANSPOSE OUT= gained RENAME=(colPlacebo=col1 colDrug_X_Low_Dose=col2 colDrug_X_High_Dose=col3); the reports reference col1-col3 but ID TRTA produces columns named after the treatment labels.
  that builds the display columns. With prefix=col the programs reference col1-col3, which only exist
  when the ID variable is the numeric treatment code.
- adam/programs/adeff.sas and advs.sas: ABLFL added to the KEEP= list of a dataset that is also filtered
  by WHERE=(ABLFL='Y'); KEEP is applied before WHERE, so the original failed.
- tlf/utilities/u_setup.sas: study paths pointed at the synthetic study (data/synth).
- f_forest.sas: the %DO loop generating y-axis values ran in open code (not allowed); moved into macro %yvals.
- tlf/utilities/u_setup.sas: added %let ntrt = 3 (t_lb_shift loops over &ntrt but nothing defines it).
- t_lb_shift.sas: PROC TRANSPOSE BY changed from TRTA TRTAN to TRTAN TRTA to match the ORDER BY of the preceding SQL step.
- t_cm.sas: PROC SORT by CMCLAS inserted before the MERGE of _atc and _atc_tot (SQL output was grouped by TRTA first).
- f_mean_cfb.sas: template placeholders [PARAMCD]/[Endpoint] filled with ACTOT / ADAS-Cog Total Score.
- t_ae_soc_pt.sas: COMPUTE AFTER AEBODSYS changed to COMPUTE AFTER soc_ord (AEBODSYS is not in the COLUMNS statement).

- `utilities/u_setup.sas` `%ods_on`: added `options orientation=landscape nodate nonumber;` before `ods rtf file=`.
  The programs open the RTF with `%ods_on` and only then call `%m_report`, whose `options orientation=landscape`
  comes too late: ODS RTF fixes the page orientation when the destination opens, so every table and listing was
  rendered portrait and wide tables were cut off at the right margin. (2026-10-27)
- `f_forest`, `f_mean_cfb`, `f_waterfall` (P080-P082, run copies via patches.csv): `options orientation=landscape;`
  inserted before `ods rtf file=`; the 10in-wide graphics were cut off on the default portrait page. (2026-10-27)
