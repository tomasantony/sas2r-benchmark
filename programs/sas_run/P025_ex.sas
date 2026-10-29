/****************************************************************/
/* STEP 3.1: SDTM EX MAPPING PROGRAM                            */
/****************************************************************/


/*--------------------------------------------------------------*/
/* 1. Get RFSTDTC from DM for Study Day Calculation             */
/*--------------------------------------------------------------*/

proc sort 
    data=sdtm_dm(
        keep=USUBJID RFSTDTC
    )
    out=dm_for_ex;

    by USUBJID;

run;


/*--------------------------------------------------------------*/
/* 2. Prepare Raw EX Data                                       */
/*--------------------------------------------------------------*/

data ex_prep;

    set edc_ex;

    /* Create USUBJID */

    length USUBJID $25;

    USUBJID = catx("-", "ONCO-2026", SUBJID);


    /* Exclude records where dose was not administered */

    if DOSE ne .;


    /* Convert Dates to ISO 8601 */

    length EXSTDTC EXENDTC $19;

    if STDT ne "" then
        EXSTDTC = put(input(STDT, date11.), yymmdd10.);

    if ENDT ne "" then
        EXENDTC = put(input(ENDT, date11.), yymmdd10.);

run;


/*--------------------------------------------------------------*/
/* 3. Sort Data for Merge and Sequencing                        */
/*--------------------------------------------------------------*/

proc sort data=ex_prep;

    by USUBJID EXSTDTC;

run;


/*--------------------------------------------------------------*/
/* 4. Create Intermediate EX Dataset                            */
/*--------------------------------------------------------------*/

data sdtm_ex1;

    /* Define Variable Lengths */

    length 
        STUDYID   $10
        DOMAIN    $2
        USUBJID   $25
        EXTRT     $40
        EXDOSE    8
        EXDOSU    $10
        EXDOSFRM  $30
        EXDOSFRQ  $10
        EXVLDIST  $20
        EXLOT     $15
        EXSTDTC   $19
        EXENDTC   $19
        VISIT     $40;

    
    /* Merge EX Data with DM */

    merge 
        ex_prep(in=a)
        dm_for_ex;

    by USUBJID;

    if a;


    /* Identifier Variables */

    STUDYID = "ONCO-2026";

    DOMAIN = "EX";


    /* Exposure Variables */

    EXTRT = upcase(TRT);

    EXDOSE = DOSE;

    EXDOSU = upcase(UNIT);

    EXDOSFRM = tranwrd(FORM, "_", " ");

    EXDOSFRQ = upcase(FREQ);

    EXVLDIST = upcase(ROUTE);

    EXLOT = LOT;


    /* Derive EXSTDY */

    if EXSTDTC ne "" and RFSTDTC ne "" then do;

        _stdt = input(EXSTDTC, yymmdd10.);

        _rfdt = input(RFSTDTC, yymmdd10.);

        if _stdt >= _rfdt then
            EXSTDY = (_stdt - _rfdt) + 1;

        else
            EXSTDY = (_stdt - _rfdt);

    end;


    /* Derive EXENDY */

    if EXENDTC ne "" and RFSTDTC ne "" then do;

        _endt = input(EXENDTC, yymmdd10.);

        _rfdt = input(RFSTDTC, yymmdd10.);

        if _endt >= _rfdt then
            EXENDY = (_endt - _rfdt) + 1;

        else
            EXENDY = (_endt - _rfdt);

    end;

run;


/*--------------------------------------------------------------*/
/* 5. Sort Final EX Dataset                                     */
/*--------------------------------------------------------------*/

proc sort data=sdtm_ex1;

    by USUBJID EXSTDTC;

run;


/*--------------------------------------------------------------*/
/* 6. Derive EXSEQ                                              */
/*--------------------------------------------------------------*/

data sdtm_ex;

    set sdtm_ex1;

    by USUBJID;

    retain EXSEQ;

    if first.USUBJID then
        EXSEQ = 1;

    else
        EXSEQ + 1;


    /* Keep Final SDTM Variables */

    keep
        STUDYID
        DOMAIN
        USUBJID
        EXSEQ
        EXTRT
        EXDOSE
        EXDOSU
        EXDOSFRM
        EXDOSFRQ
        EXVLDIST
        EXLOT
        EXSTDTC
        EXENDTC
        EXSTDY
        EXENDY
        VISIT;

run;


/*--------------------------------------------------------------*/
/* 7. View Final EX Dataset                                     */
/*--------------------------------------------------------------*/

proc print data=sdtm_ex;
run;
