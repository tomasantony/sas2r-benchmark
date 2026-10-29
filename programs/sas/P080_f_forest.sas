%macro yvals; %do r = 1 %to &sysnobs.; -&r. %end; %mend yvals;  /* test-copy patch, see tlf_test_patches.md */
/*****************************************************************************
* Program:    f_forest.sas
* Purpose:    Figure 14.2.2 - Forest Plot of Subgroup Analyses
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      adam.adtte (or adam.adeff), adam.adsl
* Output:     f_forest.rtf
* Population: Efficacy Analysis Set
* Notes:      Hazard Ratios (or Odds Ratios) with 95% CI by subgroup
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Step 1: Define subgroups ---*/
/* Each subgroup analysis is done separately, then combined */

%macro subgroup_analysis(data=, subgrp=, subgrp_label=, paramcd=OS, 
                          subgrp_ord=, levels=);

    proc sort data=&data. out=_sg; by &subgrp.; run;

    /* Run Cox model within each subgroup level */
    ods output ParameterEstimates = _pe_&subgrp_ord.;
    
    proc phreg data=_sg;
        by &subgrp.;
        class TRTA(ref="&trt1lbl.");
        model AVAL * CNSR(1) = TRTA;
        hazardratio TRTA;
    run;

    ods output close;

    /* Format results */
    data _sg_&subgrp_ord.;
        set _pe_&subgrp_ord.;
        where Parameter = 'TRTA';
        
        length subgroup $60 subgroup_level $60;
        subgroup = "&subgrp_label.";
        subgroup_level = strip(vvalue(&subgrp.));
        subgrp_ord = &subgrp_ord.;
        
        HR = exp(Estimate);
        HR_LCL = exp(Estimate - 1.96 * StdErr);
        HR_UCL = exp(Estimate + 1.96 * StdErr);
        
        /* Display strings */
        length hr_display $30 ci_display $40;
        hr_display = strip(put(HR, 5.2));
        ci_display = cat('(', strip(put(HR_LCL, 5.2)), ', ', 
                              strip(put(HR_UCL, 5.2)), ')');
        
        keep subgroup subgroup_level subgrp_ord HR HR_LCL HR_UCL 
             hr_display ci_display ProbChiSq;
    run;

%mend subgroup_analysis;

/*--- Step 2: Prepare data ---*/
proc sql noprint;
    create table eff as
    select a.USUBJID, a.TRTA, a.TRTAN, a.AVAL, a.CNSR,
           b.SEX, b.AGEGR1, b.RACE, b.REGION1, b.ECOGBL
    from adam.adtte a
    inner join adam.adsl b on a.USUBJID = b.USUBJID
    where b.EFFFL = 'Y' and a.PARAMCD = 'OS';
quit;

/*--- Step 3: Run subgroup analyses ---*/
%subgroup_analysis(data=eff, subgrp=SEX, subgrp_label=Sex, subgrp_ord=1);
%subgroup_analysis(data=eff, subgrp=AGEGR1, subgrp_label=Age Group, subgrp_ord=2);
%subgroup_analysis(data=eff, subgrp=RACE, subgrp_label=Race, subgrp_ord=3);
%subgroup_analysis(data=eff, subgrp=REGION1, subgrp_label=Region, subgrp_ord=4);

/*--- Step 4: Overall HR ---*/
ods output ParameterEstimates = _pe_overall;
proc phreg data=eff;
    class TRTA(ref="&trt1lbl.");
    model AVAL * CNSR(1) = TRTA;
run;
ods output close;

data _sg_overall;
    set _pe_overall;
    where Parameter = 'TRTA';
    length subgroup $60 subgroup_level $60;
    subgroup = 'Overall';
    subgroup_level = 'All Subjects';
    subgrp_ord = 0;
    HR = exp(Estimate);
    HR_LCL = exp(Estimate - 1.96 * StdErr);
    HR_UCL = exp(Estimate + 1.96 * StdErr);
    length hr_display $30 ci_display $40;
    hr_display = strip(put(HR, 5.2));
    ci_display = cat('(', strip(put(HR_LCL, 5.2)), ', ', 
                          strip(put(HR_UCL, 5.2)), ')');
    keep subgroup subgroup_level subgrp_ord HR HR_LCL HR_UCL 
         hr_display ci_display ProbChiSq;
run;

/*--- Step 5: Combine all subgroups ---*/
data forest_data;
    set _sg_overall _sg_1 _sg_2 _sg_3 _sg_4;
    
    /* Row ordering */
    row = _n_;
    yval = -_n_;  /* For plotting top-to-bottom */
run;

/*--- Step 6: Generate forest plot ---*/
%set_titles(output=F_FOREST, population=Efficacy Analysis Set);

ods rtf file="&tlfpath./f_forest.rtf" style=journal bodytitle;
ods graphics on / reset width=10in height=7in imagefmt=emf;

proc sgplot data=forest_data noautolegend;
    title4 j=c "Figure 14.2.2";
    title5 j=c "Forest Plot of Subgroup Analyses - Overall Survival";

    /* Reference line at HR=1 */
    refline 1 / axis=x lineattrs=(pattern=dash color=gray);

    /* CI lines */
    highlow y=yval low=HR_LCL high=HR_UCL / 
        lineattrs=(thickness=2px color=darkblue);

    /* Point estimates */
    scatter y=yval x=HR / 
        markerattrs=(symbol=diamondfilled size=10px color=darkblue);

    /* Subgroup labels on y-axis */
    yaxis type=discrete 
          values=(%yvals)  /* test-copy patch: open-code %DO is not allowed, loop moved into macro %yvals */
          display=(nolabel)
          fitpolicy=none;

    xaxis label="Hazard Ratio (95% CI)" 
          type=log logbase=2
          values=(0.1 0.25 0.5 1 2 4)
          grid;

    /* Favors labels */
    inset ("Favors &trt2lbl." = " ") / 
        position=bottomleft textattrs=(size=8pt);
    inset ("Favors &trt1lbl." = " ") / 
        position=bottomright textattrs=(size=8pt);

    footnote1 j=l "Data cutoff: &cutdate.";
    footnote2 j=l "Hazard Ratios from Cox proportional hazards model.";
    footnote3 j=l "Program: &sysin. | Run: %sysfunc(date(), date9.)";
run;

ods graphics off;
ods rtf close;

%clear_titles;

proc datasets lib=work nolist;
    delete eff _sg _sg_: _pe_: forest_data;
quit;

%put NOTE: f_forest.sas completed successfully.;
