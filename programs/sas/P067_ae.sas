/*******************************************************************************
* PROGRAM: ae.sas
* PURPOSE: Create SDTM datasets based on CDISC
* AUTHOR:  JAMES ZHAI, SAS Certified Clinical Trials Programmer
* DATE: 2025/10/01
*******************************************************************************/

proc sort data=raw.raw_ae; by SUBJID; run;
proc sort data=sdtm.dm; by SUBJID; run;

data sdtm.ae;
    merge raw.raw_ae (in=a)
          sdtm.dm;
    by SUBJID;
    if a; /* Keep only subjects who have AE */
   
    length STUDYID $10 AESTDTC AEENDTC $10;

    STUDYID = "ABC-301";           /* study identifier */
    AESTDTC = put(AESTDT, yymmdd10.); /* ISO 8601 date */
    AEENDTC = put(AEENDT, yymmdd10.);
    
    /* Convert RFSTDTC to numeric for calculation */
    rfstdt_num = input(RFSTDTC, yymmdd10.);

    /* AE Start Day */
    if not missing(AESTDT) then do;
        if AESTDT >= rfstdt_num then ASTDY = AESTDT - rfstdt_num + 1;
        else ASTDY = AESTDT - rfstdt_num; /* pre-dose events negative */
    end;

    /* AE End Day */
    if not missing(AEENDT) then do;
        if AEENDT >= rfstdt_num then AENDY = AEENDT - rfstdt_num + 1;
        else AENDY = AEENDT - rfstdt_num;
    end;

    format ASTDY AENDY 8.;
    * drop rfstdt_num;

    keep STUDYID USUBJID SUBJID AETERM AESER AESEV 
         AESTDTC AEENDTC ASTDY AENDY;
run;

