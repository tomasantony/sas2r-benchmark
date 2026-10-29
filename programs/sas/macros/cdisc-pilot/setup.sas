/* setup.sas for the original CDISC pilot programs (P002 adae.sas, P003 at14-5-02.sas).
   The pilot submission package does not ship its setup.sas, so this replacement defines
   the librefs the programs expect (sdtmnew, adamnew) on top of the local pilot data.
   The xpt files are SAS transport files; load the ones needed into a SAS library first. */
%let root = D:\meta_hackathon\sas2r-agent;
%let rawsdtm = &root.\data\raw\cdisc-pilot\sdtm;
%let rawadam = &root.\data\raw\cdisc-pilot\adam;
options dlcreatedir;
libname sdtmnew "&root.\data\derived\cdisc-pilot\sdtm";
libname adamnew "&root.\data\derived\cdisc-pilot\adam";
%macro load_xpt(lib, path, ds);
  libname _x xport "&path.\&ds..xpt";
  proc copy in=_x out=&lib.; run;
  libname _x clear;
%mend;
%load_xpt(sdtmnew, &rawsdtm., ae);
%load_xpt(sdtmnew, &rawsdtm., suppae);
%load_xpt(adamnew, &rawadam., adsl);
%load_xpt(adamnew, &rawadam., adae);
/* benchmark: the loads above refresh the input copies; restart the output-capture clock so only what the
   program itself creates (ADAMNEW.ADAE) is copied to output/sas/datasets/<id> */
%let _bench_t0 = %sysfunc(datetime());
