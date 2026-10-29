/*****************************************************************************
* Program:    m_derive_tte.sas
* Purpose:    Macros for deriving Time-to-Event (TTE) analysis variables
* Standard:   CDISC ADaM IG 1.3 (ADTTE)
*****************************************************************************/

/*===========================================================================
  %derive_tte - Derive time-to-event variables (AVAL, CNSR, EVNTDESC, etc.)
===========================================================================*/
%macro derive_tte(in_ds=, out_ds=, start_var=TRTSDT, event_var=, event_dt=,
                  censor_dt=, paramcd=, param=, event_desc=);
  data &out_ds.;
    set &in_ds.;
    length PARAMCD $8 PARAM $200 EVNTDESC $200 CNSDTDSC $200;

    PARAMCD = "&paramcd.";
    PARAM = "&param.";

    /* Determine event or censoring */
    if not missing(&event_dt.) and &event_var. = 1 then do;
      /* Event occurred */
      ADT = &event_dt.;
      CNSR = 0;
      EVNTDESC = "&event_desc.";
      CNSDTDSC = '';
    end;
    else if not missing(&censor_dt.) then do;
      /* Censored */
      ADT = &censor_dt.;
      CNSR = 1;
      EVNTDESC = '';
      CNSDTDSC = 'Censored';
    end;

    /* Calculate AVAL (time in days) */
    if not missing(ADT) and not missing(&start_var.) then do;
      AVAL = ADT - &start_var. + 1;
      if AVAL < 1 then AVAL = 1;
    end;

    /* Start date reference */
    STARTDT = &start_var.;
    format ADT STARTDT date9.;
  run;
%mend derive_tte;

/*===========================================================================
  %derive_tte_multi - Derive TTE from multiple potential event sources
===========================================================================*/
%macro derive_tte_multi(in_ds=, out_ds=, start_var=TRTSDT,
                        event_list=, /* event_flag|event_date|description; ... */
                        censor_var=, censor_dt=, censor_desc=,
                        paramcd=, param=);
  data &out_ds.;
    set &in_ds.;
    length PARAMCD $8 PARAM $200 EVNTDESC $200 CNSDTDSC $200;
    length _event_found 8 _earliest_dt 8;

    PARAMCD = "&paramcd.";
    PARAM = "&param.";

    _event_found = 0;
    _earliest_dt = .;

    /* Check each potential event source - take earliest */
    %let i = 1;
    %let event = %scan(&event_list., &i., ;);
    %do %while(%length(&event.) > 0);
      %let ev_flag = %scan(&event., 1, |);
      %let ev_dt = %scan(&event., 2, |);
      %let ev_desc = %scan(&event., 3, |);

      if &ev_flag. = 1 and not missing(&ev_dt.) then do;
        if _event_found = 0 or &ev_dt. < _earliest_dt then do;
          _earliest_dt = &ev_dt.;
          EVNTDESC = "&ev_desc.";
          _event_found = 1;
        end;
      end;

      %let i = %eval(&i. + 1);
      %let event = %scan(&event., &i., ;);
    %end;

    /* Set event or censor */
    if _event_found = 1 then do;
      ADT = _earliest_dt;
      CNSR = 0;
      CNSDTDSC = '';
    end;
    else if not missing(&censor_dt.) then do;
      ADT = &censor_dt.;
      CNSR = 1;
      EVNTDESC = '';
      CNSDTDSC = "&censor_desc.";
    end;

    /* Calculate AVAL */
    if not missing(ADT) and not missing(&start_var.) then do;
      AVAL = ADT - &start_var. + 1;
      if AVAL < 1 then AVAL = 1;
    end;

    STARTDT = &start_var.;
    format ADT STARTDT date9.;
    drop _event_found _earliest_dt;
  run;
%mend derive_tte_multi;

/*===========================================================================
  %derive_cnsr_desc - Derive censoring descriptions
===========================================================================*/
%macro derive_cnsr_desc(ds=, cnsr_var=CNSR, reason_var=);
  data &ds.;
    set &ds.;
    length CNSDTDSC $200;

    if &cnsr_var. = 1 then do;
      %if %length(&reason_var.) > 0 %then %do;
        if not missing(&reason_var.) then CNSDTDSC = &reason_var.;
        else CNSDTDSC = 'Censored - No event';
      %end;
      %else %do;
        CNSDTDSC = 'Censored';
      %end;
    end;
  run;
%mend derive_cnsr_desc;

/*===========================================================================
  %derive_aval_months - Convert AVAL from days to months
===========================================================================*/
%macro derive_aval_months(ds=, in_var=AVAL, out_var=AVAL_M);
  data &ds.;
    set &ds.;
    if not missing(&in_var.) then
      &out_var. = &in_var. / 30.4375; /* Average days per month */
  run;
%mend derive_aval_months;

/*===========================================================================
  %derive_srcseq - Derive source sequence for traceability
===========================================================================*/
%macro derive_srcseq(ds=, src_ds=, src_var=, src_seq=);
  /* Placeholder for source traceability */
  data &ds.;
    set &ds.;
    length SRCDOM $8 SRCVAR $40 SRCSEQ 8;
    SRCDOM = "&src_ds.";
    SRCVAR = "&src_var.";
    /* SRCSEQ would be derived from source dataset */
  run;
%mend derive_srcseq;

/*===========================================================================
  %create_adtte_shell - Create empty ADTTE structure
===========================================================================*/
%macro create_adtte_shell(out_ds=adtte_shell);
  data &out_ds.;
    length
      STUDYID $12 USUBJID $40 SUBJID $20
      SITEID $10 TRTP $40 TRTPN 8 TRTA $40 TRTAN 8
      AGE 8 AGEU $10 SEX $1 RACE $50
      PARAMCD $8 PARAM $200 PARAMN 8
      AVAL 8 AVALU $20 CNSR 8
      ADT 8 STARTDT 8 ADY 8
      EVNTDESC $200 CNSDTDSC $200
      SRCDOM $8 SRCVAR $40 SRCSEQ 8
      ;
    format ADT STARTDT date9.;
    stop;
  run;
%mend create_adtte_shell;
