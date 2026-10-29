/*****************************************************************************
* Program:    advs.sas
* Purpose:    Create ADVS (Vital Signs Analysis Dataset) - BDS Structure
* Standard:   CDISC ADaM IG 1.3
* Input:      SDTM VS, ADSL
* Output:     ADVS
*****************************************************************************/

%include '../macros/m_adam_utilities.sas' / nosource2;
%include '../macros/m_derive_param.sas' / nosource2;
%include '../macros/m_derive_extreme.sas' / nosource2;

/*==========================================================================
  STEP 1: Create mock SDTM VS data
==========================================================================*/
data vs;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 VSSEQ 8 VSTESTCD $8 VSTEST $40
         VSORRES $20 VSORRESU $10 VSSTRESN 8 VSSTRESU $10
         VISIT $20 VISITNUM 8 VSDTC $10;
  input STUDYID $ USUBJID $ VSSEQ VSTESTCD $ VSTEST $ VSORRES $
        VSORRESU $ VSSTRESN VSSTRESU $ VISIT $ VISITNUM VSDTC $;
datalines;
STUDY01|STUDY01-1001|1|SYSBP|Systolic Blood Pressure|128|mmHg|128|mmHg|Baseline|1|2024-01-15
STUDY01|STUDY01-1001|2|DIABP|Diastolic Blood Pressure|82|mmHg|82|mmHg|Baseline|1|2024-01-15
STUDY01|STUDY01-1001|3|PULSE|Pulse Rate|72|beats/min|72|beats/min|Baseline|1|2024-01-15
STUDY01|STUDY01-1001|4|SYSBP|Systolic Blood Pressure|122|mmHg|122|mmHg|Week 4|2|2024-02-12
STUDY01|STUDY01-1001|5|DIABP|Diastolic Blood Pressure|78|mmHg|78|mmHg|Week 4|2|2024-02-12
STUDY01|STUDY01-1001|6|PULSE|Pulse Rate|70|beats/min|70|beats/min|Week 4|2|2024-02-12
STUDY01|STUDY01-1001|7|SYSBP|Systolic Blood Pressure|118|mmHg|118|mmHg|Week 8|3|2024-03-11
STUDY01|STUDY01-1001|8|DIABP|Diastolic Blood Pressure|76|mmHg|76|mmHg|Week 8|3|2024-03-11
STUDY01|STUDY01-1002|1|SYSBP|Systolic Blood Pressure|140|mmHg|140|mmHg|Baseline|1|2024-01-18
STUDY01|STUDY01-1002|2|DIABP|Diastolic Blood Pressure|90|mmHg|90|mmHg|Baseline|1|2024-01-18
STUDY01|STUDY01-1002|3|SYSBP|Systolic Blood Pressure|138|mmHg|138|mmHg|Week 4|2|2024-02-15
STUDY01|STUDY01-1002|4|DIABP|Diastolic Blood Pressure|88|mmHg|88|mmHg|Week 4|2|2024-02-15
STUDY01|STUDY01-1003|1|SYSBP|Systolic Blood Pressure|120|mmHg|120|mmHg|Baseline|1|2024-01-20
STUDY01|STUDY01-1003|2|DIABP|Diastolic Blood Pressure|75|mmHg|75|mmHg|Baseline|1|2024-01-20
STUDY01|STUDY01-1003|3|SYSBP|Systolic Blood Pressure|115|mmHg|115|mmHg|Week 4|2|2024-02-17
STUDY01|STUDY01-1004|1|SYSBP|Systolic Blood Pressure|132|mmHg|132|mmHg|Baseline|1|2024-01-25
STUDY01|STUDY01-1005|1|SYSBP|Systolic Blood Pressure|118|mmHg|118|mmHg|Baseline|1|2024-01-28
STUDY01|STUDY01-1006|1|SYSBP|Systolic Blood Pressure|145|mmHg|145|mmHg|Baseline|1|2024-01-30
;
run;

/*==========================================================================
  STEP 2: Create mock ADSL subset
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
  STEP 3: Merge and create base ADVS structure
==========================================================================*/
proc sort data=vs; by STUDYID USUBJID; run;
proc sort data=adsl; by STUDYID USUBJID; run;

data advs_base;
  merge vs(in=a) adsl(in=b);
  by STUDYID USUBJID;
  if a and b;

  length PARAMCD $8 PARAM $200 PARAMN 8 PARCAT1 $50;
  length AVAL 8 AVALC $200 AVALU $20;
  length ADT 8 ADY 8 ATPT $20 ATPTN 8;
  length AVISIT $40 AVISITN 8;
  length ABLFL $1 ANL01FL $1;

  /*--- Map to ADaM PARAM structure ---*/
  PARAMCD = VSTESTCD;
  PARAM = VSTEST;
  PARCAT1 = 'VITAL SIGNS';

  /*--- PARAMN ---*/
  select(PARAMCD);
    when('SYSBP') PARAMN = 1;
    when('DIABP') PARAMN = 2;
    when('PULSE') PARAMN = 3;
    when('TEMP')  PARAMN = 4;
    when('RESP')  PARAMN = 5;
    when('WEIGHT') PARAMN = 6;
    when('HEIGHT') PARAMN = 7;
    otherwise PARAMN = 99;
  end;

  /*--- Analysis value ---*/
  AVAL = VSSTRESN;
  AVALU = VSSTRESU;

  /*--- Analysis date and day ---*/
  if VSDTC ne '' then ADT = input(VSDTC, yymmdd10.);

  if not missing(ADT) and not missing(TRTSDT) then do;
    if ADT >= TRTSDT then ADY = ADT - TRTSDT + 1;
    else ADY = ADT - TRTSDT;
  end;

  /*--- Analysis visit ---*/
  AVISIT = VISIT;
  AVISITN = VISITNUM;

  /*--- Analysis timepoint (if multiple per day) ---*/
  ATPT = '';
  ATPTN = .;

  format ADT date9.;
  drop VSTESTCD VSTEST VSORRES VSORRESU VSSTRESN VSSTRESU VISIT VISITNUM VSDTC;
run;

/*==========================================================================
  STEP 4: Derive baseline flag
==========================================================================*/
proc sort data=advs_base; by USUBJID PARAMCD ADT; run;

data advs_base;
  set advs_base;
  by USUBJID PARAMCD;

  /*--- Last value on or before TRTSDT is baseline ---*/
  if not missing(ADT) and not missing(TRTSDT) then do;
    if ADT <= TRTSDT then _pre_trt = 1;
    else _pre_trt = 0;
  end;
run;

/* Identify baseline - last pre-treatment record */
proc sort data=advs_base; by USUBJID PARAMCD descending ADT; run;

data advs_base;
  set advs_base;
  by USUBJID PARAMCD;
  if first.PARAMCD and _pre_trt = 1 then ABLFL = 'Y';
  else ABLFL = '';
  drop _pre_trt;
run;

proc sort data=advs_base; by USUBJID PARAMCD ADT; run;

/*==========================================================================
  STEP 5: Derive BASE, CHG, PCHG
==========================================================================*/
/* Get baseline values */
data _baseline_;
  set advs_base(where=(ABLFL='Y'));
  BASE = AVAL;
  keep USUBJID PARAMCD BASE;
run;

/* Merge baseline */
proc sort data=advs_base; by USUBJID PARAMCD; run;
proc sort data=_baseline_; by USUBJID PARAMCD; run;

data advs;
  merge advs_base(in=a) _baseline_;
  by USUBJID PARAMCD;
  if a;

  /*--- Derive change from baseline ---*/
  if not missing(AVAL) and not missing(BASE) then do;
    CHG = AVAL - BASE;
    if BASE ne 0 then PCHG = (CHG / BASE) * 100;
  end;

  /*--- Analysis flag for post-baseline ---*/
  if ABLFL ne 'Y' and not missing(AVAL) and ADT > TRTSDT then ANL01FL = 'Y';
  else ANL01FL = '';
run;

proc delete data=_baseline_; run;

/*==========================================================================
  STEP 6: Add derived records (e.g., maximum post-baseline)
==========================================================================*/
/* Maximum post-baseline value */
proc means data=advs(where=(ABLFL ne 'Y' and ADT > TRTSDT)) noprint;
  by USUBJID PARAMCD;
  var AVAL;
  output out=_max_post(drop=_type_ _freq_) max=AVAL;
run;

data _max_post;
  merge _max_post(in=a) advs(where=(ABLFL='Y') keep=ABLFL USUBJID PARAMCD BASE);
  by USUBJID PARAMCD;
  if a;
  length DTYPE $20 AVISIT $40;
  DTYPE = 'MAXIMUM';
  AVISIT = 'Maximum Post-Baseline';
  AVISITN = 99;
  if not missing(AVAL) and not missing(BASE) then CHG = AVAL - BASE;
run;

data advs;
  set advs _max_post;
run;

/*==========================================================================
  STEP 7: Add sequence and labels
==========================================================================*/
proc sort data=advs; by STUDYID USUBJID PARAMCD AVISITN ADT; run;

data advs;
  set advs;
  by STUDYID USUBJID;
  if first.USUBJID then ASEQ = 0;
  ASEQ + 1;

  label
    STUDYID  = 'Study Identifier'
    USUBJID  = 'Unique Subject Identifier'
    ASEQ     = 'Analysis Sequence Number'
    PARAMCD  = 'Parameter Code'
    PARAM    = 'Parameter'
    PARAMN   = 'Parameter (N)'
    PARCAT1  = 'Parameter Category 1'
    AVAL     = 'Analysis Value'
    AVALU    = 'Analysis Value Unit'
    BASE     = 'Baseline Value'
    CHG      = 'Change from Baseline'
    PCHG     = 'Percent Change from Baseline'
    ADT      = 'Analysis Date'
    ADY      = 'Analysis Relative Day'
    AVISIT   = 'Analysis Visit'
    AVISITN  = 'Analysis Visit (N)'
    ABLFL    = 'Baseline Record Flag'
    ANL01FL  = 'Analysis Record Flag 01'
    DTYPE    = 'Derivation Type'
    TRTP     = 'Planned Treatment'
    TRTPN    = 'Planned Treatment (N)'
    TRTSDT   = 'Date of First Exposure to Treatment'
    SAFFL    = 'Safety Population Flag'
    ;
run;

/*--- Output ---*/
proc contents data=advs varnum; run;
proc print data=advs(obs=20) noobs; run;
