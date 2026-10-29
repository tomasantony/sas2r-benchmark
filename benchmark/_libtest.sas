libname a "D:\meta_hackathon\sas2r-agent\data\derived\cdisc-pilot\adam" access=readonly;
libname b "D:\meta_hackathon\sas2r-agent\data\derived\cdisc-pilot\adam";
libname c "D:\meta_hackathon\sas2r-agent/data/derived/cdisc-pilot/sdtm";
proc contents data=b._all_ nods; run;
