/* benchmark driver: the program only defines %diagram_plot; build the header's usage example with the
   companion macros from the same repository (programs/sas/macros/morioka) and plot it */
%include "&root./programs/sas/macros/morioka/diagram_box.sas";
%include "&root./programs/sas/macros/morioka/diagram_line.sas";
%diagram_box(boxid=1, left_x=30, top_y=100, right_x=70, bottom_y=90, text=Assessed for eligibility (n=100));
%diagram_line(lineid=1, start_x=50, start_y=90, end_x=50, end_y=55);
%diagram_box(boxid=2, left_x=37, top_y=55, right_x=63, bottom_y=45, text=Randomized (n=90));
%diagram_plot(minx=0, maxx=100, miny=0, maxy=100);
