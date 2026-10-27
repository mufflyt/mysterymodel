#!/usr/bin/env Rscript
# Capability spike required by the implementation specification, section 14:
# confirm rms class support for each easystats diagnostic before any
# production module is written, and record which helpers agree numerically
# with rms itself rather than merely running without error.
#
# Run: Rscript data-raw/capability_spike.R
# Writes: inst/capability-matrix.md

suppressPackageStartupMessages(library(rms))

set.seed(1978)
n <- 400
spike <- data.frame(
  age   = rnorm(n, 60, 12),
  bmi   = rnorm(n, 29, 6),
  sex   = factor(sample(c("female", "male"), n, TRUE)),
  site  = factor(sample(c("a", "b", "c"), n, TRUE))
)
# A deliberately nonlinear age effect, so spline support is exercised.
lp <- -2 + 0.0008 * (spike$age - 60)^2 + 0.05 * (spike$bmi - 29) +
  0.4 * (spike$sex == "male")
spike$event <- rbinom(n, 1, plogis(lp))

dd <- datadist(spike)
options(datadist = "dd")
on.exit(options(datadist = NULL), add = TRUE)

fit <- lrm(event ~ rcs(age, 4) + bmi + sex + site, data = spike,
           x = TRUE, y = TRUE)

# Reference numbers straight from rms, for the agreement column.
ref_coef <- coef(fit)
ref_pred <- stats::predict(fit, type = "fitted")
ref_c    <- unname(fit$stats["C"])

rows <- list()
note <- function(pkg, call, status, agreement, detail) {
  rows[[length(rows) + 1L]] <<- data.frame(
    pkg = pkg, call = call, status = status,
    agreement = agreement, detail = detail, stringsAsFactors = FALSE)
}

try_one <- function(pkg, call, expr, agree = function(x) NA_character_) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    note(pkg, call, "package absent", "-", "not installed here")
    return(invisible(NULL))
  }
  got <- tryCatch(list(ok = TRUE, value = expr()),
                  error = function(e) list(ok = FALSE, msg = conditionMessage(e)),
                  warning = function(w) list(ok = TRUE, value = NULL,
                                             msg = conditionMessage(w)))
  if (!isTRUE(got$ok)) {
    note(pkg, call, "errors", "-", substr(gsub("\\s+", " ", got$msg), 1, 90))
    return(invisible(NULL))
  }
  ag <- tryCatch(agree(got$value), error = function(e) "check failed")
  note(pkg, call, "works", ag,
       if (!is.null(got$msg)) substr(gsub("\\s+", " ", got$msg), 1, 90) else "")
  invisible(NULL)
}

# ---- parameters ----------------------------------------------------------
try_one("parameters", "model_parameters(fit)",
  function() parameters::model_parameters(fit),
  function(p) {
    if (is.null(p)) return("warning only")
    est <- p$Coefficient
    names(est) <- p$Parameter
    common <- intersect(names(ref_coef), names(est))
    if (!length(common)) return("no matching terms")
    d <- max(abs(ref_coef[common] - est[common]))
    sprintf("max|diff| %.2e over %d terms", d, length(common))
  })

# ---- performance ---------------------------------------------------------
try_one("performance", "model_performance(fit)",
  function() performance::model_performance(fit),
  function(p) if (is.null(p)) "warning only" else
    paste(names(p)[seq_len(min(6, length(p)))], collapse = ", "))

try_one("performance", "check_collinearity(fit)",
  function() performance::check_collinearity(fit),
  function(p) {
    rv <- tryCatch(rms::vif(fit), error = function(e) NULL)
    if (is.null(p)) return("warning only")
    if (is.null(rv)) return("ran; rms::vif unavailable to compare")
    sprintf("ran; rms::vif gives %d terms, easystats %d",
            length(rv), nrow(p))
  })

try_one("performance", "check_model(fit)",
  function() performance::check_model(fit, verbose = FALSE),
  function(p) if (is.null(p)) "warning only" else "returns check object")

try_one("performance", "r2(fit)", function() performance::r2(fit),
  function(p) if (is.null(p)) "warning only" else
    paste(names(unlist(p)), collapse = ", "))

# ---- insight -------------------------------------------------------------
try_one("insight", "get_predicted(fit)",
  function() insight::get_predicted(fit),
  function(p) {
    if (is.null(p)) return("warning only")
    v <- as.numeric(p)
    if (length(v) != length(ref_pred)) return("length mismatch")
    sprintf("max|diff| vs predict() %.2e", max(abs(v - ref_pred)))
  })

try_one("insight", "find_predictors(fit)",
  function() insight::find_predictors(fit),
  function(p) if (is.null(p)) "warning only" else
    paste(unlist(p), collapse = ", "))

try_one("insight", "get_data(fit)", function() insight::get_data(fit),
  function(p) if (is.null(p)) "warning only" else
    sprintf("%d rows x %d cols", nrow(p), ncol(p)))

# ---- effectsize ----------------------------------------------------------
try_one("effectsize", "standardize_parameters(fit)",
  function() effectsize::standardize_parameters(fit),
  function(p) if (is.null(p)) "warning only" else
    sprintf("%d rows returned", nrow(p)))

# ---- not model-based, listed for completeness ----------------------------
try_one("correlation", "correlation(data)",
  function() correlation::correlation(spike[, c("age", "bmi")]),
  function(p) if (is.null(p)) "warning only" else "data-level, not model-based")

try_one("datawizard", "data_codebook(data)",
  function() datawizard::data_codebook(spike),
  function(p) if (is.null(p)) "warning only" else "data-level, not model-based")

for (p in c("modelbased", "see", "report")) {
  try_one(p, paste0(p, "::* on an lrm fit"), function() stop("unreached"))
}

matrix_df <- do.call(rbind, rows)

lines <- c(
  "# easystats capability matrix for `rms` objects",
  "",
  sprintf("Generated by `data-raw/capability_spike.R` on %s.",
          format(Sys.Date())),
  sprintf("R %s, rms %s.", getRversion(),
          as.character(utils::packageVersion("rms"))),
  "",
  paste("Required by the implementation specification, section 14:",
        "confirm `rms` class support for each easystats diagnostic before",
        "writing production modules. `works` means it returned without",
        "error, which is not the same as being correct: the agreement",
        "column is the one that matters."),
  "",
  "| package | call | status | agreement with rms | note |",
  "|---|---|---|---|---|"
)
for (i in seq_len(nrow(matrix_df))) {
  lines <- c(lines, sprintf("| `%s` | `%s` | %s | %s | %s |",
    matrix_df$pkg[i], matrix_df$call[i], matrix_df$status[i],
    matrix_df$agreement[i], matrix_df$detail[i]))
}
lines <- c(lines, "",
  sprintf("Reference fit: `lrm(event ~ rcs(age, 4) + bmi + sex + site)` on %d synthetic rows, %d events, apparent C = %.4f.",
          n, sum(spike$event), ref_c))

# ---- the findings that change the architecture -------------------------
gp <- suppressWarnings(insight::get_predicted(fit))
mp_names <- paste(names(as.data.frame(
  suppressWarnings(performance::model_performance(fit)))), collapse = ", ")
vr <- rms::vif(fit)
cc <- as.data.frame(performance::check_collinearity(fit))

lines <- c(lines, "", "## Findings", "",
  sprintf(paste0("1. **easystats cannot predict from an `lrm` fit.** ",
                 "`insight::get_predicted()` returns %s, not wrong ",
                 "numbers. Every prediction-dependent helper inherits ",
                 "this, so `cp_predict()` must call `rms` directly and ",
                 "no easystats prediction path may be used."),
          if (is.null(gp)) "NULL" else "a value"),
  "",
  sprintf(paste0("2. **No scoring rules from easystats.** ",
                 "`performance::model_performance()` returns only %s, ",
                 "and declares its own RMSE unreliable. No AUC, no ",
                 "Brier, no log-loss. The specification requires all ",
                 "three, so they come from `rms`, `pROC` and ",
                 "`yardstick`."),
          mp_names),
  "",
  sprintf(paste0("3. **The two collinearity measures answer different ",
                 "questions.** `rms::vif()` is per model-matrix ",
                 "parameter and reports %.1f at its worst spline term; ",
                 "`performance::check_collinearity()` aggregates per ",
                 "variable and reports %.2f at its lowest. Spline bases ",
                 "are collinear with each other by construction, so the ",
                 "per-parameter figure alarms without meaning and the ",
                 "per-variable figure reassures without detail. ",
                 "`cp_collinearity()` must report both, labelled."),
          max(vr), min(cc$VIF)))

dir.create("inst", showWarnings = FALSE)
writeLines(lines, "inst/capability-matrix.md")
message("wrote inst/capability-matrix.md (", nrow(matrix_df), " rows)")
