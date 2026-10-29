/* make_synthetic_study.sas: synthesize a self-contained ADaM/SDTM study for the owner's TLF programs.
   Seeded, so re-runs are identical. 120 subjects, 3 arms. Variable names follow ADaM IG conventions
   and cover everything the TLF programs reference (see required_vars.txt and the TLF source). */
%let T = D:\meta_hackathon\own_programs_test;
%let nsubj = 240;
options dlcreatedir;
libname synth "&T.\data\synth\adam"; libname ssdtm "&T.\data\synth\sdtm";

data synth.adsl;
  call streaminit(20261027);
  length STUDYID $8 USUBJID $14 SUBJID $6 SITEID $3 COUNTRY $3 REGION1 $13 SEX $1 RACE $32 ETHNIC $22 AGEGR1 $5 AGEU $5
         ARM ARMCD TRT01P TRT01A TRTP TRTA $20 SAFFL ITTFL EFFFL RANDFL PPROTFL COMPLFL DTHFL $1 EOSSTT $12 DCSREAS $30 DTHCAUS $30;
  STUDYID = 'SYN001';
  do i = 1 to &nsubj;
    SITEID = put(mod(i,6)+1, z3.); SUBJID = cats(SITEID, put(i, z3.)); USUBJID = catx('-', STUDYID, SUBJID);
    COUNTRY = choosec(mod(i,6)+1, 'USA','USA','DEU','FRA','JPN','CAN');
    REGION1 = ifc(COUNTRY in ('USA','CAN'), 'North America', ifc(COUNTRY='JPN','Asia','Europe'));
    AGE = max(18, round(55 + 12*rand('normal'))); AGEU = 'YEARS'; AGEGR1 = ifc(AGE<65, '<65', '>=65'); AGEGR1N = ifn(AGE<65, 1, 2);
    SEX = ifc(rand('uniform')<0.52, 'F', 'M');
    RACEN = rand('table', 0.72, 0.12, 0.10, 0.06);
    RACE = choosec(RACEN, 'WHITE','BLACK OR AFRICAN AMERICAN','ASIAN','OTHER');
    ETHNICN = ifn(rand('uniform')<0.15, 1, 2); ETHNIC = choosec(ETHNICN, 'HISPANIC OR LATINO', 'NOT HISPANIC OR LATINO');
    HEIGHTBL = round(ifn(SEX='F', 163, 176) + 7*rand('normal'), 0.1);
    WEIGHTBL = round(ifn(SEX='F', 68, 82) + 13*rand('normal'), 0.1);
    BMIBL = round(WEIGHTBL / (HEIGHTBL/100)**2, 0.1);
    ECOGBL = rand('table', 0.55, 0.35, 0.10) - 1;
    /* randomised 1:1:1 (a modulo assignment confounded treatment with site/region) */
    TRT01PN = rand('table', 0.34, 0.33, 0.33); TRTPN = TRT01PN; TRT01AN = TRT01PN; TRTAN = TRT01PN;
    TRT01P = choosec(TRT01PN, 'Placebo', 'Drug X Low Dose', 'Drug X High Dose'); TRTP = TRT01P; TRT01A = TRT01P; TRTA = TRT01P;
    ARMCD = choosec(TRT01PN, 'PBO','LOW','HIGH'); ARM = TRT01P;
    RANDFL = 'Y'; RANDDT = '15JAN2025'd + floor(rand('uniform')*180); TRTSDT = RANDDT + 1;
    disc = rand('uniform') < 0.18;
    TRTEDT = TRTSDT + ifn(disc, floor(rand('uniform')*150), 168 + floor(rand('uniform')*7));
    TRTDUR = TRTEDT - TRTSDT + 1;
    SAFFL = 'Y'; ITTFL = 'Y'; EFFFL = ifc(rand('uniform')<0.93, 'Y', 'N'); PPROTFL = ifc(EFFFL='Y' and rand('uniform')<0.9, 'Y', 'N');
    EOSSTT = ifc(disc, 'DISCONTINUED', 'COMPLETED'); COMPLFL = ifc(disc, 'N', 'Y');
    DCSREAS = ifc(disc, choosec(rand('table', 0.4, 0.3, 0.2, 0.1), 'ADVERSE EVENT','WITHDRAWAL BY SUBJECT','LACK OF EFFICACY','LOST TO FOLLOW-UP'), '');
    DTHFL = ifc(rand('uniform')<0.04, 'Y', 'N'); DTHDT = ifn(DTHFL='Y', TRTEDT + floor(rand('uniform')*30), .);
    DTHCAUS = ifc(DTHFL='Y', choosec(rand('table', 0.5, 0.3, 0.2), 'DISEASE PROGRESSION','CARDIAC ARREST','SEPSIS'), '');
    format RANDDT TRTSDT TRTEDT DTHDT date9.;
    output;
  end;
  drop i disc;
run;

/* ADAE: 0-5 events per subject */
data synth.adae;
  call streaminit(20261028);
  set synth.adsl(keep=STUDYID USUBJID SITEID AGE SEX RACE TRTA TRTAN TRTP TRTPN SAFFL TRTSDT TRTEDT);
  length AEBODSYS AESOC $60 AEDECOD AETERM $40 AESEV $8 AESER AEREL AESMIE AESLIFE AESHOSP AESDTH AESDISAB AESCONG $1
         AESTDTC AEENDTC $10 TRTEMFL $1 AEOUT $26 AEACN $24 AETOXGR $1;
  n = rand('table', 0.25, 0.3, 0.2, 0.15, 0.07, 0.03) - 1;
  do AESEQ = 1 to n;
    k = rand('table', 0.2,0.15,0.15,0.1,0.1,0.1,0.1,0.1);
    AEBODSYS = choosec(k, 'GASTROINTESTINAL DISORDERS','NERVOUS SYSTEM DISORDERS','INFECTIONS AND INFESTATIONS','SKIN AND SUBCUTANEOUS TISSUE DISORDERS','GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS','MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS','RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS','INVESTIGATIONS');
    AESOC = AEBODSYS; AESOCCD = 10000000 + k*1000;
    AEDECOD = choosec(k, 'Nausea','Headache','Upper respiratory tract infection','Rash','Fatigue','Arthralgia','Cough','Alanine aminotransferase increased');
    AETERM = upcase(AEDECOD);
    sevn = rand('table', 0.6, 0.3, 0.1); AESEV = choosec(sevn, 'MILD','MODERATE','SEVERE'); AETOXGR = put(sevn + ifn(rand('uniform')<0.1, 1, 0), 1.);
    AESER = ifc(rand('uniform') < 0.08, 'Y', 'N'); AEREL = ifc(rand('uniform') < 0.4 + 0.1*(TRTAN-1), 'Y', 'N');
    AESHOSP = ifc(AESER='Y' and rand('uniform')<0.7, 'Y', 'N'); AESLIFE = ifc(AESER='Y' and rand('uniform')<0.2, 'Y', 'N');
    AESDTH = ifc(AESER='Y' and rand('uniform')<0.1, 'Y', 'N'); AESDISAB = 'N'; AESCONG = 'N'; AESMIE = ifc(AESER='Y' and AESHOSP='N' and AESLIFE='N' and AESDTH='N', 'Y', 'N');
    AEACN = choosec(rand('table', 0.7, 0.15, 0.1, 0.05), 'DOSE NOT CHANGED','DRUG INTERRUPTED','DOSE REDUCED','DRUG WITHDRAWN');
    ASTDT = TRTSDT + floor(rand('uniform')*(TRTEDT-TRTSDT+5)); AENDT = ASTDT + floor(rand('uniform')*20);
    AESTDTC = put(ASTDT, yymmdd10.); AEENDTC = put(AENDT, yymmdd10.); ASTDY = ASTDT - TRTSDT + 1; AENDY = AENDT - TRTSDT + 1;
    TRTEMFL = ifc(ASTDT >= TRTSDT, 'Y', 'N'); AEOUT = ifc(rand('uniform')<0.85, 'RECOVERED/RESOLVED', 'NOT RECOVERED/NOT RESOLVED');
    format ASTDT AENDT date9.; output;
  end;
  drop n k sevn;
run;

/* ADCM */
data synth.adcm;
  call streaminit(20261029);
  set synth.adsl(keep=STUDYID USUBJID TRTA TRTAN TRTP TRTPN SAFFL TRTSDT TRTEDT);
  length CMTRT CMDECOD $40 CMCLAS $40 ATC CMCLASCD $7 CMINDC $30 CMSTDTC CMENDTC $10 CONCOMFL PREFL ONTRTFL $1;
  n = rand('table', 0.3, 0.3, 0.25, 0.15) - 1;
  do CMSEQ = 1 to n;
    k = rand('table', 0.3, 0.25, 0.2, 0.15, 0.1);
    CMDECOD = choosec(k, 'PARACETAMOL','IBUPROFEN','OMEPRAZOLE','AMLODIPINE','METFORMIN'); CMTRT = CMDECOD;
    CMCLAS = choosec(k, 'ANALGESICS','ANTIINFLAMMATORY PRODUCTS','DRUGS FOR ACID RELATED DISORDERS','CALCIUM CHANNEL BLOCKERS','DRUGS USED IN DIABETES');
    ATC = choosec(k, 'N02','M01','A02','C08','A10'); CMCLASCD = ATC;
    CMINDC = choosec(k, 'HEADACHE','PAIN','GASTRITIS','HYPERTENSION','DIABETES');
    ASTDT = TRTSDT - 30 + floor(rand('uniform')*200); AENDT = ASTDT + floor(rand('uniform')*60);
    CMSTDTC = put(ASTDT, yymmdd10.); CMENDTC = put(AENDT, yymmdd10.);
    PREFL = ifc(ASTDT < TRTSDT, 'Y', 'N'); ONTRTFL = ifc(AENDT >= TRTSDT and ASTDT <= TRTEDT, 'Y', 'N'); CONCOMFL = ONTRTFL;
    format ASTDT AENDT date9.; output;
  end;
  drop n k;
run;

/* ADEX: one record per parameter per subject */
data synth.adex;
  set synth.adsl(keep=STUDYID USUBJID TRTA TRTAN TRTP TRTPN SAFFL TRTSDT TRTEDT TRTDUR);
  length PARAMCD $8 PARAM $40 AVALU $10;
  dose = choosen(TRTAN, 0, 50, 100);
  PARAMCD='TRTDUR'; PARAM='Treatment Duration (days)'; AVAL=TRTDUR; AVALU='days'; output;
  PARAMCD='TOTDOSE'; PARAM='Total Dose (mg)'; AVAL=dose*TRTDUR; AVALU='mg'; output;
  PARAMCD='AVGDD'; PARAM='Average Daily Dose (mg/day)'; AVAL=dose; AVALU='mg/day'; output;
  drop dose;
run;

/* longitudinal BDS generator used for ADLB, ADVS, ADEFF, ADQS */
%macro bds(out, params, labels, means, sds, lo, hi, eff=0, grades=0);
  %local np; %let np = %sysfunc(countw(%superq(params), %str(,)));
data &out;
  call streaminit(20261030 + length("&out"));
  set synth.adsl(keep=STUDYID USUBJID TRTA TRTAN TRTP TRTPN SAFFL EFFFL TRTSDT TRTEDT);
  length PARAMCD $8 PARAM $40 AVISIT $10 ABLFL ANL01FL $1 ANRIND BNRIND $8 SHIFT1 $20 AVALU $10 ATOXGR BTOXGR $1;
  array pc[&np] $8 _temporary_ (&params); array pl[&np] $40 _temporary_ (&labels);
  array mu[&np] _temporary_ (&means); array sd[&np] _temporary_ (&sds); array lo[&np] _temporary_ (&lo); array hi[&np] _temporary_ (&hi);
  do p = 1 to dim(pc);
    PARAMCD = pc[p]; PARAM = pl[p]; PARAMN = p; AVALU = '';
    subj = rand('normal')*sd[p]*0.6;
    do AVISITN = 0 to 12 by 4;
      if AVISITN > 0 and TRTSDT + AVISITN*7 > TRTEDT + 7 then leave;
      AVISIT = ifc(AVISITN=0, 'Baseline', cats('Week ', AVISITN));
      ADT = TRTSDT - ifn(AVISITN=0, 1, 0) + AVISITN*7; ADY = ADT - TRTSDT + ifn(ADT>=TRTSDT,1,0);
      AVAL = round(mu[p] + subj + rand('normal')*sd[p]*0.5 - &eff*(TRTAN-1)*AVISITN/12*sd[p], 0.1);
      ABLFL = ifc(AVISITN=0, 'Y', ''); if AVISITN=0 then BASE = AVAL; CHG = ifn(AVISITN=0, ., AVAL-BASE); PCHG = ifn(AVISITN=0 or BASE=0, ., 100*CHG/BASE);
      ANL01FL = 'Y'; ANRLO = lo[p]; ANRHI = hi[p];
      ANRIND = ifc(AVAL<ANRLO, 'LOW', ifc(AVAL>ANRHI, 'HIGH', 'NORMAL')); if AVISITN=0 then BNRIND = ANRIND;
      SHIFT1 = catx(' to ', BNRIND, ANRIND);
      %if &grades %then %do;
        ATOXGR = ifc(ANRIND='NORMAL', '0', put(min(4, 1 + floor(abs(AVAL - ifn(AVAL>ANRHI, ANRHI, ANRLO)) / (sd[p]*0.8))), 1.));
        if AVISITN=0 then BTOXGR = ATOXGR;
        ATOXGRN = input(ATOXGR, 1.); BTOXGRN = input(BTOXGR, 1.);
      %end;
      format ADT date9.; output;
    end;
  end;
  drop p subj;
run;
%mend;
%bds(synth.adlb, %str('ALT','AST','BILI','CREAT','HGB','WBC','PLAT','NEUT'), %str('Alanine Aminotransferase (U/L)','Aspartate Aminotransferase (U/L)','Bilirubin (umol/L)','Creatinine (umol/L)','Hemoglobin (g/L)','Leukocytes (10^9/L)','Platelets (10^9/L)','Neutrophils (10^9/L)'), %str(28,26,9,80,140,7,250,4), %str(12,11,4,18,14,2,60,1.5), %str(7,10,3,50,120,4,150,2), %str(45,40,21,110,170,11,400,7.5), grades=1);
%bds(synth.advs, %str('SYSBP','DIABP','PULSE','WEIGHT','TEMP'), %str('Systolic Blood Pressure (mmHg)','Diastolic Blood Pressure (mmHg)','Pulse Rate (beats/min)','Weight (kg)','Temperature (C)'), %str(128,80,72,78,36.8), %str(14,9,10,15,0.4), %str(90,60,50,40,35.5), %str(140,90,100,150,37.5), eff=0.3);
%bds(synth.adeff, %str('ACTOT','CGIS'), %str('ADAS-Cog (11) Total Score','CGI Severity'), %str(22,4), %str(7,1), %str(0,1), %str(70,7), eff=0.5);
%bds(synth.adqs, %str('QSTOT'), %str('Questionnaire Total Score'), %str(50), %str(12), %str(0), %str(100), eff=0.4);

/* ADTTE */
data synth.adtte;
  call streaminit(20261031);
  set synth.adsl(keep=STUDYID USUBJID TRTA TRTAN TRTP TRTPN SAFFL EFFFL TRTSDT TRTEDT AGE AGEGR1 SEX RACE REGION1 ECOGBL);
  length PARAMCD $8 PARAM $40 EVNTDESC $40 CNSDTDSC $40;
  array pc[3] $8 _temporary_ ('OS','PFS','TTAE');
  array pl[3] $40 _temporary_ ('Overall Survival (days)','Progression-Free Survival (days)','Time to First Adverse Event (days)');
  do p = 1 to 3;
    PARAMCD = pc[p]; PARAM = pl[p]; STARTDT = TRTSDT;
    hr = 1 - 0.18*(TRTAN-1); t = -log(rand('uniform'))*choosen(p, 420, 240, 60)/hr;
    cens = (t > 360) or (p < 3 and rand('uniform') < 0.25);
    AVAL = round(min(t, 360)); ADT = STARTDT + AVAL; CNSR = cens;
    EVNTDESC = ifc(cens, '', choosec(p, 'DEATH', 'PROGRESSION OR DEATH', 'ADVERSE EVENT'));
    CNSDTDSC = ifc(cens, ifc(t>360, 'END OF STUDY', 'LOST TO FOLLOW-UP'), '');
    format STARTDT ADT date9.; output;
  end;
  drop p hr t cens;
run;

/* ADRS and ADTR (oncology response) */
data synth.adrs synth.adtr;
  call streaminit(20261101);
  set synth.adsl(keep=STUDYID USUBJID TRTA TRTAN TRTP TRTPN SAFFL EFFFL TRTSDT);
  length PARAMCD $8 PARAM $40 AVALC $4 BOR $4 AVISIT $10;
  base = 40 + rand('uniform')*60; best = -60 + 70*rand('uniform') - 12*(TRTAN-1); if best < -100 then best = -100;
  PARAMCD='SUMDIAM'; PARAM='Sum of Diameters (mm)'; BASE = round(base,1); AVALC = ''; BOR = '';
  do AVISITN = 0 to 24 by 8;
    AVISIT = ifc(AVISITN=0,'Baseline',cats('Week ',AVISITN));
    AVAL = round(base*(1 + ifn(AVISITN=0,0,best/100*min(1,AVISITN/16))),1); CHG = AVAL-BASE; PCHG = ifn(AVISITN=0,.,round(100*CHG/BASE,1));
    output synth.adtr;
  end;
  /* best percent change as its own ADTR parameter (one record per subject), carrying the response category */
  PARAMCD='BPCHG'; PARAM='Best Percent Change from Baseline in Sum of Diameters'; AVAL = round(base*(1+best/100),1); CHG = AVAL-BASE; PCHG = round(best,1); AVISIT='Best'; AVISITN=99;
  AVALC = ifc(best<=-100,'CR',ifc(best<=-30,'PR',ifc(best<20,'SD','PD'))); BOR = AVALC; output synth.adtr;
  PARAMCD='BOR'; PARAM='Best Overall Response'; AVALC = ifc(best<=-100,'CR',ifc(best<=-30,'PR',ifc(best<20,'SD','PD'))); BOR = AVALC;
  AVAL = .; CHG = .; PCHG = round(best,1); AVISIT=''; AVISITN=.; output synth.adrs;
  PARAMCD='SUMLD'; PARAM='Sum of Longest Diameters'; AVALC = ''; BOR = ''; AVAL = round(base*(1+best/100),1); CHG = AVAL-BASE; PCHG = round(best,1); output synth.adrs;
  drop base best;
run;

/* SDTM DV (protocol deviations) */
data ssdtm.dv;
  call streaminit(20261102);
  set synth.adsl(keep=STUDYID USUBJID SITEID RANDFL TRTSDT);
  length DOMAIN $2 DVTERM $60 DVDECOD $40 DVCAT $20 DVSCAT $30 DVSEV $8 EPOCH $12 DVSTDTC DVENDTC $10;
  DOMAIN = 'DV';
  if rand('uniform') < 0.3 then do;
    DVSEQ = 1; k = rand('table', 0.4, 0.3, 0.3);
    DVTERM = choosec(k, 'Visit outside protocol window', 'Study drug dose missed > 3 consecutive days', 'Prohibited concomitant medication taken');
    DVDECOD = choosec(k, 'VISIT WINDOW', 'DOSING', 'CONMED'); DVCAT = ifc(k=2, 'MAJOR', 'MINOR');
    DVSCAT = choosec(k, 'VISIT SCHEDULE', 'STUDY TREATMENT', 'PROHIBITED MEDICATION'); DVSEV = ifc(k=2, 'MAJOR', 'MINOR');
    EPOCH = 'TREATMENT'; sd = TRTSDT + floor(rand('uniform')*100); DVSTDTC = put(sd, yymmdd10.); DVENDTC = put(sd + floor(rand('uniform')*10), yymmdd10.); output;
  end;
  drop k sd TRTSDT;
run;
proc contents data=synth._all_ nods; run;
proc contents data=ssdtm._all_ nods; run;
