#!/usr/bin/env bash
# Generate driver programs for families whose programs depend on each other (one SAS session, manifest order, one log per program).
R=/d/meta_hackathon/sas2r-agent; B=$R/benchmark
gen() {  # family, ordered ids...
  fam=$1; shift; out=$B/pipelines/$fam.sas
  { echo "/* pipeline driver for family $fam: programs run in order in one session; each gets its own log */"
    echo "%let family = $fam;"
    for id in "$@"; do
      file=$(awk -F, -v i="$id" '$1==i{print $2}' "$B/manifest.csv")
      echo "proc printto log=\"&outlog./$id.log\" print=\"&outlog./$id.lst\" new; run;"
      echo "%let pid = $id; %let outds = &root./output/sas/datasets/$id; libname outds \"&outds.\";"
      echo "%put NOTE: ===== pipeline $fam: $id $file =====;"
      echo "%let _bench_t0 = %sysfunc(datetime());"
      echo "%include \"&root./programs/sas_run/$file\";"
      echo "%_bench_capture;"
      echo "proc printto; run;"
    done; } > "$out"
  echo "$fam: $# programs -> $out"
}
ids() { awk -F, -v f="$1" 'NR>1 && $2==f{print $1}' "$B/families.csv"; }
# c2c: sdtm_dm, other sdtm, adam_adsl, other adam, qc, tlf
c=$(ids c2c); order=""
for pat in '_sdtm_dm\.' '_sdtm_' '_adam_adsl\.' '_adam_' '_qc_' '_tlf_'; do for id in $c; do f=$(awk -F, -v i="$id" '$1==i{print $2}' "$B/manifest.csv"); echo "$f" | grep -qE "$pat" && ! echo " $order " | grep -q " $id " && order="$order $id"; done; done
gen c2c $order
# faijal: dm first
f=$(ids faijal); order="P023"; for id in $f; do [ "$id" = P023 ] || order="$order $id"; done; gen faijal $order
gen wxzhai $(ids wxzhai)
