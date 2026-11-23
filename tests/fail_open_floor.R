# Fail-open protection for standalone checks and mutation probes.
# A count alone is not a valid verdict.
mm_fail_open_floor <- function(ran, skipped) {
  if (length(ran) != 1L || length(skipped) != 1L ||
      !is.numeric(ran) || !is.numeric(skipped) ||
      anyNA(c(ran, skipped)) || any(c(ran, skipped) < 0)) {
    stop("ran and skipped must be nonnegative scalar counts.",
         call. = FALSE)
  }
  if (ran == 0L || skipped > ran) {
    stop(sprintf(
      "FAIL-OPEN: %d checks ran and %d skipped; no valid pass verdict.",
      ran, skipped
    ), call. = FALSE)
  }
  invisible(TRUE)
}
