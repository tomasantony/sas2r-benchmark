#!/usr/bin/env bash
# Create programs/sas_run/: verbatim copies of programs/sas plus the minimal path patches in patches.csv
# and the JumpStart %let path assignments. programs/sas stays untouched.
R=/d/meta_hackathon/sas2r-agent; SRC=$R/programs/sas; DST=$R/programs/sas_run; mkdir -p "$DST"; rm -f "$DST"/P*.sas
cp "$SRC"/P*.sas "$DST"/
# generic patches
tail -n +2 "$R/benchmark/patches.csv" | while IFS='|' read -r id pat rep why; do
  f=$(ls "$DST"/${id}_*.sas); perl -pi -e 'BEGIN{$p=shift; $r=shift} s/\Q$p\E/$r/' "$pat" "$rep" "$f" 2>/dev/null || perl -pi -e "s/\Q$pat\E/$rep/" "$f"
done
# JumpStart path macro variables (R010-R013): replace whatever the author set
for f in "$DST"/R010_*.sas "$DST"/R011_*.sas "$DST"/R012_*.sas "$DST"/R013_*.sas; do
  perl -i "$R/benchmark/patch_jumpstart.pl" "$f"
done
# generic: PHUSE test data fetched by URL -> local pilot copies (this SAS has no SSL)
for f in "$DST"/P*.sas; do perl -i "$R/benchmark/patch_urls.pl" "$f"; done
# benchmark drivers: programs that only define a macro get a documented call appended (benchmark/drivers/Pnnn.sas)
for d in "$R"/benchmark/drivers/P*.sas; do [ -e "$d" ] || continue; id=$(basename "$d" .sas); f=$(ls "$DST"/${id}_*.sas 2>/dev/null) || continue; printf "\n" >> "$f"; cat "$d" >> "$f"; done


echo "run copies: $(ls "$DST"/P*.sas | wc -l)"; echo "changed vs verbatim:"; for f in "$DST"/P*.sas; do b=$(basename "$f"); cmp -s "$f" "$SRC/$b" || echo "  $b"; done
