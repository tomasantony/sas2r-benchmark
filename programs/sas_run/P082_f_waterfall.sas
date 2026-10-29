/*****************************************************************************
* Program:    f_waterfall.sas
* Purpose:    Figure 14.2.3 - Waterfall Plot of Best Percentage Change
*             from Baseline in Target Lesion Size
* Study:      [STUDYID]
* Author:     [Programmer Name]
* Date:       [Date]
* Input:      adam.adtr (or adam.adrs), adam.adsl
* Output:     f_waterfall.rtf
* Population: Efficacy Analysis Set (EFFFL='Y')
* Notes:      Typically used in oncology trials (RECIST criteria)
*****************************************************************************/

%include "&pgmpath./utilities/u_setup.sas";
%include "&pgmpath./utilities/u_titles.sas";

/*--- Step 1: Get best percentage change per subject ---*/
proc sql noprint;
    create table tumor as
    select a.USUBJID, a.TRTA, a.TRTAN,
           a.PARAMCD, a.PARAM,
           a.PCHG,        /* Percent change from baseline */
           a.AVALC,       /* Best overall response category */
           b.EFFFL
    from adam.adtr a      /* Tumor response dataset */
    inner join adam.adsl b on a.USUBJID = b.USUBJID
    where b.EFFFL = 'Y'
          and a.PARAMCD = 'BPCHG'  /* Best percent change */
    order by a.PCHG;
quit;

/* Alternative: Derive from ADRS if ADTR not available */
/*
proc sql noprint;
    create table tumor as
    select a.USUBJID, a.TRTA, a.TRTAN,
           min(a.PCHG) as PCHG,
           b.AVALC as BOR
    from adam.adrs a
    inner join adam.adsl b on a.USUBJID = b.USUBJID
    where b.EFFFL = 'Y' and a.PARAMCD = 'SUMLD'
    group by a.USUBJID, a.TRTA, a.TRTAN, b.AVALC;
quit;
*/

/*--- Step 2: Assign display order (sorted by percent change) ---*/
data waterfall;
    set tumor;
    by PCHG;
    bar_order = _n_;
    
    /* Color by response category */
    length bar_color $20;
    select(upcase(AVALC));
        when('CR') bar_color = 'darkgreen';
        when('PR') bar_color = 'green';
        when('SD') bar_color = 'gold';
        when('PD') bar_color = 'red';
        otherwise  bar_color = 'gray';
    end;
    
    /* Cap at reasonable bounds */
    if PCHG > 100 then PCHG_display = 100;
    else if PCHG < -100 then PCHG_display = -100;
    else PCHG_display = PCHG;
run;

/*--- Step 3: Generate waterfall plot ---*/
%set_titles(output=F_WATERFALL, population=Efficacy Analysis Set);

options orientation=landscape; ods rtf file="&tlfpath./f_waterfall.rtf" style=journal bodytitle;
ods graphics on / reset width=10in height=6.5in imagefmt=emf;

proc sgplot data=waterfall;
    title4 j=c "Figure 14.2.3";
    title5 j=c "Waterfall Plot of Best Percentage Change from Baseline in Sum of Target Lesions";

    /* Bars colored by best overall response */
    vbar bar_order / response=PCHG_display 
        group=AVALC
        groupdisplay=cluster
        barwidth=1
        outline outlineattrs=(color=black thickness=0.5px);

    /* Reference lines for RECIST thresholds */
    refline -30 / axis=y lineattrs=(pattern=dash color=blue thickness=1px)
        label='-30% (PR threshold)' labelattrs=(size=7pt);
    refline 20 / axis=y lineattrs=(pattern=dash color=red thickness=1px)
        label='+20% (PD threshold)' labelattrs=(size=7pt);
    refline 0 / axis=y lineattrs=(color=black thickness=1px);

    xaxis display=none label=' ';
    yaxis label="Best Percentage Change from Baseline (%)"
          values=(-100 to 100 by 20)
          grid gridattrs=(pattern=dot color=lightgray);

    keylegend / title='Best Overall Response' 
        location=outside position=bottom across=5;

    footnote1 j=l "Data cutoff: &cutdate.";
    footnote2 j=l "Each bar represents one subject.";
    footnote3 j=l "CR=Complete Response, PR=Partial Response, SD=Stable Disease, PD=Progressive Disease";
    footnote4 j=l "Dashed lines: RECIST 1.1 thresholds for PR (-30%) and PD (+20%)";
    footnote5 j=l "Program: &sysin. | Run: %sysfunc(date(), date9.)";
run;

ods graphics off;
ods rtf close;
%clear_titles;

proc datasets lib=work nolist; delete tumor waterfall; quit;

%put NOTE: f_waterfall.sas completed successfully.;
