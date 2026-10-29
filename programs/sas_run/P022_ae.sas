/****************************************************************/
/* STEP 4.1: SDTM AE MAPPING & DERIVATION                       */
/****************************************************************/


/*--------------------------------------------------------------*/
/* 1. Sort DM for Study Day Calculations                        */
/*--------------------------------------------------------------*/

proc sort 
    data=sdtm_dm(
        keep=USUBJID RFSTDTC
    )
    out=dm_for_ae;

    by USUBJID;

run;


/*--------------------------------------------------------------*/
/* 2. Process Raw AE Data                                       */
/*--------------------------------------------------------------*/

data ae_prep;

    set edc_ae;
    
    /* Create USUBJID */

    length USUBJID $25;

    USUBJID = catx("-", "ONCO-2026", SUBJID);


    /* Convert Raw Dates to ISO 8601 */

    length AESTDTC AEENDTC $19;

    if STDT ne "" then
        AESTDTC = put(input(STDT, date11.), yymmdd10.);

    if ENDT ne "" then
        AEENDTC = put(input(ENDT, date11.), yymmdd10.);

run;


/*--------------------------------------------------------------*/
/* 3. Sort AE Data                                              */
/*--------------------------------------------------------------*/

proc sort data=ae_prep;

    by USUBJID AESTDTC TERM;

run;


/*--------------------------------------------------------------*/
/* 4. Final Mapping and Derivation                              */
/*--------------------------------------------------------------*/

data sdtm_ae1;

    /* Define Variable Lengths */

    length 
        STUDYID $10
        DOMAIN $2
        USUBJID $25
        AETERM $40
        AEDECOD $40
        AEBODSYS $40
        AESEV $10
        AETXGR 8
        AEREL $20
        AEOUT $20
        AESER $1
        AESTDTC $19
        AEENDTC $19;

    
    /* Merge AE Data with DM */

    merge 
        ae_prep(in=a)
        dm_for_ae;

    by USUBJID;

    if a;


    /* Identifier Variables */

    STUDYID = "ONCO-2026";

    DOMAIN = "AE";


    /* AE Variables */

    AETERM = TERM;

    AEDECOD = upcase(DECOD);

    /* Format Body System */

    AEBODSYS = tranwrd(BODSYS, "_", " ");

    AESEV = upcase(SEV);

    AETXGR = TXGR;

    AEREL = upcase(REL);

    AEOUT = upcase(OUT);

    AESER = SER;


    /*----------------------------------------------------------*/
    /* Derive AESTDY                                            */
    /*----------------------------------------------------------*/

    if AESTDTC ne "" and RFSTDTC ne "" then do;

        _stdt = input(AESTDTC, yymmdd10.);

        _rfdt = input(RFSTDTC, yymmdd10.);

        if _stdt >= _rfdt then
            AESTDY = (_stdt - _rfdt) + 1;

        else
            AESTDY = (_stdt - _rfdt);

    end;


    /*----------------------------------------------------------*/
    /* Derive AEENDY                                            */
    /*----------------------------------------------------------*/

    if AEENDTC ne "" and RFSTDTC ne "" then do;

        _endt = input(AEENDTC, yymmdd10.);

        _rfdt = input(RFSTDTC, yymmdd10.);

        if _endt >= _rfdt then
            AEENDY = (_endt - _rfdt) + 1;

        else
            AEENDY = (_endt - _rfdt);

    end;

run;


/*--------------------------------------------------------------*/
/* 5. Sort Final AE Dataset                                     */
/*--------------------------------------------------------------*/

proc sort data=sdtm_ae1;

    by USUBJID AESTDTC TERM;

run;


/*--------------------------------------------------------------*/
/* 6. Derive AESEQ                                              */
/*--------------------------------------------------------------*/

data sdtm_ae;
    length 
        STUDYID $10
        DOMAIN $2
        USUBJID $25
		    AESEQ 8
        AETERM $40
        AEDECOD $40
        AEBODSYS $40
        AESEV $10
        AETXGR 8
        AEREL $20
        AEOUT $20
        AESER $1
        AESTDTC $19
        AEENDTC $19;

    set sdtm_ae1;

    by USUBJID;

    retain AESEQ;

    if first.USUBJID then
        AESEQ = 1;

    else
        AESEQ + 1;


    /* Keep Final SDTM Variables */

    keep
        STUDYID
        DOMAIN
        USUBJID
        AESEQ
        AETERM
        AEDECOD
        AEBODSYS
        AESEV
        AETXGR
        AEREL
        AEOUT
        AESER
        AESTDTC
        AEENDTC
        AESTDY
        AEENDY;

run;


/*--------------------------------------------------------------*/
/* 7. View Final AE Dataset                                     */
/*--------------------------------------------------------------*/

proc print data=sdtm_ae;
run;

/*--------------------------------------------------------------*/
/* 8. Export Final AE Dataset                                   */
/*--------------------------------------------------------------*/

proc export
    data=sdtm_ae
    outfile="D:\ae.xlsx"
    dbms=xlsx
    replace;
run;
