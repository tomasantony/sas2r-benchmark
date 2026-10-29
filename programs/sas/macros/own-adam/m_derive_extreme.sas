/*****************************************************************************
* Program:    m_derive_extreme.sas
* Purpose:    Macros for deriving extreme/summary records (LOCF, WOCF, etc.)
* Standard:   CDISC ADaM IG 1.3
*****************************************************************************/

/*===========================================================================
  %derive_locf - Last Observation Carried Forward
===========================================================================*/
%macro derive_locf(in_ds=, out_ds=, by_vars=USUBJID PARAMCD,
                   date_var=ADT, value_var=AVAL, target_visits=);
  /* target_visits: visits where LOCF should be applied if missing */

  proc sort data=&in_ds. out=_locf_temp;
    by &by_vars. &date_var.;
  run;

  data _locf_temp;
    set _locf_temp;
    by &by_vars.;
    retain _last_aval _last_adt;

    if first.PARAMCD then do;
      _last_aval = .;
      _last_adt = .;
    end;

    if not missing(&value_var.) then do;
      _last_aval = &value_var.;
      _last_adt = &date_var.;
    end;
  run;

  /* Create LOCF records for target visits */
  %if %length(&target_visits.) > 0 %then %do;
    data &out_ds.;
      set _locf_temp;
      length DTYPE $20;

      /* If value is missing at target visit, use LOCF */
      if missing(&value_var.) and _last_aval ne . then do;
        /* Check if this is a target visit - implementation depends on structure */
        &value_var. = _last_aval;
        DTYPE = 'LOCF';
      end;
      drop _last_aval _last_adt;
    run;
  %end;
  %else %do;
    data &out_ds.;
      set _locf_temp;
      drop _last_aval _last_adt;
    run;
  %end;

  proc delete data=_locf_temp; run;
%mend derive_locf;

/*===========================================================================
  %derive_wocf - Worst Observation Carried Forward
===========================================================================*/
%macro derive_wocf(in_ds=, out_ds=, by_vars=USUBJID PARAMCD,
                   value_var=AVAL, direction=HIGH);
  /* direction: HIGH = higher is worse, LOW = lower is worse */

  proc sort data=&in_ds. out=_wocf_temp;
    by &by_vars.;
  run;

  data _wocf_temp;
    set _wocf_temp;
    by &by_vars.;
    retain _worst_aval;

    if first.PARAMCD then _worst_aval = .;

    if not missing(&value_var.) then do;
      %if %upcase(&direction.) = HIGH %then %do;
        if _worst_aval = . or &value_var. > _worst_aval then
          _worst_aval = &value_var.;
      %end;
      %else %do;
        if _worst_aval = . or &value_var. < _worst_aval then
          _worst_aval = &value_var.;
      %end;
    end;
  run;

  data &out_ds.;
    set _wocf_temp;
    WORST_AVAL = _worst_aval;
    drop _worst_aval;
  run;

  proc delete data=_wocf_temp; run;
%mend derive_wocf;

/*===========================================================================
  %derive_extreme_record - Create MIN/MAX/MEAN summary records
===========================================================================*/
%macro derive_extreme_record(in_ds=, out_ds=, by_vars=USUBJID PARAMCD,
                              value_var=AVAL, stat=MAX, dtype_val=MAXIMUM,
                              avisit_val=Maximum Post-Baseline);
  /* stat: MAX, MIN, MEAN, MEDIAN, LAST, FIRST */

  proc sort data=&in_ds. out=_extreme_temp;
    by &by_vars.;
  run;

  %if %upcase(&stat.) = MAX %then %do;
    proc means data=_extreme_temp noprint;
      by &by_vars.;
      var &value_var.;
      output out=_extreme_rec(drop=_type_ _freq_) max=AVAL;
    run;
  %end;
  %else %if %upcase(&stat.) = MIN %then %do;
    proc means data=_extreme_temp noprint;
      by &by_vars.;
      var &value_var.;
      output out=_extreme_rec(drop=_type_ _freq_) min=AVAL;
    run;
  %end;
  %else %if %upcase(&stat.) = MEAN %then %do;
    proc means data=_extreme_temp noprint;
      by &by_vars.;
      var &value_var.;
      output out=_extreme_rec(drop=_type_ _freq_) mean=AVAL;
    run;
  %end;
  %else %if %upcase(&stat.) = LAST %then %do;
    data _extreme_rec;
      set _extreme_temp;
      by &by_vars.;
      if last.PARAMCD;
      keep &by_vars. &value_var.;
      rename &value_var. = AVAL;
    run;
  %end;

  data &out_ds.;
    set _extreme_rec;
    length DTYPE $20 AVISIT $40;
    DTYPE = "&dtype_val.";
    AVISIT = "&avisit_val.";
  run;

  proc delete data=_extreme_temp _extreme_rec; run;
%mend derive_extreme_record;

/*===========================================================================
  %derive_shift - Derive shift from baseline categories
===========================================================================*/
%macro derive_shift(ds=, base_cat=BNRIND, post_cat=ANRIND, shift_var=SHIFT);
  data &ds.;
    set &ds.;
    length &shift_var. $40;

    if not missing(&base_cat.) and not missing(&post_cat.) then
      &shift_var. = catx(' to ', &base_cat., &post_cat.);
  run;
%mend derive_shift;

/*===========================================================================
  %derive_crit_flag - Derive criterion flag based on threshold
===========================================================================*/
%macro derive_crit_flag(ds=, value_var=AVAL, threshold=, direction=GE,
                        flag_var=CRIT1FL, crit_desc=CRIT1);
  /* direction: GE, GT, LE, LT, EQ */

  data &ds.;
    set &ds.;
    length &flag_var. $1 &crit_desc. $200;

    &crit_desc. = "&value_var. &direction. &threshold.";

    if not missing(&value_var.) then do;
      %if %upcase(&direction.) = GE %then %do;
        if &value_var. >= &threshold. then &flag_var. = 'Y';
        else &flag_var. = 'N';
      %end;
      %else %if %upcase(&direction.) = GT %then %do;
        if &value_var. > &threshold. then &flag_var. = 'Y';
        else &flag_var. = 'N';
      %end;
      %else %if %upcase(&direction.) = LE %then %do;
        if &value_var. <= &threshold. then &flag_var. = 'Y';
        else &flag_var. = 'N';
      %end;
      %else %if %upcase(&direction.) = LT %then %do;
        if &value_var. < &threshold. then &flag_var. = 'Y';
        else &flag_var. = 'N';
      %end;
    end;
  run;
%mend derive_crit_flag;

/*===========================================================================
  %derive_avalcat - Derive AVAL categories
===========================================================================*/
%macro derive_avalcat(ds=, value_var=AVAL, cat_var=AVALCAT1,
                      breaks=, labels=);
  /* breaks: numeric cutpoints (comma-separated)
     labels: category labels (|pipe-separated)
     Example: breaks=0,10,20 labels=Low|Medium|High */

  data &ds.;
    set &ds.;
    length &cat_var. $50;

    if not missing(&value_var.) then do;
      %let n_breaks = %sysfunc(countw(&breaks., %str(,)));
      %let n_labels = %sysfunc(countw(&labels., |));

      %do i = 1 %to &n_breaks.;
        %let brk = %scan(&breaks., &i., %str(,));
        %let lbl = %scan(&labels., &i., |);

        %if &i. = 1 %then %do;
          if &value_var. < &brk. then &cat_var. = "&lbl.";
        %end;
        %else %do;
          %let prev_brk = %scan(&breaks., %eval(&i.-1), %str(,));
          else if &value_var. >= &prev_brk. and &value_var. < &brk. then
            &cat_var. = "&lbl.";
        %end;
      %end;

      /* Last category (>= last break) */
      %let last_lbl = %scan(&labels., %eval(&n_breaks.+1), |);
      %let last_brk = %scan(&breaks., &n_breaks., %str(,));
      else if &value_var. >= &last_brk. then &cat_var. = "&last_lbl.";
    end;
  run;
%mend derive_avalcat;
