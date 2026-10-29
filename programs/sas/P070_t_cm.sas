/*****************************************************************************
* Program:    t_cm.sas
* Purpose:    Table 14.2.1 - Summary of Concomitant Medications by 
*             ATC Class and Preferred Name
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      adam.adcm, adam.adsl
* Output:     t_cm.rtf
* Population: Safety Analysis Set (SAFFL='Y')
* Notes:      ATC Level 2 and Preferred Name (WHO Drug Dictionary)
*             Sorted by descending frequency in Total column
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&macpath./m_counts.sas";
%include "&macpath./m_report.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Step 1: Get Big N ---*/
%m_counts(inds=adam.adsl, trtvar=TRTA, popflag=SAFFL, popval=Y);

/*--- Step 2: Prepare CM data ---*/
proc sql noprint;
    create table cm as
    select a.USUBJID, a.TRTA, a.TRTAN,
           a.CMCLAS,      /* ATC Level 2 Class */
           a.CMDECOD,     /* Preferred medication name */
           a.CMINDC,      /* Indication */
           a.CMSTDTC, a.CMENDTC
    from adam.adcm a
    inner join adam.adsl b on a.USUBJID = b.USUBJID
    where b.SAFFL = 'Y'
          and a.CONCOMFL = 'Y'  /* Concomitant flag */
    order by a.TRTAN, a.CMCLAS, a.CMDECOD;
quit;

/*--- Step 3: Any CM row ---*/
proc sql noprint;
    create table _any as
    select TRTA,
           count(distinct USUBJID) as cnt,
           'Any Concomitant Medication' as display_term length=200,
           0 as atc_ord, 0 as pref_ord, 0 as rowtype
    from cm
    group by TRTA;
quit;

/*--- Step 4: ATC class counts ---*/
proc sql noprint;
    create table _atc as
    select TRTA, CMCLAS,
           count(distinct USUBJID) as cnt
    from cm
    group by TRTA, CMCLAS;

    create table _atc_tot as
    select CMCLAS,
           count(distinct USUBJID) as cnt_tot
    from cm
    group by CMCLAS;
quit;

proc sort data=_atc; by CMCLAS; run;  /* test-copy patch: SQL output grouped by TRTA, CMCLAS is not in CMCLAS order */
data _atc_rows;
    merge _atc _atc_tot;
    by CMCLAS;
    length display_term $200;
    display_term = CMCLAS;
    atc_ord = cnt_tot;
    pref_ord = 0;
    rowtype = 1;
run;

/*--- Step 5: Preferred name counts ---*/
proc sql noprint;
    create table _pref as
    select TRTA, CMCLAS, CMDECOD,
           count(distinct USUBJID) as cnt
    from cm
    group by TRTA, CMCLAS, CMDECOD;

    create table _pref_tot as
    select CMCLAS, CMDECOD,
           count(distinct USUBJID) as cnt_tot
    from cm
    group by CMCLAS, CMDECOD;
quit;

proc sql noprint;
    create table _pref_rows as
    select a.TRTA, a.CMCLAS, a.CMDECOD, a.cnt,
           b.cnt_tot as pref_ord,
           c.cnt_tot as atc_ord,
           '  ' || strip(a.CMDECOD) as display_term length=200,
           2 as rowtype
    from _pref a
    left join _pref_tot b on a.CMCLAS = b.CMCLAS and a.CMDECOD = b.CMDECOD
    left join _atc_tot c on a.CMCLAS = c.CMCLAS;
quit;

/*--- Step 6: Combine and calculate percentages ---*/
data combined;
    set _any _atc_rows _pref_rows;
run;

proc sql noprint;
    create table combined2 as
    select a.*, b.bign,
           case when b.bign > 0 then a.cnt / b.bign * 100 else . end as pct
    from combined a
    left join work._bign b on a.TRTA = b.TRTA
    order by atc_ord desc, CMCLAS, rowtype, pref_ord desc, display_term, TRTA;
quit;

data combined3;
    set combined2;
    length value $30;
    if cnt > 0 then value = cat(strip(put(cnt, 8.)), ' (', strip(put(pct, 5.1)), ')');
    else value = '0';
run;

/*--- Step 7: Transpose ---*/
proc sort data=combined3 nodupkey;
    by descending atc_ord CMCLAS rowtype descending pref_ord display_term TRTA;
run;

proc transpose data=combined3 out=final(drop=_name_ rename=(colPlacebo=col1 colDrug_X_Low_Dose=col2 colDrug_X_High_Dose=col3)) prefix=col;  /* test-copy patch: name the transposed columns col1-col3 as the report expects */
    by descending atc_ord CMCLAS rowtype descending pref_ord display_term;
    id TRTA;
    var value;
run;

/*--- Step 8: Generate output ---*/
%set_titles(output=T_CM, population=Safety Analysis Set);
%ods_on(filename=t_cm);

proc report data=final nowd split='~'
    style(report)=[outputwidth=9.5in]
    style(header)=[just=center fontweight=bold];

    columns atc_ord rowtype pref_ord display_term col1 col2 col3;

    define atc_ord      / order descending noprint;
    define rowtype      / order noprint;
    define pref_ord     / order descending noprint;
    define display_term / display 'ATC Class~  Preferred Name' 
                          style(column)=[width=3.5in];
    define col1         / display "&col1hdr." style(column)=[width=1.5in just=center];
    define col2         / display "&col2hdr." style(column)=[width=1.5in just=center];
    define col3         / display "&col3hdr." style(column)=[width=1.5in just=center];

    compute display_term;
        if rowtype = 1 then call define(_col_, 'style', 'style=[fontweight=bold]');
    endcomp;

run;

footnote4 j=l "WHO Drug Dictionary [Version]";
footnote5 j=l "Subjects counted once per ATC class and once per preferred name within ATC class.";

%ods_off;
%clear_titles;

proc datasets lib=work nolist;
    delete cm _any _atc: _pref: combined: final;
quit;

%put NOTE: t_cm.sas completed successfully.;
