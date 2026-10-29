/* One-time: load every CDISC pilot xpt into SAS libraries so programs can use plain librefs. */
%let root = D:\meta_hackathon\sas2r-agent;
libname padam "&root.\data\derived\cdisc-pilot\adam"; libname psdtm "&root.\data\derived\cdisc-pilot\sdtm"; libname psplit "&root.\data\derived\cdisc-pilot\adam-split";
%macro loaddir(dir, lib);
  filename d "&dir."; data _n; did=dopen('d'); do i=1 to dnum(did); f=dread(did,i); if lowcase(scan(f,-1,'.'))='xpt' then do; ds=scan(f,1,'.'); output; end; end; rc=dclose(did); run;
  data _null_; set _n; call execute(cats('libname _x xport "', "&dir.\", f, '"; proc copy in=_x out=&lib.; run; libname _x clear;')); run;
%mend;
%loaddir(&root.\data\raw\cdisc-pilot\adam, padam);
%loaddir(&root.\data\raw\cdisc-pilot\sdtm, psdtm);
%loaddir(&root.\data\derived\cdisc-pilot\adam-split, psplit);
proc datasets lib=padam nolist; contents data=_all_ nodetails short; run; quit;
