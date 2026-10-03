# WS8-09: partial-pooling delegation of mskRecoveryTrajectoryFit to the
# PhysioClinStats population NLME.

.recovery_tracker <- function() {
  set.seed(1)
  act <- t(sapply(1:4, function(m) {
    A <- 50 + m * 5; b <- 0.3
    A * (1 - exp(-b * (1:9))) + rnorm(9, 0, 1.5)
  }))
  rownames(act) <- paste0("muscle_", 1:4)
  structure(list(activation_series = act, n_timepoints = 9),
            class = "MSKLongitudinalTracker")
}

test_that("partial_pool = FALSE preserves the independent-NLS trajectory (default)", {
  tr <- .recovery_tracker()
  d <- mskRecoveryTrajectoryFit(tr, model = "exponential")
  expect_s3_class(d, "MSKRecoveryTrajectory")
  expect_length(d$fits, 4L)
  expect_null(d$partial_pool)                            # no pooling marker
  expect_equal(dim(d$predicted), c(4L, 9L))
})

test_that("partial_pool = TRUE delegates to the population NLME, keeping the API", {
  skip_if_not_installed("PhysioClinStats")
  skip_if_not_installed("nlme")
  tr <- .recovery_tracker()
  p <- suppressWarnings(mskRecoveryTrajectoryFit(tr, model = "exponential",
                                                 partial_pool = TRUE))
  expect_s3_class(p, "MSKRecoveryTrajectory")
  expect_true(isTRUE(p$partial_pool))
  expect_length(p$fits, 4L)
  expect_equal(dim(p$predicted), c(4L, 9L))
  expect_true(all(c("fits", "predicted", "model_type", "recovery_rate",
                    "time_to_90pct") %in% names(p)))
  expect_equal(p$fits[[1]]$method, "nlme_partial_pool")
  expect_true(is.numeric(p$recovery_rate) && length(p$recovery_rate) == 4L)
  expect_true(all(is.finite(p$time_to_90pct)))
  # the per-muscle fit keeps the documented fields (incl. aic) of the NLS path
  expect_true(all(c("coefficients", "residuals", "r_squared", "aic",
                    "model_type") %in% names(p$fits[[1]])))
})
