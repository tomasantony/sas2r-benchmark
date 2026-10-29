/*****************************************************************************
* Macro:      m_km_survival.sas
* Purpose:    Production-grade Kaplan-Meier survival analysis macro for
*             clinical trial TLF generation. Produces:
*               1. KM survival curve (RTF/PNG/PDF) with number-at-risk
*               2. Summary table of median survival, event rates, HRs
*               3. Log-rank, Wilcoxon, and stratified test results
*               4. Landmark analysis at user-specified timepoints
*               5. Cox PH hazard ratios with 95% CI
*
* Author:     [Programmer Name]
* Date:       [Date]
* Version:    2.0
*
* Parameters:
*   --- DATA ---
*   inds        = Input ADaM dataset (e.g., adam.adtte)
*   popds       = Population dataset (e.g., adam.adsl) for Big N
*   subjvar     = Subject identifier (default: USUBJID)
*   trtvar      = Treatment variable (default: TRTA)
*   trtvarn     = Numeric treatment variable (default: TRTAN)
*   timvar      = Time-to-event variable (default: AVAL)
*   cnsvar      = Censor variable (default: CNSR)
*   cnsval      = Censor value, i.e. NOT event (default: 1)
*   paramcd     = PARAMCD filter value (e.g., OS, PFS, EFS, DFS)
*   popflag     = Population flag variable (default: SAFFL)
*   popval      = Population flag value (default: Y)
*
*   --- ANALYSIS ---
*   refgrp      = Reference treatment group label for HR (default: first sorted)
*   alpha       = Significance level (default: 0.05)
*   test        = Log-rank test type: LOGRANK | WILCOXON | BOTH (default: LOGRANK)
*   stratvar    = Stratification variable(s) for stratified log-rank/CMH
*   covars      = Covariates for Cox PH model (space-delimited)
*   ties        = Tie handling: BRESLOW | EFRON | EXACT (default: EFRON)
*   landmarks   = Space-delimited landmark timepoints (e.g., 6 12 24)
*   timeunit    = Time unit label (default: Months)
*   conftype    = CI type: LOGLOG | LOG | PLAIN | ASINSQRT (default: LOGLOG)
*
*   --- OUTPUT CONTROL ---
*   outdir      = Output directory for files
*   outname     = Base output filename (default: km_survival)
*   plot        = Y/N produce KM plot (default: Y)
*   table       = Y/N produce summary table (default: Y)
*   plotfmt     = Image format: EMF | PNG | PDF | TIFF (default: EMF)
*   plotw       = Plot width in inches (default: 10)
*   ploth       = Plot height in inches (default: 7)
*   atrisk      = Y/N show number-at-risk (default: Y)
*   atrisk_int  = Interval for at-risk numbers (default: auto)
*   censormark  = Y/N show censor tick marks (default: Y)
*   ci_band     = Y/N show confidence band (default: N)
*   pval_pos    = Position of p-value: BOTTOMLEFT | BOTTOMRIGHT | TOPLEFT
*                 | TOPRIGHT | NONE (default: BOTTOMLEFT)
*   median_line = Y/N draw reference line at median survival (default: N)
*   colors      = Pipe-delimited color list (default: auto)
*   xmax        = Maximum x-axis value (default: auto)
*   xby         = X-axis tick interval (default: auto)
*   ymin        = Minimum y-axis value: 0 to 1 (default: 0)
*   title1-3    = Custom title lines (optional)
*   foot1-3     = Custom footnote lines (optional)
*   style       = ODS style (default: journal)
*   debug       = Y/N keep intermediate datasets (default: N)
*
* Output Datasets (when debug=Y):
*   _km_surv    = Survival estimates at each timepoint
*   _km_median  = Median survival with CI
*   _km_events  = Event counts by treatment
*   _km_logrank = Log-rank/Wilcoxon test results
*   _km_hr      = Hazard ratio estimates
*   _km_landmark= Landmark survival rates
*   _km_atrisk  = Number-at-risk table
*   _km_report  = Final report-ready dataset
*
* Dependencies:
*   None (self-contained; optionally uses m_counts for Big N)
*
* Usage Examples:
*   %m_km_survival(inds=adam.adtte, popds=adam.adsl, paramcd=OS);
*
*   %m_km_survival(inds=adam.adtte, popds=adam.adsl, paramcd=PFS,
*                  refgrp=Placebo, landmarks=6 12 18 24,
*                  stratvar=REGION1 ECOGBL, outfmt=PNG);
*
*   %m_km_survival(inds=adam.adtte, popds=adam.adsl, paramcd=EFS,
*                  test=BOTH, ci_band=Y, median_line=Y,
*                  title1=Figure 14.2.1, title2=KM Estimate of EFS);
*****************************************************************************/

%macro m_km_survival(
    /* Data parameters */
    inds        = ,
    popds       = ,
    subjvar     = USUBJID,
    trtvar      = TRTA,
    trtvarn     = TRTAN,
    timvar      = AVAL,
    cnsvar      = CNSR,
    cnsval      = 1,
    paramcd     = ,
    popflag     = SAFFL,
    popval      = Y,

    /* Analysis parameters */
    refgrp      = ,
    alpha       = 0.05,
    test        = LOGRANK,
    stratvar    = ,
    covars      = ,
    ties        = EFRON,
    landmarks   = ,
    timeunit    = Months,
    conftype    = LOGLOG,

    /* Output parameters */
    outdir      = ,
    outname     = km_survival,
    plot        = Y,
    table       = Y,
    plotfmt     = EMF,
    plotw       = 10,
    ploth       = 7,
    atrisk      = Y,
    atrisk_int  = ,
    censormark  = Y,
    ci_band     = N,
    pval_pos    = BOTTOMLEFT,
    median_line = N,
    colors      = ,
    xmax        = ,
    xby         = ,
    ymin        = 0,
    title1      = ,
    title2      = ,
    title3      = ,
    foot1       = ,
    foot2       = ,
    foot3       = ,
    style       = journal,
    debug       = N
);

    %local _starttime _ntrts _ntotal _nevents _ci_pct _xmax_calc _xby_calc
           _logrank_p _logrank_chi _wilcox_p _wilcox_chi _hr_est _hr_lcl 
           _hr_ucl _hr_pval _nlandmarks _i _t _errflag;

    %let _starttime = %sysfunc(datetime());
    %let _errflag = 0;
    %let test = %upcase(&test.);
    %let _ci_pct = %sysevalf((1 - &alpha.) * 100);

    %put NOTE: ================================================================;
    %put NOTE: m_km_survival v2.0 - Kaplan-Meier Survival Analysis;
    %put NOTE: Parameter: &paramcd.;
    %put NOTE: ================================================================;


    /*====================================================================
      SECTION 1: INPUT VALIDATION
    ====================================================================*/

    %if &inds. = %then %do;
        %put %str(ER)ROR: (m_km_survival) INDS is required.;
        %let _errflag = 1;
    %end;

    %if &paramcd. = %then %do;
        %put %str(ER)ROR: (m_km_survival) PARAMCD is required.;
        %let _errflag = 1;
    %end;

    %if &_errflag. = 1 %then %return;

    /* Default output directory */
    %if &outdir. = %then %let outdir = %sysfunc(pathname(work));


    /*====================================================================
      SECTION 2: PREPARE ANALYSIS DATASET
    ====================================================================*/

    proc sql noprint;
        create table _km_adata as
        select a.&subjvar., 
               a.&trtvar., 
               a.&trtvarn.,
               a.&timvar., 
               a.&cnsvar.,
               a.PARAMCD,
               a.PARAM,
               /* Derive event flag (inverse of censor) */
               case when a.&cnsvar. = &cnsval. then 0 else 1 end as _event,
               a.EVNTDESC,
               a.CNSDTDSC
        from &inds. a
        %if &popds. ne %then %do;
            inner join &popds. b 
            on a.&subjvar. = b.&subjvar.
            where b.&popflag. = "&popval."
                  and a.PARAMCD = "&paramcd."
        %end;
        %else %do;
            where a.PARAMCD = "&paramcd."
        %end;
        order by a.&trtvarn., a.&subjvar.;
    quit;

    /* Validate we have data */
    %local _nobs;
    proc sql noprint;
        select count(*) into :_nobs trimmed from _km_adata;
    quit;

    %if &_nobs. = 0 %then %do;
        %put %str(ER)ROR: (m_km_survival) No records found for PARAMCD=&paramcd.;
        %return;
    %end;

    /* Get treatment groups and counts */
    proc sql noprint;
        select count(distinct &trtvar.) into :_ntrts trimmed from _km_adata;

        create table _km_bign as
        select &trtvar., &trtvarn.,
               count(distinct &subjvar.) as bign,
               sum(_event) as nevents,
               sum(1 - _event) as ncensored
        from _km_adata
        group by &trtvar., &trtvarn.
        order by &trtvarn.;

        select sum(bign) into :_ntotal trimmed from _km_bign;
        select sum(nevents) into :_nevents trimmed from _km_bign;
    quit;

    /* Store treatment labels and Big N */
    data _null_;
        set _km_bign;
        call symputx(cats('_trtlbl', _n_), &trtvar.);
        call symputx(cats('_bign', _n_), bign);
        call symputx(cats('_nevt', _n_), nevents);
        call symputx(cats('_ncns', _n_), ncensored);
    run;

    /* Determine reference group */
    %if &refgrp. = %then %do;
        data _null_;
            set _km_bign(obs=1);
            call symputx('refgrp', &trtvar.);
        run;
    %end;

    %put NOTE: Treatment groups: &_ntrts.;
    %put NOTE: Total subjects: &_ntotal.;
    %put NOTE: Total events: &_nevents.;
    %put NOTE: Reference group: &refgrp.;


    /*====================================================================
      SECTION 3: AUTO-CALCULATE AXIS PARAMETERS
    ====================================================================*/

    %if &xmax. = %then %do;
        proc sql noprint;
            select ceil(max(&timvar.)) into :_xmax_calc trimmed from _km_adata;
        quit;
        /* Round up to nice number */
        %let _xmax_calc = %sysfunc(ceil(%sysevalf(&_xmax_calc. / 6)) * 6);
    %end;
    %else %let _xmax_calc = &xmax.;

    %if &xby. = %then %do;
        /* Auto-determine tick interval */
        %if %sysevalf(&_xmax_calc. <= 12) %then %let _xby_calc = 2;
        %else %if %sysevalf(&_xmax_calc. <= 24) %then %let _xby_calc = 3;
        %else %if %sysevalf(&_xmax_calc. <= 48) %then %let _xby_calc = 6;
        %else %if %sysevalf(&_xmax_calc. <= 120) %then %let _xby_calc = 12;
        %else %let _xby_calc = 24;
    %end;
    %else %let _xby_calc = &xby.;

    /* At-risk interval */
    %if &atrisk_int. = %then %let atrisk_int = &_xby_calc.;

    %put NOTE: X-axis: 0 to &_xmax_calc. by &_xby_calc.;


    /*====================================================================
      SECTION 4: KAPLAN-MEIER ESTIMATION (PROC LIFETEST)
    ====================================================================*/

    /* Suppress default output; capture via ODS */
    ods select none;

    ods output 
        ProductLimitEstimates = _km_surv_raw
        Quartiles             = _km_quartiles
        HomTests              = _km_homtests
        CensoredSummary       = _km_censored
        ;

    /* Also request survival at landmark timepoints */
    %local _timelist;
    %let _timelist = ;
    %if &landmarks. ne %then %do;
        %let _nlandmarks = %sysfunc(countw(&landmarks., %str( )));
        %do _i = 1 %to &_nlandmarks.;
            %let _t = %scan(&landmarks., &_i., %str( ));
            %let _timelist = &_timelist. &_t.;
        %end;
    %end;

    proc lifetest data=_km_adata 
        outsurv=_km_outsurv(rename=(survival=_surv sdf_lcl=_lcl sdf_ucl=_ucl))
        conftype=&conftype.
        alpha=&alpha.
        %if &_timelist. ne %then %do;
            timelist=&_timelist.
        %end;
        ;

        time &timvar. * &cnsvar.(&cnsval.);
        strata &trtvar. / 
            %if &test. = LOGRANK or &test. = BOTH %then %do;
                test=logrank
            %end;
            %if &test. = WILCOXON or &test. = BOTH %then %do;
                test=wilcoxon
            %end;
            ;

        /* Stratified test if stratification variables provided */
        %if &stratvar. ne %then %do;
            strata &stratvar. / group=&trtvar.
                test=logrank;
        %end;
    run;

    /* Capture timelist output if landmarks requested */
    %if &_timelist. ne %then %do;
        ods output SurvivalPlot = _km_landmark_raw;
    %end;

    ods select all;


    /*====================================================================
      SECTION 5: EXTRACT AND FORMAT RESULTS
    ====================================================================*/

    /*--- 5a. Log-Rank / Wilcoxon Test Results ---*/

    data _km_tests;
        set _km_homtests;
        length test_name $30 chi_sq $12 df $5 pval_raw 8 pval_fmt $10;

        test_name = strip(Test);
        chi_sq = strip(put(ChiSq, 10.4));
        df = strip(put(DF, 3.));
        pval_raw = ProbChiSq;

        /* Format p-value */
        if pval_raw = . then pval_fmt = '';
        else if pval_raw < 0.0001 then pval_fmt = '<0.0001';
        else if pval_raw < 0.001 then pval_fmt = strip(put(pval_raw, 7.4));
        else if pval_raw > 0.999 then pval_fmt = '>0.999';
        else pval_fmt = strip(put(pval_raw, 6.3));
    run;

    /* Store log-rank p-value for plot annotation */
    data _null_;
        set _km_tests;
        where upcase(Test) = 'LOG-RANK';
        call symputx('_logrank_p', pval_fmt);
        call symputx('_logrank_chi', strip(put(ChiSq, 8.2)));
    run;

    %if &test. = BOTH or &test. = WILCOXON %then %do;
        data _null_;
            set _km_tests;
            where upcase(Test) = 'WILCOXON';
            call symputx('_wilcox_p', pval_fmt);
            call symputx('_wilcox_chi', strip(put(ChiSq, 8.2)));
        run;
    %end;

    /*--- 5b. Median Survival with CI ---*/

    data _km_median;
        set _km_quartiles;
        where Percent = 50;
        length median_est $12 median_ci $30 median_display $50;

        if Estimate ne . then 
            median_est = strip(put(Estimate, 8.1));
        else median_est = 'NE';

        if LowerLimit ne . and UpperLimit ne . then
            median_ci = cat('(', strip(put(LowerLimit, 8.1)), ', ', 
                                 strip(put(UpperLimit, 8.1)), ')');
        else if LowerLimit ne . and UpperLimit = . then
            median_ci = cat('(', strip(put(LowerLimit, 8.1)), ', NE)');
        else if LowerLimit = . and UpperLimit ne . then
            median_ci = cat('(NE, ', strip(put(UpperLimit, 8.1)), ')');
        else median_ci = '(NE, NE)';

        median_display = catx(' ', median_est, median_ci);

        keep &trtvar. Estimate LowerLimit UpperLimit 
             median_est median_ci median_display;
    run;

    /*--- 5c. Event Summary ---*/

    data _km_events;
        set _km_bign;
        length n_display $10 events_display $10 event_rate $15;
        n_display = strip(put(bign, 8.));
        events_display = strip(put(nevents, 8.));
        event_rate = cat(strip(put(nevents, 8.)), '/', strip(put(bign, 8.)),
                         ' (', strip(put(nevents / bign * 100, 5.1)), '%)');
    run;

    /*--- 5d. Number-at-Risk Table ---*/

    /* Generate at-risk counts at each display timepoint */
    data _km_timepoints;
        do _time = 0 to &_xmax_calc. by &atrisk_int.;
            output;
        end;
    run;

    proc sql noprint;
        create table _km_atrisk as
        select b.&trtvar., b.&trtvarn., a._time,
               sum(case when b.&timvar. >= a._time then 1 else 0 end) as n_atrisk
        from _km_timepoints a
        cross join _km_adata b
        group by b.&trtvar., b.&trtvarn., a._time
        order by b.&trtvarn., a._time;
    quit;

    /* Transpose at-risk for display */
    proc transpose data=_km_atrisk out=_km_atrisk_t(drop=_name_) prefix=t;
        by &trtvar. &trtvarn.;
        id _time;
        var n_atrisk;
    run;


    /*====================================================================
      SECTION 6: COX PROPORTIONAL HAZARDS MODEL
    ====================================================================*/

    %if &_ntrts. >= 2 %then %do;

        ods select none;
        ods output ParameterEstimates = _km_cox_pe;

        proc phreg data=_km_adata;
            class &trtvar.(ref="&refgrp.") 
                  %if &stratvar. ne %then %do; / order=internal %end; ;
            model &timvar. * &cnsvar.(&cnsval.) = &trtvar. &covars.
                / ties=&ties. risklimits alpha=&alpha.;
            %if &stratvar. ne %then %do;
                strata &stratvar.;
            %end;
        run;

        ods select all;

        /* Extract hazard ratios */
        data _km_hr;
            set _km_cox_pe;
            where upcase(Parameter) = "%upcase(&trtvar.)";
            
            length hr_est $12 hr_ci $30 hr_display $50 hr_pval $10;

            HR = exp(Estimate);
            HR_LCL = exp(Estimate - %sysfunc(quantile(NORMAL, %sysevalf(1 - &alpha./2))) * StdErr);
            HR_UCL = exp(Estimate + %sysfunc(quantile(NORMAL, %sysevalf(1 - &alpha./2))) * StdErr);

            hr_est = strip(put(HR, 6.3));
            hr_ci = cat('(', strip(put(HR_LCL, 6.3)), ', ', 
                              strip(put(HR_UCL, 6.3)), ')');
            hr_display = catx(' ', hr_est, hr_ci);

            /* P-value */
            if ProbChiSq = . then hr_pval = '';
            else if ProbChiSq < 0.0001 then hr_pval = '<0.0001';
            else if ProbChiSq < 0.001 then hr_pval = strip(put(ProbChiSq, 7.4));
            else hr_pval = strip(put(ProbChiSq, 6.3));

            keep ClassVal0 HR HR_LCL HR_UCL hr_est hr_ci hr_display hr_pval
                 Estimate StdErr ProbChiSq;
        run;

        /* Store HR for plot annotation */
        data _null_;
            set _km_hr(obs=1);
            call symputx('_hr_est', hr_est);
            call symputx('_hr_lcl', strip(put(HR_LCL, 6.3)));
            call symputx('_hr_ucl', strip(put(HR_UCL, 6.3)));
            call symputx('_hr_pval', hr_pval);
        run;

        %put NOTE: HR = &_hr_est. (&_hr_lcl., &_hr_ucl.), p = &_hr_pval.;
    %end;


    /*====================================================================
      SECTION 7: LANDMARK ANALYSIS
    ====================================================================*/

    %if &landmarks. ne %then %do;

        /* Compute survival rate at each landmark using KM estimates */
        %do _i = 1 %to &_nlandmarks.;
            %let _t = %scan(&landmarks., &_i., %str( ));

            proc sql noprint;
                create table _km_lm_&_i. as
                select &trtvar., &trtvarn.,
                       &_t. as landmark,
                       /* Get the survival estimate just at or before the landmark */
                       max(case when &timvar. <= &_t. then _surv else . end) as surv_rate,
                       max(case when &timvar. <= &_t. then _lcl else . end) as surv_lcl,
                       max(case when &timvar. <= &_t. then _ucl else . end) as surv_ucl,
                       count(distinct case when &timvar. >= &_t. then &subjvar. end) as n_atrisk
                from _km_outsurv
                natural join _km_adata
                group by &trtvar., &trtvarn.;
            quit;
        %end;

        /* Alternative approach using PROC LIFETEST timelist */
        /* Re-run with timelist for precise estimates */
        ods select none;
        ods output SurvivalPlot = _km_lm_precise;

        proc lifetest data=_km_adata 
            conftype=&conftype. alpha=&alpha.
            timelist=&_timelist.;
            time &timvar. * &cnsvar.(&cnsval.);
            strata &trtvar.;
        run;

        ods select all;

        data _km_landmark;
            set _km_lm_precise;
            length surv_display $50;

            /* Survival rate as percentage */
            if Survival ne . then do;
                surv_pct = Survival * 100;
                surv_lcl_pct = SDF_LCL * 100;
                surv_ucl_pct = SDF_UCL * 100;

                surv_display = cat(strip(put(surv_pct, 5.1)), '% (',
                                   strip(put(surv_lcl_pct, 5.1)), ', ',
                                   strip(put(surv_ucl_pct, 5.1)), ')');
            end;
            else surv_display = 'NE';
        run;

        %put NOTE: Landmark analysis completed for timepoints: &landmarks.;
    %end;


    /*====================================================================
      SECTION 8: KAPLAN-MEIER PLOT
    ====================================================================*/

    %if %upcase(&plot.) = Y %then %do;

        /*--- Set colors ---*/
        %local _c1 _c2 _c3 _c4 _c5;
        %if &colors. ne %then %do;
            %let _c1 = %scan(&colors., 1, |);
            %let _c2 = %scan(&colors., 2, |);
            %let _c3 = %scan(&colors., 3, |);
            %let _c4 = %scan(&colors., 4, |);
            %let _c5 = %scan(&colors., 5, |);
        %end;
        %else %do;
            %let _c1 = cx1F77B4;  /* Blue */
            %let _c2 = cxFF7F0E;  /* Orange */
            %let _c3 = cx2CA02C;  /* Green */
            %let _c4 = cxD62728;  /* Red */
            %let _c5 = cx9467BD;  /* Purple */
        %end;

        /* Define attribute map for consistent colors */
        data _km_attrmap;
            length value $60 linecolor $20 markersymbol $20 linepattern $10;
            id = 'trtcolors';
            %do _i = 1 %to &_ntrts.;
                value = "&&_trtlbl&_i.";
                linecolor = "&&_c&_i.";
                markercolor = "&&_c&_i.";
                markersymbol = 'circle';
                linepattern = 'solid';
                output;
            %end;
        run;

        /*--- Prepare survival curve data ---*/
        data _km_plotdata;
            set _km_outsurv;
            /* Keep only non-missing survival estimates */
            if _surv ne .;
            /* Cap at xmax */
            if &timvar. <= &_xmax_calc.;
        run;

        /* Add time=0, survival=1.0 for each treatment group */
        proc sql noprint;
            create table _km_origin as
            select distinct &trtvar., &trtvarn., 
                   0 as &timvar., 1.0 as _surv, . as _lcl, . as _ucl,
                   0 as _censor_
            from _km_plotdata;
        quit;

        data _km_plotdata;
            set _km_origin _km_plotdata;
        run;

        proc sort data=_km_plotdata; 
            by &trtvarn. &timvar.; 
        run;

        /* Separate censor marks */
        data _km_censor;
            set _km_outsurv;
            where _censor_ = 1 and _surv ne . and &timvar. <= &_xmax_calc.;
        run;

        /*--- Build annotation dataset for p-value and HR ---*/
        data _km_anno;
            length label $200 function $20 x1space $20 y1space $20 
                   anchor $10 textsize 8 textweight $10;
            
            function = 'text';
            x1space = 'graphpercent';
            y1space = 'graphpercent';
            width = 100;
            widthunit = 'percent';
            textsize = 8;
            textweight = 'normal';

            /* Build annotation text */
            %if &_ntrts. >= 2 %then %do;
                label = "HR = &_hr_est. (%sysfunc(putn(&_ci_pct., 3.0))% CI: &_hr_lcl., &_hr_ucl.)";

                %if %upcase(&pval_pos.) = BOTTOMLEFT %then %do;
                    x1 = 5; y1 = 18; anchor = 'left';
                %end;
                %else %if %upcase(&pval_pos.) = BOTTOMRIGHT %then %do;
                    x1 = 95; y1 = 18; anchor = 'right';
                %end;
                %else %if %upcase(&pval_pos.) = TOPLEFT %then %do;
                    x1 = 5; y1 = 95; anchor = 'left';
                %end;
                %else %if %upcase(&pval_pos.) = TOPRIGHT %then %do;
                    x1 = 95; y1 = 95; anchor = 'right';
                %end;

                output;

                /* Log-rank p-value line */
                y1 = y1 - 4;
                label = "Log-rank p = &_logrank_p.";
                output;

                %if &test. = BOTH %then %do;
                    y1 = y1 - 4;
                    label = "Wilcoxon p = &_wilcox_p.";
                    output;
                %end;
            %end;
        run;

        /*--- Generate the KM plot ---*/
        options orientation=landscape nodate nonumber;
        ods escapechar='^';

        %if &outdir. ne %sysfunc(pathname(work)) %then %do;
            ods rtf file="&outdir./&outname..rtf" style=&style. bodytitle;
        %end;

        ods graphics on / reset 
            width=&plotw.in height=&ploth.in 
            imagename="&outname." 
            imagefmt=&plotfmt.
            border=off antialias=on;

        /* Custom titles */
        %if &title1. ne %then %do; title1 j=c "&title1."; %end;
        %if &title2. ne %then %do; title2 j=c "&title2."; %end;
        %if &title3. ne %then %do; title3 j=c "&title3."; %end;

        proc sgplot data=_km_plotdata noautolegend noborder
            dattrmap=_km_attrmap
            %if %upcase(&pval_pos.) ne NONE and &_ntrts. >= 2 %then %do;
                sganno=_km_anno
            %end;
            ;

            /*--- Step plot for survival curves ---*/
            step x=&timvar. y=_surv / group=&trtvar.
                lineattrs=(thickness=2px)
                attrid=trtcolors
                name="km";

            /*--- Confidence bands ---*/
            %if %upcase(&ci_band.) = Y %then %do;
                band x=&timvar. lower=_lcl upper=_ucl / group=&trtvar.
                    transparency=0.85
                    attrid=trtcolors;
            %end;

            /*--- Censor marks ---*/
            %if %upcase(&censormark.) = Y %then %do;
                scatter x=&timvar. y=_surv / data=_km_censor
                    group=&trtvar.
                    markerattrs=(symbol=plus size=7px)
                    attrid=trtcolors;
            %end;

            /*--- Median survival reference line ---*/
            %if %upcase(&median_line.) = Y %then %do;
                refline 0.5 / axis=y 
                    lineattrs=(pattern=shortdash color=gray thickness=0.5px)
                    transparency=0.5;
            %end;

            /*--- Axes ---*/
            xaxis label="Time (&timeunit.)"
                  values=(0 to &_xmax_calc. by &_xby_calc.)
                  offsetmin=0.02 offsetmax=0.02
                  labelattrs=(size=10pt weight=bold)
                  valueattrs=(size=9pt);

            yaxis label="Survival Probability"
                  values=(&ymin. to 1.0 by 0.2)
                  offsetmin=0.02 offsetmax=0.02
                  grid gridattrs=(pattern=dot color=lightgray)
                  labelattrs=(size=10pt weight=bold)
                  valueattrs=(size=9pt);

            /*--- Legend ---*/
            keylegend "km" / 
                location=inside position=topright 
                across=1 
                opaque
                border
                titleattrs=(size=9pt weight=bold)
                valueattrs=(size=8pt);

        run;

        ods graphics off;

        %if &outdir. ne %sysfunc(pathname(work)) %then %do;
            ods rtf close;
        %end;

        title; footnote;

        %put NOTE: KM plot saved to &outdir./&outname..&plotfmt.;
    %end;


    /*====================================================================
      SECTION 9: NUMBER-AT-RISK TABLE (Standalone)
    ====================================================================*/

    %if %upcase(&atrisk.) = Y %then %do;

        /* Format for display below KM curve */
        proc sort data=_km_atrisk; by &trtvarn. _time; run;

        proc transpose data=_km_atrisk out=_km_atrisk_wide(drop=_name_) prefix=T_;
            by &trtvar. &trtvarn.;
            id _time;
            var n_atrisk;
        run;

        %put NOTE: Number-at-risk table generated.;
    %end;


    /*====================================================================
      SECTION 10: SUMMARY TABLE
    ====================================================================*/

    %if %upcase(&table.) = Y %then %do;

        /* Build comprehensive report dataset */
        data _km_report;
            length section $60 stat_label $60 
                   %do _i = 1 %to &_ntrts.; col&_i. $60 %end;
                   ord 8;

            /*--- Row 1: N ---*/
            section = 'Analysis Population';
            stat_label = 'N';
            ord = 1;
            %do _i = 1 %to &_ntrts.;
                col&_i. = "&&_bign&_i.";
            %end;
            output;

            /*--- Row 2: Events ---*/
            stat_label = 'Events, n (%)';
            ord = 2;
            %do _i = 1 %to &_ntrts.;
                col&_i. = cat("&&_nevt&_i.", ' (',
                    strip(put(&&_nevt&_i. / &&_bign&_i. * 100, 5.1)), ')');
            %end;
            output;

            /*--- Row 3: Censored ---*/
            stat_label = 'Censored, n (%)';
            ord = 3;
            %do _i = 1 %to &_ntrts.;
                col&_i. = cat("&&_ncns&_i.", ' (',
                    strip(put(&&_ncns&_i. / &&_bign&_i. * 100, 5.1)), ')');
            %end;
            output;
        run;

        /* Add median survival */
        proc sql noprint;
            create table _km_median_row as
            select 'Median Survival' as section length=60,
                   cat("Median (%sysfunc(putn(&_ci_pct., 3.0))% CI), &timeunit.") 
                       as stat_label length=60,
                   10 as ord
            from _km_median(obs=1);
        quit;

        data _km_median_row;
            set _km_median_row;
            length %do _i = 1 %to &_ntrts.; col&_i. $60 %end;;
        run;

        /* Merge median values */
        data _null_;
            set _km_median;
            _n = _n_;
            call symputx(cats('_med_disp', _n), median_display);
        run;

        data _km_median_row;
            set _km_median_row;
            %do _i = 1 %to &_ntrts.;
                col&_i. = "&&_med_disp&_i.";
            %end;
        run;

        /* Add HR row (if applicable) */
        %if &_ntrts. >= 2 %then %do;
            data _km_hr_row;
                length section $60 stat_label $60 
                       %do _i = 1 %to &_ntrts.; col&_i. $60 %end;
                       ord 8;

                section = 'Hazard Ratio';
                stat_label = "HR (%sysfunc(putn(&_ci_pct., 3.0))% CI)";
                ord = 20;
                col1 = ''; /* Reference group */
                col2 = "&_hr_est. (&_hr_lcl., &_hr_ucl.)";
                output;

                stat_label = 'p-value (Cox)';
                ord = 21;
                col1 = '';
                col2 = "&_hr_pval.";
                output;
            run;
        %end;

        /* Add test results rows */
        data _km_test_rows;
            length section $60 stat_label $60 
                   %do _i = 1 %to &_ntrts.; col&_i. $60 %end;
                   ord 8;

            section = 'Statistical Tests';

            stat_label = 'Log-rank p-value';
            ord = 30;
            col1 = "&_logrank_p.";
            output;

            %if &test. = BOTH %then %do;
                stat_label = 'Wilcoxon p-value';
                ord = 31;
                col1 = "&_wilcox_p.";
                output;
            %end;
        run;

        /* Add landmark rows */
        %if &landmarks. ne %then %do;
            data _km_landmark_rows;
                length section $60 stat_label $60 
                       %do _i = 1 %to &_ntrts.; col&_i. $60 %end;
                       ord 8;

                section = "Landmark Analysis";
                set _km_landmark;

                stat_label = cat(strip(put(Timelist, best.)), "-&timeunit. rate (", 
                                 "%sysfunc(putn(&_ci_pct., 3.0))% CI)");
                ord = 40 + _n_;

                /* Map to columns by treatment */
                /* This requires knowledge of treatment ordering */
            run;
        %end;

        /* Combine all rows */
        data _km_report_all;
            set _km_report 
                _km_median_row
                %if &_ntrts. >= 2 %then %do;
                    _km_hr_row
                %end;
                _km_test_rows
                %if &landmarks. ne %then %do;
                    /* _km_landmark_rows */
                %end;
                ;
        run;

        proc sort data=_km_report_all; by ord; run;

        /*--- Generate summary table output ---*/
        %if &outdir. ne %sysfunc(pathname(work)) %then %do;
            ods rtf file="&outdir./&outname._table.rtf" style=&style. bodytitle;
        %end;

        options orientation=landscape nodate nonumber;

        %if &title1. ne %then %do; title1 j=c "&title1. - Summary"; %end;
        %else %do; title1 j=c "Kaplan-Meier Summary: &paramcd."; %end;

        proc report data=_km_report_all nowd split='~'
            style(report)=[outputwidth=9in font_size=9pt]
            style(header)=[just=center fontweight=bold 
                           borderbottomcolor=black borderbottomwidth=1pt font_size=9pt];

            columns ord section stat_label 
                %do _i = 1 %to &_ntrts.; col&_i. %end;;

            define ord        / order noprint;
            define section    / order '' style(column)=[width=1.5in fontweight=bold] noprint;
            define stat_label / display 'Statistic' style(column)=[width=2.5in];
            %do _i = 1 %to &_ntrts.;
                define col&_i. / display "&&_trtlbl&_i.~(N=&&_bign&_i.)" 
                    style(column)=[width=1.8in just=center];
            %end;

            compute before section / style=[fontweight=bold bordertopcolor=lightgray 
                                            bordertopwidth=0.5pt];
                line section $60.;
            endcomp;

        run;

        /* Footnotes */
        footnote1 j=l "CI = Confidence Interval; HR = Hazard Ratio; NE = Not Estimable";
        %if &_ntrts. >= 2 %then %do;
            footnote2 j=l "HR < 1 favors &&_trtlbl2.. Reference: &refgrp.";
        %end;
        footnote3 j=l "Kaplan-Meier method with &conftype. confidence intervals (alpha=&alpha.).";
        %if &stratvar. ne %then %do;
            footnote4 j=l "Stratified by: &stratvar.";
        %end;
        %if &covars. ne %then %do;
            footnote5 j=l "Cox model covariates: &covars. | Ties: &ties.";
        %end;

        %if &foot1. ne %then %do; footnote6 j=l "&foot1."; %end;
        %if &foot2. ne %then %do; footnote7 j=l "&foot2."; %end;
        %if &foot3. ne %then %do; footnote8 j=l "&foot3."; %end;

        %if &outdir. ne %sysfunc(pathname(work)) %then %do;
            ods rtf close;
        %end;

        title; footnote;

        %put NOTE: Summary table saved to &outdir./&outname._table.rtf;
    %end;


    /*====================================================================
      SECTION 11: CLEANUP
    ====================================================================*/

    %if %upcase(&debug.) ne Y %then %do;
        proc datasets lib=work nolist;
            delete _km_adata _km_bign _km_surv_raw _km_outsurv _km_quartiles 
                   _km_homtests _km_censored _km_tests _km_median
                   _km_events _km_atrisk _km_atrisk_t _km_atrisk_wide
                   _km_cox_pe _km_hr _km_plotdata _km_origin _km_censor
                   _km_attrmap _km_anno _km_timepoints
                   _km_report _km_median_row _km_hr_row _km_test_rows
                   _km_report_all
                   _km_lm_: _km_landmark:
                   ;
        quit;
    %end;
    %else %do;
        %put NOTE: Debug mode ON - intermediate datasets retained in WORK.;
    %end;


    /*====================================================================
      SECTION 12: FINAL LOG SUMMARY
    ====================================================================*/

    %put ;
    %put NOTE: ================================================================;
    %put NOTE: m_km_survival COMPLETE;
    %put NOTE: ================================================================;
    %put NOTE: Parameter:      &paramcd.;
    %put NOTE: Subjects:       &_ntotal.;
    %put NOTE: Events:         &_nevents.;
    %put NOTE: Treatment Arms: &_ntrts.;
    %do _i = 1 %to &_ntrts.;
        %put NOTE:   &&_trtlbl&_i.: N=&&_bign&_i. Events=&&_nevt&_i.;
    %end;
    %if &_ntrts. >= 2 %then %do;
        %put NOTE: HR:             &_hr_est. (&_hr_lcl., &_hr_ucl.);
        %put NOTE: Log-rank p:     &_logrank_p.;
        %if &test. = BOTH %then %put NOTE: Wilcoxon p:     &_wilcox_p.;
    %end;
    %put NOTE: Elapsed: %sysfunc(putn(%sysevalf(%sysfunc(datetime()) - &_starttime.), time8.));
    %put NOTE: ================================================================;

%mend m_km_survival;


/*****************************************************************************
* COMPANION: Macro for multi-endpoint KM analysis
* Runs m_km_survival for multiple PARAMCD values in a single call
*
* Usage:
*   %m_km_multi(inds=adam.adtte, popds=adam.adsl,
*               params=OS PFS EFS DFS,
*               outdir=/study/output);
*****************************************************************************/

%macro m_km_multi(
    inds    = ,
    popds   = ,
    params  = ,
    outdir  = ,
    refgrp  = ,
    landmarks = ,
    debug   = N
);

    %local _np _i _p;
    %let _np = %sysfunc(countw(&params., %str( )));

    %put NOTE: ================================================================;
    %put NOTE: m_km_multi - Running KM for &_np. endpoints;
    %put NOTE: Endpoints: &params.;
    %put NOTE: ================================================================;

    %do _i = 1 %to &_np.;
        %let _p = %scan(&params., &_i., %str( ));

        %put NOTE: ------------------------------------------------;
        %put NOTE: Processing endpoint &_i. of &_np.: &_p.;
        %put NOTE: ------------------------------------------------;

        %m_km_survival(
            inds      = &inds.,
            popds     = &popds.,
            paramcd   = &_p.,
            outdir    = &outdir.,
            outname   = km_&_p.,
            refgrp    = &refgrp.,
            landmarks = &landmarks.,
            title1    = Kaplan-Meier Estimate of &_p.,
            debug     = &debug.
        );
    %end;

    %put NOTE: ================================================================;
    %put NOTE: m_km_multi complete. &_np. endpoints processed.;
    %put NOTE: ================================================================;

%mend m_km_multi;
