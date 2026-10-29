/*----------------------------------------------------------
  QC Program: adlb_qc.sas
  Purpose: Independent QC of ADLB
----------------------------------------------------------*/

proc sort data=sdtm.lb out=lb_qc;
    by USUBJID PARAM LBDTC;
run;

proc sort data=adam.adsl out=adsl_qc;
    by USUBJID;
run;

data adam.adlb_qc;
    merge lb_qc (in=a)
          adsl_qc (in=b keep=USUBJID RFSTDTC TRT01P);
    by USUBJID;
    if a and b;

    lbdt = input(LBDTC, yymmdd10.);
    rfstdt = input(RFSTDTC, yymmdd10.);

    retain BASE;

    if first.PARAM then BASE = .;

    if lbdt < rfstdt and not missing(AVAL) then BASE = AVAL;

    if lbdt < rfstdt and AVAL = BASE then ABLFL = "Y";
    else ABLFL = "";

    if not missing(BASE) then CHG = AVAL - BASE;

    drop lbdt rfstdt;
run;
