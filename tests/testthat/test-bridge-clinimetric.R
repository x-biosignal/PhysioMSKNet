# WS7-17: PhysioClinical clinimetric delegation + ICF outcome linkage.

.clin_tracker <- function(mat, muscles = paste0("m", seq_len(nrow(mat)))) {
  rownames(mat) <- muscles
  structure(list(activation_series = mat), class = "MSKLongitudinalTracker")
}

test_that("mskDetectResponderStatus delegates to PhysioClinical when instrument+population given", {
  skip_if_not_installed("PhysioClinical")
  # FMA-UE / chronic_stroke_minimal is a store pair carrying both an MDC and MCID
  tr <- .clin_tracker(matrix(c(30, 33, 38, 45,
                               45, 40, 33, 25), nrow = 2, byrow = TRUE))
  st <- suppressMessages(mskDetectResponderStatus(
    tr, instrument = "FMA-UE", population = "chronic_stroke_minimal",
    direction = "increase"))
  expect_equal(st$method, "clinimetric")
  expect_true("clinical_class" %in% colnames(st$classification))
  expect_true(all(st$classification$status %in%
                    c("responder", "non_responder", "deteriorated")))
  expect_true(all(st$classification$clinical_class %in%
                    c("true_responder", "subclinical_change",
                      "measurement_error", "non_responder")))
  # the strongly-improving muscle is a responder; the declining one deteriorated
  expect_equal(st$classification$status[1], "responder")
  expect_equal(st$classification$status[2], "deteriorated")
})

test_that("mskDetectResponderStatus falls back to the single-threshold path", {
  tr <- .clin_tracker(matrix(c(0.4, 0.5, 0.7, 0.95,
                               0.8, 0.7, 0.6, 0.45), nrow = 2, byrow = TRUE))
  # no instrument -> threshold path, no clinical_class column
  st <- mskDetectResponderStatus(tr, threshold_type = "effect_size")
  expect_equal(st$method, "threshold")
  expect_false("clinical_class" %in% colnames(st$classification))
})

test_that("delegation degrades gracefully when the store lacks the needed statistics", {
  skip_if_not_installed("PhysioClinical")
  tr <- .clin_tracker(matrix(c(10, 20, 30, 45,
                               30, 25, 20, 10), nrow = 2, byrow = TRUE))
  # FMA-UE / chronic_stroke carries only a SEM -> classifyResponder cannot run;
  # the function must warn/message and use the threshold path, not error.
  st <- suppressMessages(mskDetectResponderStatus(
    tr, instrument = "FMA-UE", population = "chronic_stroke"))
  expect_equal(st$method, "threshold")
})

test_that("mskLinkOutcomeMeasure maps a prediction to an instrument + ICF tags", {
  out <- structure(list(aggregate = list(overall_rom = 70, overall_strength = 55,
                                         overall_function = 48)),
                   class = "MSKFunctionalOutcome")
  link <- mskLinkOutcomeMeasure(out, "berg", measure = "function")
  expect_s3_class(link, "data.frame")
  expect_true(all(c("instrument_id", "measure", "predicted_value", "icf_code")
                  %in% names(link)))
  expect_equal(unique(link$predicted_value), 48)
  expect_equal(unique(link$measure), "function")
  # a numeric prediction is accepted directly
  expect_equal(mskLinkOutcomeMeasure(42, "fma_ue")$predicted_value[1], 42)
})

test_that("mskLinkOutcomeMeasure attaches ICF codes when PhysioAnnotationHub is available", {
  skip_if_not_installed("PhysioAnnotationHub")
  link <- mskLinkOutcomeMeasure(1.0, "berg")
  expect_setequal(link$icf_code, c("b710", "b755"))
  fma <- mskLinkOutcomeMeasure(1.0, "fma_ue")
  expect_true("b730" %in% fma$icf_code)
  # an instrument with no ICF link -> a single NA icf_code, no error
  none <- suppressWarnings(mskLinkOutcomeMeasure(1.0, "not_a_real_instrument"))
  expect_true(is.na(none$icf_code))
  expect_equal(nrow(none), 1L)
})

test_that("mskLinkOutcomeMeasure validates its input", {
  expect_error(mskLinkOutcomeMeasure(list(a = 1), "berg"), "MSKFunctionalOutcome")
  expect_error(mskLinkOutcomeMeasure(1, c("a", "b")), "single non-empty")
  expect_error(mskLinkOutcomeMeasure(1, NA_character_), "single non-empty")
})
