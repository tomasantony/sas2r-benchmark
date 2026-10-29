/****************************************************************/
/* STEP 6.1: SDTM VS MAPPING & DERIVATION                       */
/****************************************************************/

proc sort data=sdtm_dm out=dm_for_vs(keep=USUBJID SUBJID RFSTDTC RFXSTDTC);
    by USUBJID;
run;

/* 1. Prepare Raw Data with USUBJID */

data vs_prep;
    set edc_vs;

    length USUBJID $25;

    USUBJID = catx("-", "ONCO-2026", SUBJID);
run;

proc sort data=vs_prep;
    by USUBJID;
run;

proc sort data=dm_for_vs;
    by USUBJID;
run;

/* 2. Map VS Domain */

data sdtm_vs1;

    length STUDYID $10 DOMAIN $2 USUBJID $25
           VSTESTCD $8 VSTEST $40
           VSORRES $10 VSORRESU $20
           VSSTRESC $10 VSSTRESN 8 VSSTRESU $20
           VSDTC $19 VISIT $20 VSPOS $10;

    merge vs_prep(in=v)
          dm_for_vs(keep=USUBJID RFSTDTC RFXSTDTC);

    by USUBJID;

    if v;

    STUDYID = "ONCO-2026";
    DOMAIN  = "VS";

    VSTESTCD = TESTCD;

    if VSTESTCD = "SYSBP" then VSTEST = "Systolic Blood Pressure";
    else if VSTESTCD = "DIABP" then VSTEST = "Diastolic Blood Pressure";

    VSORRES  = ORRES;
    VSORRESU = UNIT;

    VSSTRESC = ORRES;
    VSSTRESN = input(ORRES, best.);
    VSSTRESU = UNIT;

    VISIT = tranwrd(VISIT, "_", " ");

    VSPOS = upcase(POS);

    if VSDT ne "" then
        VSDTC = put(input(VSDT, date11.), yymmdd10.);

    /* Study Day */

    if VSDTC ne "" and RFSTDTC ne "" then do;
        _stdt = input(VSDTC, yymmdd10.);
        _rfdt = input(RFSTDTC, yymmdd10.);

        if _stdt >= _rfdt then
            VSTDY = (_stdt - _rfdt) + 1;
        else
            VSTDY = (_stdt - _rfdt);
    end;

run;

/* 3. Derive VSSEQ */

proc sort data=sdtm_vs1;
    by USUBJID VSDTC;
run;

data sdtm_vs;
    length STUDYID $10 DOMAIN $2 USUBJID $25
           VSSEQ 8 VSTESTCD $8 VSTEST $40
           VSORRES $10 VSORRESU $20
           VSSTRESC $10 VSSTRESN 8 VSSTRESU $20
           VSDTC $19 VISIT $20 VSPOS $10;

    set sdtm_vs1;

    by USUBJID;

    retain VSSEQ;

    if first.USUBJID then VSSEQ = 1;
    else VSSEQ + 1;

    keep STUDYID DOMAIN USUBJID VSSEQ
         VSTESTCD VSTEST
         VSORRES VSORRESU
         VSSTRESC VSSTRESN VSSTRESU
         VSDTC VSTDY
         VISIT VSPOS;

run;

proc print data=sdtm_vs;
run;
