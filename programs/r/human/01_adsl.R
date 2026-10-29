# 01_adsl.R - Subject-Level Analysis Dataset (ADSL).
# Parent of every downstream ADaM. Derived per CDISC ADaMIG 1.3.
#
# Inputs : pharmaversesdtm::dm, ex, ds, ae
# Output : data/adam/adsl.rds (one row per USUBJID)

source(here::here("R", "00_setup.R"))
source(here::here("R", "helpers.R"))

log_step("01_adsl: start")

# 1. Source domains --------------------------------------------------------
dm <- read_pharmaverse("dm")
ex <- read_pharmaverse("ex")
ds <- read_pharmaverse("ds")
ae <- read_pharmaverse("ae")


# 2. Base subject record from DM ------------------------------------------
adsl_base <- dm %>%
  select(
    STUDYID, USUBJID, SUBJID, SITEID, AGE, AGEU, SEX, RACE, ETHNIC, COUNTRY,
    ARM, ARMCD, ACTARM, ACTARMCD,
    RFSTDTC, RFENDTC, RFXSTDTC, RFXENDTC,
    DTHDTC, DTHFL
  )


# 3. Treatment dates from RFXSTDTC / RFXENDTC -----------------------------
# RFXSTDTC = Date/Time of First Study Treatment; RFXENDTC = last.
# Use admiral::derive_vars_dt for date portion, derive_vars_dtm for datetime.
adsl_trt <- adsl_base %>%
  derive_vars_dt(new_vars_prefix = "TRTS", dtc = RFXSTDTC) %>%
  derive_vars_dt(new_vars_prefix = "TRTE", dtc = RFXENDTC) %>%
  derive_vars_dtm(new_vars_prefix = "TRTS", dtc = RFXSTDTC) %>%
  derive_vars_dtm(new_vars_prefix = "TRTE", dtc = RFXENDTC) %>%
  # derive_vars_dt/dtm name new var as <prefix>DT/<prefix>DTM but also adds a
  # *DTF imputation flag we don't need on ADSL.
  select(-any_of(c("TRTSDTF", "TRTEDTF", "TRTSTMF", "TRTETMF")))

# Treatment duration: TRTEDT - TRTSDT + 1 (calendar days)
adsl_trt <- adsl_trt %>%
  derive_vars_duration(
    new_var      = TRTDURD,
    new_var_unit = NULL,
    start_date   = TRTSDT,
    end_date     = TRTEDT,
    out_unit     = "days",
    add_one      = TRUE,
    trunc_out    = FALSE
  )


# 4. Population flags ------------------------------------------------------
# SAFFL = Y if subject received >=1 dose of randomized treatment, active OR
# placebo (any EX record with non-missing EXTRT, regardless of EXDOSE value -
# pharmaversesdtm encodes placebo as EXDOSE=0).
ex_dosed <- ex %>% filter(!is.na(EXTRT))

adsl_pop <- adsl_trt %>%
  derive_var_merged_exist_flag(
    dataset_add = ex_dosed,
    by_vars     = exprs(STUDYID, USUBJID),
    new_var     = SAFFL,
    condition   = !is.na(EXTRT)
  ) %>%
  # ITTFL = Y if subject was randomized (ARM is one of the planned arms,
  # not "Screen Failure" and not missing).
  mutate(
    ITTFL = if_else(ARM %in% c("Placebo", "Xanomeline High Dose", "Xanomeline Low Dose"), "Y", "N"),
    SAFFL = if_else(is.na(SAFFL), "N", SAFFL)
  )


# 5. Disposition variables from DS ----------------------------------------
# EOSSTT  : End of Study status from DSCAT='DISPOSITION EVENT'
# DCSREAS : Reason for study discontinuation (DSDECOD when not COMPLETED)
# DCSREASP: Free-text reason (DSTERM) when DSDECOD is OTHER
ds_disp <- ds %>%
  filter(DSCAT == "DISPOSITION EVENT" & DSDECOD != "SCREEN FAILURE") %>%
  arrange(USUBJID, DSDTC) %>%
  group_by(USUBJID) %>%
  slice_tail(n = 1) %>%
  ungroup() %>%
  transmute(
    USUBJID,
    EOSSTT  = if_else(DSDECOD == "COMPLETED", "COMPLETED", "DISCONTINUED"),
    DCSREAS = if_else(DSDECOD == "COMPLETED", NA_character_, DSDECOD),
    DCSREASP = if_else(DSDECOD == "OTHER", DSTERM, NA_character_)
  )

# EOT (end of treatment) - here we don't have a separate end-of-treatment
# row, so we set EOTSTT equal to EOSSTT.
adsl_disp <- adsl_pop %>%
  left_join(ds_disp, by = "USUBJID") %>%
  mutate(
    EOSSTT = coalesce(EOSSTT, "DISCONTINUED"),
    EOTSTT = EOSSTT
  )


# 6. Age groups and numeric codes -----------------------------------------
adsl_age <- adsl_disp %>%
  mutate(
    AGEGR1 = case_when(
      AGE <  65          ~ "<65",
      AGE >= 65 & AGE <= 80 ~ "65-80",
      AGE >  80          ~ ">80",
      TRUE               ~ NA_character_
    ),
    AGEGR1N = case_when(
      AGEGR1 == "<65"   ~ 1L,
      AGEGR1 == "65-80" ~ 2L,
      AGEGR1 == ">80"   ~ 3L,
      TRUE              ~ NA_integer_
    ),
    SEXN = case_when(
      SEX == "M" ~ 1L,
      SEX == "F" ~ 2L,
      TRUE       ~ NA_integer_
    ),
    RACEN = case_when(
      RACE == "WHITE"                              ~ 1L,
      RACE == "BLACK OR AFRICAN AMERICAN"          ~ 2L,
      RACE == "ASIAN"                              ~ 3L,
      RACE == "AMERICAN INDIAN OR ALASKA NATIVE"   ~ 4L,
      RACE == "NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER" ~ 5L,
      RACE == "MULTIPLE"                           ~ 6L,
      TRUE                                         ~ NA_integer_
    )
  )


# 7. Death info ------------------------------------------------------------
adsl_death <- adsl_age %>%
  derive_vars_dt(new_vars_prefix = "DTH", dtc = DTHDTC) %>%
  select(-any_of("DTHDTF"))


# 8. TRT01P / TRT01A: copies of ARM / ACTARM for first treatment period.
adsl_trt01 <- adsl_death %>%
  mutate(
    TRT01P = ARM,
    TRT01A = ACTARM
  )


# 9. Efficacy flag: SAFFL=Y AND has post-baseline ADAS-Cog assessment.
# pharmaversesdtm doesn't carry the original CDISC Pilot QS for ADAS-Cog,
# so EFFFL is set to SAFFL by default. R/05_adqsadas.R will refine this
# when QS data is sourced from the canonical CDISC Pilot repo.
adsl_eff <- adsl_trt01 %>%
  mutate(EFFFL = SAFFL)


# 10. Apply spec column order + labels ------------------------------------
adsl <- adsl_eff %>%
  apply_metadata("adsl") %>%
  arrange(USUBJID)

check_no_dup_usubjid(adsl, "ADSL")
log_step("ADSL built: %d subjects, %d variables", nrow(adsl), ncol(adsl))


# 11. Save -----------------------------------------------------------------
save_adam(adsl, "adsl")

log_step("01_adsl: done")
