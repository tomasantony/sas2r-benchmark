/****************************************************************/
/* STEP 5.1: SDTM DS MAPPING & DERIVATION                       */
/****************************************************************/


/*--------------------------------------------------------------*/
/* 1. Sort DM for Reference Dates                               */
/*--------------------------------------------------------------*/

proc sort 
    data=sdtm_dm(
        keep=USUBJID SUBJID RFSTDTC DTHDTC
    )
    out=dm_for_ds;

    by USUBJID;

run;


/*--------------------------------------------------------------*/
/* 2. Prepare Raw DS Data                                       */
/*--------------------------------------------------------------*/

data edc_ds_prep;

    set edc_ds;

    /* Create USUBJID */

    length USUBJID $25;

    USUBJID = catx("-", "ONCO-2026", SUBJID);

run;


/*--------------------------------------------------------------*/
/* 3. Sort Datasets for Merge                                   */
/*--------------------------------------------------------------*/

proc sort data=edc_ds_prep;

    by USUBJID;

run;

proc sort data=dm_for_ds;

    by USUBJID;

run;


/*--------------------------------------------------------------*/
/* 4. Create SDTM DS Dataset                                    */
/*--------------------------------------------------------------*/

data sdtm_ds1;

    /* Define Variable Lengths */

    length 
        STUDYID $10
        DOMAIN $2
        USUBJID $25
        DSTERM $50
        DSDECOD $30
        DSCAT $30
        DSSTDTC $19
        DTHFL $1;

    
    /* Merge DS Data with DM */

    merge 
        edc_ds_prep(in=a)
        dm_for_ds;

    by USUBJID;

    if a;


    /* Identifier Variables */

    STUDYID = "ONCO-2026";

    DOMAIN = "DS";


    /* DS Variables */

    DSTERM = tranwrd(TERM, "_", " ");

    DSDECOD = upcase(DECOD);

    DSCAT = tranwrd(CAT, "_", " ");


    /* Death Flag */

    if not missing(DTHDTC) then
        DTHFL = "Y";


    /* Convert Date to ISO 8601 */

    if STDT ne "" then
        DSSTDTC = put(input(STDT, date11.), yymmdd10.);


    /*----------------------------------------------------------*/
    /* Derive DSSTDY                                            */
    /*----------------------------------------------------------*/

    if DSSTDTC ne "" and RFSTDTC ne "" then do;

        _stdt = input(DSSTDTC, yymmdd10.);

        _rfdt = input(RFSTDTC, yymmdd10.);

        if _stdt >= _rfdt then
            DSSTDY = (_stdt - _rfdt) + 1;

        else
            DSSTDY = (_stdt - _rfdt);

    end;


    /* Consistency Check for Subject 103 */

    if USUBJID = "ONCO-2026-103" and DSSTDTC ne DTHDTC then 
        put "WARNING: Date mismatch! DS=" DSSTDTC " DM=" DTHDTC;

run;


/*--------------------------------------------------------------*/
/* 5. Sort Final DS Dataset                                     */
/*--------------------------------------------------------------*/

proc sort data=sdtm_ds1;

    by USUBJID DSSTDTC;

run;


/*--------------------------------------------------------------*/
/* 6. Derive DSSEQ                                              */
/*--------------------------------------------------------------*/

data sdtm_ds;
    length
        STUDYID $10
        DOMAIN $2
        USUBJID $25
        DSSEQ 8
        DSTERM $50
        DSDECOD $30
        DSCAT $30
        DSSTDTC $19
        DSSTDY 8
        DTHFL $1;

    set sdtm_ds1;

    by USUBJID;

    retain DSSEQ;

    if first.USUBJID then
        DSSEQ = 1;

    else
        DSSEQ + 1;


    /* Keep Final SDTM Variables */

    keep
        STUDYID
        DOMAIN
        USUBJID
        DSSEQ
        DSTERM
        DSDECOD
        DSCAT
        DSSTDTC
        DSSTDY
        DTHFL;

run;


/*--------------------------------------------------------------*/
/* 7. View Final DS Dataset                                     */
/*--------------------------------------------------------------*/

proc print data=sdtm_ds;
run;


/*--------------------------------------------------------------*/
/* 8. Export Final DS Dataset                                   */
/*--------------------------------------------------------------*/

proc export
    data=sdtm_ds
    outfile="D:\ds.xlsx"
    dbms=xlsx
    replace;
run;
