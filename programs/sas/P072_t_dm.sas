/*****************************************************************************
* Program:    t_dm.sas
* Purpose:    Table 14.1.1 - Summary of Demographics and Baseline 
*             Characteristics
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      adam.adsl
* Output:     t_dm.rtf
* Population: Safety Analysis Set (SAFFL='Y')
* Macros:     m_counts, m_desc_stats, m_report, u_titles
* Validation: Independent programming / double programming
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&macpath./m_counts.sas";
%include "&macpath./m_desc_stats.sas";
%include "&macpath./m_report.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Step 1: Get population counts ---*/
%m_counts(inds=adam.adsl, trtvar=TRTA, popflag=SAFFL, popval=Y);

/*--- Step 2: Prepare analysis dataset ---*/
data dm;
    set adam.adsl;
    where SAFFL = 'Y';

    /* Derive age groups */
    length AGEGR1 $20;
    if      AGE < 18 then AGEGR1 = '<18';
    else if AGE < 65 then AGEGR1 = '18 to <65';
    else if AGE >= 65 then AGEGR1 = '>=65';

    /* Ensure consistent ordering */
    if SEX = 'M' then SEXN = 1;
    else if SEX = 'F' then SEXN = 2;

    if RACE = 'WHITE' then RACEN = 1;
    else if RACE = 'BLACK OR AFRICAN AMERICAN' then RACEN = 2;
    else if RACE = 'ASIAN' then RACEN = 3;
    else RACEN = 4;

    if ETHNIC = 'HISPANIC OR LATINO' then ETHNICN = 1;
    else if ETHNIC = 'NOT HISPANIC OR LATINO' then ETHNICN = 2;
    else ETHNICN = 3;
run;

/*--- Step 3: Continuous variables (Age, Weight, Height, BMI) ---*/
%macro cont_block(var=, label=, ord=, decimals=1);

    %m_cont_stats(inds=dm, anavar=&var., trtvar=TRTA, outds=_c_&var., 
                  decimals=&decimals.);

    data _c_&var.;
        set _c_&var.;
        length category $60;
        category = "&label.";
        block = &ord.;
    run;

%mend cont_block;

%cont_block(var=AGE, label=Age (years), ord=1);
%cont_block(var=WEIGHTBL, label=Weight (kg), ord=5);
%cont_block(var=HEIGHTBL, label=Height (cm), ord=6);
%cont_block(var=BMIBL, label=BMI (kg/m^{super 2}), ord=7);

/*--- Step 4: Categorical variables (Sex, Race, Ethnicity, Age Group) ---*/
%macro cat_block(var=, label=, ord=);

    %m_cat_stats(inds=dm, catvar=&var., trtvar=TRTA, outds=_f_&var.);

    data _f_&var.;
        set _f_&var.;
        length category $60 stat $40;
        category = "&label.";
        stat = &var.;
        block = &ord.;
    run;

%mend cat_block;

%cat_block(var=SEX, label=Sex, ord=2);
%cat_block(var=RACE, label=Race, ord=3);
%cat_block(var=ETHNIC, label=Ethnicity, ord=4);
%cat_block(var=AGEGR1, label=Age Group, ord=8);

/*--- Step 5: Combine all results ---*/
data all_stats;
    set _c_age _f_sex _f_race _f_ethnic
        _c_weightbl _c_heightbl _c_bmibl _f_agegr1;
run;

/*--- Step 6: Transpose by treatment for columnar display ---*/
proc sort data=all_stats; by block ord stat; run;

proc transpose data=all_stats out=final(drop=_name_ rename=(colPlacebo=col1 colDrug_X_Low_Dose=col2 colDrug_X_High_Dose=col3)) prefix=col;  /* test-copy patch: name the transposed columns col1-col3 as the report expects */
    by block category ord stat;
    id TRTA;
    var value;
run;

/*--- Step 7: Create report dataset ---*/
data report;
    retain block category stat col1 col2 col3;
    set final;
    by block category;

    /* Display category label only on first row of block */
    length display_cat $60;
    if first.category then display_cat = category;
    else display_cat = ' ';

    /* Indent statistic labels */
    stat = '  ' || strip(stat);
run;

/*--- Step 8: Generate output ---*/
%set_titles(output=T_DM, population=Safety Analysis Set);
%ods_on(filename=t_dm);

proc report data=report nowd split='~'
    style(report)=[outputwidth=9.5in]
    style(header)=[just=center fontweight=bold];

    columns block display_cat stat col1 col2 col3;

    define block       / order noprint;
    define display_cat / display "Parameter" style(column)=[width=2.5in fontweight=bold];
    define stat        / display "Statistic" style(column)=[width=1.5in];
    define col1        / display "&col1hdr." style(column)=[width=1.5in just=center];
    define col2        / display "&col2hdr." style(column)=[width=1.5in just=center];
    define col3        / display "&col3hdr." style(column)=[width=1.5in just=center];

    compute after block;
        line ' ';
    endcomp;

run;

%ods_off;
%clear_titles;

/*--- Cleanup ---*/
proc datasets lib=work nolist;
    delete dm all_stats final report _c_: _f_: _bign _smalln;
quit;

%put NOTE: t_dm.sas completed successfully.;
