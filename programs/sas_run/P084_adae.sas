/*****************************************************************************
* Program:    adae.sas
* Purpose:    Create ADAE (Adverse Events Analysis Dataset)
* Standard:   CDISC ADaM IG 1.3
* Input:      SDTM AE, ADSL
* Output:     ADAE
*****************************************************************************/

%include "&root./programs/sas/macros/own-adam/m_adam_utilities.sas" / nosource2;

/*==========================================================================
  STEP 1: Create mock SDTM AE data
==========================================================================*/
data ae;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 AESEQ 8 AETERM $60 AEDECOD $60 AEBODSYS $60
         AESTDTC $10 AEENDTC $10 AESEV $10 AESER $1 AEREL $20 AEACN $25
         AEOUT $40 AETOXGR $2;
  input STUDYID $ USUBJID $ AESEQ AETERM $ AEDECOD $ AEBODSYS $
        AESTDTC $ AEENDTC $ AESEV $ AESER $ AEREL $ AEACN $ AEOUT $ AETOXGR $;
datalines;
STUDY01|STUDY01-1001|1|Headache|Headache|Nervous system disorders|2024-02-01|2024-02-03|MILD|N|NOT RELATED|DOSE NOT CHANGED|RECOVERED|1
STUDY01|STUDY01-1001|2|Nausea|Nausea|Gastrointestinal disorders|2024-02-15|2024-02-18|MODERATE|N|POSSIBLY RELATED|DOSE NOT CHANGED|RECOVERED|2
STUDY01|STUDY01-1002|1|Fatigue|Fatigue|General disorders|2024-02-10|2024-03-01|MILD|N|POSSIBLY RELATED|DOSE NOT CHANGED|RECOVERED|1
STUDY01|STUDY01-1003|1|Dizziness|Dizziness|Nervous system disorders|2024-02-20|2024-02-22|MILD|N|NOT RELATED|DOSE NOT CHANGED|RECOVERED|1
STUDY01|STUDY01-1003|2|Rash|Rash|Skin disorders|2024-03-05|2024-03-15|MODERATE|N|PROBABLY RELATED|DOSE REDUCED|RECOVERED|2
STUDY01|STUDY01-1003|3|Hepatotoxicity|Hepatotoxicity|Hepatobiliary disorders|2024-03-25|.|SEVERE|Y|RELATED|DRUG WITHDRAWN|NOT RECOVERED|3
STUDY01|STUDY01-1004|1|Insomnia|Insomnia|Psychiatric disorders|2024-02-25|2024-03-10|MILD|N|UNLIKELY|DOSE NOT CHANGED|RECOVERED|1
STUDY01|STUDY01-1005|1|Vomiting|Vomiting|Gastrointestinal disorders|2024-03-01|2024-03-02|MODERATE|N|POSSIBLY RELATED|DOSE NOT CHANGED|RECOVERED|2
STUDY01|STUDY01-1006|1|Back pain|Back pain|Musculoskeletal disorders|2024-02-28|2024-03-05|MILD|N|NOT RELATED|DOSE NOT CHANGED|RECOVERED|1
;
run;

/*==========================================================================
  STEP 2: Create mock ADSL
==========================================================================*/
data adsl;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 SITEID $4 TRTP $40 TRTPN 8
         AGE 8 AGEGR1 $10 SEX $1 RACE $50 SAFFL $1
         TRTSDT 8 TRTEDT 8;
  input STUDYID $ USUBJID $ SITEID $ TRTP $ TRTPN AGE AGEGR1 $ SEX $ RACE $ SAFFL $
        TRTSDT :date9. TRTEDT :date9.;
  format TRTSDT TRTEDT date9.;
datalines;
STUDY01|STUDY01-1001|101|Treatment A|1|59|<65|M|WHITE|Y|15JAN2024|15JUN2024
STUDY01|STUDY01-1002|101|Placebo|2|45|<65|F|BLACK OR AFRICAN AMERICAN|Y|18JAN2024|18JUN2024
STUDY01|STUDY01-1003|102|Treatment A|1|43|<65|M|ASIAN|Y|20JAN2024|01APR2024
STUDY01|STUDY01-1004|102|Treatment A|1|51|<65|F|WHITE|Y|25JAN2024|25JUN2024
STUDY01|STUDY01-1005|103|Placebo|2|36|<65|M|ASIAN|Y|28JAN2024|.
STUDY01|STUDY01-1006|103|Treatment A|1|68|>=65|F|WHITE|Y|30JAN2024|01JUL2024
;
run;

/*==========================================================================
  STEP 3: Merge AE with ADSL and derive ADAE variables
==========================================================================*/
proc sort data=ae; by STUDYID USUBJID; run;
proc sort data=adsl; by STUDYID USUBJID; run;

data adae;
  merge ae(in=a) adsl(in=b keep=STUDYID USUBJID SITEID TRTP TRTPN AGE AGEGR1
                               SEX RACE SAFFL TRTSDT TRTEDT);
  by STUDYID USUBJID;
  if a and b;

  length ASTDT AENDT 8 ASTDY AENDY 8;
  length TRTEMFL AESER_FL AOCCFL AOCCSFL AOCCPFL $1;
  length ASEV $10 ASEVN 8 AREL $20 ARELN 8;
  length AESOC $60 AEDECOD_UP $60;

  /*--- Convert dates ---*/
  if AESTDTC ne '' then ASTDT = input(AESTDTC, yymmdd10.);
  if AEENDTC ne '' and AEENDTC ne '.' then AENDT = input(AEENDTC, yymmdd10.);

  /*--- Derive analysis day ---*/
  if not missing(ASTDT) and not missing(TRTSDT) then do;
    if ASTDT >= TRTSDT then ASTDY = ASTDT - TRTSDT + 1;
    else ASTDY = ASTDT - TRTSDT;
  end;
  if not missing(AENDT) and not missing(TRTSDT) then do;
    if AENDT >= TRTSDT then AENDY = AENDT - TRTSDT + 1;
    else AENDY = AENDT - TRTSDT;
  end;

  /*--- Treatment-emergent flag ---*/
  if not missing(ASTDT) and not missing(TRTSDT) then do;
    if ASTDT >= TRTSDT then do;
      if missing(TRTEDT) then TRTEMFL = 'Y';
      else if ASTDT <= TRTEDT + 30 then TRTEMFL = 'Y'; /* 30-day grace */
    end;
  end;
  if missing(TRTEMFL) then TRTEMFL = 'N';

  /*--- Analysis severity ---*/
  ASEV = AESEV;
  select(upcase(AESEV));
    when('MILD') ASEVN = 1;
    when('MODERATE') ASEVN = 2;
    when('SEVERE') ASEVN = 3;
    otherwise ASEVN = .;
  end;

  /*--- Analysis relationship ---*/
  AREL = AEREL;
  select(upcase(AEREL));
    when('NOT RELATED') ARELN = 1;
    when('UNLIKELY') ARELN = 2;
    when('POSSIBLY RELATED') ARELN = 3;
    when('PROBABLY RELATED') ARELN = 4;
    when('RELATED') ARELN = 5;
    otherwise ARELN = .;
  end;

  /*--- Serious flag ---*/
  AESER_FL = AESER;

  /*--- SOC and PT ---*/
  AESOC = AEBODSYS;
  AEDECOD_UP = upcase(AEDECOD);

  /*--- AE duration ---*/
  if not missing(ASTDT) and not missing(AENDT) then
    AEDUR = AENDT - ASTDT + 1;

  format ASTDT AENDT date9.;
run;

/*==========================================================================
  STEP 4: Derive occurrence flags
==========================================================================*/
proc sort data=adae; by USUBJID AEBODSYS AEDECOD ASTDT; run;

data adae;
  set adae;
  by USUBJID AEBODSYS AEDECOD;

  /*--- First occurrence flags ---*/
  if first.USUBJID then AOCCFL = 'Y'; else AOCCFL = '';
  if first.AEBODSYS then AOCCSFL = 'Y'; else AOCCSFL = '';
  if first.AEDECOD then AOCCPFL = 'Y'; else AOCCPFL = '';
run;

/*==========================================================================
  STEP 5: Add labels and sequence
==========================================================================*/
proc sort data=adae; by STUDYID USUBJID ASTDT AESEQ; run;

data adae;
  set adae;
  by STUDYID USUBJID;

  if first.USUBJID then ASEQ = 0;
  ASEQ + 1;

  label
    STUDYID  = 'Study Identifier'
    USUBJID  = 'Unique Subject Identifier'
    AESEQ    = 'Sequence Number'
    ASEQ     = 'Analysis Sequence Number'
    AETERM   = 'Reported Term for the Adverse Event'
    AEDECOD  = 'Dictionary-Derived Term'
    AEBODSYS = 'Body System or Organ Class'
    AESOC    = 'Primary System Organ Class'
    ASTDT    = 'Analysis Start Date'
    AENDT    = 'Analysis End Date'
    ASTDY    = 'Analysis Start Relative Day'
    AENDY    = 'Analysis End Relative Day'
    ASEV     = 'Analysis Severity/Intensity'
    ASEVN    = 'Analysis Severity/Intensity (N)'
    AREL     = 'Analysis Causality'
    ARELN    = 'Analysis Causality (N)'
    TRTEMFL  = 'Treatment Emergent Analysis Flag'
    AESER_FL = 'Serious Event Flag'
    AOCCFL   = 'First Occurrence of Any AE Flag'
    AOCCSFL  = 'First Occurrence Within SOC Flag'
    AOCCPFL  = 'First Occurrence of Preferred Term Flag'
    AEDUR    = 'AE Duration (Days)'
    TRTP     = 'Planned Treatment'
    TRTPN    = 'Planned Treatment (N)'
    TRTSDT   = 'Date of First Exposure to Treatment'
    TRTEDT   = 'Date of Last Exposure to Treatment'
    SAFFL    = 'Safety Population Flag'
    ;
run;

/*--- Output ---*/
proc contents data=adae varnum; run;
proc print data=adae(obs=10) noobs; run;
