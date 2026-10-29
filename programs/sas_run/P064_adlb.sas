/*******************************************************************************
* PROGRAM: adlb.sas
* PURPOSE: Create ADaM ADLB dataset based on CDISC
* AUTHOR:  JAMES ZHAI, SAS Certified Clinical Trials Programmer
* DATE: 2025/10/01
*******************************************************************************/

/* Note: For simplicity, this program didn't consider more than 1 lab test before treatment */

proc sort data=sdtm.lb; by USUBJID PARAM LBDTC; run;
proc sort data=adam.adsl; by USUBJID; run;

data adam.adlb;
    merge sdtm.lb (in=a)
          adam.adsl (in=b keep=USUBJID TRT01P RFSTDTC);
    by USUBJID;
    if a and b;

    retain BASE;

    /* Baseline = last non-missing pre-dose value */
    if first.PARAM then BASE = .;
    if input(LBDTC, yymmdd10.) < input(RFSTDTC, yymmdd10.) and not missing(AVAL) then BASE = AVAL;

    /* Baseline flag */
    if input(LBDTC, yymmdd10.) < input(RFSTDTC, yymmdd10.) and AVAL = BASE then ABLFL = "Y";
    else ABLFL = "";

    /* Change from baseline */
    CHG = AVAL - BASE;

    drop LBDTC RFSTDTC;
run;


