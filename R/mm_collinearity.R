# Multicollinearity and redundancy diagnostics for the ENT nomogram.
#
# Sourced by ent_nomogram.R. These ran once by hand, found that the seven
# research counts were measuring one construct between them, and that is now
# collapsed (see docs/collinearity.md). Running them once is the problem: the
# next predictor added can reintroduce exactly what the collapse removed, and
# nothing would say so. These run on every fit.
#
# Three complementary questions, because each misses what the others catch:
#
#   VIF         how much a single coefficient's variance is inflated by the
#               other predictors. Per PARAMETER, so a k-level factor gets k-1
#               of them. Blind to a variable predictable from a COMBINATION of
#               others while correlating strongly with none.
#   redundancy  Hmisc::redun(): can this variable be predicted from all the
#               others? That is the question VIF cannot ask. Catches the
#               combination case.
#   pairs       the plain Spearman matrix. Neither of the above names the pair
#               a reader should look at, and a near-duplicate pair is the thing
#               a human can act on.
#
# No library() calls. Every rms, Hmisc and stats call is qualified, so sourcing
# this file needs none of them installed.

# A coefficient whose variance is inflated fourfold. sqrt(VIF) > 2 is the
# conventional flag and 4 is its square; below this the coefficient is readable.

# Hmisc::redun()'s own default, and the conventional cutoff: a variable 90%
# predictable from the others carries almost nothing of its own.

# Worth a human looking at, not worth failing over. The research cluster ran to
# 0.61 before the collapse.

#' Variance inflation factors above a threshold.
#'
#' @param fit an rms::lrm fit
#' @param max flag parameters at or above this VIF
#' @return list(vif, flagged, ok, reason); `vif` is sorted descending
#' @export
mm_vif_check <- function(fit, max = 4) {
  v <- sort(rms::vif(fit), decreasing = TRUE)
  flagged <- v[v >= max]
  list(vif = v, flagged = flagged, ok = length(flagged) == 0L,
       reason = if (length(flagged) == 0L)
         sprintf("VIF: highest %.2f (%s), none at or above %g",
                 v[1], names(v)[1], max)
       else
         sprintf("VIF: %d parameter(s) at or above %g: %s", length(flagged),
                 max, paste(sprintf("%s %.2f", names(flagged), flagged),
                            collapse = ", ")))
}

#' Redundancy: which variables are predictable from the others.
#'
#' Hmisc::redun() drops variables one at a time, so its `Out` is a sequence and
#' not a set: the second entry is redundant GIVEN the first was dropped.
#'
#' @param d predictors only, outcome already removed
#' @param r2 the cutoff above which a variable counts as redundant
#' @return list(r2_each, dropped, ok, reason)
#' @export
mm_redun_check <- function(d, r2 = 0.9) {
  # nk = 0: linear fits only. Allowing splines lets redun() predict a variable
  # from a transform of another and call it redundant, which is a statement
  # about the transform rather than about the variable.
  r <- Hmisc::redun(~ ., data = d, r2 = r2, nk = 0)
  each <- sort(r$rsq1, decreasing = TRUE)
  list(r2_each = each, dropped = r$Out, ok = length(r$Out) == 0L,
       reason = if (length(r$Out) == 0L)
         sprintf("redundancy: none at R2 >= %g; highest is %s at %.3f",
                 r2, names(each)[1], each[1])
       else
         sprintf("redundancy: %d variable(s) predictable at R2 >= %g, in order: %s",
                 length(r$Out), r2, paste(r$Out, collapse = ", ")))
}

#' The strongly correlated numeric pairs, for a human to look at.
#'
#' Spearman, because these are skewed counts and Pearson would be driven by the
#' tail. Numeric columns only: a factor's association with a count is what the
#' VIF and redundancy checks above cover.
#'
#' @return a data.frame of a, b, rho sorted by |rho| descending, possibly empty
#' @export
mm_cor_pairs <- function(d, max = 0.5) {
  num <- names(d)[vapply(d, is.numeric, logical(1))]
  if (length(num) < 2L) {
    return(data.frame(a = character(), b = character(), rho = numeric()))
  }
  m <- stats::cor(d[, num, drop = FALSE], method = "spearman",
                  use = "pairwise.complete.obs")
  m[upper.tri(m, diag = TRUE)] <- NA_real_
  ij <- which(abs(m) >= max, arr.ind = TRUE)
  out <- data.frame(a = rownames(m)[ij[, 1]], b = colnames(m)[ij[, 2]],
                    rho = m[ij], stringsAsFactors = FALSE)
  out[order(-abs(out$rho)), , drop = FALSE]
}

#' All three checks, as ent_nomogram.R reports them.
#'
#' @param fit an rms::lrm fit
#' @param d the frame it was fitted on, outcome included
#' @param outcome the outcome column's name, removed before the redundancy and
#'   correlation checks: a predictor correlated with the OUTCOME is the point of
#'   the model, not a problem with it
#' @return list(vif, redun, pairs, ok, text)
#' @export
mm_collinearity_report <- function(fit, d, outcome) {
  preds <- d[, setdiff(names(d), outcome), drop = FALSE]
  v <- mm_vif_check(fit)
  r <- mm_redun_check(preds)
  p <- mm_cor_pairs(preds)
  txt <- c(v$reason, r$reason,
           if (!nrow(p)) sprintf("pairs: no numeric pair at |rho| >= %g", 0.5)
           else sprintf("pairs at |rho| >= %g: %s", 0.5,
                        paste(sprintf("%s/%s %+.2f", p$a, p$b, p$rho),
                              collapse = ", ")))
  list(vif = v, redun = r, pairs = p, ok = v$ok && r$ok,
       text = paste(txt, collapse = "\n  "))
}

