/*** HELP START ***//*

Macro name:    diagram_plot
  Purpose:
    Combines all generated diagram components (boxes, text,
    and lines) and plots them as a flow diagram using PROC SGPLOT.
    The macro collects all datasets prefixed with "diagram_" and
    produces a complete diagram without axes or borders.

  Parameters:
    minx  = Minimum value of the X-axis (default=0)
    maxx  = Maximum value of the X-axis (default=100)
    miny  = Minimum value of the Y-axis (default=0)
    maxy  = Maximum value of the Y-axis (default=100)
    text_font = Text font (default=Courier)

  Notes:
    - This macro expects that %diagram_box and %diagram_line
      have already been called to create the component datasets.
    - Text is automatically split by the SPLITCHAR (#) option.
    - Arrows are drawn for lines with arrowhead at the end.

  Usage Example:
    %diagram_box(
        boxid=1,
        left_x=30, top_y=100,
        right_x=70, bottom_y=90,
        text=Assessed for eligibility (n=100)
    );

    %diagram_line(
        lineid=1,
        start_x=50, start_y=90,
        end_x=50,   end_y=55
    );

    %diagram_box(
        boxid=2,
        left_x=37, top_y=55,
        right_x=63, bottom_y=45,
        text=Randomized (n=90)
    );

    %diagram_plot(minx=0, maxx=100, miny=0, maxy=100);

*//*** HELP END ***/

%macro diagram_plot(minx=0,maxx=100,miny=0,maxy=100,text_font=Courier);
data plot_diag;
length text text2 $1000.;
set diagram_:;
run;

data plot_diag_attr;
set diag_style_: line_style_:;
run;

proc sgplot data=plot_diag noborder noautolegend dattrmap=plot_diag_attr;
  polygon id=boxid x=box_x y=box_y/attrid=DIAGID group=DIAGID;
  text x=text_x y=text_y text=text /textattrs=(family="&text_font") attrid=DIAGID group=DIAGID sizemin=1pt sizemaxresponse=100 sizemax=100pt sizeresponse = sizeresponse  splitchar='#' splitpolicy=splitalways;
  text x=text_x2 y=text_y2 text=text2 /textattrs=(family="&text_font") attrid=DIAGID group=DIAGID  sizemin=1pt sizemaxresponse=100 sizemax=100pt sizeresponse = sizeresponse  sizeresponse = sizeresponse  position=right splitchar='#' splitpolicy=splitalways;
  series x=line_x y=line_y/ attrid=_LINEID  group=_LINEID  arrowheadshape=filled arrowheadpos=end  arrowheadscale=0.3;

  xaxis display=none min=&minx. max=&maxx. offsetmin=0 offsetmax=0;
  yaxis display=none min=&miny. max=&maxy. offsetmin=0 offsetmax=0;
run;
%mend;

/* benchmark driver: the program only defines %diagram_plot; build the header's usage example with the
   companion macros from the same repository (programs/sas/macros/morioka) and plot it */
%include "&root./programs/sas/macros/morioka/diagram_box.sas";
%include "&root./programs/sas/macros/morioka/diagram_line.sas";
%diagram_box(boxid=1, left_x=30, top_y=100, right_x=70, bottom_y=90, text=Assessed for eligibility (n=100));
%diagram_line(lineid=1, start_x=50, start_y=90, end_x=50, end_y=55);
%diagram_box(boxid=2, left_x=37, top_y=55, right_x=63, bottom_y=45, text=Randomized (n=90));
%diagram_plot(minx=0, maxx=100, miny=0, maxy=100);
