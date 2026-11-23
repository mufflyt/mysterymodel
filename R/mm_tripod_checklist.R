#' Evidence-grounded reporting checklist
#'
#' This does not manufacture TRIPOD+AI findings. The caller supplies the
#' reporting items, statuses, and a machine-readable evidence manifest.
#' A claim of "Met" must resolve to a written artifact and a value in it.
#'
#' @param manifest Data frame: item, status, artifact, column, row, reason.
#' @param root Root for artifact paths.
#' @return A data frame retaining verified evidence and explicit absences.
#' @export
mm_tripod_checklist <- function(manifest, root = ".") {
  needed <- c("item", "status", "artifact", "column", "row", "reason")
  if (!is.data.frame(manifest) ||
      !all(needed %in% names(manifest))) {
    stop("manifest requires: ", paste(needed, collapse = ", "),
         call. = FALSE)
  }
  allowed <- c("Met", "Partial", "Not reported", "N/A")
  if (anyNA(manifest$status) ||
      any(!manifest$status %in% allowed)) {
    stop("Invalid reporting status. Never substitute an optimistic status.",
         call. = FALSE)
  }
  if (anyDuplicated(manifest$item)) {
    stop("Each reporting item must appear exactly once.", call. = FALSE)
  }
  if (!dir.exists(root)) stop("Artifact root is missing.", call. = FALSE)
  need_evidence <- manifest$status %in% c("Met", "Partial")
  if (any(need_evidence & (is.na(manifest$artifact) |
      !nzchar(manifest$artifact)))) {
    stop("Met or Partial items require written evidence.", call. = FALSE)
  }
  na_items <- manifest$status == "N/A"
  if (any(na_items & (is.na(manifest$reason) |
      !nzchar(trimws(manifest$reason))))) {
    stop("N/A requires an explicit justification.", call. = FALSE)
  }
  verified <- rep(NA_character_, nrow(manifest))
  for (i in which(need_evidence)) {
    path <- file.path(root, manifest$artifact[[i]])
    if (!file.exists(path)) {
      stop("Missing written evidence for ", manifest$item[[i]],
           ": ", path, call. = FALSE)
    }
    if (!grepl("[.]csv$", path, ignore.case = TRUE)) {
      stop("Evidence must be CSV for auditable numeric extraction: ",
           path, call. = FALSE)
    }
    sheet <- utils::read.csv(path, check.names = FALSE)
    column <- manifest$column[[i]]
    index <- manifest$row[[i]]
    if (is.na(column) || !column %in% names(sheet) ||
        length(index) != 1L || is.na(index) ||
        index < 1 || index > nrow(sheet) ||
        index != trunc(index)) {
      stop("Invalid evidence selector for ", manifest$item[[i]],
           call. = FALSE)
    }
    value <- sheet[[column]][[as.integer(index)]]
    if (length(value) != 1L || is.na(value)) {
      stop("Evidence value missing for ", manifest$item[[i]],
           call. = FALSE)
    }
    verified[[i]] <- as.character(value)
  }
  response <- manifest
  response$verified_value <- verified
  response
}
