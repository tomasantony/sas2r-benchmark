/*****************************************************************************
 * tlf_demog.sas - Parallel SAS implementation of Table 14.1.1 (Demographics
 * and Baseline Characteristics by Treatment Arm).
 *
 * Mirrors R/07_tlf_tables.R::build_t_demog. PDF/RTF output for side-by-side
 * comparison with the R-built t_14_1_1_demog.pdf.
 *
 * Inputs:  &adam.adsl (built by sas/adsl.sas)
 * Outputs: &outtlf./t_14_1_1_demog_sas.rtf
 *          &outtlf./t_14_1_1_demog_sas.pdf
 *
 * Run on SAS ODA after adsl.sas has populated &adam.adsl.
 *****************************************************************************/

%let adam   = ~/cdisc-pilot/adam;
%let outtlf = ~/cdisc-pilot/tlfs;

libname adam "&adam.";

/* ITT population only - drop Screen Failure subjects */
data itt;
  set adam.adsl;
  where ITTFL = "Y";
  length AGEGR1_LBL $32;
  AGEGR1_LBL = catx(": ", put(AGEGR1N, z1.), AGEGR1);
run;


/* === N counts per ARM (for the "n" row and column headers) ============= */
proc sql noprint;
  select count(*) into :n_total trimmed from itt;
  select put(count(*), 3.) into :n_pbo  trimmed from itt where ARM = "Placebo";
  select put(count(*), 3.) into :n_xlo  trimmed from itt where ARM = "Xanomeline Low Dose";
  select put(count(*), 3.) into :n_xhi  trimmed from itt where ARM = "Xanomeline High Dose";
quit;


/* === AGE descriptives by ARM =========================================== */
proc means data=itt noprint;
  class ARM;
  var AGE;
  output out=_age (drop=_type_ _freq_)
         n=n mean=mean std=std median=median min=mn max=mx;
run;


/* === Categorical counts (AGEGR1, SEX, RACE) ============================ */
%macro cat_summary(var=, lbl=);
  proc freq data=itt noprint;
    tables ARM*&var. / out=_&var. (drop=percent) outpct;
  run;
  data _&var._fmt;
    set _&var.;
    length stat $40 row $40;
    stat = catx(" ", put(count, 3.), cats("(", put(pct_row, 5.1), "%)"));
    row  = "&lbl.";
    keep ARM &var. stat row;
  run;
%mend;
%cat_summary(var=AGEGR1, lbl=Age group);
%cat_summary(var=SEX,    lbl=Sex);
%cat_summary(var=RACE,   lbl=Race);


/* === Render to RTF + PDF ============================================== */
title;
footnote;

ods escapechar = '^';
ods listing close;
ods rtf file="&outtlf./t_14_1_1_demog_sas.rtf" bodytitle nogtitle;
ods pdf file="&outtlf./t_14_1_1_demog_sas.pdf" notoc;

title  j=c "Table 14.1.1 (SAS): Demographics and Baseline Characteristics";
title2 j=c "Intent-to-Treat Population";
footnote j=l "Source: SAS ADSL. Parallel implementation of R t_14_1_1_demog.";

/* Use PROC REPORT to lay out one row per analysis cell with columns by ARM */
proc report data=_age nowd
            style(header)=[fontweight=bold backgroundcolor=lightgrey];
  columns ARM ("Age (years)" n mean std median mn mx);
  define ARM    / group;
  define n      / "n";
  define mean   / "Mean" format=6.2;
  define std    / "SD"   format=6.2;
  define median / "Median" format=6.2;
  define mn     / "Min" format=4.;
  define mx     / "Max" format=4.;
run;

proc report data=_AGEGR1_fmt nowd
            style(header)=[fontweight=bold backgroundcolor=lightgrey];
  columns row AGEGR1 ARM, stat;
  define row    / order "Age group";
  define AGEGR1 / "Group";
  define ARM    / across "Treatment arm";
  define stat   / display "n (%)";
run;

proc report data=_SEX_fmt nowd
            style(header)=[fontweight=bold backgroundcolor=lightgrey];
  columns row SEX ARM, stat;
  define row  / order "Sex";
  define SEX  / "Value";
  define ARM  / across "Treatment arm";
  define stat / display "n (%)";
run;

proc report data=_RACE_fmt nowd
            style(header)=[fontweight=bold backgroundcolor=lightgrey];
  columns row RACE ARM, stat;
  define row  / order "Race";
  define RACE / "Value";
  define ARM  / across "Treatment arm";
  define stat / display "n (%)";
run;

ods pdf close;
ods rtf close;
ods listing;

%put NOTE: SAS demographics table written to &outtlf./t_14_1_1_demog_sas.{rtf,pdf};
