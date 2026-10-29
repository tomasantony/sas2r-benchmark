/****************************************************************/
/* STEP 9.1: SDTM TR MAPPING & DERIVATION                       */
/****************************************************************/

/* 1. Prepare DM Reference Data */

proc sort data=sdtm_dm
          out=dm_for_tr(keep=USUBJID RFSTDTC);
    by USUBJID;
run;

/* 2. Prepare Raw Data */

data tr_prep;

    set edc_tr;

    length USUBJID $25;

    USUBJID = catx("-", "ONCO-2026", SUBJID);

run;

proc sort data=tr_prep;
    by USUBJID;
run;

proc sort data=dm_for_tr;
    by USUBJID;
run;

/* 3. Map TR Domain */

data sdtm_tr1;

    length STUDYID $10 DOMAIN $2 USUBJID $25
           TRLNKID $5
           TRTESTCD $8
           TRTEST $40
           TRORRES $10
           TRORRESU $10
           TRSTRESC $10
           TRSTRESN 8
           TRSTRESU $10
           TREVAL $15
           VISIT $20
           TRDTC $19;

    merge tr_prep(in=t)
          dm_for_tr;

    by USUBJID;

    if t;

    STUDYID = "ONCO-2026";
    DOMAIN  = "TR";

    TRLNKID = LNKID;

    TRTESTCD = TESTCD;

    if TRTESTCD = "LDIAM" then
        TRTEST = "Longest Diameter";

    TRORRES  = ORRES;
    TRORRESU = UNIT;

    TRSTRESC = ORRES;
    TRSTRESN = input(ORRES, best.);
    TRSTRESU = UNIT;

    TREVAL = "INVESTIGATOR";

    VISIT = upcase(tranwrd(VISIT, "_", " "));

    /* Date Conversion */

    if TRDT ne "" then
        TRDTC = put(input(TRDT, date11.), yymmdd10.);

    /* Study Day */

    if TRDTC ne "" and RFSTDTC ne "" then do;

        _stdt = input(TRDTC, yymmdd10.);
        _rfdt = input(RFSTDTC, yymmdd10.);

        if _stdt >= _rfdt then
            TRSTDY = (_stdt - _rfdt) + 1;

        else
            TRSTDY = (_stdt - _rfdt);

    end;

run;

/* 4. Derive TRSEQ */

proc sort data=sdtm_tr1;
    by USUBJID TRDTC;
run;

data sdtm_tr;
    length STUDYID $10 DOMAIN $2 USUBJID $25 TRSEQ 8
           TRLNKID $5
           TRTESTCD $8
           TRTEST $40
           TRORRES $10
           TRORRESU $10
           TRSTRESC $10
           TRSTRESN 8
           TRSTRESU $10
           TREVAL $15
           VISIT $20
           TRDTC $19;

    set sdtm_tr1;

    by USUBJID;

    retain TRSEQ;

    if first.USUBJID then
        TRSEQ = 1;

    else
        TRSEQ + 1;

    keep STUDYID DOMAIN USUBJID TRSEQ
         TRLNKID
         TRTESTCD TRTEST
         TRORRES TRORRESU
         TRSTRESC TRSTRESN TRSTRESU
         TREVAL
         TRDTC TRSTDY
         VISIT;

run;

/* 5. View Final Dataset */

proc print data=sdtm_tr;
run;

/* 6. Export Final Dataset */

proc export
    data=sdtm_tr
    outfile="D:\tr.xlsx"
    dbms=xlsx
    replace;
run;
