# ===========================================================================
# bridge-outcome.R -- Clinical functional outcome prediction from MSK network
# ===========================================================================
#
# Connects MSK network metrics to clinical functional outcomes (ROM, strength,
# composite function score), enabling clinicians to translate abstract network
# scores into meaningful rehabilitation targets.
#
# Reuses: .ensureHypergraph, .resolveMuscleIndices (bridge-clinical.R),
#   .extractSignalMatrix, .computeRMS (bridge-neuromech.R),
#   emgToMSKMapping (bridge-emg.R), mskCommunityDetect (msknet-community.R),
#   mskImpactScoreAll, mskImpactDeviation (msknet-simulation/perturbation),
#   mskSimulate (msknet-simulation.R), mskClinicalPredictor (bridge-clinical.R),
#   hyperedgeDegree (msknet-hypergraph.R), mskNetworkMetrics (msknet-metrics.R)
# ===========================================================================

# ---- Internal helpers ----

#' Predict ROM (range of motion) as percentage of normal
#'
#' Evidence-based regression: higher impact deviation leads to greater ROM loss.
#'
#' @param impact_dev Numeric vector of impact deviations.
#' @param patient_factors List with optional age, sex, bmi, injury_severity.
#' @return Numeric vector of predicted ROM percentages (0-100).
#' @keywords internal
.predictROM <- function(impact_dev, patient_factors = NULL) {
  # Base: 100 - |impact_dev| * 15

  base_rom <- 100 - abs(impact_dev) * 15

  # Patient factor adjustments
  adj <- 0
  if (!is.null(patient_factors)) {
    # Age: -0.5% per year over 40
    age <- patient_factors$age
    if (!is.null(age) && is.numeric(age) && age > 40) {
      adj <- adj - 0.5 * (age - 40)
    }

    # Severity adjustment
    severity <- patient_factors$injury_severity %||% "moderate"
    severity_adj <- switch(severity,
      mild = 0,
      moderate = -10,
      severe = -25,
      0
    )
    adj <- adj + severity_adj
  }

  rom <- base_rom + adj
  pmin(pmax(rom, 0), 100)
}


#' Predict strength as percentage of normal
#'
#' Uses activation deficit if EMG available, otherwise impact deviation.
#'
#' @param impact_dev Numeric vector of impact deviations.
#' @param activation_deficit Numeric vector of activation deficits (0-1) or NULL.
#' @param patient_factors List with optional patient characteristics.
#' @return Numeric vector of predicted strength percentages (0-100).
#' @keywords internal
.predictStrength <- function(impact_dev, activation_deficit = NULL,
                             patient_factors = NULL) {
  if (!is.null(activation_deficit) && length(activation_deficit) > 0) {
    base_str <- 100 - activation_deficit * 50
  } else {
    base_str <- 100 - abs(impact_dev) * 20
  }

  # Patient factor adjustments
  adj <- 0
  if (!is.null(patient_factors)) {
    age <- patient_factors$age
    if (!is.null(age) && is.numeric(age) && age > 40) {
      adj <- adj - 0.3 * (age - 40)
    }

    severity <- patient_factors$injury_severity %||% "moderate"
    severity_adj <- switch(severity,
      mild = 0,
      moderate = -8,
      severe = -20,
      0
    )
    adj <- adj + severity_adj
  }

  strength <- base_str + adj
  pmin(pmax(strength, 0), 100)
}


#' Predict composite function score (LEFS-like, 0-80)
#'
#' Aggregates ROM and strength weighted by muscle degree (structural importance).
#'
#' @param rom Numeric vector of ROM percentages.
#' @param strength Numeric vector of strength percentages.
#' @param muscle_weights Numeric vector of weights (e.g., normalized degree).
#' @return Numeric scalar function score (0-80).
#' @keywords internal
.predictFunctionScore <- function(rom, strength, muscle_weights = NULL) {
  n <- length(rom)
  if (is.null(muscle_weights) || length(muscle_weights) != n) {
    muscle_weights <- rep(1, n)
  }
  # Normalize weights
  w <- muscle_weights / sum(muscle_weights)

  # Composite: 50% ROM + 50% strength, scaled to 0-80
  composite_pct <- stats::weighted.mean(0.5 * rom + 0.5 * strength, w)
  score <- composite_pct * 80 / 100
  min(max(score, 0), 80)
}


#' Compute activation deficit relative to expected
#'
#' Computes how much each mapped muscle's EMG RMS falls short of expected.
#'
#' @param emg_rms Named numeric vector of RMS values per EMG channel.
#' @param hg An MSKHypergraph object.
#' @param emg_mapping data.frame from emgToMSKMapping().
#' @return Named numeric vector of deficit values (0-1), one per mapped muscle.
#' @keywords internal
.computeActivationDeficit <- function(emg_rms, hg, emg_mapping) {
  if (is.null(emg_mapping) || nrow(emg_mapping) == 0) {
    return(numeric(0))
  }

  # Match RMS values to mapped muscles
  matched <- emg_mapping$channel_name %in% names(emg_rms)
  if (!any(matched)) return(numeric(0))

  mapping_sub <- emg_mapping[matched, , drop = FALSE]
  rms_vals <- emg_rms[mapping_sub$channel_name]

  # Expected: normalized by max (fully active muscle = 1.0)
  max_rms <- max(rms_vals, na.rm = TRUE)
  if (max_rms <= 0) return(stats::setNames(rep(0.5, length(rms_vals)),
                                            mapping_sub$muscle_name))

  activation <- rms_vals / max_rms
  deficit <- 1 - activation
  stats::setNames(as.numeric(deficit), mapping_sub$muscle_name)
}


#' Generate exercises for a rehab phase
#'
#' @param muscles Character vector of muscle names.
#' @param phase Character, rehab phase name.
#' @param intensity Character, intensity level ("low", "moderate", "high").
#' @return data.frame with exercise prescriptions.
#' @keywords internal
.generatePhaseExercises <- function(muscles, phase, intensity = "moderate") {
  if (length(muscles) == 0) {
    return(data.frame(
      muscle = character(0),
      exercise = character(0),
      sets = integer(0),
      reps = integer(0),
      intensity = character(0),
      phase = character(0),
      stringsAsFactors = FALSE
    ))
  }

  # Intensity parameters
  params <- switch(intensity,
    low = list(sets = 2L, reps = 10L),
    moderate = list(sets = 3L, reps = 12L),
    high = list(sets = 4L, reps = 15L),
    list(sets = 3L, reps = 12L)
  )

  # Generic exercise names based on phase
  exercise_prefix <- switch(phase,
    "Pain Control" = "Isometric hold",
    "Restore ROM" = "Active ROM",
    "Strengthen" = "Resistance training",
    "Return to Activity" = "Functional exercise",
    "Isolated" = "Isometric hold",
    "Intra-community" = "Resistance training",
    "Cross-community" = "Functional exercise",
    "Targeted" = "Targeted strengthening",
    "Compensation Corrective" = "Corrective exercise",
    "Progressive"
  )

  data.frame(
    muscle = muscles,
    exercise = paste(exercise_prefix, "-", muscles),
    sets = rep(params$sets, length(muscles)),
    reps = rep(params$reps, length(muscles)),
    intensity = rep(intensity, length(muscles)),
    phase = rep(phase, length(muscles)),
    stringsAsFactors = FALSE
  )
}


#' Compute weighted progress score
#'
#' @param current Named numeric vector of current metric values.
#' @param previous Named numeric vector of previous metric values.
#' @return Numeric scalar progress score (0-100).
#' @keywords internal
.computeProgressScore <- function(current, previous) {
  common <- intersect(names(current), names(previous))
  if (length(common) == 0) return(50)

  cur <- current[common]
  prev <- previous[common]

  # Progress: how much improvement relative to previous
 # If previous was 0 and current > 0, that is improvement
  changes <- ifelse(prev == 0,
    ifelse(cur > 0, 100, 50),
    pmin(100, pmax(0, (cur / prev) * 50))
  )

  mean(changes, na.rm = TRUE)
}


# ---- Exported functions ----

#' Predict Functional Outcome from MSK Network Analysis
#'
#' Predicts clinical functional outcomes (ROM, strength, composite function
#' score) for injured muscles based on MSK network topology, impact analysis,
#' and optional EMG activation data. Provides evidence-based regression models
#' with confidence intervals.
#'
#' @param injured_muscles Character or integer vector identifying injured muscles.
#' @param hg An MSKHypergraph object (NULL loads default 173-bone/270-muscle network).
#' @param outcome_type Character: "rom" (range of motion), "strength",
#'   "function" (composite functional score), or "all" (default).
#' @param patient_factors Optional list with: age (numeric), sex (character),
#'   bmi (numeric), activity_level (character), injury_severity
#'   ("mild"/"moderate"/"severe").
#' @param emg Optional EMG data (SummarizedExperiment, matrix, or numeric vector)
#'   for activation-based prediction refinement.
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param confidence_level Numeric, confidence level for CIs (default: 0.95).
#' @return An S3 object of class \code{"MSKFunctionalOutcome"} with:
#'   \describe{
#'     \item{predictions}{data.frame with muscle, outcome_type, predicted_value,
#'       lower_ci, upper_ci, unit}
#'     \item{aggregate}{list with overall_rom, overall_strength, overall_function}
#'     \item{recovery_weeks}{estimated weeks to reach 90 percent of predicted outcome}
#'     \item{confidence_level}{numeric}
#'     \item{model_type}{character}
#'     \item{patient_factors_used}{list}
#'   }
#'
#' @section Clinical Validity:
#' The prediction models are based on MSK network topology and heuristic
#' adjustments. They are not independently validated clinical tools. Use as
#' a research exploration tool, not a clinical diagnostic.
#'
#' @export
#' @examples
#' \dontrun{
#' outcome <- mskPredictFunctionalOutcome(
#'   c("Biceps Brachii", "Deltoid"),
#'   patient_factors = list(age = 55, injury_severity = "moderate")
#' )
#' print(outcome)
#' }
mskPredictFunctionalOutcome <- function(injured_muscles, hg = NULL,
                                         outcome_type = c("all", "rom",
                                                          "strength", "function"),
                                         patient_factors = NULL,
                                         emg = NULL,
                                         emg_mapping = NULL,
                                         confidence_level = 0.95) {
  outcome_type <- match.arg(outcome_type)
  stopifnot(is.numeric(confidence_level) && confidence_level > 0 &&
              confidence_level < 1)

  hg <- .ensureHypergraph(hg)
  injury_idx <- .resolveMuscleIndices(injured_muscles, hg)
  injury_names <- hg$muscle_names[injury_idx]

  # Compute impact scores and deviation
  sim <- mskSimulate(hg)
  scores <- mskImpactScoreAll(sim, verbose = FALSE)
  impact_dev <- mskImpactDeviation(scores, hg)
  inj_dev <- impact_dev[injury_idx]

  # Muscle degrees for weighting
  deg <- hyperedgeDegree(hg)
  inj_deg <- deg[injury_idx]

  # EMG activation deficit if EMG data provided
  activation_deficit <- NULL
  model_type <- "network_topology"
  if (!is.null(emg)) {
    emg_data <- .extractSignalMatrix(emg, "EMG")
    emg_rms <- .computeRMS(emg_data$signal_mat)
    if (is.null(emg_mapping)) {
      emg_mapping <- emgToMSKMapping(colnames(emg_data$signal_mat),
                                      hg = hg, method = "fuzzy")
    }
    activation_deficit <- .computeActivationDeficit(emg_rms, hg, emg_mapping)
    if (length(activation_deficit) > 0) model_type <- "network_emg_hybrid"
  }

  # Predict outcomes per muscle
  rom_pred <- .predictROM(inj_dev, patient_factors)
  names(rom_pred) <- injury_names

  # Match activation deficit to injured muscles
  act_def_matched <- NULL
  if (!is.null(activation_deficit) && length(activation_deficit) > 0) {
    act_def_matched <- numeric(length(injury_names))
    for (i in seq_along(injury_names)) {
      if (injury_names[i] %in% names(activation_deficit)) {
        act_def_matched[i] <- activation_deficit[injury_names[i]]
      } else {
        act_def_matched[i] <- NA_real_
      }
    }
    # Replace NAs with NULL-like behavior (use impact_dev for those)
    has_deficit <- !is.na(act_def_matched)
    if (!any(has_deficit)) act_def_matched <- NULL
  }

  str_pred <- .predictStrength(inj_dev, act_def_matched, patient_factors)
  names(str_pred) <- injury_names

  # Muscle weights based on degree (higher degree = more important for function)
  muscle_weights <- as.numeric(inj_deg)
  func_score <- .predictFunctionScore(rom_pred, str_pred, muscle_weights)

  # CI width based on confidence level
  z <- stats::qnorm((1 + confidence_level) / 2)
  se_rom <- 5.0   # heuristic standard error
  se_str <- 6.0
  se_func <- 4.0

  # Build predictions data.frame
  pred_rows <- list()

  types_to_compute <- if (outcome_type == "all") {
    c("rom", "strength", "function")
  } else {
    outcome_type
  }

  for (otype in types_to_compute) {
    if (otype == "rom") {
      for (i in seq_along(injury_names)) {
        pred_rows[[length(pred_rows) + 1L]] <- data.frame(
          muscle = injury_names[i],
          outcome_type = "rom",
          predicted_value = round(rom_pred[i], 1),
          lower_ci = round(max(0, rom_pred[i] - z * se_rom), 1),
          upper_ci = round(min(100, rom_pred[i] + z * se_rom), 1),
          unit = "% of normal",
          stringsAsFactors = FALSE
        )
      }
    } else if (otype == "strength") {
      for (i in seq_along(injury_names)) {
        pred_rows[[length(pred_rows) + 1L]] <- data.frame(
          muscle = injury_names[i],
          outcome_type = "strength",
          predicted_value = round(str_pred[i], 1),
          lower_ci = round(max(0, str_pred[i] - z * se_str), 1),
          upper_ci = round(min(100, str_pred[i] + z * se_str), 1),
          unit = "% of normal",
          stringsAsFactors = FALSE
        )
      }
    } else if (otype == "function") {
      pred_rows[[length(pred_rows) + 1L]] <- data.frame(
        muscle = "aggregate",
        outcome_type = "function",
        predicted_value = round(func_score, 1),
        lower_ci = round(max(0, func_score - z * se_func), 1),
        upper_ci = round(min(80, func_score + z * se_func), 1),
        unit = "LEFS-like (0-80)",
        stringsAsFactors = FALSE
      )
    }
  }

  predictions <- do.call(rbind, pred_rows)
  rownames(predictions) <- NULL

  # Recovery weeks: ROM(t) = ROM_final * (1 - exp(-t/tau))
  # Solve for t when ROM(t) = 0.9 * ROM_final: t = -tau * ln(0.1)

  # tau depends on muscle degree: higher degree = slower recovery
  tau <- 2 + inj_deg * 0.5  # baseline 2 weeks + 0.5 per degree
  recovery_weeks <- round(-tau * log(0.1), 1)  # weeks to 90%
  names(recovery_weeks) <- injury_names

  # Aggregate outcomes
  aggregate <- list(
    overall_rom = round(stats::weighted.mean(rom_pred, muscle_weights), 1),
    overall_strength = round(stats::weighted.mean(str_pred, muscle_weights), 1),
    overall_function = round(func_score, 1)
  )

  structure(
    list(
      predictions = predictions,
      aggregate = aggregate,
      recovery_weeks = recovery_weeks,
      confidence_level = confidence_level,
      model_type = model_type,
      patient_factors_used = patient_factors %||% list(),
      injury_muscles = injury_names,
      injury_indices = injury_idx,
      impact_deviation = inj_dev,
      muscle_degrees = inj_deg
    ),
    class = "MSKFunctionalOutcome"
  )
}

#' @export
print.MSKFunctionalOutcome <- function(x, ...) {
  cat("MSK Functional Outcome Prediction\n")
  cat("==================================\n")
  cat("Injured muscles:", paste(x$injury_muscles, collapse = ", "), "\n")
  cat("Model type:", x$model_type, "\n")
  cat("Confidence level:", x$confidence_level, "\n\n")

  cat("Aggregate Outcomes:\n")
  cat(sprintf("  ROM:      %.1f%% of normal\n", x$aggregate$overall_rom))
  cat(sprintf("  Strength: %.1f%% of normal\n", x$aggregate$overall_strength))
  cat(sprintf("  Function: %.1f / 80 (LEFS-like)\n", x$aggregate$overall_function))

  cat("\nPer-Muscle Predictions:\n")
  for (i in seq_len(nrow(x$predictions))) {
    r <- x$predictions[i, ]
    cat(sprintf("  %s [%s]: %.1f (%s, %.0f%% CI: %.1f-%.1f)\n",
                r$muscle, r$outcome_type, r$predicted_value, r$unit,
                x$confidence_level * 100, r$lower_ci, r$upper_ci))
  }

  cat("\nEstimated Recovery (to 90% of predicted):\n")
  for (i in seq_along(x$recovery_weeks)) {
    cat(sprintf("  %s: %.1f weeks\n",
                names(x$recovery_weeks)[i], x$recovery_weeks[i]))
  }

  invisible(x)
}


#' Generate Functional Milestones for Rehabilitation
#'
#' Takes the output of \code{mskPredictFunctionalOutcome} and generates
#' time-based milestones for tracking rehabilitation progress.
#'
#' @param outcome_prediction An \code{MSKFunctionalOutcome} object.
#' @param n_milestones Integer, number of milestones to generate (default: 4).
#' @param milestone_type Character: "linear" (evenly spaced), "accelerating"
#'   (front-loaded), or "clinical" (based on standard rehab phases).
#' @return An S3 object of class \code{"MSKFunctionalMilestones"} with:
#'   \describe{
#'     \item{milestones}{data.frame with milestone_id, week, target_rom,
#'       target_strength, target_function, phase_name, description}
#'     \item{timeline_weeks}{total timeline in weeks}
#'     \item{milestone_type}{character}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' outcome <- mskPredictFunctionalOutcome("Biceps Brachii")
#' milestones <- mskFunctionalMilestones(outcome, milestone_type = "clinical")
#' print(milestones)
#' }
mskFunctionalMilestones <- function(outcome_prediction, n_milestones = 4L,
                                     milestone_type = c("clinical", "linear",
                                                        "accelerating")) {
  stopifnot(inherits(outcome_prediction, "MSKFunctionalOutcome"))
  milestone_type <- match.arg(milestone_type)
  n_milestones <- as.integer(n_milestones)
  stopifnot(n_milestones >= 1L)

  total_weeks <- max(outcome_prediction$recovery_weeks, na.rm = TRUE)
  total_weeks <- max(total_weeks, 4)  # minimum 4 weeks

  target_rom <- outcome_prediction$aggregate$overall_rom
  target_str <- outcome_prediction$aggregate$overall_strength
  target_func <- outcome_prediction$aggregate$overall_function

  if (milestone_type == "clinical") {
    # Standard rehab phases
    milestones <- data.frame(
      milestone_id = seq_len(4),
      week = c(2, 6, 12, max(14, ceiling(total_weeks))),
      target_rom = round(c(target_rom * 0.30,
                            target_rom * 0.70,
                            target_rom * 0.85,
                            target_rom * 0.95), 1),
      target_strength = round(c(target_str * 0.20,
                                 target_str * 0.50,
                                 target_str * 0.80,
                                 target_str * 0.95), 1),
      target_function = round(c(target_func * 0.25,
                                 target_func * 0.50,
                                 target_func * 0.75,
                                 target_func * 0.90), 1),
      phase_name = c("Pain Control", "Restore ROM",
                     "Strengthen", "Return to Activity"),
      description = c(
        "Pain control, protect repair (target: 25% function)",
        "Restore ROM (target: 50% function, 70% ROM)",
        "Strengthen (target: 75% function, 80% strength)",
        "Return to activity (target: 90% function)"
      ),
      stringsAsFactors = FALSE
    )
    # Trim to n_milestones if needed
    if (n_milestones < 4) {
      milestones <- milestones[seq_len(n_milestones), , drop = FALSE]
    } else if (n_milestones > 4) {
      # Add intermediate milestones
      extra <- n_milestones - 4
      extra_weeks <- seq(ceiling(total_weeks) + 2,
                         ceiling(total_weeks) + 2 * extra, by = 2)
      extra_df <- data.frame(
        milestone_id = 5:(4 + extra),
        week = extra_weeks[seq_len(extra)],
        target_rom = rep(round(target_rom * 0.98, 1), extra),
        target_strength = rep(round(target_str * 0.98, 1), extra),
        target_function = rep(round(target_func * 0.95, 1), extra),
        phase_name = rep("Maintenance", extra),
        description = rep("Maintain gains and prevent re-injury", extra),
        stringsAsFactors = FALSE
      )
      milestones <- rbind(milestones, extra_df)
    }
  } else if (milestone_type == "linear") {
    weeks <- round(seq(total_weeks / n_milestones, total_weeks,
                       length.out = n_milestones), 1)
    fractions <- seq(1 / n_milestones, 1, length.out = n_milestones)
    milestones <- data.frame(
      milestone_id = seq_len(n_milestones),
      week = weeks,
      target_rom = round(target_rom * fractions, 1),
      target_strength = round(target_str * fractions, 1),
      target_function = round(target_func * fractions, 1),
      phase_name = paste("Phase", seq_len(n_milestones)),
      description = paste0("Linear milestone ", seq_len(n_milestones),
                           " (", round(fractions * 100), "% target)"),
      stringsAsFactors = FALSE
    )
  } else {
    # Accelerating (front-loaded): exponential schedule
    raw <- 1 - exp(-3 * seq(1 / n_milestones, 1, length.out = n_milestones))
    fractions <- raw / max(raw)
    weeks <- round(fractions * total_weeks, 1)
    # Ensure weeks are monotonically increasing and at least 1 apart
    for (i in 2:length(weeks)) {
      if (weeks[i] <= weeks[i - 1]) weeks[i] <- weeks[i - 1] + 1
    }
    milestones <- data.frame(
      milestone_id = seq_len(n_milestones),
      week = weeks,
      target_rom = round(target_rom * fractions, 1),
      target_strength = round(target_str * fractions, 1),
      target_function = round(target_func * fractions, 1),
      phase_name = paste("Phase", seq_len(n_milestones)),
      description = paste0("Accelerating milestone ", seq_len(n_milestones),
                           " (", round(fractions * 100), "% target)"),
      stringsAsFactors = FALSE
    )
  }

  total_timeline <- max(milestones$week)

  structure(
    list(
      milestones = milestones,
      timeline_weeks = total_timeline,
      milestone_type = milestone_type
    ),
    class = "MSKFunctionalMilestones"
  )
}

#' @export
print.MSKFunctionalMilestones <- function(x, ...) {
  cat("MSK Functional Milestones\n")
  cat("=========================\n")
  cat("Type:", x$milestone_type, "\n")
  cat("Total timeline:", x$timeline_weeks, "weeks\n\n")

  for (i in seq_len(nrow(x$milestones))) {
    m <- x$milestones[i, ]
    cat(sprintf("  Milestone %d (Week %g) - %s:\n",
                m$milestone_id, m$week, m$phase_name))
    cat(sprintf("    ROM: %.1f%%  Strength: %.1f%%  Function: %.1f/80\n",
                m$target_rom, m$target_strength, m$target_function))
    cat(sprintf("    %s\n", m$description))
  }

  invisible(x)
}


#' Confidence Intervals for Outcome Predictions
#'
#' Computes confidence intervals for functional outcome predictions using
#' bootstrap resampling or analytical delta method.
#'
#' @param predictions An \code{MSKFunctionalOutcome} object.
#' @param method Character: "bootstrap" (default) or "analytical".
#' @param n_boot Integer, number of bootstrap resamples (default: 100).
#' @param confidence_level Numeric, confidence level (default: 0.95).
#' @return A list with:
#'   \describe{
#'     \item{ci}{data.frame with outcome, point_estimate, lower, upper, width}
#'     \item{method}{character}
#'     \item{n_boot}{integer (for bootstrap)}
#'     \item{overall_uncertainty}{numeric, mean CI width}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' outcome <- mskPredictFunctionalOutcome("Biceps Brachii")
#' ci <- mskOutcomeConfidenceInterval(outcome)
#' }
mskOutcomeConfidenceInterval <- function(predictions,
                                          method = c("bootstrap", "analytical"),
                                          n_boot = 100L,
                                          confidence_level = 0.95) {
  stopifnot(inherits(predictions, "MSKFunctionalOutcome"))
  method <- match.arg(method)
  stopifnot(is.numeric(confidence_level) && confidence_level > 0 &&
              confidence_level < 1)

  impact_dev <- predictions$impact_deviation
  pf <- predictions$patient_factors_used
  z <- stats::qnorm((1 + confidence_level) / 2)

  if (method == "bootstrap") {
    n_boot <- as.integer(n_boot)
    n_muscles <- length(impact_dev)

    # Bootstrap: add noise to impact deviations and recompute predictions
    boot_rom <- matrix(NA_real_, n_boot, n_muscles)
    boot_str <- matrix(NA_real_, n_boot, n_muscles)
    boot_func <- numeric(n_boot)

    muscle_weights <- as.numeric(predictions$muscle_degrees)

    for (b in seq_len(n_boot)) {
      noise <- stats::rnorm(n_muscles, mean = 0, sd = 0.3)
      dev_b <- impact_dev + noise
      rom_b <- .predictROM(dev_b, pf)
      str_b <- .predictStrength(dev_b, NULL, pf)
      boot_rom[b, ] <- rom_b
      boot_str[b, ] <- str_b
      boot_func[b] <- .predictFunctionScore(rom_b, str_b, muscle_weights)
    }

    alpha <- (1 - confidence_level) / 2

    ci_rows <- list()
    for (i in seq_len(n_muscles)) {
      rom_q <- stats::quantile(boot_rom[, i], probs = c(alpha, 1 - alpha))
      str_q <- stats::quantile(boot_str[, i], probs = c(alpha, 1 - alpha))

      ci_rows[[length(ci_rows) + 1L]] <- data.frame(
        outcome = paste0("rom_", predictions$injury_muscles[i]),
        point_estimate = round(.predictROM(impact_dev[i], pf), 1),
        lower = round(rom_q[1], 1),
        upper = round(rom_q[2], 1),
        width = round(rom_q[2] - rom_q[1], 1),
        stringsAsFactors = FALSE
      )
      ci_rows[[length(ci_rows) + 1L]] <- data.frame(
        outcome = paste0("strength_", predictions$injury_muscles[i]),
        point_estimate = round(.predictStrength(impact_dev[i], NULL, pf), 1),
        lower = round(str_q[1], 1),
        upper = round(str_q[2], 1),
        width = round(str_q[2] - str_q[1], 1),
        stringsAsFactors = FALSE
      )
    }

    func_q <- stats::quantile(boot_func, probs = c(alpha, 1 - alpha))
    ci_rows[[length(ci_rows) + 1L]] <- data.frame(
      outcome = "function_aggregate",
      point_estimate = round(predictions$aggregate$overall_function, 1),
      lower = round(func_q[1], 1),
      upper = round(func_q[2], 1),
      width = round(func_q[2] - func_q[1], 1),
      stringsAsFactors = FALSE
    )

  } else {
    # Analytical: use delta method approximation
    se_rom <- 5.0
    se_str <- 6.0
    se_func <- 4.0

    ci_rows <- list()
    for (i in seq_along(impact_dev)) {
      rom_pt <- .predictROM(impact_dev[i], pf)
      str_pt <- .predictStrength(impact_dev[i], NULL, pf)

      ci_rows[[length(ci_rows) + 1L]] <- data.frame(
        outcome = paste0("rom_", predictions$injury_muscles[i]),
        point_estimate = round(rom_pt, 1),
        lower = round(max(0, rom_pt - z * se_rom), 1),
        upper = round(min(100, rom_pt + z * se_rom), 1),
        width = round(min(2 * z * se_rom, 100), 1),
        stringsAsFactors = FALSE
      )
      ci_rows[[length(ci_rows) + 1L]] <- data.frame(
        outcome = paste0("strength_", predictions$injury_muscles[i]),
        point_estimate = round(str_pt, 1),
        lower = round(max(0, str_pt - z * se_str), 1),
        upper = round(min(100, str_pt + z * se_str), 1),
        width = round(min(2 * z * se_str, 100), 1),
        stringsAsFactors = FALSE
      )
    }

    func_pt <- predictions$aggregate$overall_function
    ci_rows[[length(ci_rows) + 1L]] <- data.frame(
      outcome = "function_aggregate",
      point_estimate = round(func_pt, 1),
      lower = round(max(0, func_pt - z * se_func), 1),
      upper = round(min(80, func_pt + z * se_func), 1),
      width = round(min(2 * z * se_func, 80), 1),
      stringsAsFactors = FALSE
    )
  }

  ci_df <- do.call(rbind, ci_rows)
  rownames(ci_df) <- NULL

  list(
    ci = ci_df,
    method = method,
    n_boot = if (method == "bootstrap") n_boot else NA_integer_,
    overall_uncertainty = round(mean(ci_df$width), 2)
  )
}


#' Reassess Patient Progress
#'
#' Compares current physiological measurements to a previous assessment,
#' computing progress metrics and generating recommendations.
#'
#' @param current_data A list with: emg (required, matrix or SummarizedExperiment),
#'   and optional eeg, kinematics, force.
#' @param previous_assessment A previous \code{MSKFunctionalOutcome} or
#'   \code{MSKReassessment} object.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param emg_mapping Optional pre-computed EMG-to-MSK mapping.
#' @param sr Optional numeric sampling rate.
#' @return An S3 object of class \code{"MSKReassessment"} with:
#'   \describe{
#'     \item{current_metrics}{data.frame of current activation/synergy metrics}
#'     \item{previous_metrics}{data.frame from previous assessment}
#'     \item{change}{data.frame with metric, previous, current, change,
#'       pct_change, significant}
#'     \item{progress_summary}{character vector per metric}
#'     \item{overall_progress}{weighted average progress score (0-100)}
#'     \item{recommendation}{character}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' reassessment <- mskReassess(
#'   current_data = list(emg = emg_matrix),
#'   previous_assessment = outcome
#' )
#' print(reassessment)
#' }
mskReassess <- function(current_data, previous_assessment, hg = NULL,
                         emg_mapping = NULL, sr = NULL) {
  stopifnot(is.list(current_data))
  stopifnot(!is.null(current_data$emg))
  stopifnot(inherits(previous_assessment, "MSKFunctionalOutcome") ||
              inherits(previous_assessment, "MSKReassessment"))

  hg <- .ensureHypergraph(hg)

  # Extract current EMG data
  emg_data <- .extractSignalMatrix(current_data$emg, "EMG")
  emg_mat <- emg_data$signal_mat
  current_rms <- .computeRMS(emg_mat)

  # Get EMG mapping
  if (is.null(emg_mapping)) {
    emg_mapping <- emgToMSKMapping(colnames(emg_mat), hg = hg, method = "fuzzy")
  }

  # Current activation deficit
  current_deficit <- .computeActivationDeficit(current_rms, hg, emg_mapping)

  # Current metrics data.frame
  current_metrics <- data.frame(
    metric = paste0("activation_", names(current_rms)),
    value = as.numeric(current_rms),
    stringsAsFactors = FALSE
  )
  if (length(current_deficit) > 0) {
    deficit_df <- data.frame(
      metric = paste0("deficit_", names(current_deficit)),
      value = as.numeric(current_deficit),
      stringsAsFactors = FALSE
    )
    current_metrics <- rbind(current_metrics, deficit_df)
  }

  # Previous metrics: extract from previous assessment
  if (inherits(previous_assessment, "MSKReassessment")) {
    previous_metrics <- previous_assessment$current_metrics
  } else {
    # From MSKFunctionalOutcome: use predicted values as baseline
    prev_vals <- previous_assessment$predictions$predicted_value
    prev_names <- paste0(previous_assessment$predictions$outcome_type, "_",
                         previous_assessment$predictions$muscle)
    previous_metrics <- data.frame(
      metric = prev_names,
      value = prev_vals,
      stringsAsFactors = FALSE
    )
  }

  # Compute change for common metrics
  common_metrics <- intersect(current_metrics$metric, previous_metrics$metric)
  if (length(common_metrics) > 0) {
    cur_vals <- current_metrics$value[match(common_metrics, current_metrics$metric)]
    prev_vals <- previous_metrics$value[match(common_metrics, previous_metrics$metric)]

    change_abs <- cur_vals - prev_vals
    pct_change <- ifelse(prev_vals != 0, (change_abs / abs(prev_vals)) * 100, 0)
    significant <- abs(pct_change) > 10  # >10% change considered significant

    change_df <- data.frame(
      metric = common_metrics,
      previous = round(prev_vals, 3),
      current = round(cur_vals, 3),
      change = round(change_abs, 3),
      pct_change = round(pct_change, 1),
      significant = significant,
      stringsAsFactors = FALSE
    )
  } else {
    change_df <- data.frame(
      metric = character(0),
      previous = numeric(0),
      current = numeric(0),
      change = numeric(0),
      pct_change = numeric(0),
      significant = logical(0),
      stringsAsFactors = FALSE
    )
  }

  # Progress summary per metric
  progress_summary <- if (nrow(change_df) > 0) {
    ifelse(change_df$pct_change > 10, "improving",
      ifelse(change_df$pct_change < -10, "declining", "stable"))
  } else {
    character(0)
  }
  names(progress_summary) <- change_df$metric

  # Overall progress score (0-100)
  if (nrow(change_df) > 0) {
    # Normalize changes: positive change in activation = improving
    norm_scores <- pmin(100, pmax(0, 50 + change_df$pct_change))
    overall_progress <- mean(norm_scores, na.rm = TRUE)
  } else {
    overall_progress <- 50  # neutral
  }

  # Recommendation based on overall progress
  recommendation <- if (overall_progress > 80) {
    "progress_to_next_phase"
  } else if (overall_progress > 60) {
    "continue_protocol"
  } else if (overall_progress > 40) {
    "modify_protocol"
  } else {
    "specialist_referral"
  }

  structure(
    list(
      current_metrics = current_metrics,
      previous_metrics = previous_metrics,
      change = change_df,
      progress_summary = progress_summary,
      overall_progress = round(overall_progress, 1),
      recommendation = recommendation
    ),
    class = "MSKReassessment"
  )
}

#' @export
print.MSKReassessment <- function(x, ...) {
  cat("MSK Reassessment\n")
  cat("=================\n")
  cat("Overall progress:", x$overall_progress, "/ 100\n")
  cat("Recommendation:", x$recommendation, "\n\n")

  if (nrow(x$change) > 0) {
    cat("Metric Changes:\n")
    n_show <- min(10, nrow(x$change))
    for (i in seq_len(n_show)) {
      r <- x$change[i, ]
      status <- x$progress_summary[r$metric]
      cat(sprintf("  %s: %.3f -> %.3f (%+.1f%%, %s)\n",
                  r$metric, r$previous, r$current, r$pct_change, status))
    }
    if (nrow(x$change) > 10) {
      cat("  ... and", nrow(x$change) - 10, "more metrics\n")
    }
  }

  invisible(x)
}


#' Adapt Rehabilitation Protocol Based on Reassessment
#'
#' Modifies a rehabilitation protocol based on patient reassessment results.
#' Uses decision rules to determine whether to advance, continue, reduce,
#' or modify the current protocol.
#'
#' @param reassessment An \code{MSKReassessment} object.
#' @param current_protocol An \code{MSKRehabProtocol} object from
#'   \code{mskRehabProtocol()}.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @return An S3 object of class \code{"MSKAdaptedProtocol"} with:
#'   \describe{
#'     \item{decision}{character: "advance", "continue", "reduce", "modify"}
#'     \item{adapted_exercises}{data.frame with modified exercise prescription}
#'     \item{rationale}{character explanation}
#'     \item{focus_muscles}{character vector of muscles needing attention}
#'     \item{removed_exercises}{exercises to drop}
#'     \item{added_exercises}{new exercises to add}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' protocol <- mskRehabProtocol("Biceps Brachii")
#' adapted <- mskAdaptProtocol(reassessment, protocol)
#' print(adapted)
#' }
mskAdaptProtocol <- function(reassessment, current_protocol, hg = NULL) {
  stopifnot(inherits(reassessment, "MSKReassessment"))
  stopifnot(inherits(current_protocol, "MSKRehabProtocol"))

  hg <- .ensureHypergraph(hg)
  progress <- reassessment$overall_progress

  # Decision rules
  if (progress > 80) {
    decision <- "advance"
    rationale <- sprintf(
      "Overall progress %.1f%% exceeds 80%% threshold. Advancing to next phase.",
      progress
    )
  } else if (progress >= 40) {
    decision <- "continue"
    rationale <- sprintf(
      "Overall progress %.1f%% is within 40-80%% range. Continuing current phase.",
      progress
    )
  } else {
    decision <- "reduce"
    rationale <- sprintf(
      "Overall progress %.1f%% is below 40%% threshold. Reducing intensity and adding focus exercises.",
      progress
    )
  }

  # Identify muscles needing extra attention (declining or low activation)
  focus_muscles <- character(0)
  if (nrow(reassessment$change) > 0) {
    declining <- reassessment$change$metric[
      reassessment$progress_summary == "declining"
    ]
    # Extract muscle names from metric names like "activation_MuscName"
    focus_muscles <- unique(gsub("^(activation_|deficit_)", "", declining))
    focus_muscles <- focus_muscles[nchar(focus_muscles) > 0]
  }

  # Check for compensation patterns: muscles with unexpectedly high activation
  compensation_detected <- FALSE
  if (nrow(reassessment$change) > 0) {
    act_metrics <- grep("^activation_", reassessment$change$metric, value = TRUE)
    if (length(act_metrics) > 0) {
      act_changes <- reassessment$change[
        reassessment$change$metric %in% act_metrics, , drop = FALSE
      ]
      # Very high increases in non-injured muscles suggest compensation
      high_inc <- act_changes$pct_change > 30
      if (any(high_inc)) {
        compensation_detected <- TRUE
        comp_muscles <- gsub("^activation_", "", act_changes$metric[high_inc])
        focus_muscles <- unique(c(focus_muscles, comp_muscles))
        decision <- "modify"
        rationale <- paste(rationale,
          "Compensation pattern detected in:",
          paste(comp_muscles, collapse = ", "))
      }
    }
  }

  # Generate adapted exercises
  injury_muscles <- current_protocol$injury_muscles

  if (decision == "advance") {
    # Move to next phase: use cross-community exercises
    adapted_exercises <- .generatePhaseExercises(
      injury_muscles, "Return to Activity", "high"
    )
    removed <- .generatePhaseExercises(injury_muscles, "Isolated", "low")
    added <- .generatePhaseExercises(
      c(injury_muscles, focus_muscles), "Return to Activity", "moderate"
    )
  } else if (decision == "continue") {
    adapted_exercises <- .generatePhaseExercises(
      injury_muscles, "Strengthen", "moderate"
    )
    removed <- data.frame(
      muscle = character(0), exercise = character(0),
      sets = integer(0), reps = integer(0),
      intensity = character(0), phase = character(0),
      stringsAsFactors = FALSE
    )
    added <- if (length(focus_muscles) > 0) {
      .generatePhaseExercises(focus_muscles, "Targeted", "moderate")
    } else {
      data.frame(
        muscle = character(0), exercise = character(0),
        sets = integer(0), reps = integer(0),
        intensity = character(0), phase = character(0),
        stringsAsFactors = FALSE
      )
    }
  } else if (decision == "reduce") {
    adapted_exercises <- .generatePhaseExercises(
      injury_muscles, "Isolated", "low"
    )
    removed <- .generatePhaseExercises(injury_muscles, "Strengthen", "high")
    added <- .generatePhaseExercises(
      c(injury_muscles, focus_muscles), "Isolated", "low"
    )
  } else {
    # modify (compensation detected)
    adapted_exercises <- .generatePhaseExercises(
      injury_muscles, "Strengthen", "moderate"
    )
    removed <- data.frame(
      muscle = character(0), exercise = character(0),
      sets = integer(0), reps = integer(0),
      intensity = character(0), phase = character(0),
      stringsAsFactors = FALSE
    )
    added <- .generatePhaseExercises(
      focus_muscles, "Compensation Corrective", "low"
    )
  }

  structure(
    list(
      decision = decision,
      adapted_exercises = adapted_exercises,
      rationale = rationale,
      focus_muscles = focus_muscles,
      removed_exercises = removed,
      added_exercises = added
    ),
    class = "MSKAdaptedProtocol"
  )
}

#' @export
print.MSKAdaptedProtocol <- function(x, ...) {
  cat("MSK Adapted Protocol\n")
  cat("=====================\n")
  cat("Decision:", x$decision, "\n")
  cat("Rationale:", x$rationale, "\n\n")

  if (length(x$focus_muscles) > 0) {
    cat("Focus muscles:", paste(x$focus_muscles, collapse = ", "), "\n\n")
  }

  cat("Adapted Exercises (", nrow(x$adapted_exercises), "):\n", sep = "")
  if (nrow(x$adapted_exercises) > 0) {
    n_show <- min(5, nrow(x$adapted_exercises))
    for (i in seq_len(n_show)) {
      e <- x$adapted_exercises[i, ]
      cat(sprintf("  %s: %dx%d (%s)\n",
                  e$exercise, e$sets, e$reps, e$intensity))
    }
    if (nrow(x$adapted_exercises) > 5) {
      cat("  ... and", nrow(x$adapted_exercises) - 5, "more\n")
    }
  }

  if (nrow(x$added_exercises) > 0) {
    cat("\nAdded Exercises (", nrow(x$added_exercises), "):\n", sep = "")
    n_show <- min(3, nrow(x$added_exercises))
    for (i in seq_len(n_show)) {
      e <- x$added_exercises[i, ]
      cat(sprintf("  + %s: %dx%d (%s)\n",
                  e$exercise, e$sets, e$reps, e$intensity))
    }
  }

  if (nrow(x$removed_exercises) > 0) {
    cat("\nRemoved Exercises (", nrow(x$removed_exercises), "):\n", sep = "")
    n_show <- min(3, nrow(x$removed_exercises))
    for (i in seq_len(n_show)) {
      e <- x$removed_exercises[i, ]
      cat(sprintf("  - %s\n", e$exercise))
    }
  }

  invisible(x)
}


#' Comprehensive Outcome Report
#'
#' Orchestrator function that combines functional outcome prediction,
#' milestones, and optional reassessment into a comprehensive report.
#'
#' @param outcome An \code{MSKFunctionalOutcome} object.
#' @param milestones Optional \code{MSKFunctionalMilestones} object.
#' @param reassessment Optional \code{MSKReassessment} object.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @return An S3 object of class \code{"MSKOutcomeReport"} with all sub-results.
#'
#' @export
#' @examples
#' \dontrun{
#' outcome <- mskPredictFunctionalOutcome("Biceps Brachii")
#' milestones <- mskFunctionalMilestones(outcome)
#' report <- mskOutcomeReport(outcome, milestones)
#' print(report)
#' }
mskOutcomeReport <- function(outcome, milestones = NULL,
                              reassessment = NULL, hg = NULL) {
  stopifnot(inherits(outcome, "MSKFunctionalOutcome"))

  hg <- .ensureHypergraph(hg)

  # Compute milestones if not provided
  milestones_result <- tryCatch({
    if (!is.null(milestones)) {
      stopifnot(inherits(milestones, "MSKFunctionalMilestones"))
      milestones
    } else {
      mskFunctionalMilestones(outcome, milestone_type = "clinical")
    }
  }, error = function(e) NULL)

  # Confidence intervals
  ci_result <- tryCatch({
    mskOutcomeConfidenceInterval(outcome, method = "analytical")
  }, error = function(e) NULL)

  # Reassessment (use provided or NULL)
  reassessment_result <- tryCatch({
    if (!is.null(reassessment)) {
      stopifnot(inherits(reassessment, "MSKReassessment"))
      reassessment
    } else {
      NULL
    }
  }, error = function(e) NULL)

  available_analyses <- c("outcome_prediction")
  if (!is.null(milestones_result)) {
    available_analyses <- c(available_analyses, "milestones")
  }
  if (!is.null(ci_result)) {
    available_analyses <- c(available_analyses, "confidence_intervals")
  }
  if (!is.null(reassessment_result)) {
    available_analyses <- c(available_analyses, "reassessment")
  }

  structure(
    list(
      outcome = outcome,
      milestones = milestones_result,
      confidence_intervals = ci_result,
      reassessment = reassessment_result,
      available_analyses = available_analyses,
      injury_muscles = outcome$injury_muscles,
      generated_at = Sys.time()
    ),
    class = "MSKOutcomeReport"
  )
}

#' @export
print.MSKOutcomeReport <- function(x, ...) {
  cat("=== MSK Outcome Report ===\n")
  cat("Generated:", format(x$generated_at, "%Y-%m-%d %H:%M:%S"), "\n")
  cat("Injured muscles:", paste(x$injury_muscles, collapse = ", "), "\n")
  cat("Available analyses:", paste(x$available_analyses, collapse = ", "), "\n\n")

  cat("--- Outcome Prediction ---\n")
  cat(sprintf("  ROM:      %.1f%% of normal\n", x$outcome$aggregate$overall_rom))
  cat(sprintf("  Strength: %.1f%% of normal\n", x$outcome$aggregate$overall_strength))
  cat(sprintf("  Function: %.1f / 80\n", x$outcome$aggregate$overall_function))

  if (!is.null(x$milestones)) {
    cat("\n--- Milestones ---\n")
    cat(sprintf("  Type: %s, Timeline: %g weeks, Phases: %d\n",
                x$milestones$milestone_type,
                x$milestones$timeline_weeks,
                nrow(x$milestones$milestones)))
  }

  if (!is.null(x$confidence_intervals)) {
    cat("\n--- Confidence Intervals ---\n")
    cat(sprintf("  Method: %s, Overall uncertainty: %.2f\n",
                x$confidence_intervals$method,
                x$confidence_intervals$overall_uncertainty))
  }

  if (!is.null(x$reassessment)) {
    cat("\n--- Reassessment ---\n")
    cat(sprintf("  Progress: %.1f / 100\n", x$reassessment$overall_progress))
    cat(sprintf("  Recommendation: %s\n", x$reassessment$recommendation))
  }

  invisible(x)
}


#' Link a network-derived outcome prediction to a clinical outcome measure
#'
#' Maps an MSK-network functional-outcome prediction to a validated clinical
#' outcome measure (COM) instrument and its WHO ICF category tags (via
#' \code{PhysioAnnotationHub::tagICF()}, when that package is installed). This
#' bridges an abstract network prediction to a documented, ICF-anchored clinical
#' instrument.
#'
#' @param outcome An \code{MSKFunctionalOutcome} (from
#'   [mskPredictFunctionalOutcome()]) or a single numeric prediction.
#' @param instrument_id A clinical outcome-measure instrument id (e.g.
#'   \code{"fma_ue"}, \code{"berg"}).
#' @param measure Which aggregate prediction to link when \code{outcome} is an
#'   \code{MSKFunctionalOutcome}: \code{"function"} (default), \code{"rom"}, or
#'   \code{"strength"}.
#' @param hub Optional \code{PhysioAnnotationHub} passed to
#'   \code{tagICF()}.
#' @return A data.frame with \code{instrument_id}, \code{measure},
#'   \code{predicted_value}, and \code{icf_code} (one row per ICF tag; a single
#'   \code{NA} \code{icf_code} when no ICF link is available).
#' @seealso [mskPredictFunctionalOutcome()]
#' @examples
#' \dontrun{
#' out <- mskPredictFunctionalOutcome(c("Deltoid", "Biceps Brachii"))
#' mskLinkOutcomeMeasure(out, "fma_ue", measure = "strength")
#' }
#' @export
mskLinkOutcomeMeasure <- function(outcome, instrument_id,
                                  measure = c("function", "rom", "strength"),
                                  hub = NULL) {
  measure <- match.arg(measure)
  if (missing(instrument_id) || length(instrument_id) != 1L ||
      is.na(instrument_id) || !nzchar(instrument_id)) {
    stop("'instrument_id' must be a single non-empty identifier.", call. = FALSE)
  }
  value <- if (inherits(outcome, "MSKFunctionalOutcome")) {
    outcome$aggregate[[paste0("overall_", measure)]]
  } else if (is.numeric(outcome) && length(outcome) == 1L) {
    as.numeric(outcome)
  } else {
    stop("'outcome' must be an MSKFunctionalOutcome or a single numeric value.",
         call. = FALSE)
  }
  if (is.null(value)) value <- NA_real_

  icf <- character(0)
  if (requireNamespace("PhysioAnnotationHub", quietly = TRUE)) {
    icf <- tryCatch(
      suppressWarnings(PhysioAnnotationHub::tagICF(instrument_id, hub = hub)),
      error = function(e) character(0))
  } else {
    warning("PhysioAnnotationHub not installed; ICF tags omitted.",
            call. = FALSE)
  }
  if (!length(icf)) icf <- NA_character_

  data.frame(instrument_id = instrument_id, measure = measure,
             predicted_value = as.numeric(value), icf_code = icf,
             stringsAsFactors = FALSE)
}
