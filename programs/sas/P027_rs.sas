/****************************************************************/
/* STEP 10.1: SDTM RS MAPPING & DERIVATION                      */
/****************************************************************/

/* 1. Prepare DM Reference Data */

proc sort data=sdtm_dm
          out=dm_for_rs(keep=USUBJID RFSTDTC);
    by USUBJID;
run;

/* 2. Prepare Raw Data */

data rs_prep;

    set edc_rs;

    length USUBJID $25;

    USUBJID = catx("-", "ONCO-2026", SUBJID);

run;

proc sort data=rs_prep;
    by USUBJID;
run;

proc sort data=dm_for_rs;
    by USUBJID;
run;

/* 3. Map RS Domain */

data sdtm_rs1;

    length STUDYID $10 DOMAIN $2 USUBJID $25
           RSTESTCD $8
           RSTEST $40
           RSCAT $15
           RSORRES $10
           RSSTRESC $10
           RSEVAL $15
           VISIT $20
           RSDTC $19;

    merge rs_prep(in=r)
          dm_for_rs;

    by USUBJID;

    if r;

    STUDYID = "ONCO-2026";
    DOMAIN  = "RS";

    RSTESTCD = TESTCD;

    if RSTESTCD = "OVRLRESP" then
        RSTEST = "Overall Response";

    RSCAT = "RECIST 1.1";

    RSORRES  = upcase(ORRES);
    RSSTRESC = RSORRES;

    RSEVAL = "INVESTIGATOR";

    VISIT = upcase(tranwrd(VISIT, "_", " "));

    /* Date Conversion */

    if RSDT ne "" then
        RSDTC = put(input(RSDT, date11.), yymmdd10.);

    /* Study Day */

    if RSDTC ne "" and RFSTDTC ne "" then do;

        _stdt = input(RSDTC, yymmdd10.);
        _rfdt = input(RFSTDTC, yymmdd10.);

        if _stdt >= _rfdt then
            RSSTDY = (_stdt - _rfdt) + 1;

        else
            RSSTDY = (_stdt - _rfdt);

    end;

run;

/* 4. Derive RSSEQ */

proc sort data=sdtm_rs1;
    by USUBJID RSDTC;
run;

data sdtm_rs;
    length STUDYID $10 DOMAIN $2 USUBJID $25 RSSEQ 8
           RSTESTCD $8
           RSTEST $40
           RSCAT $15
           RSORRES $10
           RSSTRESC $10
           RSEVAL $15
           VISIT $20
           RSDTC $19;

    set sdtm_rs1;

    by USUBJID;

    retain RSSEQ;

    if first.USUBJID then
        RSSEQ = 1;

    else
        RSSEQ + 1;

    keep STUDYID DOMAIN USUBJID RSSEQ
         RSTESTCD RSTEST
         RSCAT
         RSORRES RSSTRESC
         RSEVAL
         RSDTC RSSTDY
         VISIT;

run;

/* 5. View Final Dataset */

proc print data=sdtm_rs;
run;

/* 6. Export Final Dataset */

proc export
    data=sdtm_rs
    outfile="D:\rs.xlsx"
    dbms=xlsx
    replace;
run;
