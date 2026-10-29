/*****************************************************************************
* Macro:      m_desc_stats.sas
* Purpose:    Compute descriptive statistics for continuous and categorical
*             variables, formatted for TLF reporting
* Author:     [Programmer Name]
* Date:       [Date]
* Parameters: See individual sub-macros below
*****************************************************************************/

/*==========================================================================
  CONTINUOUS VARIABLES - Descriptive Statistics
  n, Mean, SD, Median, Min, Max, Q1, Q3
==========================================================================*/

%macro m_cont_stats(inds=, anavar=, trtvar=TRTA, byvar=, popflag=, 
                    popval=Y, subjvar=USUBJID, outds=work._contstats,
                    decimals=1);

    %let dp = &decimals.;
    %let dp1 = %eval(&decimals. + 1);

    /*--- Compute statistics ---*/
    proc means data=&inds. nway noprint;
        %if &popflag. ne %then %do;
            where upcase(&popflag.) = "%upcase(&popval.)";
        %end;
        class &trtvar. %if &byvar. ne %then %do; &byvar. %end;;
        var &anavar.;
        output out=_stats(drop=_type_ _freq_)
            n=n mean=mean std=std median=median min=min max=max
            q1=q1 q3=q3;
    run;

    /*--- Format statistics for display ---*/
    data &outds.;
        length stat $40 value $60;
        set _stats;

        array _dispord{8} _temporary_ (1 2 3 4 5 6 7 8);
        array _statlbl{8} $40 _temporary_ 
            ('n' 'Mean' 'SD' 'Median' 'Q1' 'Q3' 'Min' 'Max');
        
        /* n */
        stat = 'n'; ord = 1;
        value = strip(put(n, 8.));
        output;

        /* Mean (dp1) */
        stat = 'Mean'; ord = 2;
        if n > 0 then value = strip(put(mean, 12.&dp1.));
        else value = '';
        output;

        /* SD (dp1) */
        stat = 'SD'; ord = 3;
        if n > 1 then value = strip(put(std, 12.&dp1.));
        else value = '';
        output;

        /* Median (dp) */
        stat = 'Median'; ord = 4;
        if n > 0 then value = strip(put(median, 12.&dp.));
        else value = '';
        output;

        /* Q1, Q3 (dp) */
        stat = 'Q1, Q3'; ord = 5;
        if n > 0 then value = catx(', ', strip(put(q1, 12.&dp.)), 
                                          strip(put(q3, 12.&dp.)));
        else value = '';
        output;

        /* Min, Max (dp) */
        stat = 'Min, Max'; ord = 6;
        if n > 0 then value = catx(', ', strip(put(min, 12.&dp.)), 
                                          strip(put(max, 12.&dp.)));
        else value = '';
        output;

        keep &trtvar. %if &byvar. ne %then %do; &byvar. %end; stat value ord;
    run;

    proc sort data=&outds.; 
        by %if &byvar. ne %then %do; &byvar. %end; ord &trtvar.; 
    run;

    proc datasets lib=work nolist; delete _stats; quit;

%mend m_cont_stats;


/*==========================================================================
  CATEGORICAL VARIABLES - Frequency Counts n (%)
==========================================================================*/

%macro m_cat_stats(inds=, catvar=, trtvar=TRTA, byvar=, popflag=,
                   popval=Y, subjvar=USUBJID, outds=work._catstats,
                   denom=bign, pctfmt=5.1);

    /*--- Count subjects per category ---*/
    proc sql noprint;
        create table _catcnt as
        select &trtvar.
               %if &byvar. ne %then %do; , &byvar. %end;
               , &catvar.
               , count(distinct &subjvar.) as cnt format=8.
        from &inds.
        %if &popflag. ne %then %do;
            where upcase(&popflag.) = "%upcase(&popval.)")
        %end;
        group by &trtvar.
               %if &byvar. ne %then %do; , &byvar. %end;
               , &catvar.
        ;
    quit;

    /*--- Merge with Big N for denominator ---*/
    proc sql noprint;
        create table &outds. as
        select a.*,
               b.bign,
               case when b.bign > 0 
                    then a.cnt / b.bign * 100 
                    else . 
               end as pct format=&pctfmt.
        from _catcnt a
        left join work._bign b
        on a.&trtvar. = b.&trtvar.
        order by %if &byvar. ne %then %do; a.&byvar., %end; 
                 a.&catvar., a.&trtvar.;
    quit;

    /*--- Format n (%) display string ---*/
    data &outds.;
        set &outds.;
        length value $30;
        if cnt > 0 then 
            value = cat(strip(put(cnt, 8.)), ' (', 
                        strip(put(pct, &pctfmt.)), ')');
        else value = '0';
    run;

    proc datasets lib=work nolist; delete _catcnt; quit;

%mend m_cat_stats;


/*==========================================================================
  P-VALUE FORMATTING
==========================================================================*/

%macro m_pvalue(pval=, outvar=pval_fmt);

    length &outvar. $10;

    if &pval. = . then &outvar. = '';
    else if &pval. < 0.001 then &outvar. = '<0.001';
    else if &pval. > 0.999 then &outvar. = '>0.999';
    else &outvar. = strip(put(&pval., 6.3));

%mend m_pvalue;
