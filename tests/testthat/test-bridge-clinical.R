library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-clinical.R -- Tests for clinical bridge functions
# ===========================================================================

# ---- Helper: small hypergraph for fast tests ----

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


# ---- .resolveMuscleIndices ----

test_that(".resolveMuscleIndices resolves by name (exact match)", {
  hg <- .make_small_hg()
  idx <- PhysioMSKNet:::.resolveMuscleIndices("Biceps Brachii", hg)
  expect_equal(idx, 1L)
})

test_that(".resolveMuscleIndices resolves by integer index", {
  hg <- .make_small_hg()
  idx <- PhysioMSKNet:::.resolveMuscleIndices(c(1, 3), hg)
  expect_equal(idx, c(1L, 3L))
})

test_that(".resolveMuscleIndices uses fuzzy matching", {
  hg <- .make_small_hg()
  # Slight misspelling
  idx <- PhysioMSKNet:::.resolveMuscleIndices("Biceps Brachi", hg)
  expect_equal(idx, 1L)
})

test_that(".resolveMuscleIndices errors on invalid name", {
  hg <- .make_small_hg()
  expect_error(
    PhysioMSKNet:::.resolveMuscleIndices("NonexistentMuscle123", hg),
    "Could not match"
  )
})

test_that(".resolveMuscleIndices errors on out-of-range index", {
  hg <- .make_small_hg()
  expect_error(
    PhysioMSKNet:::.resolveMuscleIndices(99, hg),
    "out of range"
  )
})


# ---- .ensureHypergraph ----

test_that(".ensureHypergraph returns default if NULL", {
  hg <- PhysioMSKNet:::.ensureHypergraph(NULL)
  expect_s3_class(hg, "MSKHypergraph")
  expect_equal(hg$n_bones, 173)
})

test_that(".ensureHypergraph passes through existing hg", {
  hg <- .make_small_hg()
  hg2 <- PhysioMSKNet:::.ensureHypergraph(hg)
  expect_identical(hg, hg2)
})


# ---- mskClinicalPredictor ----

test_that("mskClinicalPredictor returns MSKClinicalPrediction object", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  pred <- mskClinicalPredictor(c(1, 2), hg = hg, sim = sim, verbose = FALSE)

  expect_s3_class(pred, "MSKClinicalPrediction")
  expect_true(all(c("recovery", "compensatory", "secondary_risk",
                     "injury_muscles", "injury_indices") %in% names(pred)))
})

test_that("mskClinicalPredictor recovery data frame has correct columns", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  pred <- mskClinicalPredictor(1, hg = hg, sim = sim, verbose = FALSE)

  expect_s3_class(pred$recovery, "data.frame")
  expect_true(all(c("muscle", "predicted_weeks", "ci_lower", "ci_upper")
                   %in% names(pred$recovery)))
  expect_equal(nrow(pred$recovery), 1)
  expect_true(pred$recovery$predicted_weeks[1] > 0)
})

test_that("mskClinicalPredictor accepts character muscle names", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  pred <- mskClinicalPredictor("Deltoid", hg = hg, sim = sim, verbose = FALSE)

  expect_equal(pred$injury_muscles, "Deltoid")
})

test_that("mskClinicalPredictor compensatory muscles are not injured muscles", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  pred <- mskClinicalPredictor(c(1, 2), hg = hg, sim = sim, verbose = FALSE)

  for (nm in names(pred$compensatory)) {
    if (nrow(pred$compensatory[[nm]]) > 0) {
      expect_false(any(pred$compensatory[[nm]]$muscle %in% pred$injury_muscles))
    }
  }
})

test_that("print.MSKClinicalPrediction produces output", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  pred <- mskClinicalPredictor(1, hg = hg, sim = sim, verbose = FALSE)

  expect_output(print(pred), "MSK Clinical Prediction")
  expect_output(print(pred), "Recovery Prediction")
})


# ---- mskRecoveryTimeline ----

test_that("mskRecoveryTimeline returns correct structure", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  tl <- mskRecoveryTimeline(1, hg = hg, sim = sim, n_weeks = 6)

  expect_s3_class(tl, "data.frame")
  expect_true(all(c("week", "muscle", "remaining_impact_pct", "phase", "milestone")
                   %in% names(tl)))
  # Should have 0 to 6 = 7 rows per muscle
  expect_equal(nrow(tl), 7)
})

test_that("mskRecoveryTimeline starts at 100% and decreases", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  tl <- mskRecoveryTimeline(1, hg = hg, sim = sim, n_weeks = 12)

  expect_equal(tl$remaining_impact_pct[1], 100.0)
  last <- tl$remaining_impact_pct[nrow(tl)]
  expect_lt(last, 100)
})

test_that("mskRecoveryTimeline phase assignments are valid", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  tl <- mskRecoveryTimeline(1, hg = hg, sim = sim, n_weeks = 20)

  valid_phases <- c("Acute", "Subacute", "Remodeling", "Return")
  expect_true(all(tl$phase %in% valid_phases))
})


# ---- mskInjuryRiskProfile ----

test_that("mskInjuryRiskProfile returns MSKInjuryRiskProfile", {
  hg <- .make_small_hg()
  profile <- mskInjuryRiskProfile(list(age = 30), hg = hg)

  expect_s3_class(profile, "MSKInjuryRiskProfile")
  expect_true(all(c("risk_scores", "patient_data", "factors") %in% names(profile)))
})

test_that("mskInjuryRiskProfile risk scores in [0, 1]", {
  hg <- .make_small_hg()
  profile <- mskInjuryRiskProfile(list(age = 50, bmi = 27), hg = hg)

  expect_true(all(profile$risk_scores$adjusted_risk >= 0))
  expect_true(all(profile$risk_scores$adjusted_risk <= 1))
})

test_that("mskInjuryRiskProfile applies age factor", {
  hg <- .make_small_hg()
  young <- mskInjuryRiskProfile(list(age = 20), hg = hg)
  old <- mskInjuryRiskProfile(list(age = 60), hg = hg)

  expect_equal(young$factors$age, 0.8)
  expect_equal(old$factors$age, 1.4)
})

test_that("mskInjuryRiskProfile errors without age", {
  hg <- .make_small_hg()
  expect_error(mskInjuryRiskProfile(list(bmi = 25), hg = hg))
})

test_that("print.MSKInjuryRiskProfile produces output", {
  hg <- .make_small_hg()
  profile <- mskInjuryRiskProfile(list(age = 40), hg = hg)
  expect_output(print(profile), "MSK Injury Risk Profile")
})


# ---- mskRehabProtocol ----

test_that("mskRehabProtocol returns MSKRehabProtocol", {
  hg <- .make_small_hg()
  protocol <- mskRehabProtocol(1, hg = hg)

  expect_s3_class(protocol, "MSKRehabProtocol")
  expect_true("phases" %in% names(protocol))
  expect_equal(length(protocol$phases), 3)
  expect_true(all(c("isolated", "intra_community", "cross_community")
                   %in% names(protocol$phases)))
})

test_that("mskRehabProtocol injured muscle appears in phase 1", {
  hg <- .make_small_hg()
  protocol <- mskRehabProtocol("Biceps Brachii", hg = hg)

  expect_true("Biceps Brachii" %in% protocol$phases$isolated$muscle)
})

test_that("print.MSKRehabProtocol produces output", {
  hg <- .make_small_hg()
  protocol <- mskRehabProtocol(1, hg = hg)
  expect_output(print(protocol), "MSK Rehabilitation Protocol")
  expect_output(print(protocol), "Phase 1")
})


# ---- mskOutcomeSummary ----

test_that("mskOutcomeSummary returns MSKOutcomeSummary", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  summary <- mskOutcomeSummary(1, hg = hg, sim = sim)

  expect_s3_class(summary, "MSKOutcomeSummary")
  expect_true(all(c("prediction", "timeline", "rehab", "injury_muscles")
                   %in% names(summary)))
})

test_that("mskOutcomeSummary includes risk profile when patient_data provided", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  summary <- mskOutcomeSummary(1, patient_data = list(age = 35),
                                hg = hg, sim = sim)

  expect_false(is.null(summary$risk_profile))
  expect_s3_class(summary$risk_profile, "MSKInjuryRiskProfile")
})

test_that("mskOutcomeSummary risk_profile is NULL without patient_data", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  summary <- mskOutcomeSummary(1, hg = hg, sim = sim)

  expect_null(summary$risk_profile)
})

test_that("print.MSKOutcomeSummary produces output", {
  hg <- .make_small_hg()
  sim <- mskSimulate(hg)
  summary <- mskOutcomeSummary(1, hg = hg, sim = sim)
  expect_output(print(summary), "MSK Outcome Summary")
})
