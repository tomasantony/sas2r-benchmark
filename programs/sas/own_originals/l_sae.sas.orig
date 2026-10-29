/*****************************************************************************
* Program:    l_sae.sas
* Purpose:    Listing 16.2.7.2 - Listing of Serious Adverse Events
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      adam.adae, adam.adsl
* Output:     l_sae.rtf
* Population: Safety Analysis Set (SAFFL='Y')
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&macpath./m_report.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Step 1: Prepare SAE listing data ---*/
proc sql noprint;
    create table sae_list as
    select a.USUBJID,
           b.TRTA, b.AGE, b.SEX, b.RACE,
           b.TRTSDT format=date9. as TRT_START,
           a.AEBODSYS as SOC,
           a.AEDECOD as PT,
           a.AETERM as VERBATIM,
           a.AESTDTC as START_DATE,
           a.AEENDTC as END_DATE,
           a.AETOXGR as GRADE,
           a.AEREL as RELATIONSHIP,
           a.AEACN as ACTION_TAKEN,
           a.AEOUT as OUTCOME,
           /* SAE criteria */
           a.AESDTH,     /* Results in death */
           a.AESLIFE,    /* Life threatening */
           a.AESHOSP,    /* Requires hospitalization */
           a.AESDISAB,   /* Results in disability */
           a.AESCONG,    /* Congenital anomaly */
           a.AESMIE      /* Other medically important */
    from adam.adae a
    inner join adam.adsl b on a.USUBJID = b.USUBJID
    where b.SAFFL = 'Y' 
          and a.AESER = 'Y'
    order by b.TRTA, a.USUBJID, a.AESTDTC;
quit;

/*--- Step 2: Derive SAE criteria display ---*/
data sae_report;
    set sae_list;
    length sae_criteria $200;
    
    sae_criteria = '';
    if AESDTH = 'Y'   then sae_criteria = catx(', ', sae_criteria, 'Death');
    if AESLIFE = 'Y'  then sae_criteria = catx(', ', sae_criteria, 'Life-threatening');
    if AESHOSP = 'Y'  then sae_criteria = catx(', ', sae_criteria, 'Hospitalization');
    if AESDISAB = 'Y' then sae_criteria = catx(', ', sae_criteria, 'Disability');
    if AESCONG = 'Y'  then sae_criteria = catx(', ', sae_criteria, 'Congenital anomaly');
    if AESMIE = 'Y'   then sae_criteria = catx(', ', sae_criteria, 'Medically important');
    
    /* Days from first dose to onset */
    length onset_day $20;
    if TRT_START ne . and input(START_DATE, ??yymmdd10.) ne . then do;
        _onset = input(START_DATE, yymmdd10.) - TRT_START + 1;
        onset_day = strip(put(_onset, 8.));
    end;
    else onset_day = '';
    
    /* Demographics string */
    length demog $40;
    demog = catx('/', strip(put(AGE, best.)), strip(SEX), strip(substr(RACE, 1, 1)));
run;

/*--- Step 3: Generate listing ---*/
%set_titles(output=L_SAE, population=Safety Analysis Set);
%ods_on(filename=l_sae);

proc report data=sae_report nowd split='~'
    style(report)=[outputwidth=10in font_size=7pt]
    style(header)=[just=center fontweight=bold font_size=7pt]
    style(column)=[just=left verticalalign=top font_size=7pt];

    columns TRTA USUBJID demog SOC PT START_DATE END_DATE onset_day
            GRADE RELATIONSHIP ACTION_TAKEN OUTCOME sae_criteria;

    define TRTA         / order 'Treatment' style(column)=[width=0.7in];
    define USUBJID      / order 'Subject~ID' style(column)=[width=0.7in];
    define demog        / display 'Age/Sex/~Race' style(column)=[width=0.5in];
    define SOC          / display 'SOC' style(column)=[width=1.1in];
    define PT           / display 'Preferred~Term' style(column)=[width=0.9in];
    define START_DATE   / display 'Start~Date' style(column)=[width=0.7in];
    define END_DATE     / display 'End~Date' style(column)=[width=0.7in];
    define onset_day    / display 'Study~Day' style(column)=[width=0.4in just=center];
    define GRADE        / display 'Grade' style(column)=[width=0.4in just=center];
    define RELATIONSHIP / display 'Relation-~ship' style(column)=[width=0.7in];
    define ACTION_TAKEN / display 'Action~Taken' style(column)=[width=0.8in];
    define OUTCOME      / display 'Outcome' style(column)=[width=0.8in];
    define sae_criteria / display 'SAE~Criteria' style(column)=[width=1.1in];

    break after TRTA / page;

run;

%ods_off;
%clear_titles;

proc datasets lib=work nolist; delete sae_list sae_report; quit;

%put NOTE: l_sae.sas completed successfully.;
