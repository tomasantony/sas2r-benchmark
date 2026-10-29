/*** HELP START ***//*

Macro Name:    diagram_box
   Purpose:
     Creates a rectangular box (polygon) and corresponding
     text annotation dataset for use in flow diagrams.
     The macro generates two datasets:
       - diagram_box_<boxid>:  Coordinates of the box
       - diagram_box_text_<boxid>: Position and content of text
 
   Parameters:
     boxid      = Unique identifier for the box (default=1)
     left_x     = X coordinate of the left edge   (default=10)
     top_y      = Y coordinate of the top edge    (default=100)
     right_x    = X coordinate of the right edge  (default=30)
     bottom_y   = Y coordinate of the bottom edge (default=90)
     text       = Label text to be displayed inside the box
     text_just  = Text justification (CENTER [default] or LEFT)
     text_size = Text font size [1-100 pt] (default =10 pt)
     text_color = Text font color (default = black)
     linecolor = Box linecolor (default = black)
     linepattern = Box linepattern (default=Solid)
     linethickness = Box linethickness (default=1)

   Notes:
     - Coordinates define an axis-aligned rectangle.
     - Text position is calculated based on justification:
         CENTER 竊・centered at the box
          LEFT   竊・aligned to the left edge, vertically centered
     - Text can include line breaks using the SPLITCHAR in SGPLOT.
     - The macro is typically used in combination with diagram_line
       and diagram_plot to build flow diagrams (e.g., CONSORT).

  Usage Example:
    %diagram_box(
        boxid=1,
        left_x=30,
        top_y=100,
        right_x=70,
        bottom_y=90,
        text=Assessed for eligibility (n=100)
    );
 
    %diagram_box(
        boxid=2,
        left_x=65,
        top_y=86,
        right_x=95,
        bottom_y=60,
        text_just=left,
        text=Excluded (n=10)#- Not meeting inclusion criteria (n=4)
             #- Declined to participate (n=4)
             #- Other reasons (n=2)
    );

*//*** HELP END ***/

%macro diagram_box(boxid=1,left_x=10,top_y=100,right_x=30,bottom_y=90,text=,text_just=center,text_size=10,text_color=black,linecolor=black,linepattern=solid,linethickness=1);
data diagram_box_&boxid.;
DIAGID=cats(&boxid.);
boxid=&boxid.;box_x=&left_x.;box_y=&top_y.;output;
boxid=&boxid.;box_x=&right_x.;box_y=&top_y.;output;
boxid=&boxid.;box_x=&right_x.;box_y=&bottom_y.;output;
boxid=&boxid.;box_x=&left_x.;box_y=&bottom_y.;output;
run;

data diagram_box_text_&boxid.;
length text_x text_y text_x2 text_y2 8. text text2 $1000. sizeresponse 8.;
call missing(of  text_x text_y text_x2 text_y2 text text2 );
    x1=&left_x.; y1=&top_y.;   
    x2=&right_x.; y2=&top_y.;   
    x3=&right_x.; y3=&bottom_y.  ;
    x4=&left_x.; y4=&bottom_y.;  

    den = (x1-x3)*(y2-y4) - (y1-y3)*(x2-x4);

    if den = 0 then do;
        put "WARNING: The diagonals are parallel or coincide. A quadrilateral cannot be formed.";
    end;
    else do;
        num1 = (x1*y3 - y1*x3);
        num2 = (x2*y4 - y2*x4);
        %if %upcase(&text_just) ne LEFT %then %do;
          text_x = ( num1*(x2-x4) - (x1-x3)*num2 ) / den;
          text_y = ( num1*(y2-y4) - (y1-y3)*num2 ) / den;
          text="&text";
        %end;
        %if %upcase(&text_just) eq LEFT %then %do;
          text_x2 = x1 + 1;
          text_y2 = ( num1*(y2-y4) - (y1-y3)*num2 ) / den;
          text2="&text";
        %end;
    end;
    sizeresponse = &text_size.;
    DIAGID=cats("&boxid.");
drop den num1 num2;
run;

data diag_style_&boxid.;
length id $20. value textcolor linecolor linepattern  $30. linethickness 8.;
id="DIAGID";
value =cats("&boxid.");
textcolor= "&text_color";
linecolor="&linecolor";
linepattern="&linepattern";
linethickness=&linethickness;
run;

%mend;
