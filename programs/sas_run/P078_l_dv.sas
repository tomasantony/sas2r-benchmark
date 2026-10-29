/*****************************************************************************
* Program:    l_dv.sas
* Purpose:    Listing 16.2.2 - Listing of Protocol Deviations
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      sdtm.dv, adam.adsl
* Output:     l_dv.rtf
* Population: All Randomized Subjects
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&macpath./m_report.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Step 1: Prepare data ---*/
proc sql noprint;
    create table dv_list as
    select a.USUBJID,
           b.TRTA,
           b.SITEID as SITE,
           a.DVCAT as CATEGORY,
           a.DVSCAT as SUBCATEGORY,
           a.DVTERM as DESCRIPTION,
           a.DVSTDTC as START_DATE,
           a.DVENDTC as END_DATE,
           a.EPOCH,
           /* Major/Minor classification if available */
           a.DVSEV as SEVERITY
    from sdtm.dv a
    inner join adam.adsl b on a.USUBJID = b.USUBJID
    where b.RANDFL = 'Y'
    order by b.TRTA, b.SITEID, a.USUBJID, a.DVSTDTC;
quit;

/*--- Step 2: Generate listing ---*/
%set_titles(output=L_DV, population=All Randomized Subjects);
%ods_on(filename=l_dv);

proc report data=dv_list nowd split='~'
    style(report)=[outputwidth=9.5in font_size=8pt]
    style(header)=[just=center fontweight=bold font_size=8pt]
    style(column)=[just=left verticalalign=top font_size=8pt];

    columns TRTA SITE USUBJID CATEGORY SUBCATEGORY DESCRIPTION 
            START_DATE END_DATE EPOCH SEVERITY;

    define TRTA        / order 'Treatment' style(column)=[width=0.8in];
    define SITE        / order 'Site' style(column)=[width=0.5in];
    define USUBJID     / order 'Subject~ID' style(column)=[width=0.8in];
    define CATEGORY    / display 'Deviation~Category' style(column)=[width=1.2in];
    define SUBCATEGORY / display 'Sub-~category' style(column)=[width=1.0in];
    define DESCRIPTION / display 'Description' style(column)=[width=2.0in];
    define START_DATE  / display 'Start~Date' style(column)=[width=0.7in];
    define END_DATE    / display 'End~Date' style(column)=[width=0.7in];
    define EPOCH       / display 'Epoch' style(column)=[width=0.8in];
    define SEVERITY    / display 'Severity' style(column)=[width=0.6in];

    break after TRTA / page;

run;

%ods_off;
%clear_titles;

proc datasets lib=work nolist; delete dv_list; quit;

%put NOTE: l_dv.sas completed successfully.;
