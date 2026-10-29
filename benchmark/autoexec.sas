/* autoexec.sas: common environment for the SAS reference run. The runner passes the program id
   (Pnnn) or a pipeline family name in -sysparm. benchmark/env/<family>.sas is then included so
   each source family gets the librefs and macro variables its programs expect.
   Everything conditional is inside a macro because this SAS (9.4 M3) has no open-code %IF. */
%let root    = D:\meta_hackathon\sas2r-agent;
%let pid     = &sysparm;
%let rawadam = &root.\data\raw\cdisc-pilot\adam;
%let rawsdtm = &root.\data\raw\cdisc-pilot\sdtm;
%let rawsplit= &root.\data\derived\cdisc-pilot\adam-split;
%let rawdir  = &root.\data\raw;
%let outtlf  = &root.\output\sas\tlf;
%let outlog  = &root.\output\sas\logs;
%let outds   = &root.\output\sas\datasets\&pid.;
%let family  = &pid;
options dlcreatedir;
libname outds "&outds.";
libname padam "&root.\data\derived\cdisc-pilot\adam" access=readonly;
libname psdtm "&root.\data\derived\cdisc-pilot\sdtm" access=readonly;
options mautosource sasautos=("&root.\programs\sas\macros\phuse-utilities" sasautos);
options nodate nonumber ls=132 ps=60 msglevel=i fullstimer;
ods listing;
%macro _bench_env;
  %if %substr(&pid,1,1) = P and %length(&pid) = 4 %then %do;
    data _null_; infile "&root.\benchmark\families.csv" dsd firstobs=2; length id $4 fam $16; input id fam;
      if id = "&pid" then call symputx('family', fam, 'G'); run;
  %end;
  %put NOTE: benchmark autoexec: pid=&pid family=&family;
  %if %sysfunc(fileexist(&root.\benchmark\env\&family..sas)) %then %do;
    %include "&root.\benchmark\env\&family..sas";
  %end;
%mend _bench_env;
%_bench_env;

/* Output capture: copy every permanent dataset a program created or modified since &_bench_t0 into outds,
   so pipeline families (which write to data/derived) and programs with their own librefs still leave their
   result under output/sas/datasets/<id>. The runner calls it through -termstmt; pipelines call it per program. */
%let _bench_t0 = %sysfunc(datetime());
%global _bench_list;
%macro _bench_capture;
  %local n i lib mem;
  %let _bench_list = ;
  proc sql noprint;
    select distinct catx(' ', t.libname, t.memname) into :_bench_list separated by '|'
    from dictionary.tables t
    where t.memtype = 'DATA' and t.modate >= &_bench_t0
      and t.libname not in ('WORK','SASHELP','SASUSER','MAPS','MAPSGFK','MAPSSAS','OUTDS','LIBRARY','PADAM','PSDTM')
      and t.libname in (select distinct libname from dictionary.libnames where engine ne 'XPORT');
  quit;
  %let n = %sysfunc(countw(%superq(_bench_list), |));
  %do i = 1 %to &n;
    %let lib = %scan(%scan(%superq(_bench_list), &i, |), 1, %str( ));
    %let mem = %scan(%scan(%superq(_bench_list), &i, |), 2, %str( ));
    proc copy in=&lib out=outds memtype=data; select &mem; run;
  %end;
  %put NOTE: benchmark capture: &n permanent dataset(s) copied to outds (%superq(_bench_list));
%mend _bench_capture;
