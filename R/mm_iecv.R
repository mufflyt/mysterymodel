#' Internal-external validation by holding out each declared cluster
#'
#' Each cluster is held out in turn. The prespecified project is refitted
#' using the remaining clusters. No row from the held-out cluster may enter
#' model fitting. The returned pooled estimate uses out-of-fold predictions,
#' not a refit on the whole sample.
#'
#' This is internal-external validation across observed clusters, not a
#' claim of transportability to an entirely new population.
#'
#' @param project An [mm_project()] with no temporal split.
#' @param cohort The cohort to partition.
#' @param cluster_col Name of the held-out site, period, or study cluster.
#' @param min_val Minimum evaluable held-out rows per fold.
#' @param min_events Minimum events and non-events in each held-out fold.
#' @return A list with per-fold metrics and pooled out-of-fold metrics.
#' @export
mm_iecv <- function(project, cohort, cluster_col,
                    min_val = 30L, min_events = 5L) {
  if (!inherits(project, "mm_project")) {
    stop("project must come from mm_project().", call. = FALSE)
  }
  if (!is.null(project$split_var)) {
    stop("mm_iecv() requires a project without a separate temporal split.",
         call. = FALSE)
  }
  if (!is.data.frame(cohort) ||
      !is.character(cluster_col) || length(cluster_col) != 1L ||
      !cluster_col %in% names(cohort)) {
    stop("cluster_col must name one column in cohort.", call. = FALSE)
  }
  if (!is.numeric(min_val) || length(min_val) != 1L ||
      !is.finite(min_val) || min_val < 1 || min_val != trunc(min_val)) {
    stop("min_val must be a positive whole number.", call. = FALSE)
  }
  if (!is.numeric(min_events) || length(min_events) != 1L ||
      !is.finite(min_events) || min_events < 1 ||
      min_events != trunc(min_events)) {
    stop("min_events must be a positive whole number.", call. = FALSE)
  }
  sites <- cohort[[cluster_col]]
  if (anyNA(sites)) {
    stop("holdout cluster has missing identifiers.", call. = FALSE)
  }
  folds <- sort(unique(as.character(sites)))
  if (length(folds) < 2L) {
    stop("internal-external validation requires two or more clusters.",
         call. = FALSE)
  }

  fold_metrics <- vector("list", length(folds))
  predictions <- vector("list", length(folds))
  for (i in seq_along(folds)) {
    held <- as.character(sites) == folds[[i]]
    training <- cohort[!held, , drop = FALSE]
    held_rows <- cohort[held, , drop = FALSE]
    if (!is.null(project$cluster_id)) {
      repeated <- intersect(
        unique(as.character(training[[project$cluster_id]])),
        unique(as.character(held_rows[[project$cluster_id]]))
      )
      repeated <- repeated[!is.na(repeated)]
      if (length(repeated)) {
        stop('IECV fold ', folds[[i]], ': ', length(repeated),
             ' subject cluster(s) appear in training and holdout.',
             call. = FALSE)
      }
    }
    eligible <- mm_evaluable(project, held_rows)
    val <- held_rows[eligible$usable, , drop = FALSE]
    y <- mm_event_indicator(val[[project$outcome]],
                            project$positive_class)
    events <- sum(y == 1L)
    nonevents <- sum(y == 0L)
    if (nrow(val) < min_val || events < min_events ||
        nonevents < min_events) {
      stop("IECV fold ", folds[[i]], " has ", nrow(val),
           " evaluable rows, ", events, " events and ",
           nonevents, " non-events; minimum is ",
           min_val, " rows and ", min_events, " of each class.",
           call. = FALSE)
    }
    base::message("IECV fold ", folds[[i]], ": training=",
                  nrow(training), ", evaluable held-out=",
                  nrow(val))
    fitted <- mm_model(project, training)
    risks <- mm_predict(fitted, val)$.pred
    fold_metrics[[i]] <- mm_metrics(
      risks, y, basis = paste0("IECV: ", folds[[i]])
    )
    predictions[[i]] <- data.frame(
      cluster = folds[[i]], truth = y, risk = risks,
      stringsAsFactors = FALSE
    )
  }
  scored <- do.call(rbind, predictions)
  pooled <- mm_metrics(scored$risk, scored$truth,
                       basis = "IECV pooled out-of-fold")
  list(folds = do.call(rbind, fold_metrics),
       pooled = pooled, predictions = scored,
       cluster_col = cluster_col, n_folds = length(folds))
}
