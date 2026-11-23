# The mutation campaign driver that produced the MP01-MP12 rows in
# review/mutation-evidence.csv. Kept so the run can be repeated rather than
# taken on trust.
#
#   python3 -I review/mutation-campaign.py
#
# It edits files under R/ in place and restores them, so run it on a clean
# tree and check `git status` afterwards. Every file is hash-compared against
# its pre-mutation state and the comparison is printed.
#
# WHAT THIS DRIVER LEARNED THE HARD WAY, because each rule below is a defect it
# shipped at least once:
#
#   1. A mutation whose anchor does not match EXACTLY ONCE is INVALID, never a
#      pass and never a survivor. An earlier run used a perl \Q pattern that
#      silently did not apply, and would have scored a meaningless pass.
#   2. A run that produces no result line is INVALID, not SURVIVED. The first
#      version of this driver defaulted a missing result to SURVIVED for all
#      four mutations in a campaign, which is a classification taken from a
#      tool that never reported.
#   3. The baseline must be green before any mutation is judged, because a
#      suite that is red for an unrelated reason reports every mutation
#      detected while testing nothing.
#   4. The comparison on the baseline line is on TOKENS, not on the whole
#      string: cat() emits a trailing space and an exact-string check aborted a
#      valid campaign.
#   5. Each mutant runs in a separate Rscript process, so a mutated definition
#      cannot leak into the next run.
#
# A standing, package-native version of this harness is staged in PR #27 as
# tests/mutate.R and should replace this file once it has passed its own
# self-tests.

import io, os, subprocess, hashlib, sys

REPO = "/Users/tylermuffly/mysterymodel"
FILTER = "decision-curve|recalibrate|collinearity"
RS = '''
r <- testthat::test_local(filter = "%s",
                          reporter = testthat::SilentReporter$new(),
                          stop_on_failure = FALSE)
d <- as.data.frame(r)
cat("RESULT FAIL", sum(d$failed), "ERR", sum(d$error), "\\n")
n <- 0
for (x in r) for (e in x$results) {
  if (inherits(e, "expectation_failure") || inherits(e, "expectation_error")) {
    n <- n + 1
    if (n <= 1) cat("EVID", x$test, "::", gsub("\\n", " ", conditionMessage(e)), "\\n")
  }
}
''' % FILTER

M = [
 ("MP01", "decision curve: keep NA rows instead of dropping them",
  "R/decision_curve.R",
  "  keep <- !is.na(y) & !is.na(pred)\n  dropped <- sum(!keep)",
  "  keep <- rep(TRUE, length(y))\n  dropped <- 0L"),
 ("MP02", "decision curve: drop the threshold range guard",
  "R/decision_curve.R",
  """  if (!length(thresholds) || anyNA(thresholds) || !is.numeric(thresholds) ||
      any(thresholds < 0) || any(thresholds >= 1)) {""",
  "  if (FALSE) {"),
 ("MP03", "decision curve: treat ties above the threshold, not at it",
  "R/decision_curve.R",
  "  tp <- vapply(thresholds, function(t) sum(p >= t & y == 1L), numeric(1))",
  "  tp <- vapply(thresholds, function(t) sum(p > t & y == 1L), numeric(1))"),
 ("MP04", "decision curve: accept an event level the outcome lacks",
  "R/decision_curve.R",
  '  mm_check_positive(obs, positive, "mm_decision_curve")\n', ""),
 ("MP05", "decision curve: accept a linear predictor as a probability",
  "R/decision_curve.R",
  "  if (any(pred < 0 | pred > 1, na.rm = TRUE)) {", "  if (FALSE) {"),
 ("MP06", "recalibrate: test the slope against 0 instead of against 1",
  "R/recalibrate.R",
  "  z <- (unname(cf[[2]]) - 1) / se[[2]]",
  "  z <- unname(cf[[2]]) / se[[2]]"),
 ("MP07", "recalibrate: allow a slope that reorders patients",
  "R/recalibrate.R", "  if (b <= 0) {", "  if (FALSE) {"),
 ("MP08", "recalibrate: drop Rubin's between-imputation inflation",
  "R/recalibrate.R",
  "  total <- within + (1 + 1 / m) * between", "  total <- within"),
 ("MP09", "recalibrate: average non-finite imputations in instead of dropping",
  "R/recalibrate.R",
  "  keep <- is.finite(est) & is.finite(se)\n  est <- est[keep]\n  se <- se[keep]",
  "  keep <- rep(TRUE, length(est))"),
 ("MP10", "collinearity: leave the outcome in the predictor frame",
  "R/collinearity.R",
  "  preds <- dev[, intersect(project$predictors, names(dev)), drop = FALSE]",
  "  preds <- dev"),
 ("MP11", "collinearity: skip the development-cohort check",
  "R/collinearity.R",
  '  mm_same_development(model, dev, "these collinearity diagnostics")\n', ""),
 ("MP12", "collinearity: report pairs unsorted",
  "R/collinearity.R",
  "  out[order(-abs(out$rho)), , drop = FALSE]", "  out"),
]

def md5(p):
    return hashlib.md5(io.open(p, "rb").read()).hexdigest()

def run():
    return subprocess.run(["Rscript", "-e", RS], cwd=REPO,
                          capture_output=True, text=True)

print("=== BASELINE")
b = run()
bl = [l for l in b.stdout.splitlines() if l.startswith("RESULT")]
if not bl:
    print("NO RESULT LINE; rc=%s" % b.returncode)
    print(b.stderr[-600:]); sys.exit("baseline did not report")
print("   " + bl[0])
if bl[0].split()[:5] != ["RESULT", "FAIL", "0", "ERR", "0"]:
    sys.exit("BASELINE NOT GREEN; no mutation can be judged")

rows = []
for mid, what, rel, old, new in M:
    path = os.path.join(REPO, rel)
    src = io.open(path, encoding="utf-8").read()
    before = md5(path)
    print("\n=== %s  %s  [%s]" % (mid, what, rel))
    if src.count(old) != 1:
        print("   MUTATION NOT APPLIED: %d match(es) -> INVALID" % src.count(old))
        rows.append([mid, rel, what, "INVALID (anchor)", "-", "-"])
        continue
    io.open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
    print("   applied: %s -> %s" % (before[:8], md5(path)[:8]))
    d = subprocess.run(["diff", "-u", "-", path], input=src,
                       capture_output=True, text=True).stdout
    for ln in d.splitlines():
        if ln[:1] in "+-" and not ln.startswith(("+++", "---")):
            print("   " + ln.rstrip()[:104])
    p = run()
    res = [l for l in p.stdout.splitlines() if l.startswith("RESULT")]
    evid = [l for l in p.stdout.splitlines() if l.startswith("EVID")]
    io.open(path, "w", encoding="utf-8").write(src)
    restored = md5(path) == before
    if not res:
        print("   NO RESULT LINE; rc=%s" % p.returncode)
        print("   stderr:", p.stderr.strip()[-300:].replace("\n", " | "))
        cls, fails = "INVALID (no report)", "-"
    else:
        print("   " + res[0])
        for e in evid:
            print("   " + e[:175])
        parts = res[0].split()
        fails = int(parts[2]) + int(parts[4])
        cls = "DETECTED" if fails > 0 else "SURVIVED"
    print("   restored=%s  %s" % (restored, cls))
    rows.append([mid, rel, what, cls, str(fails), str(restored)])

print("\n=== SUMMARY")
for r in rows:
    print(" | ".join(r))
print("detected: %d of %d" % (sum(1 for r in rows if r[3] == "DETECTED"), len(rows)))
