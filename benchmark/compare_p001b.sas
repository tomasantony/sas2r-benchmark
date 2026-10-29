libname ours1 "D:\meta_hackathon\sas2r-agent\output\sas\datasets\P001";
libname ship1 xport "D:\meta_hackathon\sas2r-agent\output\sas\shipped\P001\adsl.xpt";
options ls=160 nodate nonumber;
title "nmiss of TRTSDTM/TRTEDTM: shipped then ours";
proc means data=ship1.adsl n nmiss; var trtsdtm trtedtm; run;
proc means data=ours1.adsl n nmiss; var trtsdtm trtedtm; run;
title "EFFFL differing subjects";
data d; merge ship1.adsl(keep=usubjid efffl saffl ittfl rename=(efffl=f_ship)) ours1.adsl(keep=usubjid efffl rename=(efffl=f_ours)); by usubjid; if f_ship ne f_ours; run;
proc print data=d; run;
