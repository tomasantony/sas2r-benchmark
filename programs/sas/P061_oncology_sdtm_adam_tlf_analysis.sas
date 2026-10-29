/*-----------------------------------------------------------*
Project: Oncology Clinical Trial Analysis
Standard: CDISC SDTM / ADaM
Programming: SAS
Dataset: Breast Cancer METABRIC
Author: Sumit Choudhary

Description:
This project demonstrates clinical trial data preparation,
SDTM dataset creation, ADaM dataset derivation, and generation
of Tables, Listings, and Figures (TLFs) for oncology analysis.
*-----------------------------------------------------------*/




libname Cancer "/home/u64214007" ;

/* Import Raw Data */

proc import datafile="/home/u64214007/sasuser.v94/u64214007/Breast Cancer METABRIC.csv"
out=raw_metabric
dbms=csv
replace;
getnames=yes;
run;

/* Create SDTM DM (Demographics) */

data sdtm_dm;
set raw_metabric;

STUDYID="ONC001";
DOMAIN="DM";

USUBJID=catx("-",STUDYID,patient_id);

AGE=age_at_diagnosis;

run;

/* Create ADaM Dataset */

data adam_adsl;
set sdtm_dm;

TRT01P="CHEMO";
SAFFL="Y";

run;

/* Validate ADaM Dataset */

proc contents data=adam_adsl;
run;

proc print data=adam_adsl(obs=10);
run;

/* Create Demographic Summary Table */

proc means data=adam_adsl n mean std min max;
var 'Age at Diagnosis'n;
title "Demographic Summary - Age";
run;

/* Gender Distribution Table */

proc freq data=adam_adsl;
tables sex;
title "Gender Distribution";
run;

/* Tumor Stage Table */

proc freq data=adam_adsl;
tables 'Tumor Stage'n;
title "Tumor Stage Distribution";
run;

/* Tumor Size Summary Table */

proc means data=adam_adsl n mean std min max;
var 'Tumor Size'n;
title "Tumor Size Summary";
run;

/* Survival Analysis Dataset */

data adam_adtte;
set adam_adsl;

AVAL='Overall Survival (Months)'n;

if 'Overall Survival Status'n="Deceased" then CNSR=0;
else CNSR=1;

run;

/* Kaplan-Meier Survival Curve */

proc lifetest data=adam_adtte plots=survival;
time AVAL*CNSR(1);
title "Kaplan-Meier Survival Curve";
run;

/* Treatment Analysis */

proc freq data=adam_adsl;
tables Chemotherapy;
title "Chemotherapy Treatment Summary";
run;

/* ER / HER2 Status Analysis */
/* Oncology me biomarker analysis important hota hai. */

proc freq data=adam_adsl;
tables 'ER Status'n 'HER2 Status'n;
run;



/* Create TLF (Tables Listings Figures) */

ods pdf file="/home/u64214007/oncology_report.pdf";

proc means data=adam_adsl;
var 'AGE at Diagnosis'n;
run;

proc freq data=adam_adsl;
tables sex;
run;

proc freq data=adam_adsl;
tables 'Tumor Stage'n;
run;

proc lifetest data=adam_adtte plots=survival;
time AVAL*CNSR(1);
run;

ods pdf close;

/* Kaplan-Meier Survival Graph (Figure 1) */

proc lifetest data=adam_adtte plots=survival;
time AVAL*CNSR(1);
title "Kaplan-Meier Survival Curve";
run;

/* Tumor Stage Bar Graph */

proc sgplot data=adam_adsl;
vbar 'Tumor Stage'n;
title "Tumor Stage Distribution";
run;

/* Age Distribution Histogram */

proc sgplot data=adam_adsl;
histogram 'AGE at Diagnosis'n;
density 'AGE at Diagnosis'n;
title "Age Distribution of Patients";
run;

/* Tumor Size vs Survival Scatter Plot */

proc sgplot data=adam_adsl;
scatter x='Tumor Size'n y='Overall Survival (Months)'n;
title "Tumor Size vs Survival";
run;

/* ER Status vs Survival Box Plot */

proc sgplot data=adam_adsl;
vbox 'Overall Survival (Months)'n / category='ER Status'n;
title "Survival by ER Status";
run;

/* Treatment Analysis Graph */

proc sgplot data=adam_adsl;
vbar Chemotherapy;
title "Chemotherapy Treatment Distribution";
run;

/* Export All Graphs in PDF */

ods pdf file="/home/u64214007/oncology_graphs.pdf";

proc sgplot data=adam_adsl;
histogram 'AGE at Diagnosis'n;
run;

proc sgplot data=adam_adsl;
vbar 'Tumor Stage'n;
run;

proc lifetest data=adam_adtte plots=survival;
time AVAL*CNSR(1);
run;

ods pdf close;



