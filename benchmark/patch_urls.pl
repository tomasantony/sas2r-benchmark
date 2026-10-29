# Generic rewrites for the run copies. Forward slashes are used on purpose: SAS on Windows accepts them
# and this perl build mangles backslashes in replacements. \x5c is a literal backslash in the patterns.
while (<>) {
  # PHUSE test data fetched by URL -> local pilot copies (this SAS has no SSL)
  s{filename\s+(\w+)\s+url\s+"https://raw\.githubusercontent\.com/phuse-org/phuse-scripts/master/data/adam/cdisc/([^"]+)\.xpt"}{filename $1 "&rawadam./$2.xpt"}i;
  s{filename\s+(\w+)\s+"https://raw\.githubusercontent\.com/phuse-org/phuse-scripts/master/data/adam/cdisc/([^"]+)\.xpt"}{filename $1 "&rawadam./$2.xpt"}i;
  s{filename\s+(\w+)\s+url\s+"http://phuse-scripts\.googlecode\.com/svn/trunk/scriptathon2014/data/adae_updated\.xpt"}{filename $1 "&rawadam./adae.xpt"}i;
  s{filename\s+(\w+)\s+url\s+"http://phuse-scripts\.googlecode\.com/svn/trunk/scriptathon2014/data/([^"]+)\.xpt"}{filename $1 "&rawadam./$2.xpt"}i;
  s{filename\s+(\w+)\s+url\s+"http://phuse-scripts\.googlecode\.com/svn/trunk/lang/R/report/test/data/mcsl\.csv"}{filename $1 "&rawdir./phuse-mcsl/mcsl.csv"}i;
  # WPCT shift figure (P043): author UNC path to the split pilot data
  s{^libname adam "\x5c\x5cquintiles[^;]*;}{libname adam "&root./data/derived/cdisc-pilot/adam-split";}i;
  # WPCT F.07.02/03 as published carry an annotation after the OPTIONS line that is a syntax error in any SAS
  s{^(\s*)OPTIONS sasautos=\(%sysfunc\(getoption\(sasautos\)\) ""\);.*$}{$1%* benchmark: SASAUTOS is set in autoexec, the published line and its trailing note do not parse;}i;
  # WPCT F.07.01 on ADLBC: the program header says to add dummy ATPTN/ATPT because the test data has none
  if ($ARGV =~ /R01[45]_/) {
    s{local=\x5c\x5cquintiles[^)]*\)\s*;}{local=) ; DATA &ds; SET &ds; ATPTN = 1; ATPT = "TimePoint unknown"; RUN; %* benchmark: dummy time point per the program header;}i;
  }
  # owner ADaM programs include their macros relative to the original tree
  s{'\.\./macros/(m_\w+\.sas)'}{"&root./programs/sas/macros/own-adam/$1"}g;
  print;
}
