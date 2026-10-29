/****************************************************************/
/* STEP 8.1: SDTM TU MAPPING & DERIVATION                       */
/****************************************************************/

/* 1. Prepare DM Reference Data */

proc sort data=sdtm_dm
          out=dm_for_tu(keep=USUBJID RFSTDTC);
    by USUBJID;
run;

/* 2. Prepare Raw Data */

data tu_prep;

    set edc_tu;

    length USUBJID $25;

    USUBJID = catx("-", "ONCO-2026", SUBJID);

    TULOC    = upcase(tranwrd(LOC, "_", " "));
    TUMETHOD = upcase(tranwrd(METH, "_", " "));

run;

proc sort data=tu_prep;
    by USUBJID;
run;

proc sort data=dm_for_tu;
    by USUBJID;
run;

/* 3. Map TU Domain */

data sdtm_tu1;

    length STUDYID $10 DOMAIN $2 USUBJID $25
           TULNKID $5
           TUTESTCD $8
           TUTEST $40
           TUORRES $15
           TUSTRESC $15
           TULOC $20
           TUMETHOD $20
           TUEVAL $15
           VISIT $20
           TUDTC $19;

    merge tu_prep(in=t)
          dm_for_tu;

    by USUBJID;

    if t;

    STUDYID = "ONCO-2026";
    DOMAIN  = "TU";

    TULNKID = LNKID;

    TUTESTCD = "TUMIDENT";
    TUTEST   = "Tumor Identification";

    TUORRES  = upcase(TYPE);
    TUSTRESC = TUORRES;

    TUEVAL = "INVESTIGATOR";

    VISIT = upcase(tranwrd(VISIT, "_", " "));

    if TUDT ne "" then
        TUDTC = put(input(TUDT, date11.), yymmdd10.);

    /* Study Day */

    if TUDTC ne "" and RFSTDTC ne "" then do;

        _stdt = input(TUDTC, yymmdd10.);
        _rfdt = input(RFSTDTC, yymmdd10.);

        if _stdt >= _rfdt then
            TUSTDY = (_stdt - _rfdt) + 1;

        else
            TUSTDY = (_stdt - _rfdt);

    end;

run;

/* 4. Derive TUSEQ */

proc sort data=sdtm_tu1;
    by USUBJID TUDTC;
run;

data sdtm_tu;
    length STUDYID $10 DOMAIN $2 USUBJID $25 TUSEQ 8
           TULNKID $5
           TUTESTCD $8
           TUTEST $40
           TUORRES $15
           TUSTRESC $15
           TULOC $20
           TUMETHOD $20
           TUEVAL $15
           VISIT $20
           TUDTC $19;

    set sdtm_tu1;

    by USUBJID;

    retain TUSEQ;

    if first.USUBJID then
        TUSEQ = 1;

    else
        TUSEQ + 1;

    keep STUDYID DOMAIN USUBJID TUSEQ
         TULNKID
         TUTESTCD TUTEST
         TUORRES TUSTRESC
         TULOC
         TUMETHOD
         TUEVAL
         TUDTC TUSTDY
         VISIT;

run;

/* 5. View Final Dataset */

proc print data=sdtm_tu;
run;

/* 6. Export Final Dataset */

proc export
    data=sdtm_tu
    outfile="D:\Self Clinical SAS Project\New sdtm\raw data for sdtm\5 sdtm_derivation_TU TR RS\tu.xlsx"
    dbms=xlsx
    replace;
run;
