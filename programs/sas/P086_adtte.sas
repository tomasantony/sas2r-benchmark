/*****************************************************************************
* Program:    adtte.sas
* Purpose:    Create ADTTE (Time-to-Event Analysis Dataset)
* Standard:   CDISC ADaM IG 1.3
* Input:      SDTM AE, DS, ADSL
* Output:     ADTTE
*****************************************************************************/

%include '../macros/m_adam_utilities.sas' / nosource2;
%include '../macros/m_derive_tte.sas' / nosource2;

/*==========================================================================
  STEP 1: Create mock source data
==========================================================================*/

/*--- ADSL with dates ---*/
data adsl;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 TRTP $40 TRTPN 8 AGE 8 AGEGR1 $10 SEX $1 RACE $50
         SAFFL $1 ITTFL $1 TRTSDT 8 TRTEDT 8 EOSDT 8 DTHDT 8 DTHFL $1;
  input STUDYID $ USUBJID $ TRTP $ TRTPN AGE AGEGR1 $ SEX $ RACE $ SAFFL $ ITTFL $
        TRTSDT :date9. TRTEDT :date9. EOSDT :date9. DTHDT :date9. DTHFL $;
  format TRTSDT TRTEDT EOSDT DTHDT date9.;
datalines;
STUDY01|STUDY01-1001|Treatment A|1|59|<65|M|WHITE|Y|Y|15JAN2024|15JUN2024|15JUN2024|.|N
STUDY01|STUDY01-1002|Placebo|2|45|<65|F|BLACK|Y|Y|18JAN2024|18JUN2024|18JUN2024|.|N
STUDY01|STUDY01-1003|Treatment A|1|43|<65|M|ASIAN|Y|Y|20JAN2024|01APR2024|01APR2024|15APR2024|Y
STUDY01|STUDY01-1004|Treatment A|1|51|<65|F|WHITE|Y|Y|25JAN2024|25JUN2024|25JUN2024|.|N
STUDY01|STUDY01-1005|Placebo|2|36|<65|M|ASIAN|Y|Y|28JAN2024|.|15JUL2024|.|N
STUDY01|STUDY01-1006|Treatment A|1|68|>=65|F|WHITE|Y|Y|30JAN2024|01JUL2024|01JUL2024|.|N
;
run;

/*--- Disease progression events ---*/
data adrs;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 RSSTRESC $20 RSDTC $10;
  input STUDYID $ USUBJID $ RSSTRESC $ RSDTC $;
datalines;
STUDY01|STUDY01-1001|STABLE DISEASE|2024-03-15
STUDY01|STUDY01-1001|STABLE DISEASE|2024-06-15
STUDY01|STUDY01-1002|STABLE DISEASE|2024-03-18
STUDY01|STUDY01-1002|PROGRESSIVE DISEASE|2024-05-20
STUDY01|STUDY01-1003|PARTIAL RESPONSE|2024-02-20
STUDY01|STUDY01-1003|PROGRESSIVE DISEASE|2024-03-25
STUDY01|STUDY01-1004|PARTIAL RESPONSE|2024-03-25
STUDY01|STUDY01-1005|STABLE DISEASE|2024-04-28
STUDY01|STUDY01-1006|COMPLETE RESPONSE|2024-04-30
;
run;

/*==========================================================================
  STEP 2: Derive PFS (Progression-Free Survival)
==========================================================================*/

/* Get progression date */
proc sort data=adrs; by USUBJID RSDTC; run;

data _prog_;
  set adrs(where=(RSSTRESC='PROGRESSIVE DISEASE'));
  by USUBJID;
  if first.USUBJID;
  PROGDT = input(RSDTC, yymmdd10.);
  keep USUBJID PROGDT;
  format PROGDT date9.;
run;

/* Merge progression and death */
proc sort data=adsl; by USUBJID; run;
proc sort data=_prog_; by USUBJID; run;

data adtte_pfs;
  merge adsl(in=a) _prog_;
  by USUBJID;
  if a;

  length PARAMCD $8 PARAM $200 PARAMN 8;
  length ADT STARTDT 8 AVAL 8 CNSR 8;
  length EVNTDESC $200 CNSDTDSC $200;
  length SRCDOM $8;

  PARAMCD = 'PFS';
  PARAM = 'Progression-Free Survival (Days)';
  PARAMN = 1;

  STARTDT = TRTSDT;

  /*--- Determine event or censoring ---*/
  /* Event: progression or death, whichever comes first */
  if not missing(PROGDT) and not missing(DTHDT) then do;
    if PROGDT <= DTHDT then do;
      ADT = PROGDT;
      EVNTDESC = 'Disease Progression';
      SRCDOM = 'RS';
    end;
    else do;
      ADT = DTHDT;
      EVNTDESC = 'Death';
      SRCDOM = 'ADSL';
    end;
    CNSR = 0;
  end;
  else if not missing(PROGDT) then do;
    ADT = PROGDT;
    CNSR = 0;
    EVNTDESC = 'Disease Progression';
    SRCDOM = 'RS';
  end;
  else if not missing(DTHDT) then do;
    ADT = DTHDT;
    CNSR = 0;
    EVNTDESC = 'Death';
    SRCDOM = 'ADSL';
  end;
  else do;
    /* Censored at last known alive date */
    ADT = coalesce(EOSDT, TRTEDT, TRTSDT);
    CNSR = 1;
    EVNTDESC = '';
    CNSDTDSC = 'Censored - No progression or death';
    SRCDOM = 'ADSL';
  end;

  /*--- Derive AVAL (days) ---*/
  if not missing(ADT) and not missing(STARTDT) then do;
    AVAL = ADT - STARTDT + 1;
    if AVAL < 1 then AVAL = 1;
  end;

  format ADT STARTDT date9.;
  keep STUDYID USUBJID TRTP TRTPN AGE AGEGR1 SEX RACE SAFFL ITTFL
       PARAMCD PARAM PARAMN STARTDT ADT AVAL CNSR EVNTDESC CNSDTDSC SRCDOM;
run;

/*==========================================================================
  STEP 3: Derive OS (Overall Survival)
==========================================================================*/
data adtte_os;
  set adsl;

  length PARAMCD $8 PARAM $200 PARAMN 8;
  length ADT STARTDT 8 AVAL 8 CNSR 8;
  length EVNTDESC $200 CNSDTDSC $200;
  length SRCDOM $8;

  PARAMCD = 'OS';
  PARAM = 'Overall Survival (Days)';
  PARAMN = 2;

  STARTDT = TRTSDT;

  /*--- Event = death ---*/
  if DTHFL = 'Y' and not missing(DTHDT) then do;
    ADT = DTHDT;
    CNSR = 0;
    EVNTDESC = 'Death';
    CNSDTDSC = '';
    SRCDOM = 'ADSL';
  end;
  else do;
    /* Censored at last known alive */
    ADT = coalesce(EOSDT, TRTEDT, TRTSDT);
    CNSR = 1;
    EVNTDESC = '';
    CNSDTDSC = 'Censored - Alive';
    SRCDOM = 'ADSL';
  end;

  /*--- Derive AVAL ---*/
  if not missing(ADT) and not missing(STARTDT) then do;
    AVAL = ADT - STARTDT + 1;
    if AVAL < 1 then AVAL = 1;
  end;

  format ADT STARTDT date9.;
  keep STUDYID USUBJID TRTP TRTPN AGE AGEGR1 SEX RACE SAFFL ITTFL
       PARAMCD PARAM PARAMN STARTDT ADT AVAL CNSR EVNTDESC CNSDTDSC SRCDOM;
run;

/*==========================================================================
  STEP 4: Derive TTR (Time to Response) - for responders only
==========================================================================*/
/* Get first response */
data _resp_;
  set adrs(where=(RSSTRESC in ('COMPLETE RESPONSE', 'PARTIAL RESPONSE')));
  by USUBJID;
  if first.USUBJID;
  RESPDT = input(RSDTC, yymmdd10.);
  keep USUBJID RESPDT;
  format RESPDT date9.;
run;

proc sort data=adsl; by USUBJID; run;
proc sort data=_resp_; by USUBJID; run;

data adtte_ttr;
  merge adsl(in=a) _resp_;
  by USUBJID;
  if a;

  length PARAMCD $8 PARAM $200 PARAMN 8;
  length ADT STARTDT 8 AVAL 8 CNSR 8;
  length EVNTDESC $200 CNSDTDSC $200;

  PARAMCD = 'TTR';
  PARAM = 'Time to Response (Days)';
  PARAMN = 3;

  STARTDT = TRTSDT;

  if not missing(RESPDT) then do;
    ADT = RESPDT;
    CNSR = 0;
    EVNTDESC = 'Response';
  end;
  else do;
    ADT = coalesce(EOSDT, TRTEDT, TRTSDT);
    CNSR = 1;
    EVNTDESC = '';
    CNSDTDSC = 'Censored - No response';
  end;

  if not missing(ADT) and not missing(STARTDT) then do;
    AVAL = ADT - STARTDT + 1;
    if AVAL < 1 then AVAL = 1;
  end;

  format ADT STARTDT date9.;
  keep STUDYID USUBJID TRTP TRTPN AGE AGEGR1 SEX RACE SAFFL ITTFL
       PARAMCD PARAM PARAMN STARTDT ADT AVAL CNSR EVNTDESC CNSDTDSC;
run;

/*==========================================================================
  STEP 5: Combine all TTE parameters
==========================================================================*/
data adtte;
  set adtte_pfs adtte_os adtte_ttr;
run;

/* Derive AVAL in months */
data adtte;
  set adtte;
  if not missing(AVAL) then AVAL_M = AVAL / 30.4375;
  label AVAL_M = 'Analysis Value (Months)';
run;

/*==========================================================================
  STEP 6: Add sequence and labels
==========================================================================*/
proc sort data=adtte; by STUDYID USUBJID PARAMN; run;

data adtte;
  set adtte;
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
    AVAL     = 'Analysis Value'
    CNSR     = 'Censor'
    ADT      = 'Analysis Date'
    STARTDT  = 'Time-to-Event Origin Date'
    EVNTDESC = 'Event Description'
    CNSDTDSC = 'Censor Description'
    SRCDOM   = 'Source Domain'
    TRTP     = 'Planned Treatment'
    TRTPN    = 'Planned Treatment (N)'
    SAFFL    = 'Safety Population Flag'
    ITTFL    = 'Intent-to-Treat Population Flag'
    ;
run;

proc delete data=_prog_ _resp_; run;

/*--- Output ---*/
proc contents data=adtte varnum; run;
proc print data=adtte noobs; run;
