/* benchmark driver: the program only defines %WaterFall_3D_Macro. Its companions from the same SGF 2019 folder
   (programs/sas/macros/sgf2019-matange) compile the FCMP matrix routines and build the tumor data, attribute map
   and the three example calls. */
%include "&root./programs/sas/macros/sgf2019-matange/Matrix_Functions.sas";
%include "&root./programs/sas/macros/sgf2019-matange/WaterFall_3D.sas";
