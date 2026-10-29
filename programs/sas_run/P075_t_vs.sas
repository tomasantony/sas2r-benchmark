/*****************************************************************************
* Program:    t_vs.sas
* Purpose:    Table 14.3.5 - Summary of Vital Signs by Visit
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      adam.advs, adam.adsl
* Output:     t_vs.rtf
* Population: Safety Analysis Set (SAFFL='Y')
* Notes:      Displays actual value and change from baseline at each visit
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&macpath./m_counts.sas";
%include "&macpath./m_desc_stats.sas";
%include "&macpath./m_report.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Step 1: Get Big N ---*/
%m_counts(inds=adam.adsl, trtvar=TRTA, popflag=SAFFL, popval=Y);

/*--- Step 2: Prepare analysis data ---*/
proc sql noprint;
    create table vs as
    select a.USUBJID, a.TRTA, a.TRTAN,
           a.PARAMCD, a.PARAM, a.PARAMN,
           a.AVISIT, a.AVISITN,
           a.AVAL, a.BASE, a.CHG,
           a.ABLFL, a.ANL01FL
    from adam.advs a
    inner join adam.adsl b on a.USUBJID = b.USUBJID
    where b.SAFFL = 'Y'
          and a.PARAMCD in ('SYSBP', 'DIABP', 'PULSE', 'TEMP', 'RESP', 'WEIGHT')
          and a.ANL01FL = 'Y'  /* Analysis-relevant records */
    order by a.PARAMN, a.AVISITN, a.TRTAN;
quit;

/*--- Step 3: Descriptive stats by parameter, visit, treatment ---*/
proc means data=vs nway noprint;
    class PARAMCD PARAM PARAMN AVISIT AVISITN TRTA TRTAN;
    var AVAL;
    output out=_actual(drop=_type_ _freq_)
        n=n mean=mean std=std median=median min=min max=max;
run;

proc means data=vs(where=(CHG ne . and ABLFL ne 'Y')) nway noprint;
    class PARAMCD PARAM PARAMN AVISIT AVISITN TRTA TRTAN;
    var CHG;
    output out=_change(drop=_type_ _freq_)
        n=n_chg mean=mean_chg std=std_chg median=median_chg 
        min=min_chg max=max_chg;
run;

/*--- Step 4: Merge actual and change ---*/
proc sql noprint;
    create table stats as
    select a.*, 
           b.n_chg, b.mean_chg, b.std_chg, b.median_chg, 
           b.min_chg, b.max_chg
    from _actual a
    left join _change b
    on a.PARAMCD = b.PARAMCD and a.AVISITN = b.AVISITN and a.TRTAN = b.TRTAN
    order by a.PARAMN, a.AVISITN, a.TRTAN;
quit;

/*--- Step 5: Format for display ---*/
data report;
    set stats;
    length stat1-stat6 $30 chg1-chg6 $30;

    /* Actual value stats */
    stat1 = strip(put(n, 8.));
    stat2 = strip(put(mean, 8.1));
    stat3 = strip(put(std, 8.2));
    stat4 = strip(put(median, 8.1));
    stat5 = catx(', ', strip(put(min, 8.1)), strip(put(max, 8.1)));

    /* Change from baseline stats */
    if n_chg > 0 then do;
        chg1 = strip(put(n_chg, 8.));
        chg2 = strip(put(mean_chg, 8.2));
        chg3 = strip(put(std_chg, 8.2));
        chg4 = strip(put(median_chg, 8.2));
        chg5 = catx(', ', strip(put(min_chg, 8.1)), strip(put(max_chg, 8.1)));
    end;
run;

/*--- Step 6: Generate output (one page per parameter) ---*/
%set_titles(output=T_VS, population=Safety Analysis Set);
%ods_on(filename=t_vs);

proc report data=report nowd split='~'
    style(report)=[outputwidth=9.5in]
    style(header)=[just=center fontweight=bold];

    columns PARAMN PARAM AVISITN AVISIT TRTA 
            ('Actual Value' stat1 stat2 stat3 stat4 stat5)
            ('Change from Baseline' chg1 chg2 chg3 chg4 chg5);

    define PARAMN  / order noprint;
    define PARAM   / order 'Parameter' style(column)=[width=1.2in fontweight=bold];
    define AVISITN / order noprint;
    define AVISIT  / order 'Visit' style(column)=[width=1in];
    define TRTA    / display 'Treatment' style(column)=[width=1in];
    define stat1   / display 'n' style(column)=[width=0.4in just=center];
    define stat2   / display 'Mean' style(column)=[width=0.6in just=center];
    define stat3   / display 'SD' style(column)=[width=0.6in just=center];
    define stat4   / display 'Median' style(column)=[width=0.6in just=center];
    define stat5   / display 'Min, Max' style(column)=[width=0.9in just=center];
    define chg1    / display 'n' style(column)=[width=0.4in just=center];
    define chg2    / display 'Mean' style(column)=[width=0.6in just=center];
    define chg3    / display 'SD' style(column)=[width=0.6in just=center];
    define chg4    / display 'Median' style(column)=[width=0.6in just=center];
    define chg5    / display 'Min, Max' style(column)=[width=0.9in just=center];

    break after PARAM / page;

run;

%ods_off;
%clear_titles;

proc datasets lib=work nolist;
    delete vs _actual _change stats report;
quit;

%put NOTE: t_vs.sas completed successfully.;
