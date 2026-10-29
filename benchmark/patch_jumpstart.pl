# Rewrite the FDA JumpStart %let path assignments to the benchmark tree (forward slashes are fine for SAS on Windows)
while (<>) {
  s{^(\s*%let\s+studypath\s*=)[^;]*;}{$1 D:/meta_hackathon/sas2r-agent/data/derived/cdisc-pilot/sdtm;}i;
  s{^(\s*%let\s+saspath\s*=)[^;]*;}{$1 D:/meta_hackathon/sas2r-agent/programs/sas/macros/phuse-jumpstart;}i;
  s{^(\s*%let\s+utilpath\s*=)[^;]*;}{$1 D:/meta_hackathon/sas2r-agent/programs/sas/macros/phuse-jumpstart;}i;
  s{^(\s*%let\s+templatepath\s*=)[^;]*;}{$1 D:/meta_hackathon/sas2r-agent/data/raw/phuse-templates;}i;
  s{^(\s*%let\s+outpath\s*=)[^;]*;}{$1 &outds.;}i;
  s{^(\s*%let\s+dosfrqpath\s*=)\s*;}{$1 D:/meta_hackathon/sas2r-agent/programs/sas/macros/phuse-jumpstart;}i;
  print;
}
