/* Row and variable counts for every sas7bdat under output/sas/datasets/Pnnn -> benchmark/dataset_obs.csv.
   Run: sas -sysin benchmark\audit_datasets.sas -nosplash -noterminal                                       */
%macro audit;
  filename dirs pipe 'dir /b /ad "D:\meta_hackathon\sas2r-agent\output\sas\datasets"';
  data _dirs; infile dirs truncover; input d $64.; if d =: 'P'; run;
  data _all; length path $200 nobs nvar 8; stop; run;
  data _null_; set _dirs;
    call execute(cats('libname d', d, ' "D:\meta_hackathon\sas2r-agent\output\sas\datasets\', d, '" access=readonly;'));
    call execute(cats('proc sql noprint; insert into _all select cats("datasets/', d, '/", lowcase(memname), ".sas7bdat"), nobs, nvar from dictionary.tables where libname="D', d, '" and memtype="DATA"; quit;'));
    call execute(catt('libname d', d, ' clear;'));
  run;
  proc export data=_all outfile="D:\meta_hackathon\sas2r-agent\benchmark\dataset_obs.csv" dbms=csv replace; run;
%mend; %audit;
