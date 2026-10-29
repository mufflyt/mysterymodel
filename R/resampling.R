#' Draw one bootstrap resample, by patient when a cluster is declared
#'
#' With repeated observations on the same patient, resampling rows treats two
#' visits by one person as two independent facts. That narrows every interval
#' it touches. When the project declares a cluster, whole patients are drawn
#' instead, which is what the specification's clustered design asks for.
#'
#' @param cohort Rows to resample.
#' @param cluster_id Column naming the patient, or `NULL` for row-level.
#'
#' @return Integer row indices, with replacement.
#' @keywords internal
cp_resample <- function(cohort, cluster_id = NULL) {
  n <- nrow(cohort)
  if (is.null(cluster_id)) {
    return(sample.int(n, n, replace = TRUE))
  }
  if (!cluster_id %in% names(cohort)) {
    stop("`", cluster_id, "` is not a column of the cohort, so patients ",
         "cannot be resampled as units.", call. = FALSE)
  }
  ids <- as.character(cohort[[cluster_id]])
  if (anyNA(ids)) {
    stop(sum(is.na(ids)), " row(s) have no ", cluster_id, ". An ",
         "unidentified row cannot be assigned to a patient, and dropping ",
         "it silently would change the cohort.", call. = FALSE)
  }
  by_id <- split(seq_len(n), ids)
  drawn <- sample(names(by_id), length(by_id), replace = TRUE)
  unlist(by_id[drawn], use.names = FALSE)
}
