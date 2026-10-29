/****************************************************************/
/* STEP 7.1: SDTM LB MAPPING & DERIVATION                       */
/****************************************************************/

/* 1. Prepare DM Reference Data */

proc sort data=sdtm_dm
          out=dm_for_lb(keep=USUBJID RFSTDTC);
    by USUBJID;
run;

/* 2. Prepare Raw Data with USUBJID */

data lb_prep;
    set edc_lb;

    length USUBJID $25;

    USUBJID = catx("-", "ONCO-2026", SUBJID);
run;

proc sort data=lb_prep;
    by USUBJID;
run;

proc sort data=dm_for_lb;
    by USUBJID;
run;

/* 3. Map LB Domain */

data sdtm_lb1;

    length STUDYID $10 DOMAIN $2 USUBJID $25
           LBTESTCD $8 LBTEST $40 LBCAT $15
           LBORRES $10 LBORRESU $20
           LBSTRESC $10 LBSTRESN 8 LBSTRESU $20
           LBORNRLO $10 LBORNRHI $10
           LBDTC $19 VISIT $20
           LBNRIND $8;

    merge lb_prep(in=l)
          dm_for_lb;

    by USUBJID;

    if l;

    STUDYID = "ONCO-2026";
    DOMAIN  = "LB";

    LBTESTCD = TESTCD;
    LBCAT    = CAT;

    /* Map Test Names */

    if LBTESTCD = "HGB" then
        LBTEST = "Hemoglobin";

    else if LBTESTCD = "ALT" then
        LBTEST = "Alanine Aminotransferase";

    LBORRES  = ORRES;
    LBORRESU = UNIT;

    LBSTRESC = ORRES;
    LBSTRESN = input(ORRES, best.);
    LBSTRESU = UNIT;

    LBORNRLO = LOW;
    LBORNRHI = HIGH;

    VISIT = tranwrd(VISIT, "_", " ");

    /* Reference Range Indicator */

    if not missing(LBSTRESN) then do;

        if LBSTRESN < input(LOW, best.) then
            LBNRIND = "LOW";

        else if LBSTRESN > input(HIGH, best.) then
            LBNRIND = "HIGH";

        else
            LBNRIND = "NORMAL";

    end;

    /* Date Conversion */

    if LBDT ne "" then
        LBDTC = put(input(LBDT, date11.), yymmdd10.);

    /* Study Day */

    if LBDTC ne "" and RFSTDTC ne "" then do;

        _stdt = input(LBDTC, yymmdd10.);
        _rfdt = input(RFSTDTC, yymmdd10.);

        if _stdt >= _rfdt then
            LBSTDY = (_stdt - _rfdt) + 1;

        else
            LBSTDY = (_stdt - _rfdt);

    end;

run;

/* 4. Derive LBSEQ */

proc sort data=sdtm_lb1;
    by USUBJID LBDTC;
run;

data sdtm_lb;
    length STUDYID $10 DOMAIN $2 USUBJID $25
           LBSEQ 8 LBTESTCD $8 LBTEST $40
           LBCAT $15 LBORRES $10 LBORRESU $20
           LBSTRESC $10 LBSTRESN 8 LBSTRESU $20
           LBORNRLO $10 LBORNRHI $10
           LBDTC $19 VISIT $20
           LBNRIND $8;

    set sdtm_lb1;

    by USUBJID;

    retain LBSEQ;

    if first.USUBJID then
        LBSEQ = 1;

    else
        LBSEQ + 1;

    keep STUDYID DOMAIN USUBJID LBSEQ
         LBTESTCD LBTEST LBCAT
         LBORRES LBORRESU
         LBSTRESC LBSTRESN LBSTRESU
         LBORNRLO LBORNRHI
         LBNRIND
         LBDTC LBSTDY
         VISIT;

run;

/* 5. View Final Dataset */

proc print data=sdtm_lb;
run;

/* 6. Export Final Dataset */

proc export
    data=sdtm_lb
    outfile="D:\\lb.xlsx"
    dbms=xlsx
    replace;
run;
