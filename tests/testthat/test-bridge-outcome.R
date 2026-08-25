library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-outcome.R -- Tests for functional outcome bridge module
# ===========================================================================

# ---- Test helpers ----

.make_small_hg <- function() {
  C <- matrix(c(
    1, 0, 1, 0, 0,
    1, 1, 0, 0, 0,
    0, 1, 1, 1, 0,
    0, 0, 0, 1, 1,
    0, 0, 0, 0, 1,
    0, 0, 1, 0, 1
  ), nrow = 6, ncol = 5, byrow = TRUE)
  rownames(C) <- c("Humerus", "Scapula", "Clavicle", "Femur", "Tibia", "Radius")
  colnames(C) <- c("Biceps Brachii", "Deltoid", "Trapezius",
                    "Quadriceps", "Gastrocnemius")
  MSKHypergraph(C)
}

.make_mock_emg <- function(n_time = 500, n_channels = 3, sr = 1000) {
  set.seed(42)
  mat <- matrix(abs(rnorm(n_time * n_channels)), nrow = n_time, ncol = n_channels)
  colnames(mat) <- c("Biceps Brachii", "Deltoid", "Trapezius")[seq_len(n_channels)]
  attr(mat, "sr") <- sr
  mat
}


# ===========================================================================
# Internal helpers
# ===========================================================================

test_that(".predictROM returns values in [0, 100]", {
  rom <- PhysioMSKNet:::.predictROM(c(0, 1, 2, -1, 5))
  expect_true(all(rom >= 0 & rom <= 100))
})

test_that(".predictROM: higher impact deviation -> lower ROM", {
  rom_low <- PhysioMSKNet:::.predictROM(0.5)
  rom_high <- PhysioMSKNet:::.predictROM(3.0)
  expect_true(rom_low > rom_high)
})

test_that(".predictROM applies age adjustment", {
  rom_young <- PhysioMSKNet:::.predictROM(1.0, list(age = 30))
  rom_old <- PhysioMSKNet:::.predictROM(1.0, list(age = 60))
  expect_true(rom_young > rom_old)
})

test_that(".predictROM applies severity adjustment", {
  rom_mild <- PhysioMSKNet:::.predictROM(1.0, list(injury_severity = "mild"))
  rom_severe <- PhysioMSKNet:::.predictROM(1.0, list(injury_severity = "severe"))
  expect_true(rom_mild > rom_severe)
})

test_that(".predictStrength returns values in [0, 100]", {
  str <- PhysioMSKNet:::.predictStrength(c(0, 1, 2, -1))
  expect_true(all(str >= 0 & str <= 100))
})

test_that(".predictStrength uses activation deficit when available", {
  str_no_def <- PhysioMSKNet:::.predictStrength(1.0, activation_deficit = NULL)
  str_with_def <- PhysioMSKNet:::.predictStrength(1.0, activation_deficit = 0.8)
  # With high deficit, strength should be lower
  expect_true(str_with_def < str_no_def)
})

test_that(".predictFunctionScore bounded 0-80", {
  score <- PhysioMSKNet:::.predictFunctionScore(
    c(100, 100), c(100, 100), c(1, 1)
  )
  expect_true(score >= 0 && score <= 80)
  expect_equal(score, 80)

  score_low <- PhysioMSKNet:::.predictFunctionScore(
    c(0, 0), c(0, 0), c(1, 1)
  )
  expect_equal(score_low, 0)
})

test_that(".computeActivationDeficit returns values in [0, 1]", {
  hg <- .make_small_hg()
  emg_rms <- c("Biceps Brachii" = 0.8, "Deltoid" = 0.5, "Trapezius" = 1.0)
  mapping <- data.frame(
    channel_name = c("Biceps Brachii", "Deltoid"),
    muscle_name = c("Biceps Brachii", "Deltoid"),
    stringsAsFactors = FALSE
  )
  deficit <- PhysioMSKNet:::.computeActivationDeficit(emg_rms, hg, mapping)
  expect_true(all(deficit >= 0 & deficit <= 1))
  expect_equal(length(deficit), 2)
})

test_that(".generatePhaseExercises returns correct structure", {
  ex <- PhysioMSKNet:::.generatePhaseExercises(
    c("Biceps Brachii", "Deltoid"), "Strengthen", "moderate"
  )
  expect_s3_class(ex, "data.frame")
  expect_equal(nrow(ex), 2)
  expect_true(all(c("muscle", "exercise", "sets", "reps", "intensity", "phase")
                  %in% names(ex)))
})

test_that(".generatePhaseExercises handles empty muscles", {
  ex <- PhysioMSKNet:::.generatePhaseExercises(character(0), "Strengthen", "low")
  expect_equal(nrow(ex), 0)
})

test_that(".computeProgressScore returns value in [0, 100]", {
  current <- c(a = 10, b = 20)
  previous <- c(a = 5, b = 15)
  score <- PhysioMSKNet:::.computeProgressScore(current, previous)
  expect_true(score >= 0 && score <= 100)
})


# ===========================================================================
# mskPredictFunctionalOutcome
# ===========================================================================

test_that("mskPredictFunctionalOutcome returns correct S3 class", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome("Biceps Brachii", hg = hg)
  expect_s3_class(outcome, "MSKFunctionalOutcome")
})

test_that("mskPredictFunctionalOutcome predictions have valid structure", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(c(1, 2), hg = hg)
  expect_true(is.data.frame(outcome$predictions))
  expect_true(all(c("muscle", "outcome_type", "predicted_value",
                     "lower_ci", "upper_ci", "unit")
                  %in% names(outcome$predictions)))
})

test_that("mskPredictFunctionalOutcome ROM predictions in valid range", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg, outcome_type = "rom")
  rom_vals <- outcome$predictions$predicted_value[
    outcome$predictions$outcome_type == "rom"
  ]
  expect_true(all(rom_vals >= 0 & rom_vals <= 100))
})

test_that("mskPredictFunctionalOutcome strength predictions in valid range", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg, outcome_type = "strength")
  str_vals <- outcome$predictions$predicted_value[
    outcome$predictions$outcome_type == "strength"
  ]
  expect_true(all(str_vals >= 0 & str_vals <= 100))
})

test_that("mskPredictFunctionalOutcome function score bounded 0-80", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg, outcome_type = "function")
  func_vals <- outcome$predictions$predicted_value[
    outcome$predictions$outcome_type == "function"
  ]
  expect_true(all(func_vals >= 0 & func_vals <= 80))
})

test_that("mskPredictFunctionalOutcome CI contains point estimate", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  preds <- outcome$predictions
  for (i in seq_len(nrow(preds))) {
    expect_true(preds$lower_ci[i] <= preds$predicted_value[i])
    expect_true(preds$upper_ci[i] >= preds$predicted_value[i])
  }
})

test_that("mskPredictFunctionalOutcome aggregate values populated", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(c(1, 2), hg = hg)
  expect_true(is.numeric(outcome$aggregate$overall_rom))
  expect_true(is.numeric(outcome$aggregate$overall_strength))
  expect_true(is.numeric(outcome$aggregate$overall_function))
})

test_that("mskPredictFunctionalOutcome with patient_factors", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(
    1, hg = hg,
    patient_factors = list(age = 55, injury_severity = "severe")
  )
  expect_s3_class(outcome, "MSKFunctionalOutcome")
  expect_equal(outcome$patient_factors_used$age, 55)
})

test_that("mskPredictFunctionalOutcome single muscle works", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  expect_s3_class(outcome, "MSKFunctionalOutcome")
  expect_equal(length(outcome$injury_muscles), 1)
})

test_that("mskPredictFunctionalOutcome no patient_factors works", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg, patient_factors = NULL)
  expect_s3_class(outcome, "MSKFunctionalOutcome")
  expect_equal(length(outcome$patient_factors_used), 0)
})

test_that("mskPredictFunctionalOutcome recovery_weeks is positive", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(c(1, 2), hg = hg)
  expect_true(all(outcome$recovery_weeks > 0))
})

test_that("mskPredictFunctionalOutcome with EMG data", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  outcome <- mskPredictFunctionalOutcome(
    c("Biceps Brachii", "Deltoid"), hg = hg, emg = emg
  )
  expect_s3_class(outcome, "MSKFunctionalOutcome")
  expect_equal(outcome$model_type, "network_emg_hybrid")
})


# ===========================================================================
# mskFunctionalMilestones
# ===========================================================================

test_that("mskFunctionalMilestones returns correct S3 class", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ms <- mskFunctionalMilestones(outcome)
  expect_s3_class(ms, "MSKFunctionalMilestones")
})

test_that("mskFunctionalMilestones correct number of milestones", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ms <- mskFunctionalMilestones(outcome, n_milestones = 4)
  expect_equal(nrow(ms$milestones), 4)
})

test_that("mskFunctionalMilestones weeks are chronologically ordered", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ms <- mskFunctionalMilestones(outcome, n_milestones = 4,
                                 milestone_type = "linear")
  weeks <- ms$milestones$week
  expect_true(all(diff(weeks) > 0))
})

test_that("mskFunctionalMilestones targets increase", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ms <- mskFunctionalMilestones(outcome, n_milestones = 4,
                                 milestone_type = "linear")
  expect_true(all(diff(ms$milestones$target_rom) >= 0))
  expect_true(all(diff(ms$milestones$target_function) >= 0))
})

test_that("mskFunctionalMilestones clinical type has 4 standard phases", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ms <- mskFunctionalMilestones(outcome, milestone_type = "clinical")
  expect_true("Pain Control" %in% ms$milestones$phase_name)
  expect_true("Restore ROM" %in% ms$milestones$phase_name)
  expect_true("Strengthen" %in% ms$milestones$phase_name)
  expect_true("Return to Activity" %in% ms$milestones$phase_name)
})

test_that("mskFunctionalMilestones accelerating type works", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ms <- mskFunctionalMilestones(outcome, n_milestones = 5,
                                 milestone_type = "accelerating")
  expect_equal(nrow(ms$milestones), 5)
  expect_true(all(diff(ms$milestones$week) > 0))
})


# ===========================================================================
# mskOutcomeConfidenceInterval
# ===========================================================================

test_that("mskOutcomeConfidenceInterval bootstrap CI width > 0", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ci <- mskOutcomeConfidenceInterval(outcome, method = "bootstrap",
                                      n_boot = 50)
  expect_true(all(ci$ci$width > 0))
})

test_that("mskOutcomeConfidenceInterval lower < upper", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ci <- mskOutcomeConfidenceInterval(outcome, method = "analytical")
  expect_true(all(ci$ci$lower <= ci$ci$upper))
})

test_that("mskOutcomeConfidenceInterval analytical method works", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(c(1, 2), hg = hg)
  ci <- mskOutcomeConfidenceInterval(outcome, method = "analytical")
  expect_equal(ci$method, "analytical")
  expect_true(is.na(ci$n_boot))
  expect_true(ci$overall_uncertainty > 0)
})


# ===========================================================================
# mskReassess
# ===========================================================================

test_that("mskReassess returns correct S3 class", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(c(1, 2), hg = hg)
  emg <- .make_mock_emg()
  reassessment <- mskReassess(
    current_data = list(emg = emg),
    previous_assessment = outcome,
    hg = hg
  )
  expect_s3_class(reassessment, "MSKReassessment")
})

test_that("mskReassess progress score in [0, 100]", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(c(1, 2), hg = hg)
  emg <- .make_mock_emg()
  reassessment <- mskReassess(
    current_data = list(emg = emg),
    previous_assessment = outcome,
    hg = hg
  )
  expect_true(reassessment$overall_progress >= 0)
  expect_true(reassessment$overall_progress <= 100)
})

test_that("mskReassess recommendation is valid string", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  emg <- .make_mock_emg(n_channels = 1)
  colnames(emg) <- "Biceps Brachii"
  reassessment <- mskReassess(
    current_data = list(emg = emg),
    previous_assessment = outcome,
    hg = hg
  )
  valid_recs <- c("continue_protocol", "progress_to_next_phase",
                  "modify_protocol", "specialist_referral")
  expect_true(reassessment$recommendation %in% valid_recs)
})

test_that("mskReassess works with previous MSKReassessment", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  emg1 <- .make_mock_emg(n_channels = 1)
  colnames(emg1) <- "Biceps Brachii"

  reassess1 <- mskReassess(
    current_data = list(emg = emg1),
    previous_assessment = outcome,
    hg = hg
  )

  set.seed(99)
  emg2 <- matrix(abs(rnorm(500)), nrow = 500, ncol = 1)
  colnames(emg2) <- "Biceps Brachii"

  reassess2 <- mskReassess(
    current_data = list(emg = emg2),
    previous_assessment = reassess1,
    hg = hg
  )
  expect_s3_class(reassess2, "MSKReassessment")
})


# ===========================================================================
# mskAdaptProtocol
# ===========================================================================

test_that("mskAdaptProtocol returns correct S3 class", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  protocol <- mskRehabProtocol(1, hg = hg)
  emg <- .make_mock_emg(n_channels = 1)
  colnames(emg) <- "Biceps Brachii"
  reassessment <- mskReassess(
    current_data = list(emg = emg),
    previous_assessment = outcome,
    hg = hg
  )
  adapted <- mskAdaptProtocol(reassessment, protocol, hg = hg)
  expect_s3_class(adapted, "MSKAdaptedProtocol")
})

test_that("mskAdaptProtocol decision is valid string", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  protocol <- mskRehabProtocol(1, hg = hg)
  emg <- .make_mock_emg(n_channels = 1)
  colnames(emg) <- "Biceps Brachii"
  reassessment <- mskReassess(
    current_data = list(emg = emg),
    previous_assessment = outcome,
    hg = hg
  )
  adapted <- mskAdaptProtocol(reassessment, protocol, hg = hg)
  expect_true(adapted$decision %in% c("advance", "continue", "reduce", "modify"))
})

test_that("mskAdaptProtocol has adapted_exercises data.frame", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  protocol <- mskRehabProtocol(1, hg = hg)
  emg <- .make_mock_emg(n_channels = 1)
  colnames(emg) <- "Biceps Brachii"
  reassessment <- mskReassess(
    current_data = list(emg = emg),
    previous_assessment = outcome,
    hg = hg
  )
  adapted <- mskAdaptProtocol(reassessment, protocol, hg = hg)
  expect_s3_class(adapted$adapted_exercises, "data.frame")
  expect_true(nrow(adapted$adapted_exercises) > 0)
})


# ===========================================================================
# mskOutcomeReport
# ===========================================================================

test_that("mskOutcomeReport returns correct S3 class", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  report <- mskOutcomeReport(outcome, hg = hg)
  expect_s3_class(report, "MSKOutcomeReport")
})

test_that("mskOutcomeReport available_analyses populated", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  report <- mskOutcomeReport(outcome, hg = hg)
  expect_true("outcome_prediction" %in% report$available_analyses)
  expect_true("milestones" %in% report$available_analyses)
  expect_true("confidence_intervals" %in% report$available_analyses)
})

test_that("mskOutcomeReport with explicit milestones", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ms <- mskFunctionalMilestones(outcome, milestone_type = "linear")
  report <- mskOutcomeReport(outcome, milestones = ms, hg = hg)
  expect_equal(report$milestones$milestone_type, "linear")
})

test_that("mskOutcomeReport with reassessment", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  emg <- .make_mock_emg(n_channels = 1)
  colnames(emg) <- "Biceps Brachii"
  reassessment <- mskReassess(
    current_data = list(emg = emg),
    previous_assessment = outcome,
    hg = hg
  )
  report <- mskOutcomeReport(outcome, reassessment = reassessment, hg = hg)
  expect_true("reassessment" %in% report$available_analyses)
})


# ===========================================================================
# Print methods
# ===========================================================================

test_that("print.MSKFunctionalOutcome works", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  expect_output(print(outcome), "MSK Functional Outcome")
})

test_that("print.MSKFunctionalMilestones works", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  ms <- mskFunctionalMilestones(outcome)
  expect_output(print(ms), "MSK Functional Milestones")
})

test_that("print.MSKReassessment works", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  emg <- .make_mock_emg(n_channels = 1)
  colnames(emg) <- "Biceps Brachii"
  reassessment <- mskReassess(
    current_data = list(emg = emg),
    previous_assessment = outcome,
    hg = hg
  )
  expect_output(print(reassessment), "MSK Reassessment")
})

test_that("print.MSKAdaptedProtocol works", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  protocol <- mskRehabProtocol(1, hg = hg)
  emg <- .make_mock_emg(n_channels = 1)
  colnames(emg) <- "Biceps Brachii"
  reassessment <- mskReassess(
    current_data = list(emg = emg),
    previous_assessment = outcome,
    hg = hg
  )
  adapted <- mskAdaptProtocol(reassessment, protocol, hg = hg)
  expect_output(print(adapted), "MSK Adapted Protocol")
})

test_that("print.MSKOutcomeReport works", {
  hg <- .make_small_hg()
  outcome <- mskPredictFunctionalOutcome(1, hg = hg)
  report <- mskOutcomeReport(outcome, hg = hg)
  expect_output(print(report), "MSK Outcome Report")
})
