/*****************************************************************************
* Program:    adex.sas
* Purpose:    Create ADEX (Exposure Analysis Dataset) - BDS Structure
* Standard:   CDISC ADaM IG 1.3
* Input:      SDTM EX, ADSL
* Output:     ADEX
*****************************************************************************/

%include '../macros/m_adam_utilities.sas' / nosource2;

/*==========================================================================
  STEP 1: Create mock SDTM EX data
==========================================================================*/
data ex;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 EXSEQ 8 EXTRT $40 EXDOSE 8 EXDOSU $20
         EXDOSFRM $20 EXROUTE $20 EXSTDTC $10 EXENDTC $10 VISITNUM 8 VISIT $20;
  input STUDYID $ USUBJID $ EXSEQ EXTRT $ EXDOSE EXDOSU $ EXDOSFRM $
        EXROUTE $ EXSTDTC $ EXENDTC $ VISITNUM VISIT $;
datalines;
STUDY01|STUDY01-1001|1|Treatment A|100|mg|TABLET|ORAL|2024-01-15|2024-01-28|1|Week 1-2
STUDY01|STUDY01-1001|2|Treatment A|100|mg|TABLET|ORAL|2024-01-29|2024-02-11|2|Week 3-4
STUDY01|STUDY01-1001|3|Treatment A|150|mg|TABLET|ORAL|2024-02-12|2024-03-10|3|Week 5-8
STUDY01|STUDY01-1001|4|Treatment A|150|mg|TABLET|ORAL|2024-03-11|2024-06-15|4|Week 9+
STUDY01|STUDY01-1002|1|Placebo|0|mg|TABLET|ORAL|2024-01-18|2024-02-14|1|Week 1-4
STUDY01|STUDY01-1002|2|Placebo|0|mg|TABLET|ORAL|2024-02-15|2024-06-18|2|Week 5+
STUDY01|STUDY01-1003|1|Treatment A|100|mg|TABLET|ORAL|2024-01-20|2024-02-16|1|Week 1-4
STUDY01|STUDY01-1003|2|Treatment A|100|mg|TABLET|ORAL|2024-02-17|2024-03-15|2|Week 5-8
STUDY01|STUDY01-1003|3|Treatment A|50|mg|TABLET|ORAL|2024-03-16|2024-04-01|3|Week 9+
STUDY01|STUDY01-1004|1|Treatment A|100|mg|TABLET|ORAL|2024-01-25|2024-06-25|1|All
STUDY01|STUDY01-1005|1|Placebo|0|mg|TABLET|ORAL|2024-01-28|.|1|All
STUDY01|STUDY01-1006|1|Treatment A|100|mg|TABLET|ORAL|2024-01-30|2024-03-30|1|Week 1-8
STUDY01|STUDY01-1006|2|Treatment A|150|mg|TABLET|ORAL|2024-03-31|2024-07-01|2|Week 9+
;
run;

/*==========================================================================
  STEP 2: Create mock ADSL
==========================================================================*/
data adsl;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 TRTP $40 TRTPN 8 AGE 8 SEX $1
         TRTSDT 8 TRTEDT 8 SAFFL $1;
  input STUDYID $ USUBJID $ TRTP $ TRTPN AGE SEX $ SAFFL $
        TRTSDT :date9. TRTEDT :date9.;
  format TRTSDT TRTEDT date9.;
datalines;
STUDY01|STUDY01-1001|Treatment A|1|59|M|Y|15JAN2024|15JUN2024
STUDY01|STUDY01-1002|Placebo|2|45|F|Y|18JAN2024|18JUN2024
STUDY01|STUDY01-1003|Treatment A|1|43|M|Y|20JAN2024|01APR2024
STUDY01|STUDY01-1004|Treatment A|1|51|F|Y|25JAN2024|25JUN2024
STUDY01|STUDY01-1005|Placebo|2|36|M|Y|28JAN2024|.
STUDY01|STUDY01-1006|Treatment A|1|68|F|Y|30JAN2024|01JUL2024
;
run;

/*==========================================================================
  STEP 3: Merge and create base exposure variables
==========================================================================*/
proc sort data=ex; by STUDYID USUBJID; run;
proc sort data=adsl; by STUDYID USUBJID; run;

data adex_base;
  merge ex(in=a) adsl(in=b);
  by STUDYID USUBJID;
  if a and b;

  length PARAMCD $8 PARAM $200 PARAMN 8;
  length AVAL 8 AVALC $40 AVALU $20;
  length ASTDT AENDT 8 ASTDY AENDY 8;
  length AVISIT $40 AVISITN 8;
  length DOSINTFL DOSEADFL $1;

  /*--- Parameter: Dose ---*/
  PARAMCD = 'DOSE';
  PARAM = 'Dose';
  PARAMN = 1;
  AVAL = EXDOSE;
  AVALU = EXDOSU;

  /*--- Convert dates ---*/
  if EXSTDTC ne '' and EXSTDTC ne '.' then ASTDT = input(EXSTDTC, yymmdd10.);
  if EXENDTC ne '' and EXENDTC ne '.' then AENDT = input(EXENDTC, yymmdd10.);

  /*--- Analysis day ---*/
  if not missing(ASTDT) and not missing(TRTSDT) then do;
    if ASTDT >= TRTSDT then ASTDY = ASTDT - TRTSDT + 1;
    else ASTDY = ASTDT - TRTSDT;
  end;
  if not missing(AENDT) and not missing(TRTSDT) then do;
    if AENDT >= TRTSDT then AENDY = AENDT - TRTSDT + 1;
    else AENDY = AENDT - TRTSDT;
  end;

  /*--- Analysis visit ---*/
  AVISIT = VISIT;
  AVISITN = VISITNUM;

  /*--- Duration of this exposure period ---*/
  if not missing(ASTDT) and not missing(AENDT) then
    EXDURN = AENDT - ASTDT + 1;

  /*--- Dose flags ---*/
  /* Dose interruption flag (gap from previous) */
  DOSINTFL = 'N';
  /* Dose adjustment flag */
  DOSEADFL = 'N';

  format ASTDT AENDT date9.;
  drop EXSTDTC EXENDTC VISIT VISITNUM;
run;

/*==========================================================================
  STEP 4: Identify dose adjustments
==========================================================================*/
proc sort data=adex_base; by USUBJID ASTDT; run;

data adex_base;
  set adex_base;
  by USUBJID;

  retain _prev_dose _prev_end;

  if first.USUBJID then do;
    _prev_dose = .;
    _prev_end = .;
  end;

  /*--- Check for dose adjustment from previous ---*/
  if not first.USUBJID and not missing(_prev_dose) and AVAL ne _prev_dose then
    DOSEADFL = 'Y';

  /*--- Check for dose interruption ---*/
  if not first.USUBJID and not missing(_prev_end) and not missing(ASTDT) then do;
    if ASTDT - _prev_end > 1 then DOSINTFL = 'Y';
  end;

  _prev_dose = AVAL;
  _prev_end = AENDT;

  drop _prev_dose _prev_end;
run;

/*==========================================================================
  STEP 5: Create summary exposure parameters
==========================================================================*/

/*--- Total duration ---*/
proc sql;
  create table _totdur as
  select STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX,
         sum(EXDURN) as AVAL,
         'TOTDUR' as PARAMCD length=8,
         'Total Exposure Duration (Days)' as PARAM length=200,
         2 as PARAMN,
         'days' as AVALU length=20
  from adex_base
  group by STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX;
quit;

/*--- Average daily dose ---*/
proc sql;
  create table _avgdose as
  select STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX,
         sum(AVAL * EXDURN) / sum(EXDURN) as AVAL,
         'AVGDOSE' as PARAMCD length=8,
         'Average Daily Dose' as PARAM length=200,
         3 as PARAMN,
         'mg' as AVALU length=20
  from adex_base
  where AVAL > 0
  group by STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX;
quit;

/*--- Maximum dose ---*/
proc sql;
  create table _maxdose as
  select STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX,
         max(AVAL) as AVAL,
         'MAXDOSE' as PARAMCD length=8,
         'Maximum Dose' as PARAM length=200,
         4 as PARAMN,
         'mg' as AVALU length=20
  from adex_base
  where AVAL > 0
  group by STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX;
quit;

/*--- Cumulative dose ---*/
proc sql;
  create table _cumdose as
  select STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX,
         sum(AVAL * EXDURN) as AVAL,
         'CUMDOSE' as PARAMCD length=8,
         'Cumulative Dose' as PARAM length=200,
         5 as PARAMN,
         'mg' as AVALU length=20
  from adex_base
  where AVAL > 0
  group by STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX;
quit;

/*--- Number of dose adjustments ---*/
proc sql;
  create table _ndosadj as
  select STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX,
         sum(case when DOSEADFL = 'Y' then 1 else 0 end) as AVAL,
         'NDOSADJ' as PARAMCD length=8,
         'Number of Dose Adjustments' as PARAM length=200,
         6 as PARAMN,
         '' as AVALU length=20
  from adex_base
  group by STUDYID, USUBJID, TRTP, TRTPN, SAFFL, TRTSDT, TRTEDT, AGE, SEX;
quit;

/*==========================================================================
  STEP 6: Combine all parameters
==========================================================================*/
data adex;
  set adex_base(keep=STUDYID USUBJID TRTP TRTPN SAFFL TRTSDT TRTEDT AGE SEX
                     PARAMCD PARAM PARAMN AVAL AVALU ASTDT AENDT ASTDY AENDY
                     EXDURN DOSINTFL DOSEADFL EXTRT EXDOSE EXDOSU EXDOSFRM EXROUTE EXSEQ AVISIT AVISITN)
      _totdur _avgdose _maxdose _cumdose _ndosadj;
run;

proc delete data=_totdur _avgdose _maxdose _cumdose _ndosadj; run;

/*==========================================================================
  STEP 7: Add sequence and labels
==========================================================================*/
proc sort data=adex; by STUDYID USUBJID PARAMN ASTDT; run;

data adex;
  set adex;
  by STUDYID USUBJID;

  if first.USUBJID then ASEQ = 0;
  ASEQ + 1;

  /*--- Derive dose category ---*/
  length DOSECAT $20;
  if PARAMCD = 'DOSE' then do;
    if AVAL = 0 then DOSECAT = 'Placebo';
    else if AVAL <= 50 then DOSECAT = 'Low';
    else if AVAL <= 100 then DOSECAT = 'Medium';
    else DOSECAT = 'High';
  end;

  label
    STUDYID   = 'Study Identifier'
    USUBJID   = 'Unique Subject Identifier'
    ASEQ      = 'Analysis Sequence Number'
    PARAMCD   = 'Parameter Code'
    PARAM     = 'Parameter'
    PARAMN    = 'Parameter (N)'
    AVAL      = 'Analysis Value'
    AVALU     = 'Analysis Value Unit'
    ASTDT     = 'Analysis Start Date'
    AENDT     = 'Analysis End Date'
    ASTDY     = 'Analysis Start Relative Day'
    AENDY     = 'Analysis End Relative Day'
    AVISIT    = 'Analysis Visit'
    AVISITN   = 'Analysis Visit (N)'
    EXDURN    = 'Exposure Duration (Days)'
    EXTRT     = 'Name of Treatment'
    EXDOSE    = 'Dose per Administration'
    EXDOSU    = 'Dose Units'
    EXDOSFRM  = 'Dose Form'
    EXROUTE   = 'Route of Administration'
    DOSINTFL  = 'Dose Interruption Flag'
    DOSEADFL  = 'Dose Adjustment Flag'
    DOSECAT   = 'Dose Category'
    TRTP      = 'Planned Treatment'
    TRTPN     = 'Planned Treatment (N)'
    SAFFL     = 'Safety Population Flag'
    ;
run;

/*--- Output ---*/
proc contents data=adex varnum; run;
proc print data=adex(obs=20) noobs; run;
