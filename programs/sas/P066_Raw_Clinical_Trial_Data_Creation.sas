/*******************************************************************************
* PROGRAM: Raw Clinical Trial Data Creation
* PURPOSE: Raw Clinical Trial Data for portfolio demonstration
* AUTHOR:  JAMES ZHAI, SAS Certified Clinical Trials Programmer
* DATE: 2025/10/01
*******************************************************************************/

data raw.raw_dm;
    infile datalines dlm=',' dsd;
    input SUBJID SEX $ AGE TRTGRP $ RANDDT : yymmdd10. RFENDT : yymmdd10.;
    format RANDDT RFENDT yymmdd10.;
datalines;
101,M,55,A,2022-01-10,2022-06-30
102,F,62,B,2022-01-12,2022-06-28
103,M,48,A,2022-01-15,2022-06-29
104,F,59,B,2022-01-18,2022-06-27
;
run;

data raw.raw_ex;
    infile datalines dlm=',' dsd;
    input SUBJID EXSTDAT : yymmdd10. EXENDAT : yymmdd10. DOSE;
    format EXSTDAT EXENDAT yymmdd10.;
datalines;
101,2022-01-11,2022-06-30,10
102,2022-01-13,2022-06-28,0
103,2022-01-16,2022-06-29,10
104,2022-01-19,2022-06-27,0
;
run;

data raw.raw_lb;
    infile datalines dlm=',' dsd;
    input SUBJID VISIT $ LBDT : yymmdd10. PARAM $ AVAL;
    format LBDT yymmdd10.;
datalines;
101,Screening,2021-12-28,HbA1c,8.2
101,Baseline,2022-01-10,HbA1c,8.1
101,Week12,2022-04-04,HbA1c,7.4
101,Week24,2022-06-28,HbA1c,6.9
102,Screening,2021-12-30,HbA1c,8.5
102,Baseline,2022-01-12,HbA1c,8.4
102,Week12,2022-04-06,HbA1c,8.1
102,Week24,2022-06-26,HbA1c,7.9
103,Screening,2021-12-29,HbA1c,7.9
103,Baseline,2022-01-15,HbA1c,7.8
103,Week24,2022-06-27,HbA1c,7.0
104,Screening,2021-12-31,HbA1c,8.3
104,Baseline,2022-01-18,HbA1c,8.2
104,Week24,2022-06-25,HbA1c,8.0
;
run;

data raw.raw_ae;
    infile datalines dlm=',' dsd;
    input SUBJID AETERM $ AESER $ AESEV $ AESTDT : yymmdd10. AEENDT : yymmdd10.;
    format AESTDT AEENDT yymmdd10.;
datalines;
101,Headache,N,MILD,2022-02-01,2022-02-03
101,Nausea,N,MODERATE,2022-03-15,2022-03-18
102,Dizziness,Y,SEVERE,2022-04-10,2022-04-15
103,Fatigue,N,MILD,2022-02-20,2022-02-22
;
run;

data raw.raw_vs;
    infile datalines dlm=',' dsd;
    input SUBJID VISIT $ VSDT : yymmdd10. PARAM $ AVAL;
    format VSDT yymmdd10.;
datalines;
101,Baseline,2022-01-10,WEIGHT,82
101,Week24,2022-06-28,WEIGHT,78
102,Baseline,2022-01-12,WEIGHT,75
102,Week24,2022-06-26,WEIGHT,74
;
run;

