/*****************************************************************************
* Program:    m_derive_param.sas
* Purpose:    Macros for deriving PARAM, PARAMCD, PARAMN, PARCAT variables
* Standard:   CDISC ADaM IG 1.3
*****************************************************************************/

/*===========================================================================
  %create_param_lookup - Create parameter lookup dataset from metadata
===========================================================================*/
%macro create_param_lookup(out_ds=param_lookup, metadata=);
  /* metadata format: PARAMCD|PARAM|PARAMN|PARCAT1 (pipe-delim, semicolon between)
     Example: SYSBP|Systolic Blood Pressure|1|VITAL SIGNS */

  data &out_ds.;
    length PARAMCD $8 PARAM $200 PARAMN 8 PARCAT1 $50;
    %let i = 1;
    %let param = %scan(&metadata., &i., ;);
    %do %while(%length(&param.) > 0);
      PARAMCD = "%scan(&param., 1, |)";
      PARAM = "%scan(&param., 2, |)";
      PARAMN = %scan(&param., 3, |);
      PARCAT1 = "%scan(&param., 4, |)";
      output;
      %let i = %eval(&i. + 1);
      %let param = %scan(&metadata., &i., ;);
    %end;
  run;
%mend create_param_lookup;

/*===========================================================================
  %assign_paramn - Assign PARAMN based on PARAMCD order
===========================================================================*/
%macro assign_paramn(ds=, by_var=PARAMCD);
  proc sql noprint;
    select distinct &by_var. into :params separated by '|'
    from &ds.
    order by &by_var.;
  quit;

  data &ds.;
    set &ds.;
    %let i = 1;
    %let p = %scan(&params., &i., |);
    %do %while(%length(&p.) > 0);
      if &by_var. = "&p." then PARAMN = &i.;
      %let i = %eval(&i. + 1);
      %let p = %scan(&params., &i., |);
    %end;
  run;
%mend assign_paramn;

/*===========================================================================
  %derive_param_exist - Derive existence parameters (Y/N flags to numeric)
===========================================================================*/
%macro derive_param_exist(in_ds=, out_ds=, flag_var=, paramcd=, param=,
                          by_vars=USUBJID, parcat1=);
  data &out_ds.;
    set &in_ds.;
    length PARAMCD $8 PARAM $200 PARCAT1 $50 AVAL 8 AVALC $20;

    PARAMCD = "&paramcd.";
    PARAM = "&param.";
    %if %length(&parcat1.) > 0 %then %do;
      PARCAT1 = "&parcat1.";
    %end;

    if &flag_var. = 'Y' then do;
      AVAL = 1;
      AVALC = 'Y';
    end;
    else do;
      AVAL = 0;
      AVALC = 'N';
    end;

    keep &by_vars. PARAMCD PARAM PARCAT1 AVAL AVALC;
  run;
%mend derive_param_exist;

/*===========================================================================
  %derive_param_count - Derive count parameters
===========================================================================*/
%macro derive_param_count(in_ds=, out_ds=, count_var=, paramcd=, param=,
                          by_vars=USUBJID, parcat1=);
  proc sql;
    create table &out_ds. as
    select distinct
      %let i = 1;
      %let v = %scan(&by_vars., &i.);
      %do %while(%length(&v.) > 0);
        &v.,
        %let i = %eval(&i. + 1);
        %let v = %scan(&by_vars., &i.);
      %end;
      "&paramcd." as PARAMCD length=8,
      "&param." as PARAM length=200,
      "&parcat1." as PARCAT1 length=50,
      count(&count_var.) as AVAL
    from &in_ds.
    group by
      %let i = 1;
      %let v = %scan(&by_vars., &i.);
      %do %while(%length(&v.) > 0);
        &v.
        %let i = %eval(&i. + 1);
        %let v = %scan(&by_vars., &i.);
        %if %length(&v.) > 0 %then ,;
      %end;
    ;
  quit;
%mend derive_param_count;

/*===========================================================================
  %transpose_to_param - Transpose wide data to ADaM BDS structure
===========================================================================*/
%macro transpose_to_param(in_ds=, out_ds=, by_vars=USUBJID VISIT VISITNUM ADT ADY,
                          var_list=, paramcd_list=, param_list=, parcat1=);
  /* var_list, paramcd_list, param_list should have same number of items */

  data &out_ds.;
    set &in_ds.;
    length PARAMCD $8 PARAM $200 PARCAT1 $50 AVAL 8;

    %if %length(&parcat1.) > 0 %then %do;
      PARCAT1 = "&parcat1.";
    %end;

    %let n = %sysfunc(countw(&var_list.));
    %do i = 1 %to &n.;
      %let var = %scan(&var_list., &i.);
      %let pcd = %scan(&paramcd_list., &i.);
      %let pnm = %scan(&param_list., &i., |);

      if not missing(&var.) then do;
        PARAMCD = "&pcd.";
        PARAM = "&pnm.";
        AVAL = &var.;
        output;
      end;
    %end;

    keep &by_vars. PARAMCD PARAM PARCAT1 AVAL;
  run;
%mend transpose_to_param;

/*===========================================================================
  %derive_paramtyp - Derive PARAMTYP (DERIVED vs original)
===========================================================================*/
%macro derive_paramtyp(ds=, dtype_var=DTYPE);
  data &ds.;
    set &ds.;
    length PARAMTYP $20;
    if not missing(&dtype_var.) then PARAMTYP = 'DERIVED';
    else PARAMTYP = '';
  run;
%mend derive_paramtyp;
