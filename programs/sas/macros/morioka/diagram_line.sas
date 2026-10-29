/*** HELP START ***//*

Macro Name : diagram_line
Purpose : Create a dataset containing line coordinates (start -> [mid] -> end).
Useful for plotting diagrams where lines are defined by 2 or 3 points.

 Parameters :
   lineid      = (numeric, default=1)
                 Identifier for the line. Used as a variable in the output dataset name.

   start_x     = (numeric, default=30)
   start_y     = (numeric, default=90)
                 Coordinates of the starting point of the line.

   midpoint_x  = (numeric, optional)
   midpoint_y  = (numeric, optional)
                 Coordinates of an optional midpoint. If both are provided,
                 the line will include this point.

   end_x       = (numeric, default=30)
   end_y       = (numeric, default=60)
                 Coordinates of the end point of the line.

   linecolor    = Lline color (default = black)
   linepattern = Line pattern (default=Solid)
   linethickness = Linethickness (default=1)


 Output     :
   A dataset named diagram_line_<lineid> with variables:
     - lineid : the line identifier
     - line_x : x coordinate of points
     - line_y : y coordinate of points

 Example    :
   %diagram_line(lineid=2, start_x=10, start_y=20, midpoint_x=15, midpoint_y=25, end_x=30, end_y=40);
  -> Produces dataset diagram_line_2 with 3 points: (10,20) -> (15,25) -> (30,40)

*//*** HELP END ***/

%macro diagram_line(lineid=1,
                      start_x=30,
                      start_y=90,
                      midpoint_x=,
                      midpoint_y=,
                      end_x=30,
                      end_y=60,
                      linecolor=black,
                      linepattern=solid,
                      linethickness=1
);
data diagram_line_&lineid.;
_LINEID=cats(&lineid.);
lineid=&lineid.;line_x=&start_x.;line_y=&start_y.;output;
%if %length(&midpoint_x.) ne  0 and %length(&midpoint_y.) ne  0 %then %do;
lineid=&lineid.;line_x=&midpoint_x.;line_y=&midpoint_y.;output;
%end;
lineid=&lineid.;line_x=&end_x.;line_y=&end_y.;output;
run;

data line_style_&lineid.;
length id $20. value  linecolor linepattern  $30. linethickness 8.;
id="_LINEID";
value =cats("&lineid.");
linecolor="&linecolor";
linepattern="&linepattern";
linethickness=&linethickness;
run;
%mend;
