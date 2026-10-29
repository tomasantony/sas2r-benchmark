libname ours1 "D:\meta_hackathon\sas2r-agent\output\sas\datasets\P001";
libname ship1 xport "D:\meta_hackathon\sas2r-agent\output\sas\shipped\P001\adsl.xpt";
options ls=160 ps=300 nodate nonumber;
proc compare base=ship1.adsl compare=ours1.adsl criterion=1e-8 maxprint=(5,50); id USUBJID; run;
title "TRTSDTM/TRTEDTM differences in seconds (shipped minus ours)";
data d; merge ship1.adsl(keep=usubjid trtsdtm trtedtm efffl rename=(trtsdtm=s1 trtedtm=e1 efffl=f1)) ours1.adsl(keep=usubjid trtsdtm trtedtm efffl); by usubjid; ds=s1-trtsdtm; de=e1-trtedtm; fdiff=(f1 ne efffl); run;
proc freq data=d; tables ds de fdiff / missing; run;
