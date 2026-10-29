libname psdtm "D:\meta_hackathon\sas2r-agent\data\derived\cdisc-pilot\sdtm";
libname c2c "D:\meta_hackathon\sas2r-agent\data\derived\c2c\data\sdtm";
libname wx "D:\meta_hackathon\sas2r-agent\data\derived\wxzhai\sdtm";
options ls=120 nodate nonumber;
proc contents data=psdtm._all_ out=c1(keep=libname memname name nobs) noprint; run;
proc contents data=c2c._all_ out=c2(keep=libname memname name nobs) noprint; run;
proc contents data=wx._all_ out=c3(keep=libname memname name nobs) noprint; run;
data all; set c1 c2 c3; run;
proc sql; select libname, memname, count(*) as nvars, max(nobs) as nobs from all group by libname, memname order by libname, memname; quit;
