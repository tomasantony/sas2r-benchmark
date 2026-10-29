# 00_setup.R - sourced at the top of every pipeline script.
# Loads packages, defines paths and study constants. No side effects beyond
# library loading and path string assignment.

suppressPackageStartupMessages({
  library(admiral)
  library(admiraldev)
  library(pharmaversesdtm)
  library(xportr)
  library(metacore)
  library(metatools)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(lubridate)
  library(haven)
  library(readr)
  library(readxl)
  library(here)
  library(cli)
})

# Study metadata -----------------------------------------------------------
STUDY_ID    <- "CDISCPILOT01"
STUDY_TITLE <- "Safety and Efficacy of the Xanomeline Transdermal Therapeutic System (TTS) in Patients with Mild to Moderate Alzheimer's Disease"
DATA_CUTOFF <- as.Date("2008-04-04")

# Pipeline paths -----------------------------------------------------------
PATH_REPO     <- here::here()
PATH_RAW      <- here::here("data", "raw")
PATH_INTERIM  <- here::here("data", "intermediate")
PATH_ADAM     <- here::here("data", "adam")
PATH_XPT      <- here::here("data", "xpt")
PATH_TLF      <- here::here("outputs", "tlfs")
PATH_VALID    <- here::here("outputs", "validation")
PATH_DEFINE   <- here::here("outputs", "define")
PATH_METADATA <- here::here("metadata")
PATH_DOCS     <- here::here("docs")

# Ensure write paths exist
for (p in c(PATH_ADAM, PATH_XPT, PATH_TLF, PATH_VALID, PATH_DEFINE)) {
  if (!dir.exists(p)) dir.create(p, recursive = TRUE)
}

# Options ------------------------------------------------------------------
options(
  dplyr.summarise.inform = FALSE,
  pillar.print_min = 5,
  pillar.print_max = 5,
  scipen = 999
)
