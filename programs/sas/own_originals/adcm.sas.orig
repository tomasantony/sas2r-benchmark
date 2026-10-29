/*****************************************************************************
* Program:    adcm.sas
* Purpose:    Create ADCM (Concomitant Medications Analysis Dataset)
* Standard:   CDISC ADaM IG 1.3
* Input:      SDTM CM, ADSL
* Output:     ADCM
*****************************************************************************/

%include '../macros/m_adam_utilities.sas' / nosource2;

/*==========================================================================
  STEP 1: Create mock SDTM CM data
==========================================================================*/
data cm;
  infile datalines dlm='|' truncover;
  length STUDYID $12 USUBJID $20 CMSEQ 8 CMTRT $60 CMDECOD $60 CMCLAS $60
         CMSTDTC $10 CMENDTC $10 CMDOSE 8 CMDOSU $20 CMROUTE $20 CMFRQ $20
         CMINDC $100 CMONGO $1;
  input STUDYID $ USUBJID $ CMSEQ CMTRT $ CMDECOD $ CMCLAS $
        CMSTDTC $ CMENDTC $ CMDOSE CMDOSU $ CMROUTE $ CMFRQ $ CMINDC $ CMONGO $;
datalines;
STUDY01|STUDY01-1001|1|ASPIRIN|ASPIRIN|ANALGESICS|2023-06-15|.|81|mg|ORAL|QD|CARDIOVASCULAR PROTECTION|Y
STUDY01|STUDY01-1001|2|LISINOPRIL|LISINOPRIL|ACE INHIBITORS|2023-01-10|.|10|mg|ORAL|QD|HYPERTENSION|Y
STUDY01|STUDY01-1001|3|ACETAMINOPHEN|PARACETAMOL|ANALGESICS|2024-02-01|2024-02-03|500|mg|ORAL|PRN|HEADACHE|N
STUDY01|STUDY01-1002|1|METFORMIN|METFORMIN|ANTIDIABETICS|2022-03-20|.|500|mg|ORAL|BID|DIABETES|Y
STUDY01|STUDY01-1002|2|ATORVASTATIN|ATORVASTATIN|STATINS|2023-08-01|.|20|mg|ORAL|QD|HYPERLIPIDEMIA|Y
STUDY01|STUDY01-1003|1|OMEPRAZOLE|OMEPRAZOLE|PROTON PUMP INHIBITORS|2024-01-15|.|20|mg|ORAL|QD|GERD|Y
STUDY01|STUDY01-1003|2|IBUPROFEN|IBUPROFEN|NSAIDS|2024-02-20|2024-02-22|400|mg|ORAL|TID|BACK PAIN|N
STUDY01|STUDY01-1004|1|AMLODIPINE|AMLODIPINE|CALCIUM CHANNEL BLOCKERS|2023-05-10|.|5|mg|ORAL|QD|HYPERTENSION|Y
STUDY01|STUDY01-1005|1|LORATADINE|LORATADINE|ANTIHISTAMINES|2024-03-01|2024-03-15|10|mg|ORAL|QD|ALLERGIES|N
STUDY01|STUDY01-1006|1|LEVOTHYROXINE|LEVOTHYROXINE|THYROID HORMONES|2020-01-01|.|75|mcg|ORAL|QD|HYPOTHYROIDISM|Y
STUDY01|STUDY01-1006|2|CALCIUM|CALCIUM CARBONATE|SUPPLEMENTS|2023-09-01|.|600|mg|ORAL|QD|BONE HEALTH|Y
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
  STEP 3: Merge CM with ADSL and derive variables
==========================================================================*/
proc sort data=cm; by STUDYID USUBJID; run;
proc sort data=adsl; by STUDYID USUBJID; run;

data adcm;
  merge cm(in=a) adsl(in=b);
  by STUDYID USUBJID;
  if a and b;

  length ASTDT AENDT 8 ASTDY AENDY 8;
  length ONTRTFL PREFL CONCOMFL $1;
  length ATCCD1 $10 ATCCD2 $10 ATC1 $60 ATC2 $60;
  length CMDECOD_UP $60 CMCLAS_UP $60;
  length ADTEFFL $1 ADTEFN 8;
  length CMDURN 8;

  /*--- Convert dates ---*/
  if CMSTDTC ne '' and CMSTDTC ne '.' then ASTDT = input(CMSTDTC, yymmdd10.);
  if CMENDTC ne '' and CMENDTC ne '.' then AENDT = input(CMENDTC, yymmdd10.);

  /*--- Derive analysis day ---*/
  if not missing(ASTDT) and not missing(TRTSDT) then do;
    if ASTDT >= TRTSDT then ASTDY = ASTDT - TRTSDT + 1;
    else ASTDY = ASTDT - TRTSDT;
  end;
  if not missing(AENDT) and not missing(TRTSDT) then do;
    if AENDT >= TRTSDT then AENDY = AENDT - TRTSDT + 1;
    else AENDY = AENDT - TRTSDT;
  end;

  /*--- Duration ---*/
  if not missing(ASTDT) and not missing(AENDT) then
    CMDURN = AENDT - ASTDT + 1;

  /*--- Timing flags ---*/
  /* Prior medication: started before first dose */
  if not missing(ASTDT) and not missing(TRTSDT) then do;
    if ASTDT < TRTSDT then PREFL = 'Y';
    else PREFL = 'N';
  end;

  /* On-treatment: active during treatment period */
  if not missing(TRTSDT) then do;
    _trt_end = coalesce(TRTEDT, today());
    if not missing(ASTDT) then do;
      if missing(AENDT) then do;
        /* Ongoing medication */
        if ASTDT <= _trt_end then ONTRTFL = 'Y';
      end;
      else do;
        /* Completed medication - check overlap with treatment */
        if ASTDT <= _trt_end and AENDT >= TRTSDT then ONTRTFL = 'Y';
      end;
    end;
  end;
  if missing(ONTRTFL) then ONTRTFL = 'N';

  /* Concomitant: taken during study */
  if ONTRTFL = 'Y' or PREFL = 'Y' then CONCOMFL = 'Y';
  else CONCOMFL = 'N';

  /*--- Ongoing flag at end of treatment ---*/
  if CMONGO = 'Y' or missing(AENDT) then ADTEFFL = 'Y';
  else ADTEFFL = 'N';
  if ADTEFFL = 'Y' then ADTEFN = 1;
  else ADTEFN = 0;

  /*--- Standardized terms (uppercase) ---*/
  CMDECOD_UP = upcase(CMDECOD);
  CMCLAS_UP = upcase(CMCLAS);

  /*--- Mock ATC codes (in real studies, these come from WHO Drug Dictionary) ---*/
  select(CMCLAS_UP);
    when('ANALGESICS') do; ATCCD1 = 'N02'; ATC1 = 'ANALGESICS'; end;
    when('ACE INHIBITORS') do; ATCCD1 = 'C09A'; ATC1 = 'ACE INHIBITORS, PLAIN'; end;
    when('ANTIDIABETICS') do; ATCCD1 = 'A10'; ATC1 = 'DRUGS USED IN DIABETES'; end;
    when('STATINS') do; ATCCD1 = 'C10AA'; ATC1 = 'HMG COA REDUCTASE INHIBITORS'; end;
    when('PROTON PUMP INHIBITORS') do; ATCCD1 = 'A02BC'; ATC1 = 'PROTON PUMP INHIBITORS'; end;
    when('NSAIDS') do; ATCCD1 = 'M01A'; ATC1 = 'ANTIINFLAMMATORY, ANTIRHEUMATIC NON-STEROIDS'; end;
    when('CALCIUM CHANNEL BLOCKERS') do; ATCCD1 = 'C08CA'; ATC1 = 'DIHYDROPYRIDINE DERIVATIVES'; end;
    when('ANTIHISTAMINES') do; ATCCD1 = 'R06A'; ATC1 = 'ANTIHISTAMINES FOR SYSTEMIC USE'; end;
    when('THYROID HORMONES') do; ATCCD1 = 'H03AA'; ATC1 = 'THYROID HORMONES'; end;
    when('SUPPLEMENTS') do; ATCCD1 = 'A12AA'; ATC1 = 'CALCIUM'; end;
    otherwise do; ATCCD1 = ''; ATC1 = ''; end;
  end;

  format ASTDT AENDT date9.;
  drop _trt_end;
run;

/*==========================================================================
  STEP 4: Add sequence and labels
==========================================================================*/
proc sort data=adcm; by STUDYID USUBJID ASTDT CMSEQ; run;

data adcm;
  set adcm;
  by STUDYID USUBJID;

  if first.USUBJID then ASEQ = 0;
  ASEQ + 1;

  label
    STUDYID   = 'Study Identifier'
    USUBJID   = 'Unique Subject Identifier'
    CMSEQ     = 'Sequence Number'
    ASEQ      = 'Analysis Sequence Number'
    CMTRT     = 'Reported Name of Drug/Therapy'
    CMDECOD   = 'Standardized Medication Name'
    CMCLAS    = 'Medication Class'
    ASTDT     = 'Analysis Start Date'
    AENDT     = 'Analysis End Date'
    ASTDY     = 'Analysis Start Relative Day'
    AENDY     = 'Analysis End Relative Day'
    CMDOSE    = 'Dose per Administration'
    CMDOSU    = 'Dose Units'
    CMROUTE   = 'Route of Administration'
    CMFRQ     = 'Dosing Frequency'
    CMINDC    = 'Indication'
    CMONGO    = 'Ongoing Medication'
    ONTRTFL   = 'On-Treatment Flag'
    PREFL     = 'Prior Medication Flag'
    CONCOMFL  = 'Concomitant Medication Flag'
    ADTEFFL   = 'Medication Active at End of Treatment Flag'
    CMDURN    = 'Medication Duration (Days)'
    ATCCD1    = 'ATC Level 1 Code'
    ATC1      = 'ATC Level 1 Text'
    TRTP      = 'Planned Treatment'
    TRTPN     = 'Planned Treatment (N)'
    SAFFL     = 'Safety Population Flag'
    ;
run;

/*--- Output ---*/
proc contents data=adcm varnum; run;
proc print data=adcm(obs=15) noobs; run;
