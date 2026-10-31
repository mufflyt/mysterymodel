#' A calculator for exactly this fitted model
#'
#' Builds a Shiny application from the model's own prediction schema: one input
#' per predictor, a dropdown for a categorical one offering only the levels the
#' model was developed on, a number for a continuous one defaulting to the
#' median the `datadist` recorded and stating the range it was developed on.
#' Scoring goes through [mm_predict()], so the calculator agrees with the model
#' by construction rather than by comparison.
#'
#' This is here because the ecosystem renderers could not be trusted with these
#' fits. `DynNom` refits the model it is handed, which means the figures on
#' screen come from coefficients re-estimated on whatever rows it recovered and
#' not from the ones that were reported. `regplot` has no `data` argument at
#' all. Both, together with `emmeans`, `marginaleffects`, `effects` and
#' `sjPlot`, also fail outright on a [mm_model()] because the formula is built
#' in an empty environment and carries no cohort to recover: see DEC-015 and
#' `inst/capability-matrix.md`. A front end over [mm_predict()] reads the
#' stored coefficients, refuses an unseen level by name and marks a row outside
#' the development range, which is the behaviour a clinical calculator needs.
#'
#' No confidence interval is shown, because [mm_predict()] does not produce one.
#'
#' @param model A [mm_model()].
#' @param title The heading. Defaults to the outcome the model predicts.
#' @param subtitle A line under the heading. Defaults to the project slug and
#'   the predictors.
#' @param threshold The risk the bands are taken relative to. The default is
#'   the development cohort's own event rate, which is the only threshold a
#'   fitted model carries; a decision threshold from a decision-curve analysis
#'   belongs here when there is one. Whatever it is, the screen says so, because
#'   a band shown without the number it is relative to is not interpretable.
#' @param higher_is Whether a higher prediction is the `"worse"` outcome, as it
#'   is for a complication, or the `"better"` one, as it is for a chance of
#'   matching. It decides which way round the colours and the gauge gradient
#'   run. The model cannot know this and the package will not guess: the
#'   default is `"worse"`, because this is a risk calculator. The band's label
#'   stays directional either way, so the colour is never the only carrier.
#' @param subject What one row is, in the singular. A clinical model scores a
#'   `"patient"`, which is the default; the ENT applicant model this was first
#'   run against scores an `"applicant"`. It is a word, not decoration: every
#'   sentence on the page uses it, and a page that calls an applicant a patient
#'   reads as though it were written for a different model.
#' @param audience Who the page is written for: a `"clinician"` scoring
#'   someone else, or the `"self"` the row is about, reading their own
#'   prediction. It changes the instructions, which are the part of a
#'   calculator a reader is most likely to act on. An applicant reading their
#'   own chance of matching needs to be told that the model describes people
#'   who share their values rather than them; a clinician does not need that
#'   and does need to be told the number is not advice.
#' @param event What the outcome is, in the past tense, as it would complete
#'   "of 100 applicants, 15 ___". The default is the outcome column's name,
#'   which is right when the column is named for what happened (`matched`) and
#'   wrong when it is not. It is read by the sentences the page writes for the
#'   person the prediction is about, where "had the outcome" is the kind of
#'   phrasing that tells a reader this page was not written for them.
#' @param gates Inputs that another input switches off, as a named list: each
#'   name is a numeric predictor and each element gives `by` (the categorical
#'   predictor that controls it), `when` (the level at which it is switched
#'   off) and optionally `value` (what it reads while off, defaulting to the
#'   median the `datadist` recorded). A Step 2 score means nothing for an
#'   applicant who has not sat Step 2, and a form that accepts "not reported"
#'   beside a score of 250 submits a combination the model was never fitted
#'   on.
#' @param nomogram Whether to draw the model's nomogram onto the page. The
#'   sheet comes from [mm_nomogram()], so it is the verified one: it does not
#'   appear unless reading it back the way a clinician reads it reproduces
#'   [mm_predict()]. A model that cannot be drawn says why in place of the
#'   figure rather than leaving the panel empty.
#' @return A [shiny::shinyApp()] object, which launches when printed.
#'
#' @examples
#' cohort <- mm_synthetic_cohort(n = 300, seed = 1)
#' project <- mm_project("uds", "event", c("age", "bmi", "sex"),
#'                       cohort = cohort)
#' fit <- mm_model(project, cohort)
#' if (interactive() && requireNamespace("shiny", quietly = TRUE)) {
#'   mm_calculator(fit)
#' }
#' @export
mm_calculator <- function(model, title = NULL, subtitle = NULL,
                          threshold = NULL,
                          higher_is = c("worse", "better"),
                          subject = "patient",
                          audience = c("clinician", "self"),
                          event = NULL, gates = NULL, nomogram = TRUE) {
  if (!inherits(model, "mm_model")) {
    stop("`model` must come from mm_model().", call. = FALSE)
  }
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("mm_calculator() needs the shiny package.", call. = FALSE)
  }
  higher_is <- match.arg(higher_is)
  audience <- match.arg(audience)
  event <- event %||% model$schema$outcome
  gates <- mm_calculator_gates(gates, model)
  if (!is.character(subject) || length(subject) != 1L || !nzchar(subject)) {
    stop("`subject` must be a single word naming what one row is.",
         call. = FALSE)
  }
  threshold <- mm_calculator_threshold(model, threshold)
  drawn <- if (isTRUE(nomogram)) mm_calculator_nomogram(model, higher_is)
  specs <- model$schema$predictors
  ids <- mm_calculator_ids(specs)
  defaults <- mm_calculator_defaults(model)

  ui <- mm_calculator_ui(model, title, subtitle, threshold, subject,
                         drawn, audience, gates)

  server <- function(input, output, session) {
    row <- shiny::reactive({
      vals <- lapply(names(specs), function(p) {
        v <- input[[ids[[p]]]]
        if (identical(specs[[p]]$type, "categorical")) v else as.numeric(v)
      })
      shiny::req(all(lengths(vals) == 1L))
      stats::setNames(
        as.data.frame(vals, stringsAsFactors = FALSE), names(specs))
    })

    pred <- shiny::reactive(
      mm_predict(model, row(), on_missing = "na", interval = TRUE))
    prob <- shiny::reactive(pred()$.pred[1])
    band <- shiny::reactive({
      if (is.na(prob())) NULL else
        mm_calculator_band(prob(), threshold, higher_is, subject, audience,
                           event, length(model$schema$predictors))
    })

    output$gauge <- shiny::renderUI(
      mm_calculator_gauge(prob(), band(), threshold, higher_is))

    output$probability <- shiny::renderText({
      if (is.na(prob())) "--" else sprintf("%.1f%%", 100 * prob())
    })

    output$interval <- shiny::renderText({
      p <- pred()
      if (is.na(p$.lower[1]) || is.na(p$.upper[1])) return("")
      sprintf("95%% CI %.1f%% to %.1f%%", 100 * p$.lower[1], 100 * p$.upper[1])
    })

    output$interpretation <- shiny::renderUI({
      b <- band()
      if (is.null(b)) {
        shiny::tags$p(sprintf("Enter every predictor to score one %s.",
                              subject))
      } else {
        shiny::tags$p(b$recommendation)
      }
    })

    output$icons <- shiny::renderUI(
      mm_calculator_icons(prob(), band(), subject, event))

    output$extrapolation <- shiny::renderUI({
      if (!isTRUE(pred()$.extrapolated[1])) return(NULL)
      shiny::div(
        class = "alert-extrapolation",
        shiny::tags$strong("Outside the development range. "),
        "At least one value entered lies outside the range this model was ",
        "developed on. The risk shown is an extrapolation and the model ",
        "carries no evidence about patients like this one.")
    })

    # A gated input is rendered rather than fixed, so that shutting it off and
    # parking it at its value are one act. The control stays in the page while
    # it is shut, inside a disabled fieldset, so the form still submits the
    # parked value and the row is complete.
    for (p in names(gates)) {
      local({
        gp <- p
        g <- gates[[gp]]
        output[[paste0(ids[[gp]], "_slot")]] <- shiny::renderUI({
          shut <- identical(input[[ids[[g$by]]]], g$when)
          mm_calculator_gated_input(gp, ids[[gp]], specs[[gp]],
                                    if (shut) g$value else defaults[[gp]],
                                    shut, g)
        })
      })
    }

    # DynNom's one good idea: a prediction on its own answers nothing, and the
    # question a reader actually has is what happens if one value were
    # different. So rows accumulate and are shown side by side.
    saved <- shiny::reactiveVal(list())

    shiny::observeEvent(input$save, {
      p <- pred()
      if (is.na(p$.pred[1])) return()
      saved(c(saved(), list(list(values = row(), pred = p$.pred[1],
                                 lower = p$.lower[1], upper = p$.upper[1],
                                 extrapolated = isTRUE(p$.extrapolated[1])))))
    })
    shiny::observeEvent(input$clear_saved, saved(list()))

    output$comparison <- shiny::renderUI(
      mm_calculator_comparison(saved(), threshold, higher_is, subject,
                               specs))

    shiny::observeEvent(input$reset, {
      defaults <- mm_calculator_defaults(model)
      for (p in names(specs)) {
        if (identical(specs[[p]]$type, "categorical")) {
          shiny::updateSelectInput(session, ids[[p]], selected = defaults[[p]])
        } else {
          shiny::updateNumericInput(session, ids[[p]], value = defaults[[p]])
        }
      }
    })
  }

  shiny::shinyApp(ui, server)
}

#' The risk the calculator's bands are taken relative to
#'
#' A fitted model carries exactly one threshold that means anything without a
#' further analysis, which is the rate at which the outcome occurred in the
#' cohort it was developed on. A decision threshold is a different object: it
#' comes from a decision curve and the clinical cost of each error, neither of
#' which this package has. So the default is the development prevalence and the
#' screen names it, rather than a round number that would look like a standard.
#'
#' @param model A [mm_model()].
#' @param threshold A supplied threshold, or `NULL`.
#' @return A single probability.
#' @keywords internal
mm_calculator_threshold <- function(model, threshold = NULL) {
  if (is.null(threshold)) return(model$adequacy$prevalence)
  if (!is.numeric(threshold) || length(threshold) != 1L || is.na(threshold) ||
      threshold <= 0 || threshold >= 1) {
    stop("`threshold` must be a single probability strictly between 0 and 1.",
         call. = FALSE)
  }
  threshold
}

#' Which band a predicted risk falls in
#'
#' The cut points are odds ratios against the reference, not multiples of it.
#' Multiples of a probability look natural and stop working as soon as the
#' outcome is common: twice a 62% match rate is not a probability, so on the
#' ENT applicant cohort every patient above the reference fell in one band and
#' the top two could not be reached at all. A logistic model is linear in the
#' log odds, so a band taken on the odds ratio is a band on the scale the model
#' works in, it is symmetric about the reference, and it behaves the same at a
#' 9% event rate as at a 62% one.
#'
#' The band is a position relative to the development cohort. Whether that
#' position is good or bad is not something the model knows, so `higher_is`
#' decides which end of the colour ramp it takes, and the label stays
#' directional either way.
#'
#' @param prob A predicted probability.
#' @param threshold The risk the bands are relative to.
#' @param higher_is `"worse"` when a higher prediction is the bad outcome,
#'   `"better"` when it is the good one.
#' @param subject What one row is, in the singular.
#' @return A list: `level`, `color`, `odds_ratio` and `recommendation`. The
#'   band's position is carried by the colour and by the sentence, not by a
#'   label of its own: a pill reading WELL BELOW REFERENCE is a verdict
#'   printed larger than the number it is about, and the sentence beneath it
#'   already says the same thing in a form a reader can weigh.
#' @keywords internal
mm_calculator_band <- function(prob, threshold,
                               higher_is = c("worse", "better"),
                               subject = "patient",
                               audience = c("clinician", "self"),
                               event = "the outcome",
                               n_predictors = NULL) {
  higher_is <- match.arg(higher_is)
  audience <- match.arg(audience)
  odds <- function(x) x / (1 - x)
  or <- if (prob >= 1) Inf else if (prob <= 0) 0 else odds(prob) / odds(threshold)

  position <- if (or < 0.5) 1L else if (or < 1) 2L else if (or < 2) 3L else 4L
  level <- c("well-below", "below", "above", "well-above")[position]
  severity <- if (identical(higher_is, "worse")) position else 5L - position
  color <- c("#10b981", "#f59e0b", "#f97316", "#ef4444")[severity]

  recommendation <- if (identical(audience, "clinician")) {
    mm_band_text_clinician(prob, threshold, or, level, subject)
  } else {
    mm_band_text_self(prob, threshold, level, subject, event, n_predictors)
  }

  list(level = level, color = color, odds_ratio = or,
       recommendation = recommendation)
}

#' What the band means, for someone scoring another person
#'
#' The odds ratio is here because a clinician reading a model's output can use
#' it and because it is the quantity the band was cut on. It is the wrong
#' thing to put in front of the person the prediction is about.
#'
#' @param prob,threshold Probabilities.
#' @param or The odds ratio against the reference.
#' @param level The band.
#' @param subject What one row is, in the singular.
#' @return A single string.
#' @keywords internal
mm_band_text_clinician <- function(prob, threshold, or, level, subject) {
  pct <- function(x) sprintf("%.1f%%", 100 * x)
  comparison <- if (!is.finite(or)) {
    "The odds against the reference are unbounded."
  } else {
    sprintf("That is %.2f times the odds in the development cohort.", or)
  }
  tail_text <- c(
    "well-below" = paste("This", subject, "sits well below the rate at which",
      "the outcome occurred in the development cohort. The model separates",
      "one", paste0(subject, " from another;"), "it does not decide what to",
      "do about either."),
    "below" = paste("This", subject, "sits below the development cohort's own",
      "rate, but within a factor of two on the odds. Whether that separation",
      "is large enough to act on depends on the cost of each error, which",
      "this model does not know."),
    "above" = paste("This", subject, "sits above the development cohort's own",
      "rate, within a factor of two on the odds. Read it alongside the",
      "factors the model does not contain."),
    "well-above" = paste("This", subject, "sits well above the development",
      "cohort's rate. Note that the most extreme predictions are where a",
      "model is least reliable; see the panel below for what this one was",
      "fitted on."))
  paste(sprintf("Predicted %s against a reference of %s. %s",
                pct(prob), pct(threshold), comparison),
        unname(tail_text[level]))
}

#' What the band means, for the person it is about
#'
#' A different piece of writing, not the same one with simpler words. Someone
#' reading their own number is not weighing a decision about a third party;
#' they are being told something about themselves by a machine, and the three
#' things they need are what the number counts, what it cannot see, and what
#' to do next.
#'
#' So: no odds ratio, because a ratio of odds is not a fact anyone can hold
#' about themselves. A count out of a hundred instead, for both the
#' prediction and the reference, because "15 in 100" is the form of this
#' quantity people read most reliably. The number of predictors is named,
#' because the strongest honest thing to say about a low prediction is how
#' little of an application the model actually saw. The low bands neither
#' reassure nor commiserate: the number is reported, what the model could not
#' see is named, and the reader is sent to someone who can advise them.
#'
#' @param prob,threshold Probabilities.
#' @param level The band.
#' @param subject What one row is, in the singular.
#' @param event What the outcome is, in the past tense, as it would complete
#'   "of 100 ..., 15 ___".
#' @param n_predictors How many predictors the model holds, or `NULL`.
#' @return A single string.
#' @keywords internal
mm_band_text_self <- function(prob, threshold, level, subject,
                              event = "the outcome", n_predictors = NULL) {
  n <- max(0L, min(100L, as.integer(round(100 * prob))))
  ref <- max(0L, min(100L, as.integer(round(100 * threshold))))

  counts <- sprintf(paste("Of 100 %ss who answered this form the way you just",
                          "did, about %d %s. Across everyone in the data it",
                          "was about %d in 100."),
                    subject, n, event, ref)

  blind <- if (is.null(n_predictors)) {
    paste("This form holds a handful of things about you and nothing else.")
  } else {
    sprintf(paste("This form holds %d things about you and nothing else:",
                  "not your letters, not your interview, not the people who",
                  "know you."), n_predictors)
  }

  tail_text <- c(
    "well-below" = paste(
      blind,
      "Change an answer above and watch the number move, which is this model",
      "showing you what it weighs."),
    "below" = paste(
      "You are under the typical figure, but not by much on the scale this",
      "model works in.", blind,
      "A difference this size is smaller than the things the form cannot",
      "see."),
    "above" = paste(
      "You are above the typical figure, which is a good sign and not a",
      "promise.", blind,
      "People with this prediction do not all get there, and the ones who do",
      "still had to do the rest of it. Keep going as though the number said",
      "nothing."),
    "well-above" = paste(
      "You are well above the typical figure. Two cautions come with that:",
      "the most extreme predictions are the ones a model gets least right,",
      "and this one is reading a form, not a person.", blind,
      "It is a reason for confidence, not for fewer applications."))

  paste(counts, unname(tail_text[level]))
}

#' The gauge needle, pointed at the predicted risk
#'
#' The dial runs from zero to four times the threshold rather than to 1,
#' because a needle that has to render every clinically distinct value of a
#' low-prevalence outcome inside the first few degrees of a 0 to 100% sweep
#' shows nothing. Both ends are printed under the dial, so the sweep cannot be
#' mistaken for a percentage scale.
#'
#' @param prob A predicted probability, possibly `NA`.
#' @param band The output of [mm_calculator_band()], or `NULL`.
#' @param threshold The risk the bands are relative to.
#' @return A Shiny tag.
#' @keywords internal
mm_calculator_gauge <- function(prob, band, threshold,
                                higher_is = c("worse", "better")) {
  higher_is <- match.arg(higher_is)
  top <- min(1, 4 * threshold)
  if (is.na(prob) || is.null(band)) {
    rotation <- -90
    color <- "#cbd5e1"
  } else {
    rotation <- -90 + 180 * min(1, prob / top)
    color <- band$color
  }
  shiny::tagList(
    shiny::div(
      class = "gauge-container",
      shiny::div(
        class = if (identical(higher_is, "better")) "gauge-bg gauge-bg-good-high"
                else "gauge-bg",
        shiny::div(class = "gauge-mask"),
        shiny::div(class = "gauge-needle",
                   style = sprintf("transform: rotate(%fdeg); background-color: %s;",
                                   rotation, color)),
        shiny::div(class = "gauge-center",
                   style = sprintf("background-color: %s;", color)))),
    shiny::div(class = "gauge-scale",
               shiny::span("0%"),
               shiny::span(if (top >= 1) "100%"
                           else sprintf("%.0f%% or more", 100 * top))))
}

#' A hundred figures, of which the predicted number are marked
#'
#' The frequency format, because a probability read as a percentage is
#' understood less reliably than the same quantity read as a count out of a
#' hundred. Rounding is to the nearest whole patient, which is what the format
#' can honestly carry.
#'
#' @param prob A predicted probability, possibly `NA`.
#' @param band The output of [mm_calculator_band()], or `NULL`.
#' @param subject What one row is, in the singular.
#' @param event What the outcome is, in the past tense.
#' @return A Shiny tag.
#' @keywords internal
mm_calculator_icons <- function(prob, band, subject = "patient",
                                event = "had the outcome") {
  if (is.na(prob) || is.null(band)) return(NULL)
  n <- max(0L, min(100L, as.integer(round(100 * prob))))
  dots <- lapply(seq_len(100), function(i) {
    shiny::span(class = if (i <= n) "dot dot-on" else "dot",
                style = if (i <= n) sprintf("background-color: %s;", band$color) else NULL)
  })
  shiny::tagList(
    shiny::div(class = "icon-grid", dots),
    shiny::tags$p(class = "icon-caption", sprintf(
      "Each dot is one of 100 %ss with these values. The model expects %d of them to have %s.",
      subject, n, event)))
}

#' One numeric input, switched on or off
#'
#' A disabled `fieldset` rather than a removed control or a line of JavaScript.
#' The browser greys an input inside one and refuses to let it be typed in,
#' and Shiny still reports its value, so the form submits the parked figure
#' and the row stays complete. Removing the control instead would leave the
#' predictor missing and the model unable to score the row at all, which is
#' the opposite of the point.
#'
#' @param predictor The predictor's name.
#' @param id Its input identifier.
#' @param spec Its entry in the prediction schema.
#' @param value What the box reads.
#' @param shut Whether the gate is closed.
#' @param gate The gate, for the sentence explaining why.
#' @return A Shiny tag.
#' @keywords internal
mm_calculator_gated_input <- function(predictor, id, spec, value, shut, gate) {
  shown <- spec$label %||% predictor
  control <- shiny::tagList(
    shiny::numericInput(id, shown, value = value),
    shiny::tags$p(class = "help-text", if (shut) {
      sprintf("Not used while %s is \"%s\". The model was fitted with this parked at %s.",
              gate$by_label, mm_title_case(gate$when), format(gate$value))
    } else {
      sprintf("developed on %s to %s", signif(spec$range[1], 4),
              signif(spec$range[2], 4))
    }))
  if (!shut) return(control)
  shiny::tags$fieldset(disabled = "disabled", class = "gated", control)
}

#' Which inputs are switched off by another input, and at what value
#'
#' Some predictors only mean something when another one says so. A Step 2
#' score has no value for an applicant who has not sat Step 2, and a form that
#' lets a reader say "not reported" and leave 250 in the box beside it is
#' offering a combination the model was never fitted on: the model reads that
#' as an applicant with the parked score plus the not-reported offset, which
#' is not what the reader typed and not what they meant.
#'
#' So a gate names the controlling predictor, the level at which the gate
#' closes, and the value the gated input takes while it is shut. The default
#' value is the median the `datadist` recorded, which is where a parked value
#' is usually put.
#'
#' @param gates A named list, or `NULL`. Each name is a gated predictor and
#'   each element is a list with `by`, `when`, and optionally `value`.
#' @param model A [mm_model()].
#' @return The gates, normalised, with `value` and the controlling
#'   predictor's printed name filled in.
#' @keywords internal
mm_calculator_gates <- function(gates, model) {
  if (is.null(gates) || !length(gates)) return(list())
  specs <- model$schema$predictors
  if (is.null(names(gates)) || any(!nzchar(names(gates)))) {
    stop("`gates` must be a named list, one name per gated predictor.",
         call. = FALSE)
  }
  lapply(stats::setNames(names(gates), names(gates)), function(p) {
    g <- gates[[p]]
    if (!p %in% names(specs)) {
      stop("`gates` names `", p, "`, which this model has no predictor for. ",
           "It has ", paste(names(specs), collapse = ", "), ".", call. = FALSE)
    }
    if (!identical(specs[[p]]$type, "numeric")) {
      stop("`gates$", p, "` gates a categorical predictor. A dropdown already ",
           "offers only what the model can score, so there is nothing to shut ",
           "off.", call. = FALSE)
    }
    if (is.null(g$by) || !g$by %in% names(specs)) {
      stop("`gates$", p, "$by` must name a predictor of this model.",
           call. = FALSE)
    }
    by <- specs[[g$by]]
    if (!identical(by$type, "categorical")) {
      stop("`gates$", p, "$by` names `", g$by, "`, which is not categorical. ",
           "A gate is shut by a level, so the controlling predictor must have ",
           "levels.", call. = FALSE)
    }
    if (is.null(g$when) || !as.character(g$when) %in% by$levels) {
      stop("`gates$", p, "$when` must be a level of `", g$by, "`. It has ",
           paste(by$levels, collapse = ", "), ".", call. = FALSE)
    }
    value <- g$value %||% unname(model$datadist$limits["Adjust to", p])
    if (!is.numeric(value) || length(value) != 1L || is.na(value)) {
      stop("`gates$", p, "$value` must be a single number.", call. = FALSE)
    }
    list(by = g$by, by_label = by$label %||% g$by,
         when = as.character(g$when), value = value)
  })
}

#' The value each input starts at, and returns to
#'
#' One definition read by the form and by the reset button, so that what
#' "reset" restores cannot drift from what the form opened with.
#'
#' Both come from the `datadist`'s "Adjust to" row, which holds the median of
#' each continuous predictor and the commonest level of each categorical one.
#' That is the cohort's most ordinary member, and it is where the model is
#' most certain, because the standard error of a prediction grows with
#' distance from the middle of the data the model was fitted on. Opening
#' there means the first number a reader sees is the one the model is best
#' placed to make.
#'
#' The obvious alternative, each factor's first level, is what this used to
#' do, and it is worse in a way that is easy to miss: first levels are chosen
#' for the model's arithmetic, not for how common they are, and combining one
#' per predictor can produce somebody almost nobody is. On the ENT applicant
#' model it opened on an international graduate needing work authorisation on
#' a second attempt with no Step 2 score, whose interval was among the widest
#' in the cohort.
#'
#' A level the fit never saw cannot be offered, so an "Adjust to" value that
#' is not in the schema falls back to the first level. That happens when a
#' level was carried only by rows dropped for incompleteness.
#'
#' @param model A [mm_model()].
#' @return A named list, one element per predictor.
#' @keywords internal
mm_calculator_defaults <- function(model) {
  specs <- model$schema$predictors
  stats::setNames(lapply(names(specs), function(p) {
    typical <- unname(model$datadist$limits["Adjust to", p])
    if (identical(specs[[p]]$type, "categorical")) {
      typical <- as.character(typical)
      if (length(typical) != 1L || is.na(typical) ||
          !typical %in% specs[[p]]$levels) {
        return(specs[[p]]$levels[1])
      }
      typical
    } else {
      typical
    }
  }), names(specs))
}

#' The rows a reader has kept, side by side
#'
#' Taken from `DynNom`, which is the one thing that package does that this one
#' did not: a prediction on its own answers nothing, and the question a reader
#' actually has is what the number would be if one value were different. So
#' rows accumulate and are drawn against a common scale, with the interval
#' beside each, which is the only way the difference between two of them can
#' be read honestly.
#'
#' Drawn as bars rather than through a plotting package. `DynNom` reaches for
#' `plotly` and `ggplot2` to put eleven points on one axis; the same picture
#' is a few positioned divs, and a calculator that needs no graphics device is
#' one that can be served anywhere.
#'
#' @param saved A list of kept rows, each with `values`, `pred`, `lower`,
#'   `upper` and `extrapolated`.
#' @param threshold The risk the bands are relative to.
#' @param higher_is Whether a higher prediction is the worse outcome.
#' @param subject What one row is, in the singular.
#' @param specs The schema's predictors.
#' @return A Shiny tag, or `NULL` when nothing has been kept.
#' @keywords internal
mm_calculator_comparison <- function(saved, threshold,
                                     higher_is = "worse",
                                     subject = "patient", specs = NULL) {
  if (!length(saved)) return(NULL)
  top <- min(1, max(4 * threshold,
                    vapply(saved, function(r) r$upper, numeric(1)) * 1.05))
  pos <- function(x) 100 * min(1, max(0, x)) / top
  at <- function(x) sprintf("%.4f%%", pos(x))

  rows <- lapply(seq_along(saved), function(i) {
    r <- saved[[i]]
    band <- mm_calculator_band(r$pred, threshold, higher_is, subject)
    # Every value that produced the row, so a kept row can be told apart from
    # its neighbour without being read back into the form.
    detail <- paste(vapply(names(r$values), function(p)
      paste0(if (is.null(specs)) p else specs[[p]]$label %||% p, ": ",
             format(r$values[[p]][1])), character(1)), collapse = ", ")

    shiny::div(
      class = "compare-row", title = detail,
      shiny::div(class = "compare-n", i),
      shiny::div(
        class = "compare-track",
        shiny::div(class = "compare-ci",
                   style = sprintf("left: %s; right: %.4f%%;", at(r$lower),
                                   100 - pos(r$upper))),
        shiny::div(class = "compare-dot",
                   style = sprintf("left: %s; background-color: %s;",
                                   at(r$pred), band$color))),
      shiny::div(class = "compare-figure",
                 sprintf("%.1f%%", 100 * r$pred),
                 shiny::tags$span(class = "compare-ci-text",
                                  sprintf(" (%.1f to %.1f)", 100 * r$lower,
                                          100 * r$upper)),
                 if (r$extrapolated)
                   shiny::tags$span(class = "compare-flag", " extrapolated")))
  })

  shiny::div(
    class = "nomogram-card",
    shiny::h4("Predictions"),
    shiny::tags$p(class = "result-sub", sprintf(paste(
      "Each row is one set of answers you pressed the button on, so you can",
      "change a value and see what it moves. The dot is the estimate and the",
      "bar is its 95%% interval, both on a common scale ending at %.0f%%.",
      "Hover a row for the values that produced it."),
      100 * top)),
    shiny::div(class = "compare-list", rows),
    shiny::actionButton("clear_saved", "Clear the list", class = "btn-reset"))
}

#' Draw the model's nomogram for the page, or say why there is none
#'
#' Drawn once when the application is built, not per session, because the sheet
#' is a property of the fitted model and nothing on the page changes it. The
#' figure is served from a temporary directory rather than embedded, so a
#' large nomogram does not inflate every page load.
#'
#' The drawing goes through [mm_nomogram()], which refuses to return a sheet
#' that disagrees with [mm_predict()] when read back. That refusal is the
#' reason the nomogram can be shown beside the calculator at all: the two
#' would otherwise be two instruments that merely look like each other.
#'
#' @param model A [mm_model()].
#' @param higher_is Whether a higher prediction is the worse outcome.
#' @return A list with `src` and `nom` when the model could be drawn, or
#'   `refusal` when it could not. `NULL` when the drawing device is absent.
#' @keywords internal
mm_calculator_nomogram <- function(model, higher_is = "worse") {
  if (!requireNamespace("ragg", quietly = TRUE)) return(NULL)
  dir <- file.path(tempdir(),
                   paste0("mm-nomogram-", substr(model$fingerprint, 1, 12)))
  out <- tryCatch(
    suppressMessages(
      mm_nomogram(model, out_dir = dir,
                  funlabel = if (identical(higher_is, "better")) "Predicted chance"
                             else "Predicted risk")),
    error = function(e) conditionMessage(e))
  if (is.character(out)) return(list(refusal = out))

  png <- grep("[.]png$", out$files, value = TRUE)
  if (!length(png)) return(NULL)
  # The prefix carries the fingerprint, so two calculators for two models in
  # one process serve two sheets rather than one of them serving the other's.
  prefix <- paste0("mmnom-", substr(model$fingerprint, 1, 12))
  shiny::addResourcePath(prefix, dirname(png[1]))
  list(src = file.path(prefix, basename(png[1])), nom = out)
}

#' The nomogram panel, with the check that lets it be shown
#'
#' @param drawn The output of [mm_calculator_nomogram()], or `NULL`.
#' @return A Shiny tag, or `NULL`.
#' @keywords internal
mm_calculator_nomogram_panel <- function(drawn) {
  if (is.null(drawn)) return(NULL)
  if (!is.null(drawn$refusal)) {
    return(shiny::div(
      class = "nomogram-card",
      shiny::h4("Nomogram"),
      shiny::div(class = "adequacy adequacy-short",
                 shiny::tags$strong("This model cannot be drawn as a nomogram. "),
                 drawn$refusal)))
  }

  nom <- drawn$nom
  fig <- function(x) format(signif(x, 3), scientific = TRUE)
  shiny::div(
    class = "nomogram-card",
    shiny::h4("Nomogram"),
    shiny::tags$p(class = "result-sub", paste(
      "The same model on paper. Read each axis to its points, add them, and",
      "find the total on the bottom scale.")),
    shiny::tags$img(src = drawn$src, class = "nomogram-img",
                    alt = "Nomogram for this model"),
    shiny::div(
      class = "adequacy adequacy-ok",
      shiny::tags$strong("Checked against the model, not assumed to match it. "),
      sprintf(paste("Reading this sheet back the way a clinician reads it,",
                    "across %d tabulated profile(s) on %d axes, reproduces the",
                    "calculator above to %s. It would not have been drawn",
                    "otherwise."),
              nom$profiles_checked, nom$n_axes, fig(nom$worst_disagreement))),
    shiny::tags$p(class = "icon-caption", sprintf(paste(
      "Reading between the printed ticks costs up to %s in predicted",
      "probability. A straight edge interpolates between ticks and a curved",
      "term does not, so the bound is larger when a predictor is splined.",
      "It is a property of every printed nomogram, not of this one."),
      fig(nom$reading_error))),
    if (length(nom$exclusive_axes)) {
      shiny::div(class = "adequacy adequacy-short",
                 shiny::tags$strong("Score one axis per group. "),
                 paste("These axes are alternatives, not additions:",
                       paste(vapply(nom$exclusive_axes, paste, character(1),
                                    collapse = " / "), collapse = "; ")),
                 ". Scoring two of a group counts the same person twice, and",
                 " nothing in the arithmetic can see that happen on paper.")
    })
}

#' Positional input identifiers for the calculator
#'
#' A predictor may be named anything a data frame permits, and a Shiny input
#' identifier may not, so the identifiers are positional and both halves of the
#' application derive them the same way.
#'
#' @param specs The `predictors` element of a prediction schema.
#' @return A character vector of identifiers, named by predictor.
#' @keywords internal
mm_calculator_ids <- function(specs) {
  stats::setNames(paste0("p", seq_along(specs)), names(specs))
}

#' The calculator's inputs, read from the prediction schema
#'
#' Separate from [mm_calculator()] so that what a clinician is offered can be
#' checked without a browser: a dropdown must contain the levels the model was
#' developed on and no others.
#'
#' @param model A [mm_model()].
#' @param title The heading, or `NULL` for the default.
#' @param subtitle The line under it, or `NULL` for the default.
#' @param threshold The risk the bands are relative to.
#' @param subject What one row is, in the singular.
#' @param drawn The output of [mm_calculator_nomogram()], or `NULL`.
#' @param audience Who the page is written for.
#' @param gates Inputs another input switches off, already normalised by
#'   [mm_calculator_gates()].
#' @return A Shiny UI definition.
#' @keywords internal
mm_calculator_ui <- function(model, title = NULL, subtitle = NULL,
                             threshold = NULL, subject = "patient",
                             drawn = NULL,
                             audience = c("clinician", "self"),
                             gates = list()) {
  audience <- match.arg(audience)
  specs <- model$schema$predictors
  ids <- mm_calculator_ids(specs)
  defaults <- mm_calculator_defaults(model)
  threshold <- mm_calculator_threshold(model, threshold)
  title <- title %||% paste("Predicted risk of", model$schema$outcome)
  subtitle <- subtitle %||% paste0(
    model$project$slug, ": ", length(specs), " predictor(s), ",
    paste(names(specs), collapse = ", "))

  shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$title(title),
      shiny::tags$link(
        rel = "stylesheet",
        href = paste0("https://fonts.googleapis.com/css2?",
                      "family=Outfit:wght@400;500;600;700;800&",
                      "family=Plus+Jakarta+Sans:wght@400;500;600;700&",
                      "display=swap")),
      shiny::tags$style(shiny::HTML(mm_calculator_css()))),

    shiny::div(
      class = "header-banner",
      shiny::h1(title),
      shiny::h4(subtitle)),

    shiny::div(
      class = "main-container",
      shiny::fluidRow(
        shiny::column(
          4,
          shiny::div(
            class = "input-card",
            shiny::h4(paste0(toupper(substring(subject, 1, 1)),
                             substring(subject, 2), " values")),
            lapply(names(specs), function(p) {
              spec <- specs[[p]]
              # A gated input is drawn by the server, because whether it is
              # switched on depends on another input's value.
              if (p %in% names(gates))
                return(shiny::uiOutput(paste0(ids[[p]], "_slot")))
              # The schema carries the printed name, so the form and the
              # nomogram axis for one predictor cannot read differently.
              shown <- spec$label %||% p
              if (identical(spec$type, "categorical")) {
                shiny::tagList(
                  # Names are shown, values are submitted. The value stays
                  # the level the fit knows, because mm_predict() refuses a
                  # level it has not seen and a tidier spelling is exactly
                  # that.
                  shiny::selectInput(
                    ids[[p]], shown,
                    choices = stats::setNames(spec$levels,
                                              mm_title_case(spec$levels)),
                    selected = defaults[[p]]),
                  shiny::tags$p(class = "help-text", sprintf(
                    "%d level(s) seen in development", length(spec$levels))))
              } else {
                shiny::tagList(
                  shiny::numericInput(ids[[p]], shown, value = defaults[[p]]),
                  shiny::tags$p(class = "help-text", sprintf(
                    "developed on %s to %s",
                    signif(spec$range[1], 4), signif(spec$range[2], 4))))
              }
            })),
          shiny::actionButton("save", paste("Add this", subject, "to the list"),
                              class = "btn-save"),
          shiny::actionButton("reset", "Reset to cohort medians",
                              class = "btn-reset")),

        shiny::column(
          8,
          shiny::div(
            # Sticky, because a model with many predictors makes a form longer
            # than its own result. On the ENT applicant model, 27 predictors,
            # scrolling to the last of them left the prediction off the top of
            # the screen and the right-hand half of the page empty.
            class = "result-sticky",
          shiny::div(
            class = "result-card",
            shiny::h3("Prediction"),
            shiny::tags$p(class = "result-sub",
                          "Read from the stored coefficients. Nothing is refitted."),
            shiny::uiOutput("gauge"),
            shiny::div(class = "gauge-value",
                       shiny::textOutput("probability", inline = TRUE)),
            shiny::div(class = "ci-display",
                       shiny::textOutput("interval", inline = TRUE)),
            shiny::uiOutput("extrapolation"),
            shiny::div(
              class = "interpretation-box",
              shiny::h5("What this means"),
              shiny::uiOutput("interpretation")),
            shiny::div(class = "icon-grid-container",
                       shiny::uiOutput("icons")),
            mm_calculator_model_card(model, threshold),
            mm_calculator_disclaimer(subject, audience))))),
      shiny::uiOutput("comparison"),
      # Full width, below both columns. A nomogram is a landscape sheet and
      # the result column is too narrow to read one in.
      mm_calculator_nomogram_panel(drawn))
  )
}

#' What the screen says about the model behind it
#'
#' The adequacy verdict is on the face of the calculator rather than in a
#' footnote, because a model that is short of the sample its shape requires
#' produces predictions that are too extreme at both ends, and that is a fact
#' about every number the page displays.
#'
#' @param model A [mm_model()].
#' @param threshold The risk the bands are relative to.
#' @return A Shiny tag.
#' @keywords internal
mm_calculator_model_card <- function(model, threshold) {
  a <- model$adequacy
  badge <- function(label, value) {
    shiny::span(class = "stat-badge", label, " ", shiny::tags$strong(value))
  }
  shiny::div(
    class = "model-info-card",
    shiny::h5("The model behind this number"),
    shiny::div(
      badge("developed on", format(a$n, big.mark = ",")),
      badge("events", format(a$events, big.mark = ",")),
      badge("event rate", sprintf("%.1f%%", 100 * a$prevalence)),
      badge("parameters", a$parameters),
      badge("events per parameter", sprintf("%.1f", a$events_per_parameter)),
      badge("band reference", sprintf("%.1f%%", 100 * threshold))),
    if (isTRUE(a$adequate)) {
      shiny::div(class = "adequacy adequacy-ok",
                 "The development sample meets the size this model's shape requires.")
    } else {
      shiny::div(
        class = "adequacy adequacy-short",
        shiny::tags$strong("Development sample is short of what this model's shape requires."),
        paste0(" ", a$reason, ". Coefficients from a sample this size are ",
               "expected to be overfitted, so the predictions on this page ",
               "are likely too extreme at both ends."))
    },
    shiny::tags$p(class = "fingerprint",
                  "coefficient fingerprint ", shiny::tags$code(model$fingerprint)))
}

#' Title case that leaves an acronym alone
#'
#' Factor levels arrive as they were typed into a data-entry form: "member",
#' "senior elections", "no AOA at school". Printed in a dropdown beside
#' sentence-cased labels they read as unfinished. Naive title case is worse,
#' because it turns AOA into Aoa and USMLE into Usmle, so a word carrying a
#' capital of its own is left exactly as it is, and the short joining words
#' stay lowercase unless they open or close the phrase.
#'
#' This changes what is shown and never what is submitted: the dropdown's
#' values stay the levels the fit knows, because [mm_predict()] refuses a
#' level it has not seen and a prettier spelling is exactly that.
#'
#' @param x A character vector.
#' @return The same vector, title cased.
#' @keywords internal
mm_title_case <- function(x) {
  small <- c("a", "aka", "an", "and", "as", "at", "but", "by", "for", "if",
             "in", "nor", "of", "on", "or", "per", "the", "to", "via", "vs")
  vapply(x, function(s) {
    if (is.na(s) || !nzchar(s)) return(s)
    words <- strsplit(s, " ", fixed = TRUE)[[1]]
    n <- length(words)
    done <- vapply(seq_along(words), function(i) {
      w <- words[i]
      core <- gsub("^[^[:alnum:]]+|[^[:alnum:]]+$", "", w)
      if (!nzchar(core)) return(w)
      # A capital anywhere but the front means the writer meant it: AOA,
      # USMLE, pH, MD. Leave the word untouched.
      if (grepl("[A-Z]", substring(core, 2))) return(w)
      lower <- tolower(core)
      shown <- if (lower %in% small && i != 1L && i != n) {
        lower
      } else {
        paste0(toupper(substring(lower, 1, 1)), substring(lower, 2))
      }
      sub(core, shown, w, fixed = TRUE)
    }, character(1))
    paste(done, collapse = " ")
  }, character(1), USE.NAMES = FALSE)
}

#' "a" or "an", for a noun the caller chose
#'
#' The page writes sentences around a word it was handed, and "a applicant" is
#' the kind of seam that makes a tool look assembled rather than written.
#'
#' @param word A noun.
#' @return The word with its article.
#' @keywords internal
mm_an <- function(word) {
  article <- if (grepl("^[aeiou]", word, ignore.case = TRUE)) "an" else "a"
  paste(article, word)
}

#' The standing caveats, written for whoever is reading them
#'
#' Two readers need two different pages. A clinician reading a risk about
#' someone else needs to be told that the number is not advice and that the
#' model cannot see the person in front of them. The person the row is about,
#' reading their own prediction, needs something else entirely: that the model
#' describes people who share their values and not them, that a number is not
#' a verdict, and that it was fitted on people who came before them. The
#' clinical page handed to an applicant reads as a warning about medical
#' advice, which is both wrong and faintly absurd.
#'
#' Written in the caller's noun throughout, so a page about applicants does
#' not warn about patients.
#'
#' @param subject What one row is, in the singular.
#' @param audience Who is reading: a `"clinician"` scoring someone else, or
#'   the `"self"` the row is about, reading their own prediction.
#' @return A Shiny tag.
#' @keywords internal
mm_calculator_disclaimer <- function(subject = "patient",
                                     audience = c("clinician", "self")) {
  audience <- match.arg(audience)
  para <- function(head, ...) shiny::tags$p(shiny::tags$strong(head), ...)

  body <- if (identical(audience, "clinician")) {
    list(
      para("Support for a decision, not the decision. ",
        "This calculator reports what the fitted model predicts. It is not ",
        "advice, and it knows nothing about this ", subject, " beyond the ",
        "values entered above."),
      para("Complete data only. ",
        paste0("The model was fitted on rows with every predictor observed, ",
               "so ", mm_an(subject), " with a missing value cannot be ",
               "scored rather than being scored approximately.")))
  } else {
    list(
      para("This describes people like you, not you. ",
        paste0("The number is what the model expects across ", subject,
               "s who share the values you entered. It has never met you, ",
               "and it cannot see the things that are not on this form.")),
      para("It is not a verdict and not a plan. ",
        "A number below the reference is not a reason to give up, and one ",
        "above it is not a promise."),
      para("It was fitted on people who came before you. ",
        "Nothing here knows what this year looks like, and a field left ",
        "blank means you cannot be scored at all rather than scored ",
        "approximately."))
  }

  shiny::div(
    class = "disclaimer-box",
    shiny::h6("Before you use this"),
    body,
    if (identical(audience, "clinician")) {
      para("What the interval covers. ",
        "The 95% interval is the uncertainty in the coefficients at these ",
        "values, transformed to the probability scale. It does not say how ",
        "much people sharing these values differ from one another, and it ",
        "does not cover which predictors were chosen or what shape they were ",
        "given. On a model short of the sample its shape requires, the ",
        "interval is too narrow for the same reason the coefficients are too ",
        "extreme.")
    } else {
      para("The range is the model's, not yours. ",
        "It says how sure the model is about its own number, given how much ",
        "data it was fitted on. It is not the range you might fall in: two ",
        paste0(subject, "s"), "who answer this form identically can still ",
        "have different years, and nothing on this page measures that.")
    },
    para("Performance is reported elsewhere. ",
      "Discrimination and calibration, apparent and corrected, come from ",
      "mm_validate() and are not on this screen. A calculator that shows a ",
      "prediction without them shows half the picture."))
}

#' The calculator's stylesheet
#'
#' One string rather than a file under `inst/`, so that the application is a
#' value a caller can hand around and the package has no static assets to keep
#' in step with the code that references them.
#'
#' @return A single character string of CSS.
#' @keywords internal
mm_calculator_css <- function() {
  paste(
"body { font-family: 'Plus Jakarta Sans', sans-serif; background-color: #f4f6fa; color: #1e293b; margin: 0; padding: 0; }",
".header-banner { background: linear-gradient(135deg, #0f2537 0%, #1a365d 50%, #2b6cb0 100%); color: white; padding: 35px 40px; margin: 0 0 30px 0; box-shadow: 0 10px 30px rgba(15,23,42,0.15); }",
".header-banner h1 { font-family: 'Outfit', sans-serif; font-size: 30px; font-weight: 700; margin: 0 0 8px 0; letter-spacing: -0.5px; }",
".header-banner h4 { font-weight: 400; font-size: 15px; opacity: 0.85; margin: 0; letter-spacing: 0.2px; }",
".main-container { max-width: 1280px; margin: 0 auto; padding: 0 20px 40px 20px; }",
".input-card { background: white; border-radius: 16px; padding: 28px; box-shadow: 0 4px 20px rgba(15,23,42,0.04); border: 1px solid rgba(226,232,240,0.8); margin-bottom: 20px; }",
".input-card h4 { color: #0f172a; font-family: 'Outfit', sans-serif; font-weight: 600; font-size: 18px; border-bottom: 2px solid #3b82f6; padding-bottom: 12px; margin-top: 0; margin-bottom: 24px; }",
# Bootstrap 3 floats its columns, so each is only as tall as its own
# content and a sticky child has nothing to stick within once the page
# scrolls past it. Making the row a flex container stretches both
# columns to the height of the taller one, which is what gives the
# result something to stay inside.
".main-container .row { display: flex; flex-wrap: wrap; align-items: stretch; }",
".result-sticky { position: sticky; top: 16px; max-height: calc(100vh - 32px); overflow-y: auto; }",
".result-card { background: white; border-radius: 16px; padding: 35px; box-shadow: 0 10px 30px rgba(15,23,42,0.06); border: 1px solid rgba(226,232,240,0.8); text-align: center; }",
".result-card h3 { font-family: 'Outfit', sans-serif; font-weight: 700; color: #0f172a; margin: 0 0 4px 0; font-size: 22px; }",
".result-sub { color: #64748b; font-size: 13px; margin: 0 0 10px 0; }",
".gauge-container { position: relative; width: 250px; height: 135px; margin: 20px auto 10px auto; overflow: hidden; }",
".gauge-bg { width: 250px; height: 125px; border-radius: 125px 125px 0 0; background: linear-gradient(90deg, #10b981 0%, #34d399 25%, #fbbf24 50%, #f87171 75%, #ef4444 100%); position: relative; overflow: hidden; box-shadow: inset 0 2px 5px rgba(0,0,0,0.06); }",
".gauge-bg-good-high { background: linear-gradient(90deg, #ef4444 0%, #f87171 25%, #fbbf24 50%, #34d399 75%, #10b981 100%); }",
".gauge-mask { position: absolute; bottom: 0; left: 20px; width: 210px; height: 105px; background: #ffffff; border-radius: 105px 105px 0 0; z-index: 2; }",
".gauge-needle { position: absolute; bottom: 0; left: 122.5px; width: 5px; height: 105px; transform-origin: bottom center; transition: transform 1.0s cubic-bezier(0.19,1,0.22,1); border-radius: 4px 4px 0 0; box-shadow: 0 0 8px rgba(0,0,0,0.18); z-index: 5; }",
".gauge-center { position: absolute; bottom: -10px; left: 115px; width: 20px; height: 20px; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 5px rgba(15,23,42,0.15); z-index: 10; transition: background-color 1.0s ease; }",
".gauge-scale { display: flex; justify-content: space-between; width: 250px; margin: 0 auto; font-size: 11px; color: #94a3b8; }",
".gauge-value { font-family: 'Outfit', sans-serif; font-size: 48px; font-weight: 800; color: #0f172a; margin-top: 6px; letter-spacing: -1px; }",
".ci-display { font-size: 13px; color: #64748b; margin-top: 2px; min-height: 18px; }",
".alert-extrapolation { background-color: #fff7ed; border: 1px solid #fed7aa; color: #9a3412; padding: 14px 18px; border-radius: 12px; margin: 10px 0 0 0; text-align: left; font-size: 13px; line-height: 1.5; }",
".interpretation-box { background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%); border-left: 4px solid #3b82f6; padding: 20px 22px; margin: 22px 0; border-radius: 0 12px 12px 0; text-align: left; }",
".interpretation-box h5 { color: #1e3a8a; margin: 0 0 8px 0; font-family: 'Outfit', sans-serif; font-weight: 600; font-size: 15px; }",
".interpretation-box p { margin: 0; line-height: 1.55; color: #334155; font-size: 14px; }",
".icon-grid-container { margin: 22px 0; }",
".icon-grid { display: grid; grid-template-columns: repeat(20, 1fr); gap: 4px; max-width: 420px; margin: 0 auto; }",
".dot { width: 100%; padding-bottom: 100%; border-radius: 50%; background-color: #e2e8f0; display: block; }",
".icon-caption { font-size: 12px; color: #64748b; margin-top: 12px; }",
".btn-reset { background: #f1f5f9; border: 1px solid #cbd5e1; color: #475569; padding: 12px 30px; font-family: 'Outfit', sans-serif; font-size: 14px; font-weight: 500; border-radius: 10px; width: 100%; }",
".btn-reset:hover { background: #e2e8f0; color: #1e293b; }",
".form-group label { font-weight: 600; color: #334155; margin-bottom: 8px; font-size: 14px; }",
".form-control, .selectize-input { border: 1px solid #cbd5e1 !important; border-radius: 10px !important; padding: 10px 14px !important; font-size: 14px !important; background-color: #ffffff !important; }",
".form-control:focus, .selectize-input.focus { border-color: #3b82f6 !important; box-shadow: 0 0 0 4px rgba(59,130,246,0.15) !important; outline: none !important; }",
".gated { border: none; padding: 0; margin: 0; opacity: 0.55; }",
".help-text { font-size: 12px; color: #64748b; margin-top: 6px; margin-bottom: 18px; line-height: 1.4; }",
".model-info-card { background: #f8fafc; border-radius: 12px; padding: 22px; margin-top: 22px; border: 1px solid #e2e8f0; text-align: left; }",
".model-info-card h5 { color: #0f172a; font-family: 'Outfit', sans-serif; font-weight: 600; margin: 0 0 14px 0; font-size: 15px; }",
".stat-badge { display: inline-block; background: white; padding: 9px 14px; border-radius: 8px; margin: 5px 5px 5px 0; font-size: 13px; border: 1px solid #e2e8f0; color: #475569; }",
".stat-badge strong { color: #2563eb; }",
".adequacy { margin-top: 14px; padding: 14px 16px; border-radius: 10px; font-size: 13px; line-height: 1.5; }",
".adequacy-ok { background: #ecfdf5; border: 1px solid #a7f3d0; color: #065f46; }",
".adequacy-short { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; }",
".fingerprint { font-size: 11px; color: #94a3b8; margin: 14px 0 0 0; word-break: break-all; }",
".fingerprint code { background: transparent; color: #94a3b8; padding: 0; font-size: 11px; }",
".btn-save { background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%); border: none; color: white; padding: 13px 30px; font-family: 'Outfit', sans-serif; font-size: 14px; font-weight: 600; border-radius: 10px; width: 100%; margin-bottom: 10px; }",
".btn-save:hover { filter: brightness(1.06); color: white; }",
".compare-list { margin: 8px 0 18px 0; }",
".compare-row { display: flex; align-items: center; gap: 14px; padding: 7px 0; border-bottom: 1px solid #f1f5f9; }",
".compare-n { width: 22px; color: #94a3b8; font-size: 12px; text-align: right; }",
".compare-track { position: relative; flex: 1; height: 14px; background: #f1f5f9; border-radius: 7px; }",
".compare-ci { position: absolute; top: 5px; height: 4px; background: #cbd5e1; border-radius: 2px; }",
".compare-dot { position: absolute; top: 2px; width: 10px; height: 10px; margin-left: -5px; border-radius: 50%; border: 2px solid white; }",
".compare-figure { width: 210px; font-size: 13px; color: #334155; font-variant-numeric: tabular-nums; }",
".compare-ci-text { color: #94a3b8; }",
".compare-flag { color: #b45309; font-weight: 600; }",
".nomogram-card { background: white; border-radius: 16px; padding: 28px; margin-top: 25px; box-shadow: 0 4px 20px rgba(15,23,42,0.04); border: 1px solid rgba(226,232,240,0.8); }",
".nomogram-card h4 { color: #0f172a; font-family: 'Outfit', sans-serif; font-weight: 600; font-size: 18px; border-bottom: 2px solid #3b82f6; padding-bottom: 12px; margin-top: 0; margin-bottom: 10px; }",
".nomogram-img { width: 100%; height: auto; margin: 10px 0 18px 0; }",
".disclaimer-box { background: #fffbeb; border: 1px solid #fef3c7; border-radius: 12px; padding: 22px; margin-top: 24px; font-size: 12px; color: #78350f; text-align: left; line-height: 1.55; }",
".disclaimer-box h6 { font-family: 'Outfit', sans-serif; font-weight: 700; font-size: 13px; margin: 0 0 10px 0; }",
".disclaimer-box p { margin: 0 0 8px 0; }",
"@media (max-width: 991px) { .main-container .row { display: block; } .result-sticky { position: static; max-height: none; overflow-y: visible; } }",
"@media (max-width: 768px) { .header-banner { padding: 25px 20px; } .header-banner h1 { font-size: 24px; } .gauge-value { font-size: 38px; } }",
    sep = "\n")
}
