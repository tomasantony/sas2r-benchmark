/*****************************************************************************
* Program:    adsl.sas
* Purpose:    Create ADSL (Subject-Level Analysis Dataset)
* Standard:   CDISC ADaM IG 1.3
* Input:      SDTM DM, DS, EX, SV (mock data inline)
* Output:     ADSL
*****************************************************************************/

%include "&root./programs/sas/macros/own-adam/m_adam_utilities.sas" / nosource2;

/*==========================================================================
  STEP 1: Create mock SDTM source data
==========================================================================*/

/*--- DM (Demographics) ---*/
data dm;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 SUBJID $8 SITEID $4 SEX $1 RACE $50
         ETHNIC $30 ARMCD $8 ARM $40 COUNTRY $3 BRTHDTC $10 RFICDTC $10
         RFSTDTC $10 RFENDTC $10 RFXSTDTC $10 RFXENDTC $10 AGE 8;
  input STUDYID $ USUBJID $ SUBJID $ SITEID $ SEX $ RACE $ ETHNIC $
        ARMCD $ ARM $ COUNTRY $ BRTHDTC $ RFICDTC $ RFSTDTC $
        RFENDTC $ RFXSTDTC $ RFXENDTC $ AGE;
  format _all_;
datalines;
STUDY01|STUDY01-1001|1001|101|M|WHITE|NOT HISPANIC|TRT|Treatment A|USA|1965-03-15|2024-01-10|2024-01-15|2024-06-15|2024-01-15|2024-06-15|59
STUDY01|STUDY01-1002|1002|101|F|BLACK OR AFRICAN AMERICAN|NOT HISPANIC|PBO|Placebo|USA|1978-08-22|2024-01-12|2024-01-18|2024-06-18|2024-01-18|2024-06-18|45
STUDY01|STUDY01-1003|1003|102|M|ASIAN|HISPANIC OR LATINO|TRT|Treatment A|USA|1980-11-01|2024-01-15|2024-01-20|2024-04-01|2024-01-20|2024-04-01|43
STUDY01|STUDY01-1004|1004|102|F|WHITE|NOT HISPANIC|TRT|Treatment A|USA|1972-06-30|2024-01-18|2024-01-25|2024-06-25|2024-01-25|2024-06-25|51
STUDY01|STUDY01-1005|1005|103|M|ASIAN|NOT HISPANIC|PBO|Placebo|USA|1988-02-14|2024-01-20|2024-01-28|.|2024-01-28|.|36
STUDY01|STUDY01-1006|1006|103|F|WHITE|HISPANIC OR LATINO|TRT|Treatment A|USA|1955-12-05|2024-01-22|2024-01-30|2024-07-01|2024-01-30|2024-07-01|68
;
run;

/*--- DS (Disposition) ---*/
data ds;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 DSTERM $50 DSDECOD $50 DSCAT $30 DSSTDTC $10;
  input STUDYID $ USUBJID $ DSTERM $ DSDECOD $ DSCAT $ DSSTDTC $;
datalines;
STUDY01|STUDY01-1001|COMPLETED|COMPLETED|DISPOSITION EVENT|2024-06-15
STUDY01|STUDY01-1002|COMPLETED|COMPLETED|DISPOSITION EVENT|2024-06-18
STUDY01|STUDY01-1003|ADVERSE EVENT|ADVERSE EVENT|DISPOSITION EVENT|2024-04-01
STUDY01|STUDY01-1004|COMPLETED|COMPLETED|DISPOSITION EVENT|2024-06-25
STUDY01|STUDY01-1005|ONGOING|ONGOING|DISPOSITION EVENT|.
STUDY01|STUDY01-1006|COMPLETED|COMPLETED|DISPOSITION EVENT|2024-07-01
;
run;

/*--- EX (Exposure) for treatment dates ---*/
data ex;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 EXTRT $40 EXSTDTC $10 EXENDTC $10;
  input STUDYID $ USUBJID $ EXTRT $ EXSTDTC $ EXENDTC $;
datalines;
STUDY01|STUDY01-1001|Treatment A|2024-01-15|2024-06-15
STUDY01|STUDY01-1002|Placebo|2024-01-18|2024-06-18
STUDY01|STUDY01-1003|Treatment A|2024-01-20|2024-04-01
STUDY01|STUDY01-1004|Treatment A|2024-01-25|2024-06-25
STUDY01|STUDY01-1005|Placebo|2024-01-28|.
STUDY01|STUDY01-1006|Treatment A|2024-01-30|2024-07-01
;
run;

/*==========================================================================
  STEP 2: Derive ADSL variables
==========================================================================*/

/*--- Start with DM as base ---*/
data adsl;
  set dm;

  length TRTSDT TRTEDT RANDDT 8;
  length TRTP $40 TRTPN 8 TRTA $40 TRTAN 8;
  length AGEGR1 $20 AGEGR1N 8 RACEN 8 SEXN 8;
  length SAFFL ITTFL EFFFL COMPLFL $1;
  length DCSREAS $50 EOSSTT $20;
  length TRTDURD 8;

  /*--- Treatment variables ---*/
  TRTP = ARM;
  if ARMCD = 'TRT' then TRTPN = 1;
  else if ARMCD = 'PBO' then TRTPN = 2;

  TRTA = TRTP;
  TRTAN = TRTPN;

  /*--- Convert dates ---*/
  if RFXSTDTC ne '' then TRTSDT = input(RFXSTDTC, yymmdd10.);
  if RFXENDTC ne '' and RFXENDTC ne '.' then TRTEDT = input(RFXENDTC, yymmdd10.);
  if RFSTDTC ne '' then RANDDT = input(RFSTDTC, yymmdd10.);

  /*--- Treatment duration ---*/
  if not missing(TRTSDT) and not missing(TRTEDT) then
    TRTDURD = TRTEDT - TRTSDT + 1;

  /*--- Age group ---*/
  if AGE < 65 then do; AGEGR1 = '<65'; AGEGR1N = 1; end;
  else do; AGEGR1 = '>=65'; AGEGR1N = 2; end;

  /*--- Sex numeric ---*/
  if SEX = 'M' then SEXN = 1;
  else if SEX = 'F' then SEXN = 2;

  /*--- Race numeric ---*/
  select(RACE);
    when('WHITE') RACEN = 1;
    when('BLACK OR AFRICAN AMERICAN') RACEN = 2;
    when('ASIAN') RACEN = 3;
    otherwise RACEN = 4;
  end;

  /*--- Population flags ---*/
  SAFFL = 'Y'; /* All with at least one dose */
  ITTFL = 'Y'; /* All randomized */
  EFFFL = 'Y'; /* Efficacy evaluable */

  format TRTSDT TRTEDT RANDDT date9.;
run;

/*--- Merge disposition ---*/
proc sort data=adsl; by STUDYID USUBJID; run;
proc sort data=ds; by STUDYID USUBJID; run;

data adsl;
  merge adsl(in=a) ds(in=b keep=STUDYID USUBJID DSTERM DSDECOD);
  by STUDYID USUBJID;
  if a;

  /*--- End of Study Status ---*/
  if DSDECOD = 'COMPLETED' then do;
    EOSSTT = 'COMPLETED';
    COMPLFL = 'Y';
    DCSREAS = '';
  end;
  else if DSDECOD = 'ONGOING' then do;
    EOSSTT = 'ONGOING';
    COMPLFL = 'N';
    DCSREAS = '';
  end;
  else do;
    EOSSTT = 'DISCONTINUED';
    COMPLFL = 'N';
    DCSREAS = DSDECOD;
  end;

  drop DSTERM DSDECOD;
run;

/*==========================================================================
  STEP 3: Add labels and finalize
==========================================================================*/
data adsl;
  set adsl;

  label
    STUDYID  = 'Study Identifier'
    USUBJID  = 'Unique Subject Identifier'
    SUBJID   = 'Subject Identifier for the Study'
    SITEID   = 'Study Site Identifier'
    SEX      = 'Sex'
    SEXN     = 'Sex (N)'
    RACE     = 'Race'
    RACEN    = 'Race (N)'
    ETHNIC   = 'Ethnicity'
    AGE      = 'Age'
    AGEGR1   = 'Age Group 1'
    AGEGR1N  = 'Age Group 1 (N)'
    ARM      = 'Description of Planned Arm'
    ARMCD    = 'Planned Arm Code'
    TRTP     = 'Planned Treatment'
    TRTPN    = 'Planned Treatment (N)'
    TRTA     = 'Actual Treatment'
    TRTAN    = 'Actual Treatment (N)'
    TRTSDT   = 'Date of First Exposure to Treatment'
    TRTEDT   = 'Date of Last Exposure to Treatment'
    TRTDURD  = 'Total Treatment Duration (Days)'
    RANDDT   = 'Date of Randomization'
    SAFFL    = 'Safety Population Flag'
    ITTFL    = 'Intent-to-Treat Population Flag'
    EFFFL    = 'Efficacy Population Flag'
    COMPLFL  = 'Completers Population Flag'
    EOSSTT   = 'End of Study Status'
    DCSREAS  = 'Reason for Discontinuation'
    COUNTRY  = 'Country'
    ;
run;

proc sort data=adsl; by STUDYID USUBJID; run;

/*--- Output ---*/
proc contents data=adsl varnum; run;
proc print data=adsl(obs=10) noobs; run;
