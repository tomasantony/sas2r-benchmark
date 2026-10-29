/*****************************************************************************
* Program:    f_mean_cfb.sas
* Purpose:    Figure 14.2.4 - Mean Change from Baseline Over Time
*             (with error bars showing SE or 95% CI)
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      adam.adeff (or adam.adlb, adam.advs, adam.adqs)
* Output:     f_mean_cfb.rtf
* Population: Efficacy Analysis Set (EFFFL='Y')
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Parameters ---*/
%let eff_param = ACTOT;   /* test copy: placeholder filled with the synthetic efficacy parameter */    /* Analysis parameter */
%let y_label   = Change from Baseline in ADAS-Cog Total Score;

/*--- Step 1: Prepare analysis data ---*/
proc sql noprint;
    create table eff as
    select a.USUBJID, a.TRTA, a.TRTAN,
           a.PARAMCD, a.PARAM,
           a.AVISIT, a.AVISITN,
           a.AVAL, a.BASE, a.CHG,
           a.ANL01FL
    from adam.adeff a
    inner join adam.adsl b on a.USUBJID = b.USUBJID
    where b.EFFFL = 'Y'
          and a.PARAMCD = "&eff_param."
          and a.ANL01FL = 'Y'
          and a.CHG ne .
    order by a.TRTAN, a.AVISITN;
quit;

/*--- Step 2: Compute summary statistics by visit and treatment ---*/
proc means data=eff nway noprint;
    class TRTA TRTAN AVISIT AVISITN;
    var CHG;
    output out=stats(drop=_type_ _freq_)
        n=n mean=mean stderr=se 
        lclm=lcl uclm=ucl;
run;

/*--- Step 3: Small offset to prevent overlapping points ---*/
data plot_data;
    set stats;
    /* Offset x-position slightly by treatment for readability */
    select(TRTAN);
        when(1) xpos = AVISITN - 0.15;
        when(2) xpos = AVISITN;
        when(3) xpos = AVISITN + 0.15;
        otherwise xpos = AVISITN;
    end;
run;

/*--- Step 4: Generate figure ---*/
%set_titles(output=F_MEAN_CFB, population=Efficacy Analysis Set);

options orientation=landscape; ods rtf file="&tlfpath./f_mean_cfb.rtf" style=journal bodytitle;
ods graphics on / reset width=10in height=6.5in imagefmt=emf;

proc sgplot data=plot_data;
    title4 j=c "Figure 14.2.4";
    title5 j=c "Mean Change from Baseline Over Time";
    title6 j=c "Efficacy Analysis Set";

    /* Error bars (95% CI) */
    highlow x=xpos low=lcl high=ucl / group=TRTA
        lineattrs=(thickness=1.5px)
        type=bar barwidth=0.05;

    /* Mean values connected by lines */
    series x=xpos y=mean / group=TRTA
        lineattrs=(thickness=2px) name="trt"
        markers markerattrs=(size=8px symbol=circlefilled);

    /* Reference line at 0 */
    refline 0 / axis=y lineattrs=(pattern=dash color=gray thickness=1px);

    /* Axes */
    xaxis label="Visit (Week)" 
          type=linear
          integer;
    yaxis label="&y_label." 
          grid gridattrs=(pattern=dot color=lightgray);

    keylegend "trt" / location=outside position=bottom across=3;

    footnote1 j=l "Data cutoff: &cutdate.";
    footnote2 j=l "Error bars represent 95% confidence intervals.";
    footnote3 j=l "n = number of subjects with non-missing change from baseline.";
    footnote4 j=l "Program: &sysin. | Run: %sysfunc(date(), date9.)";
run;

ods graphics off;
ods rtf close;
%clear_titles;

/*--- Step 5: Supporting data table (n per visit per treatment) ---*/
proc tabulate data=plot_data out=_ntable;
    class TRTA AVISIT AVISITN;
    var n;
    table TRTA, AVISIT * n * sum / box='n per visit';
run;

proc datasets lib=work nolist;
    delete eff stats plot_data _ntable;
quit;

%put NOTE: f_mean_cfb.sas completed successfully.;
