/*****************************************************************************
* Program:    l_ae.sas
* Purpose:    Listing 16.2.7.1 - Listing of Adverse Events
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      adam.adae, adam.adsl
* Output:     l_ae.rtf
* Population: Safety Analysis Set (SAFFL='Y')
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&macpath./m_report.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Step 1: Prepare listing data ---*/
proc sql noprint;
    create table ae_list as
    select a.USUBJID, 
           b.TRTA,
           b.AGE, b.SEX, b.RACE,
           a.AEBODSYS as SOC,
           a.AEDECOD as PT,
           a.AETERM as VERBATIM,
           a.AESTDTC as START_DATE,
           a.AEENDTC as END_DATE,
           a.AESEV as SEVERITY,
           a.AEREL as RELATIONSHIP,
           a.AESER as SERIOUS,
           a.AEACN as ACTION_TAKEN,
           a.AEOUT as OUTCOME,
           a.AETOXGR as CTCAE_GRADE,
           a.TRTEMFL
    from adam.adae a
    inner join adam.adsl b on a.USUBJID = b.USUBJID
    where b.SAFFL = 'Y' and a.TRTEMFL = 'Y'
    order by b.TRTA, a.USUBJID, a.AESTDTC, a.AEBODSYS, a.AEDECOD;
quit;

/*--- Step 2: Format display values ---*/
data ae_report;
    set ae_list;
    length severity_d $10 rel_d $15 serious_d $3 action_d $30 outcome_d $30;

    /* Truncate/format for display */
    severity_d = propcase(SEVERITY);
    rel_d = propcase(RELATIONSHIP);
    serious_d = ifc(SERIOUS = 'Y', 'Yes', 'No');

    select(upcase(ACTION_TAKEN));
        when('DRUG WITHDRAWN')     action_d = 'Drug Withdrawn';
        when('DOSE REDUCED')       action_d = 'Dose Reduced';
        when('DRUG INTERRUPTED')   action_d = 'Drug Interrupted';
        when('DOSE NOT CHANGED')   action_d = 'Dose Not Changed';
        when('NOT APPLICABLE')     action_d = 'Not Applicable';
        otherwise                  action_d = propcase(ACTION_TAKEN);
    end;

    select(upcase(OUTCOME));
        when('RECOVERED/RESOLVED')            outcome_d = 'Resolved';
        when('RECOVERING/RESOLVING')          outcome_d = 'Resolving';
        when('NOT RECOVERED/NOT RESOLVED')    outcome_d = 'Not Resolved';
        when('RECOVERED/RESOLVED WITH SEQUELAE') outcome_d = 'Resolved w/ Sequelae';
        when('FATAL')                         outcome_d = 'Fatal';
        otherwise                             outcome_d = propcase(OUTCOME);
    end;
run;

/*--- Step 3: Generate listing ---*/
%set_titles(output=L_AE, population=Safety Analysis Set);
%ods_on(filename=l_ae);

proc report data=ae_report nowd split='~' 
    style(report)=[outputwidth=10in font_size=7pt]
    style(header)=[just=center fontweight=bold font_size=7pt
                   borderbottomcolor=black borderbottomwidth=1pt]
    style(column)=[just=left verticalalign=top font_size=7pt cellpadding=2pt];

    columns TRTA USUBJID SOC PT VERBATIM START_DATE END_DATE
            CTCAE_GRADE severity_d serious_d rel_d action_d outcome_d;

    define TRTA        / order 'Treatment' style(column)=[width=0.7in];
    define USUBJID     / order 'Subject~ID' style(column)=[width=0.8in];
    define SOC         / display 'System Organ~Class' style(column)=[width=1.2in];
    define PT          / display 'Preferred~Term' style(column)=[width=1.0in];
    define VERBATIM    / display 'Verbatim~Term' style(column)=[width=1.0in];
    define START_DATE  / display 'Start~Date' style(column)=[width=0.7in];
    define END_DATE    / display 'End~Date' style(column)=[width=0.7in];
    define CTCAE_GRADE / display 'CTCAE~Grade' style(column)=[width=0.4in just=center];
    define severity_d  / display 'Severity' style(column)=[width=0.6in];
    define serious_d   / display 'SAE' style(column)=[width=0.3in just=center];
    define rel_d       / display 'Relationship' style(column)=[width=0.7in];
    define action_d    / display 'Action~Taken' style(column)=[width=0.8in];
    define outcome_d   / display 'Outcome' style(column)=[width=0.8in];

    break after TRTA / page;

run;

%ods_off;
%clear_titles;

proc datasets lib=work nolist; delete ae_list ae_report; quit;

%put NOTE: l_ae.sas completed successfully.;
