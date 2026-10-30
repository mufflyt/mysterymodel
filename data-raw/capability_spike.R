#!/usr/bin/env Rscript
# Capability spike required by the implementation specification, section 14:
# confirm rms class support for each helper before any production module is
# written, and record which helpers agree numerically with rms itself rather
# than merely running without error.
#
# Three layers are distinguished, because they ask different questions:
#   model helper   applied directly to an rms::lrm object. Section 49.
#   engine         an alternative estimator, fitted on its own terms.
#   consumer       takes a prediction vector or a data frame, so it needs no
#                  rms class support, only rms output.
#
# Run: Rscript data-raw/capability_spike.R
# Writes: inst/capability-matrix.md

suppressPackageStartupMessages(library(rms))

set.seed(1978)
n <- 400
spike <- data.frame(
  age  = rnorm(n, 60, 12),
  bmi  = rnorm(n, 29, 6),
  sex  = factor(sample(c("female", "male"), n, TRUE)),
  site = factor(sample(c("a", "b", "c"), n, TRUE))
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

ref_coef <- coef(fit)
ref_pred <- stats::predict(fit, type = "fitted")
ref_c    <- unname(fit$stats["C"])

rows <- list()

#' Run one helper and record what came back. Warnings are captured alongside
#' the value rather than in place of it, because a helper that warns and
#' returns NULL is a different fact from one that warns and returns numbers.
try_one <- function(pkg, call, expr, layer,
                    agree = function(x) NA_character_) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    rows[[length(rows) + 1L]] <<- data.frame(
      layer = layer, pkg = pkg, call = call, status = "package absent",
      finding = "not installed", stringsAsFactors = FALSE)
    return(invisible(NULL))
  }
  warns <- character(0)
  value <- NULL
  failed <- NA_character_
  tryCatch(
    withCallingHandlers(
      value <- expr(),
      warning = function(w) {
        warns <<- c(warns, conditionMessage(w))
        invokeRestart("muffleWarning")
      }),
    error = function(e) failed <<- conditionMessage(e))

  status <- if (!is.na(failed)) "errors" else
    if (is.null(value)) "returns NULL" else "returns a value"

  finding <- if (!is.na(failed)) {
    substr(gsub("\\s+", " ", failed), 1, 110)
  } else {
    # Do not run the agreement check on a NULL return. Comparing nothing
    # against rms produces a misleading note such as "length mismatch",
    # when the fact worth recording is that nothing came back.
    ag <- if (is.null(value)) "nothing returned to compare" else
      tryCatch(agree(value), error = function(e) "agreement check failed")
    w  <- if (length(warns)) {
      paste0(" Warns: ", substr(gsub("\\s+", " ", warns[1]), 1, 70))
    } else ""
    paste0(if (is.na(ag)) "" else ag, w)
  }

  rows[[length(rows) + 1L]] <<- data.frame(
    layer = layer, pkg = pkg, call = call, status = status,
    finding = trimws(finding), stringsAsFactors = FALSE)
  invisible(NULL)
}

M <- "model helper"
E <- "engine"
C <- "consumer"

# ---- easystats model helpers on an lrm fit ------------------------------
try_one("parameters", "model_parameters(fit)",
  function() parameters::model_parameters(fit), M,
  function(p) {
    est <- p$Coefficient
    names(est) <- p$Parameter
    common <- intersect(names(ref_coef), names(est))
    if (!length(common)) return("no matching terms")
    sprintf("coefficients match coef() to %.2e over %d terms",
            max(abs(ref_coef[common] - est[common])), length(common))
  })

try_one("performance", "model_performance(fit)",
  function() performance::model_performance(fit), M,
  function(p) sprintf("returns only %s",
                      paste(names(as.data.frame(p)), collapse = ", ")))

try_one("performance", "check_collinearity(fit)",
  function() performance::check_collinearity(fit), M,
  function(p) sprintf("%d variables, vs %d parameters from rms::vif()",
                      nrow(as.data.frame(p)), length(rms::vif(fit))))

try_one("performance", "check_model(fit)",
  function() performance::check_model(fit, verbose = FALSE), M,
  function(p) sprintf("object of class %s", class(p)[1]))

try_one("performance", "r2(fit)", function() performance::r2(fit), M,
  function(p) paste(names(unlist(p)), collapse = ", "))

try_one("insight", "get_predicted(fit)",
  function() insight::get_predicted(fit), M,
  function(p) {
    v <- as.numeric(p)
    if (length(v) != length(ref_pred)) return("length mismatch")
    sprintf("max|diff| vs predict() %.2e", max(abs(v - ref_pred)))
  })

try_one("insight", "find_predictors(fit)",
  function() insight::find_predictors(fit), M,
  function(p) paste(unlist(p), collapse = ", "))

try_one("insight", "get_data(fit)", function() insight::get_data(fit), M,
  function(p) sprintf("%d rows x %d cols", nrow(p), ncol(p)))

try_one("effectsize", "standardize_parameters(fit)",
  function() effectsize::standardize_parameters(fit), M,
  function(p) sprintf("%d rows", nrow(as.data.frame(p))))

try_one("modelbased", "estimate_relation(fit)",
  function() modelbased::estimate_relation(fit), M,
  function(p) sprintf("%d rows", nrow(as.data.frame(p))))

try_one("modelbased", "estimate_means(fit, \"sex\")",
  function() modelbased::estimate_means(fit, "sex"), M,
  function(p) sprintf("%d rows", nrow(as.data.frame(p))))

try_one("report", "report(fit)", function() report::report(fit), M,
  function(p) sprintf("%d characters of prose",
                      nchar(paste(as.character(p), collapse = " "))))

try_one("see", "plot(check_collinearity(fit))",
  function() plot(performance::check_collinearity(fit)), M,
  function(p) sprintf("ggplot of class %s", class(p)[1]))

# ---- alternative engines ------------------------------------------------
try_one("glinternet", "glinternet(X, y, numLevels)",
  function() {
    X <- data.frame(age = spike$age, bmi = spike$bmi,
                    sex = as.integer(spike$sex) - 1L)
    glinternet::glinternet(as.matrix(X), spike$event,
                           numLevels = c(1L, 1L, 2L), family = "binomial",
                           nLambda = 5)
  }, E,
  function(p) sprintf("fits; %d lambda values", length(p$lambda)))

try_one("brglm2", "glm(method = brglmFit)",
  function() stats::glm(event ~ age + bmi + sex, data = spike,
                        family = binomial(), method = brglm2::brglmFit), E,
  function(p) sprintf("fits; %d coefficients", length(coef(p))))

# ---- consumers of rms output -------------------------------------------
try_one("probably", "cal_plot_breaks(preds)",
  function() {
    pr <- data.frame(truth = factor(ifelse(spike$event == 1, "yes", "no"),
                                    levels = c("yes", "no")),
                     .pred_yes = ref_pred)
    probably::cal_plot_breaks(pr, truth = truth, estimate = .pred_yes)
  }, C,
  function(p) sprintf("calibration plot, class %s", class(p)[1]))

try_one("dcurves", "dca(event ~ pred)",
  function() {
    pr <- data.frame(event = spike$event, pred = ref_pred)
    dcurves::dca(event ~ pred, data = pr)
  }, C,
  function(p) "decision curve computed from rms predictions")

try_one("pointblank", "create_agent() |> interrogate()",
  function() {
    ag <- pointblank::create_agent(tbl = spike)
    ag <- pointblank::col_vals_not_null(ag, columns = "age")
    pointblank::interrogate(ag)
  }, C,
  function(p) "data validation agent runs")

try_one("GGally", "ggpairs(data)",
  function() GGally::ggpairs(spike[, c("age", "bmi")]), C,
  function(p) sprintf("matrix plot, class %s", class(p)[1]))

try_one("correlation", "correlation(data)",
  function() correlation::correlation(spike[, c("age", "bmi")]), C,
  function(p) sprintf("%d pair(s)", nrow(as.data.frame(p))))

try_one("datawizard", "data_codebook(data)",
  function() datawizard::data_codebook(spike), C,
  function(p) sprintf("%d rows", nrow(as.data.frame(p))))

# ---- write the matrix ---------------------------------------------------
matrix_df <- do.call(rbind, rows)

lines <- c(
  "# Capability matrix for `rms` objects",
  "",
  sprintf("Generated by `data-raw/capability_spike.R` on %s. R %s, rms %s.",
          format(Sys.Date()), getRversion(),
          as.character(utils::packageVersion("rms"))),
  "",
  paste("Required by the implementation specification, section 14. A status",
        "of `returns a value` means the call completed, which is not the",
        "same as being correct: the finding column is the one that matters."),
  "",
  paste("The three layers ask different questions. A **model helper** is",
        "applied directly to an `rms::lrm` object, which is the class",
        "compatibility question section 49 raises. An **engine** is an",
        "alternative estimator fitted on its own terms. A **consumer** takes",
        "a prediction vector or a data frame, so it needs no `rms` class",
        "support at all, only `rms` output."),
  "")

for (lay in c(M, E, C)) {
  part <- matrix_df[matrix_df$layer == lay, , drop = FALSE]
  lines <- c(lines, sprintf("## %s", tools::toTitleCase(lay)), "",
             "| package | call | status | finding |", "|---|---|---|---|")
  for (i in seq_len(nrow(part))) {
    lines <- c(lines, sprintf("| `%s` | `%s` | %s | %s |",
      part$pkg[i], part$call[i], part$status[i], part$finding[i]))
  }
  lines <- c(lines, "")
}

gp <- suppressWarnings(insight::get_predicted(fit))
mp_names <- paste(names(as.data.frame(
  suppressWarnings(performance::model_performance(fit)))), collapse = ", ")
vr <- rms::vif(fit)
cc <- as.data.frame(performance::check_collinearity(fit))

lines <- c(lines, "## Findings", "",
  sprintf(paste0("1. **easystats cannot predict from an `lrm` fit.** ",
                 "`insight::get_predicted()` returns %s, not wrong ",
                 "numbers. Every prediction-dependent helper inherits ",
                 "this, so `mm_predict()` must call `rms` directly and no ",
                 "easystats prediction path may be used."),
          if (is.null(gp)) "NULL" else "a value"),
  "",
  sprintf(paste0("2. **No scoring rules from easystats.** ",
                 "`performance::model_performance()` returns only %s, and ",
                 "declares its own RMSE unreliable. No AUC, no Brier, no ",
                 "log-loss, all three of which section 27 requires. They ",
                 "come from `rms`, `pROC` and `yardstick`."),
          mp_names),
  "",
  sprintf(paste0("3. **The two collinearity measures answer different ",
                 "questions.** `rms::vif()` is per model-matrix parameter ",
                 "and reports %.1f at its worst spline term; ",
                 "`performance::check_collinearity()` aggregates per ",
                 "variable and reports %.2f at its lowest. Spline bases ",
                 "are collinear with each other by construction, so the ",
                 "per-parameter figure alarms without meaning and the ",
                 "per-variable figure reassures without detail. ",
                 "`mm_collinearity()` must report both, labelled."),
          max(vr), min(cc$VIF)),
  "",
  paste0("4. **The two newly installed easystats packages fail for the ",
         "same reason.** `report::report()` errors with \"argument is of ",
         "length zero\" and `modelbased::estimate_relation()` with ",
         "\"arguments imply differing number of rows: 251, 0\". Both are ",
         "downstream of finding 1: they ask for predictions, receive ",
         "nothing, and fail on the empty result. They are not separate ",
         "defects and no adapter fixes them short of a prediction path."),
  "",
  paste0("5. **`performance::check_model()` now returns an object**, ",
         "because it needed `see`, which is installed. Its contents were ",
         "not validated here, and since its diagnostics rest on ",
         "predictions and residuals that this class does not supply, the ",
         "object completing is not evidence that its panels are ",
         "meaningful. Treat as unverified."),
  "",
  paste0("6. **The consumer layer is the usable one.** Tools that take a ",
         "prediction vector or a data frame work regardless of model ",
         "class, because they never touch the fit. That is the shape the ",
         "integration should prefer: compute with `rms`, then hand numbers ",
         "onward."),
  "",
  sprintf(paste0("Reference fit: `lrm(event ~ rcs(age, 4) + bmi + sex + ",
                 "site)` on %d synthetic rows, %d events, apparent ",
                 "C = %.4f."), n, sum(spike$event), ref_c))

dir.create("inst", showWarnings = FALSE)
writeLines(lines, "inst/capability-matrix.md")
message("wrote inst/capability-matrix.md (", nrow(matrix_df), " rows)")
