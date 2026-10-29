/*****************************************************************************
* Program:    l_death.sas
* Purpose:    Listing 16.2.7.3 - Listing of Deaths
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      adam.adsl, adam.adae
* Output:     l_death.rtf
* Population: All Subjects
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&macpath./m_report.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Step 1: Identify deaths ---*/
proc sql noprint;
    create table deaths as
    select a.USUBJID,
           a.TRTA, a.AGE, a.SEX, a.RACE,
           a.TRTSDT format=date9. as TRT_START,
           a.TRTEDT format=date9. as TRT_END,
           a.DTHDT format=date9. as DEATH_DATE,
           a.DTHCAUS as CAUSE_OF_DEATH,
           /* Days from last dose to death */
           case when a.DTHDT ne . and a.TRTEDT ne .
                then a.DTHDT - a.TRTEDT
                else .
           end as DAYS_LASTDOSE_DEATH,
           /* Days from first dose to death */
           case when a.DTHDT ne . and a.TRTSDT ne .
                then a.DTHDT - a.TRTSDT + 1
                else .
           end as DAYS_FIRSTDOSE_DEATH
    from adam.adsl a
    where a.DTHFL = 'Y'
    order by a.TRTA, a.USUBJID;
quit;

/*--- Step 2: Add fatal AE information ---*/
proc sql noprint;
    create table death_ae as
    select distinct USUBJID,
           AEBODSYS as FATAL_AE_SOC,
           AEDECOD as FATAL_AE_PT,
           AEREL as FATAL_AE_REL
    from adam.adae
    where AEOUT = 'FATAL'
    order by USUBJID;
quit;

proc sql noprint;
    create table death_report as
    select a.*,
           b.FATAL_AE_SOC, b.FATAL_AE_PT, b.FATAL_AE_REL
    from deaths a
    left join death_ae b on a.USUBJID = b.USUBJID
    order by a.TRTA, a.USUBJID;
quit;

/*--- Step 3: Format display ---*/
data death_final;
    set death_report;
    length demog $40 days_display $20;
    
    demog = catx('/', strip(put(AGE, best.)), strip(SEX), strip(substr(RACE, 1, 1)));
    
    if DAYS_LASTDOSE_DEATH ne . then 
        days_display = strip(put(DAYS_LASTDOSE_DEATH, 8.));
    else days_display = 'N/A';
run;

/*--- Step 4: Generate listing ---*/
%set_titles(output=L_DEATH, population=All Subjects);
%ods_on(filename=l_death);

proc report data=death_final nowd split='~'
    style(report)=[outputwidth=9.5in font_size=8pt]
    style(header)=[just=center fontweight=bold font_size=8pt]
    style(column)=[just=left verticalalign=top font_size=8pt];

    columns TRTA USUBJID demog TRT_START TRT_END DEATH_DATE
            days_display CAUSE_OF_DEATH FATAL_AE_SOC FATAL_AE_PT FATAL_AE_REL;

    define TRTA           / order 'Treatment' style(column)=[width=0.8in];
    define USUBJID        / display 'Subject~ID' style(column)=[width=0.8in];
    define demog          / display 'Age/Sex/~Race' style(column)=[width=0.5in];
    define TRT_START      / display 'First~Dose' style(column)=[width=0.7in];
    define TRT_END        / display 'Last~Dose' style(column)=[width=0.7in];
    define DEATH_DATE     / display 'Death~Date' style(column)=[width=0.7in];
    define days_display   / display 'Days Last~Dose to~Death' style(column)=[width=0.6in just=center];
    define CAUSE_OF_DEATH / display 'Cause of~Death' style(column)=[width=1.2in];
    define FATAL_AE_SOC   / display 'Fatal AE~SOC' style(column)=[width=1.2in];
    define FATAL_AE_PT    / display 'Fatal AE~PT' style(column)=[width=1.0in];
    define FATAL_AE_REL   / display 'Relationship' style(column)=[width=0.8in];

run;

%ods_off;
%clear_titles;

proc datasets lib=work nolist; delete deaths death_ae death_report death_final; quit;

%put NOTE: l_death.sas completed successfully.;
