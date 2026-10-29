# helpers.R - shared utilities used across the pipeline.
# Source AFTER 00_setup.R so that PATH_* and library symbols exist.

#' Log a timestamped message via cli.
log_step <- function(msg, ...) {
  cli::cli_alert_info(sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), sprintf(msg, ...)))
}

#' Read an SDTM domain from pharmaversesdtm by name.
#' Wraps `data()` so callers can do `dm <- read_pharmaverse("dm")`.
read_pharmaverse <- function(domain) {
  e <- new.env()
  data(list = domain, package = "pharmaversesdtm", envir = e)
  if (!exists(domain, envir = e)) {
    cli::cli_abort("Domain {.val {domain}} not found in pharmaversesdtm.")
  }
  get(domain, envir = e)
}

#' Read a single-sheet metadata Excel spec into a tibble.
#' Expected columns: dataset, variable, label, type, length, format,
#' codelist, origin, derivation, comment.
read_metadata_spec <- function(dataset_name) {
  path <- file.path(PATH_METADATA, paste0(tolower(dataset_name), "_spec.xlsx"))
  if (!file.exists(path)) {
    cli::cli_abort("Metadata spec not found: {.file {path}}")
  }
  readxl::read_excel(path)
}

#' Apply variable labels and column order from a metadata spec to an ADaM
#' data frame. By default `strict = TRUE`: keep only spec variables (drop
#' working/intermediate vars) so the output matches the submission deliverable.
apply_metadata <- function(df, dataset_name, strict = TRUE) {
  spec <- read_metadata_spec(dataset_name)
  spec_vars <- toupper(spec$variable)
  df_vars   <- toupper(names(df))

  missing_vars <- setdiff(spec_vars, df_vars)
  if (length(missing_vars) > 0) {
    cli::cli_alert_warning(
      "Spec variables missing from {.val {dataset_name}}: {.field {missing_vars}}"
    )
  }
  extra_vars <- setdiff(df_vars, spec_vars)
  if (length(extra_vars) > 0 && strict) {
    cli::cli_alert_info(
      "Dropping {length(extra_vars)} non-spec var{?s} from {.val {dataset_name}}: {.field {extra_vars}}"
    )
  }

  for (i in seq_len(nrow(spec))) {
    v <- toupper(spec$variable[i])
    if (v %in% df_vars) {
      attr(df[[v]], "label") <- spec$label[i]
    }
  }

  ordered_vars <- if (strict) {
    intersect(spec_vars, df_vars)
  } else {
    c(intersect(spec_vars, df_vars), extra_vars)
  }
  df[ordered_vars]
}

#' Assert that USUBJID is unique in a one-record-per-subject dataset (e.g. ADSL).
check_no_dup_usubjid <- function(df, where = deparse(substitute(df))) {
  if (anyDuplicated(df$USUBJID)) {
    dups <- df$USUBJID[duplicated(df$USUBJID)]
    cli::cli_abort(c(
      "Duplicate USUBJID in {.val {where}}",
      "i" = "First duplicates: {.val {head(unique(dups), 5)}}"
    ))
  }
  invisible(df)
}

#' Save an ADaM dataset to data/adam/<name>.rds.
save_adam <- function(df, name) {
  path <- file.path(PATH_ADAM, paste0(tolower(name), ".rds"))
  saveRDS(df, path)
  log_step("Wrote %s (%d rows, %d vars) to %s", name, nrow(df), ncol(df), path)
  invisible(df)
}

#' Load an ADaM dataset previously written by save_adam.
load_adam <- function(name) {
  path <- file.path(PATH_ADAM, paste0(tolower(name), ".rds"))
  if (!file.exists(path)) {
    cli::cli_abort("ADaM dataset not found: {.file {path}}")
  }
  readRDS(path)
}
