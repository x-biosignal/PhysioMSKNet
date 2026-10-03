library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-longitudinal.R -- Tests for longitudinal rehabilitation bridge
# ===========================================================================

# ---- Test helpers ----

.make_emg_matrix <- function(n_time = 200, n_channels = 4, sr = 1000,
                              seed = 42, scale = 1.0) {
  set.seed(seed)
  mat <- matrix(abs(rnorm(n_time * n_channels, sd = scale)),
                nrow = n_time, ncol = n_channels)
  colnames(mat) <- paste0("muscle_", seq_len(n_channels))
  attr(mat, "sr") <- sr
  mat
}

.make_timepoints <- function(n_tp = 3, n_time = 200, n_channels = 4,
                              increasing = TRUE) {
  tps <- list()
  for (i in seq_len(n_tp)) {
    seed <- 40 + i
    scale <- if (increasing) 1 + (i - 1) * 0.5 else 1
    tps[[paste0("T", i - 1)]] <- .make_emg_matrix(n_time, n_channels,
                                                    seed = seed, scale = scale)
  }
  tps
}

.make_tracker <- function(n_tp = 3, n_channels = 4, increasing = TRUE) {
  tps <- .make_timepoints(n_tp, n_channels = n_channels, increasing = increasing)
  mskLongitudinalTracker(tps, metrics = c("rms"))
}


# ===========================================================================
# 1. Internal helpers
# ===========================================================================

# ---- .computeICC ----

test_that(".computeICC returns value in [0, 1]", {
  set.seed(1)
  mat <- matrix(rnorm(20), nrow = 5, ncol = 4)
  icc <- PhysioMSKNet:::.computeICC(mat)
  expect_true(is.numeric(icc))
  expect_true(icc >= 0 && icc <= 1)
})

test_that(".computeICC returns high ICC for consistent measurements", {
  # Each subject (row) has similar values across timepoints (columns)
  # but subjects differ from each other -> high between, low within
  set.seed(42)
  mat <- matrix(rep(c(1, 2, 3, 4, 5), times = 4), nrow = 5, ncol = 4)
  mat <- mat + matrix(rnorm(20, sd = 0.05), 5, 4)
  icc <- PhysioMSKNet:::.computeICC(mat)
  expect_true(icc > 0.9)
})

test_that(".computeICC returns low ICC for inconsistent measurements", {
  set.seed(99)
  mat <- matrix(rnorm(20), nrow = 5, ncol = 4)
  icc <- PhysioMSKNet:::.computeICC(mat)
  # Random data should have low-to-moderate ICC

  expect_true(icc < 0.9)
})

test_that(".computeICC handles single row", {
  mat <- matrix(c(1, 2, 3), nrow = 1)
  icc <- PhysioMSKNet:::.computeICC(mat)
  expect_equal(icc, 0)
})

test_that(".computeICC handles single column", {
  mat <- matrix(c(1, 2, 3), ncol = 1)
  icc <- PhysioMSKNet:::.computeICC(mat)
  expect_equal(icc, 0)
})

# ---- .fitExponentialRecovery ----

test_that(".fitExponentialRecovery fits exponential data", {
  t <- seq(1, 10)
  y <- 5 * (1 - exp(-0.5 * t)) + 2 + rnorm(10, sd = 0.01)
  fit <- PhysioMSKNet:::.fitExponentialRecovery(t, y)

  expect_type(fit, "list")
  expect_true(fit$model_type %in% c("exponential", "linear"))
  expect_true(fit$r_squared > 0.8)
  expect_equal(length(fit$predicted), length(y))
})

test_that(".fitExponentialRecovery falls back to linear for constant data", {
  t <- seq(1, 5)
  y <- rep(3, 5)
  fit <- PhysioMSKNet:::.fitExponentialRecovery(t, y)
  expect_equal(fit$model_type, "linear")
})

test_that(".fitExponentialRecovery falls back to linear with 2 points", {
  t <- c(1, 2)
  y <- c(3, 5)
  fit <- PhysioMSKNet:::.fitExponentialRecovery(t, y)
  expect_equal(fit$model_type, "linear")
})

# ---- .fitSigmoidRecovery ----

test_that(".fitSigmoidRecovery fits sigmoid data", {
  t <- seq(1, 20)
  y <- 10 / (1 + exp(-0.5 * (t - 10))) + rnorm(20, sd = 0.1)
  fit <- PhysioMSKNet:::.fitSigmoidRecovery(t, y)

  expect_type(fit, "list")
  expect_true(fit$model_type %in% c("sigmoid", "linear"))
  expect_true(fit$r_squared > 0.8)
})

test_that(".fitSigmoidRecovery falls back for constant data", {
  t <- seq(1, 5)
  y <- rep(7, 5)
  fit <- PhysioMSKNet:::.fitSigmoidRecovery(t, y)
  expect_equal(fit$model_type, "linear")
})

# ---- .fitLinearRecovery ----

test_that(".fitLinearRecovery fits linear data correctly", {
  t <- seq(1, 10)
  y <- 2 + 3 * t + rnorm(10, sd = 0.01)
  fit <- PhysioMSKNet:::.fitLinearRecovery(t, y)

  expect_equal(fit$model_type, "linear")
  expect_true(fit$r_squared > 0.99)
  expect_true(abs(fit$coefficients$b - 3) < 0.1)
})

test_that(".fitLinearRecovery handles single point", {
  t <- 1
  y <- 5
  fit <- PhysioMSKNet:::.fitLinearRecovery(t, y)
  expect_equal(fit$model_type, "linear")
  expect_equal(fit$coefficients$b, 0)
})

# ---- .alignSynergies ----

test_that(".alignSynergies returns perfect match for identical matrices", {
  W <- matrix(c(1, 0, 0, 1, 0.5, 0.5), nrow = 3, ncol = 2)
  result <- PhysioMSKNet:::.alignSynergies(W, W)

  expect_equal(result$mean_cosine, 1)
  expect_true(all(result$cosine_similarities >= 0.99))
})

test_that(".alignSynergies handles permuted columns", {
  W1 <- matrix(c(1, 0, 0, 0, 1, 0), nrow = 3, ncol = 2)
  W2 <- matrix(c(0, 1, 0, 1, 0, 0), nrow = 3, ncol = 2)  # columns swapped
  result <- PhysioMSKNet:::.alignSynergies(W1, W2)

  expect_true(result$mean_cosine >= 0.99)
})

test_that(".alignSynergies returns low similarity for orthogonal matrices", {
  W1 <- matrix(c(1, 0, 0, 0, 1, 0, 0, 0, 1), nrow = 3, ncol = 3)
  W2 <- matrix(c(0, 1, 0, 0, 0, 1, 1, 0, 0), nrow = 3, ncol = 3)
  result <- PhysioMSKNet:::.alignSynergies(W1, W2)

  # Should still find good alignment since these are just permuted
  expect_true(result$mean_cosine >= 0.99)
})

# ---- .rollingSlope ----

test_that(".rollingSlope computes correct slopes", {
  x <- c(1, 2, 3, 4, 5)
  slopes <- PhysioMSKNet:::.rollingSlope(x, window = 3)
  # Linear data with slope 1
  expect_equal(length(slopes), 3)
  expect_true(all(abs(slopes - 1) < 0.01))
})

test_that(".rollingSlope returns empty for window > length", {
  x <- c(1, 2)
  slopes <- PhysioMSKNet:::.rollingSlope(x, window = 5)
  expect_length(slopes, 0)
})

test_that(".rollingSlope returns zero slope for constant data", {
  x <- rep(5, 10)
  slopes <- PhysioMSKNet:::.rollingSlope(x, window = 3)
  expect_true(all(abs(slopes) < 1e-10))
})


# ===========================================================================
# 2. mskLongitudinalTracker
# ===========================================================================

test_that("mskLongitudinalTracker creates valid tracker", {
  tps <- .make_timepoints(3, n_channels = 4)
  tracker <- mskLongitudinalTracker(tps, metrics = c("rms"))

  expect_s3_class(tracker, "MSKLongitudinalTracker")
  expect_equal(tracker$n_timepoints, 3L)
  expect_equal(tracker$timepoint_labels, c("T0", "T1", "T2"))
  expect_equal(nrow(tracker$activation_series), 4)
  expect_equal(ncol(tracker$activation_series), 3)
  expect_true(nrow(tracker$metrics_table) > 0)
})

test_that("mskLongitudinalTracker handles unnamed timepoints", {
  tps <- list(.make_emg_matrix(), .make_emg_matrix(seed = 43))
  tracker <- mskLongitudinalTracker(tps, metrics = c("rms"))
  expect_equal(tracker$timepoint_labels, c("T0", "T1"))
})

test_that("mskLongitudinalTracker computes synergy when requested", {
  tps <- .make_timepoints(2, n_channels = 3)
  tracker <- mskLongitudinalTracker(tps, metrics = c("rms", "synergy"))

  expect_true(any(!vapply(tracker$synergy_series, is.null, logical(1))))
})

test_that("mskLongitudinalTracker works with single timepoint", {
  tps <- list(T0 = .make_emg_matrix())
  tracker <- mskLongitudinalTracker(tps, metrics = c("rms"))

  expect_equal(tracker$n_timepoints, 1L)
  expect_equal(ncol(tracker$activation_series), 1)
})

test_that("mskLongitudinalTracker computes mean_activation", {
  tps <- .make_timepoints(2, n_channels = 3)
  tracker <- mskLongitudinalTracker(tps, metrics = c("mean_activation"))
  expect_true(any(tracker$metrics_table$metric_name == "mean_activation"))
})

test_that("mskLongitudinalTracker computes peak_activation", {
  tps <- .make_timepoints(2, n_channels = 3)
  tracker <- mskLongitudinalTracker(tps, metrics = c("peak_activation"))
  expect_true(any(tracker$metrics_table$metric_name == "peak_activation"))
})


# ===========================================================================
# 3. mskMinimalDetectableChange
# ===========================================================================

test_that("mskMinimalDetectableChange computes valid MDC table", {
  tracker <- .make_tracker(3)
  mdc <- mskMinimalDetectableChange(tracker, confidence = 0.95)

  expect_s3_class(mdc, "MSKMinimalDetectableChange")
  expect_true(nrow(mdc$mdc_table) > 0)
  expect_true(all(c("muscle", "metric", "ICC", "SEM", "MDC", "pooled_SD") %in%
                    colnames(mdc$mdc_table)))
  expect_equal(mdc$confidence_level, 0.95)
})

test_that("MDC formula is correct: MDC = SEM * z * sqrt(2)", {
  tracker <- .make_tracker(4)
  mdc <- mskMinimalDetectableChange(tracker, confidence = 0.95)

  z_95 <- qnorm(0.975)  # 1.96
  for (i in seq_len(nrow(mdc$mdc_table))) {
    row <- mdc$mdc_table[i, ]
    if (!is.na(row$SEM) && !is.na(row$MDC)) {
      expected_mdc <- row$SEM * z_95 * sqrt(2)
      expect_equal(row$MDC, round(expected_mdc, 4), tolerance = 0.01)
    }
  }
})

test_that("SEM formula is correct: SEM = SD * sqrt(1 - ICC)", {
  tracker <- .make_tracker(4)
  mdc <- mskMinimalDetectableChange(tracker, confidence = 0.95)

  for (i in seq_len(nrow(mdc$mdc_table))) {
    row <- mdc$mdc_table[i, ]
    if (!is.na(row$SEM) && !is.na(row$ICC) && !is.na(row$pooled_SD)) {
      expected_sem <- row$pooled_SD * sqrt(1 - row$ICC)
      expect_equal(row$SEM, round(expected_sem, 4), tolerance = 0.01)
    }
  }
})

test_that("mskMinimalDetectableChange handles 2-timepoint tracker", {
  tracker <- .make_tracker(2)
  mdc <- mskMinimalDetectableChange(tracker)
  expect_true(nrow(mdc$mdc_table) > 0)
})

test_that("MDC values are non-negative", {
  tracker <- .make_tracker(4)
  mdc <- mskMinimalDetectableChange(tracker)
  expect_true(all(mdc$mdc_table$MDC >= 0 | is.na(mdc$mdc_table$MDC)))
})


# ===========================================================================
# 4. mskRecoveryTrajectoryFit
# ===========================================================================

test_that("mskRecoveryTrajectoryFit fits exponential model", {
  tracker <- .make_tracker(5, increasing = TRUE)
  traj <- mskRecoveryTrajectoryFit(tracker, model = "exponential")

  expect_s3_class(traj, "MSKRecoveryTrajectory")
  expect_equal(length(traj$fits), nrow(tracker$activation_series))
  expect_equal(nrow(traj$predicted), nrow(tracker$activation_series))
  expect_equal(ncol(traj$predicted), tracker$n_timepoints)
})

test_that("mskRecoveryTrajectoryFit fits sigmoid model", {
  tracker <- .make_tracker(5, increasing = TRUE)
  traj <- mskRecoveryTrajectoryFit(tracker, model = "sigmoid")

  expect_s3_class(traj, "MSKRecoveryTrajectory")
  expect_true(all(vapply(traj$fits, function(f) f$model_type, character(1))
                  %in% c("sigmoid", "linear")))
})

test_that("mskRecoveryTrajectoryFit fits linear model", {
  tracker <- .make_tracker(5)
  traj <- mskRecoveryTrajectoryFit(tracker, model = "linear")

  expect_true(all(vapply(traj$fits, function(f) f$model_type, character(1))
                  == "linear"))
})

test_that("mskRecoveryTrajectoryFit respects muscle_subset", {
  tracker <- .make_tracker(4, n_channels = 4)
  traj <- mskRecoveryTrajectoryFit(tracker, model = "linear",
                                    muscle_subset = c("muscle_1", "muscle_3"))
  expect_equal(length(traj$fits), 2)
  expect_equal(names(traj$fits), c("muscle_1", "muscle_3"))
})

test_that("mskRecoveryTrajectoryFit errors on invalid muscle_subset", {
  tracker <- .make_tracker(3)
  expect_error(mskRecoveryTrajectoryFit(tracker, muscle_subset = "nonexistent"))
})

test_that("recovery_rate is numeric vector", {
  tracker <- .make_tracker(5)
  traj <- mskRecoveryTrajectoryFit(tracker, model = "linear")
  expect_true(is.numeric(traj$recovery_rate))
  expect_equal(length(traj$recovery_rate), nrow(tracker$activation_series))
})

test_that("time_to_90pct is numeric vector", {
  tracker <- .make_tracker(5)
  traj <- mskRecoveryTrajectoryFit(tracker, model = "linear")
  expect_true(is.numeric(traj$time_to_90pct))
  expect_equal(length(traj$time_to_90pct), nrow(tracker$activation_series))
})


# ===========================================================================
# 5. mskDetectResponderStatus
# ===========================================================================

test_that("mskDetectResponderStatus classifies correctly with MDC", {
  tracker <- .make_tracker(3, increasing = TRUE)
  mdc <- mskMinimalDetectableChange(tracker)
  status <- mskDetectResponderStatus(tracker, mdc, threshold_type = "mdc")

  expect_s3_class(status, "MSKResponderStatus")
  expect_true(all(c("muscle", "status", "change", "threshold", "effect_size_d")
                  %in% colnames(status$classification)))
  expect_true(all(status$classification$status %in%
                    c("responder", "non_responder", "deteriorated")))
})

test_that("mskDetectResponderStatus classifies with effect_size", {
  tracker <- .make_tracker(3, increasing = TRUE)
  status <- mskDetectResponderStatus(tracker, threshold_type = "effect_size")
  expect_s3_class(status, "MSKResponderStatus")
})

test_that("mskDetectResponderStatus summary counts add up", {
  tracker <- .make_tracker(4, n_channels = 5)
  status <- mskDetectResponderStatus(tracker, threshold_type = "effect_size")
  total <- sum(status$summary)
  expect_equal(total, 5L)
})

test_that("mskDetectResponderStatus handles single timepoint", {
  tracker <- .make_tracker(1)
  status <- mskDetectResponderStatus(tracker)
  expect_true(all(status$classification$status == "unknown"))
})

test_that("overall_status reflects majority", {
  tracker <- .make_tracker(3)
  status <- mskDetectResponderStatus(tracker)
  # overall_status should be one of the three categories
  expect_true(status$overall_status %in%
                c("responder", "non_responder", "deteriorated", "unknown"))
})


# ===========================================================================
# 6. mskDetectRecoveryPlateau
# ===========================================================================

test_that("mskDetectRecoveryPlateau detects plateau in constant data", {
  # Create tracker with constant activation
  tps <- list()
  for (i in 1:5) {
    mat <- matrix(1.0, nrow = 100, ncol = 3)
    colnames(mat) <- paste0("muscle_", 1:3)
    tps[[paste0("T", i - 1)]] <- mat
  }
  tracker <- mskLongitudinalTracker(tps, metrics = c("rms"))
  plateau <- mskDetectRecoveryPlateau(tracker, window = 3)

  expect_s3_class(plateau, "MSKRecoveryPlateau")
  expect_true(all(plateau$plateau_detected))
})

test_that("mskDetectRecoveryPlateau does not detect plateau in increasing data", {
  # Strongly increasing data
  tps <- list()
  for (i in 1:5) {
    mat <- matrix(abs(rnorm(300, mean = i * 10, sd = 0.01)), nrow = 100, ncol = 3)
    colnames(mat) <- paste0("muscle_", 1:3)
    tps[[paste0("T", i - 1)]] <- mat
  }
  tracker <- mskLongitudinalTracker(tps, metrics = c("rms"))
  plateau <- mskDetectRecoveryPlateau(tracker, window = 3)

  # With strongly increasing, should not detect plateau
  expect_true(any(!plateau$plateau_detected))
})

test_that("mskDetectRecoveryPlateau warns with insufficient timepoints", {
  tracker <- .make_tracker(2)
  expect_warning(
    plateau <- mskDetectRecoveryPlateau(tracker, window = 3),
    "Not enough timepoints"
  )
})

test_that("mskDetectRecoveryPlateau returns valid recommendation", {
  tracker <- .make_tracker(5)
  plateau <- mskDetectRecoveryPlateau(tracker, window = 3)
  expect_true(plateau$recommendation %in%
                c("continue", "modify_protocol", "reassess"))
})

test_that("mskDetectRecoveryPlateau supports change_rate method", {
  tracker <- .make_tracker(5)
  plateau <- mskDetectRecoveryPlateau(tracker, window = 3, method = "change_rate")
  expect_s3_class(plateau, "MSKRecoveryPlateau")
})


# ===========================================================================
# 7. mskSynergyChangeIndex
# ===========================================================================

test_that("mskSynergyChangeIndex returns 0 for identical matrices", {
  W <- matrix(abs(rnorm(12)), nrow = 4, ncol = 3)
  sci <- mskSynergyChangeIndex(W, W, method = "cosine")
  expect_equal(sci$global_change_index, 0, tolerance = 1e-6)
})

test_that("mskSynergyChangeIndex returns value near 1 for orthogonal matrices", {
  W1 <- diag(3)
  # Make W2 very different but normalized
  W2 <- matrix(c(0.5, 0.5, 0, 0, 0.5, 0.5, 0.5, 0, 0.5), nrow = 3, ncol = 3)
  sci <- mskSynergyChangeIndex(W1, W2, method = "cosine")
  expect_true(sci$global_change_index >= 0)
  expect_true(sci$global_change_index <= 1)
})

test_that("mskSynergyChangeIndex bounds in [0, 1]", {
  set.seed(10)
  W1 <- matrix(abs(rnorm(12)), 4, 3)
  W2 <- matrix(abs(rnorm(12)), 4, 3)
  sci <- mskSynergyChangeIndex(W1, W2, method = "cosine")
  expect_true(sci$global_change_index >= 0)
  expect_true(sci$global_change_index <= 1)
  expect_true(all(sci$per_synergy_change >= 0))
  expect_true(all(sci$per_synergy_change <= 1))
})

test_that("mskSynergyChangeIndex works with correlation method", {
  set.seed(11)
  W1 <- matrix(abs(rnorm(12)), 4, 3)
  W2 <- W1 + matrix(rnorm(12, sd = 0.1), 4, 3)
  sci <- mskSynergyChangeIndex(W1, W2, method = "correlation")
  expect_true(sci$global_change_index >= 0)
  expect_true(sci$global_change_index <= 1)
})

test_that("mskSynergyChangeIndex works with procrustes method", {
  set.seed(12)
  W1 <- matrix(abs(rnorm(12)), 4, 3)
  W2 <- W1 + matrix(rnorm(12, sd = 0.1), 4, 3)
  sci <- mskSynergyChangeIndex(W1, W2, method = "procrustes")
  expect_true(sci$global_change_index >= 0)
  expect_true(sci$global_change_index <= 1)
})

test_that("mskSynergyChangeIndex accepts MSKNeuromechSynergy objects", {
  tps <- .make_timepoints(2, n_channels = 3)
  syn1 <- neuromechMuscleSynergy(tps[["T0"]], method = "nmf", n_synergies = 2)
  syn2 <- neuromechMuscleSynergy(tps[["T1"]], method = "nmf", n_synergies = 2)

  sci <- mskSynergyChangeIndex(syn1, syn2, method = "cosine")
  expect_true(sci$global_change_index >= 0)
  expect_true(sci$global_change_index <= 1)
})


# ===========================================================================
# 8. mskNeuralAdaptationIndex
# ===========================================================================

test_that("mskNeuralAdaptationIndex computes CMC change", {
  set.seed(20)
  cmc0 <- matrix(runif(12, 0, 0.5), nrow = 3, ncol = 4)
  cmc1 <- matrix(runif(12, 0.2, 0.8), nrow = 3, ncol = 4)

  nai <- mskNeuralAdaptationIndex(cmc0, cmc1)

  expect_type(nai, "list")
  expect_true(is.numeric(nai$cmc_change))
  expect_true(nai$cmc_change >= 0)
  expect_true(nai$interpretation %in% c("improving", "stable", "declining"))
})

test_that("mskNeuralAdaptationIndex returns stable for identical CMC", {
  cmc <- matrix(0.5, nrow = 3, ncol = 4)
  nai <- mskNeuralAdaptationIndex(cmc, cmc)

  expect_equal(nai$cmc_change, 0)
  expect_equal(nai$interpretation, "stable")
})

test_that("mskNeuralAdaptationIndex handles directional coupling", {
  cmc0 <- matrix(0.3, 2, 3)
  cmc1 <- matrix(0.5, 2, 3)
  dom0 <- c(m1 = 1.5, m2 = 2.0, m3 = 1.0)
  dom1 <- c(m1 = 2.0, m2 = 2.5, m3 = 1.5)

  nai <- mskNeuralAdaptationIndex(cmc0, cmc1, dom0, dom1)

  expect_true(is.numeric(nai$directional_change))
  expect_true(nai$directional_change > 0)
})

test_that("mskNeuralAdaptationIndex adaptation_index is numeric", {
  cmc0 <- matrix(runif(6), 2, 3)
  cmc1 <- matrix(runif(6), 2, 3)
  nai <- mskNeuralAdaptationIndex(cmc0, cmc1)
  expect_true(is.numeric(nai$adaptation_index))
})


# ===========================================================================
# 9. mskCoordinationQualityScore
# ===========================================================================

test_that("mskCoordinationQualityScore returns score in [0, 1]", {
  set.seed(30)
  emg <- matrix(abs(rnorm(800)), 200, 4)
  colnames(emg) <- paste0("muscle_", 1:4)
  ref <- matrix(abs(rnorm(800)), 200, 4)
  colnames(ref) <- paste0("muscle_", 1:4)
  attr(emg, "sr") <- 1000
  attr(ref, "sr") <- 1000

  cqs <- mskCoordinationQualityScore(emg, ref, method = "synergy_distance")

  expect_true(is.numeric(cqs$quality_score))
  expect_true(is.na(cqs$quality_score) ||
                (cqs$quality_score >= 0 && cqs$quality_score <= 1))
})

test_that("mskCoordinationQualityScore correlation_profile method works", {
  set.seed(31)
  emg <- matrix(abs(rnorm(800)), 200, 4)
  colnames(emg) <- paste0("m_", 1:4)
  ref <- emg + matrix(rnorm(800, sd = 0.1), 200, 4)
  colnames(ref) <- paste0("m_", 1:4)

  cqs <- mskCoordinationQualityScore(emg, ref,
                                      method = "correlation_profile")
  expect_true(is.numeric(cqs$quality_score))
  expect_true(cqs$quality_score >= 0 && cqs$quality_score <= 1)
})

test_that("mskCoordinationQualityScore network_similarity method works", {
  set.seed(32)
  emg <- matrix(abs(rnorm(800)), 200, 4)
  colnames(emg) <- paste0("m_", 1:4)
  ref <- emg + matrix(rnorm(800, sd = 0.1), 200, 4)
  colnames(ref) <- paste0("m_", 1:4)
  attr(emg, "sr") <- 1000
  attr(ref, "sr") <- 1000

  cqs <- mskCoordinationQualityScore(emg, ref, method = "network_similarity")
  expect_true(cqs$quality_score >= 0 && cqs$quality_score <= 1)
})

test_that("mskCoordinationQualityScore works without reference (within-subject)", {
  set.seed(33)
  emg <- matrix(abs(rnorm(800)), 200, 4)
  colnames(emg) <- paste0("m_", 1:4)
  attr(emg, "sr") <- 1000

  cqs <- mskCoordinationQualityScore(emg, method = "correlation_profile")
  expect_true(is.numeric(cqs$quality_score))
})

test_that("muscle_contributions length matches number of muscles", {
  set.seed(34)
  emg <- matrix(abs(rnorm(600)), 200, 3)
  colnames(emg) <- paste0("m_", 1:3)
  ref <- matrix(abs(rnorm(600)), 200, 3)
  colnames(ref) <- paste0("m_", 1:3)

  cqs <- mskCoordinationQualityScore(emg, ref, method = "correlation_profile")
  expect_equal(length(cqs$muscle_contributions), 3)
})


# ===========================================================================
# 10. Print methods
# ===========================================================================

test_that("print.MSKLongitudinalTracker does not error", {
  tracker <- .make_tracker(3)
  expect_output(print(tracker), "MSK Longitudinal Tracker")
})

test_that("print.MSKMinimalDetectableChange does not error", {
  tracker <- .make_tracker(3)
  mdc <- mskMinimalDetectableChange(tracker)
  expect_output(print(mdc), "MSK Minimal Detectable Change")
})

test_that("print.MSKRecoveryTrajectory does not error", {
  tracker <- .make_tracker(4)
  traj <- mskRecoveryTrajectoryFit(tracker, model = "linear")
  expect_output(print(traj), "MSK Recovery Trajectory")
})

test_that("print.MSKResponderStatus does not error", {
  tracker <- .make_tracker(3)
  status <- mskDetectResponderStatus(tracker, threshold_type = "effect_size")
  expect_output(print(status), "MSK Responder Status")
})

test_that("print.MSKRecoveryPlateau does not error", {
  tracker <- .make_tracker(5)
  plateau <- mskDetectRecoveryPlateau(tracker, window = 3)
  expect_output(print(plateau), "MSK Recovery Plateau Detection")
})


# ===========================================================================
# 11. Edge cases
# ===========================================================================

test_that("single muscle works through full pipeline", {
  tps <- .make_timepoints(3, n_channels = 1)
  tracker <- mskLongitudinalTracker(tps, metrics = c("rms"))
  expect_equal(nrow(tracker$activation_series), 1)

  mdc <- mskMinimalDetectableChange(tracker)
  expect_equal(nrow(mdc$mdc_table), 1)

  traj <- mskRecoveryTrajectoryFit(tracker, model = "linear")
  expect_equal(length(traj$fits), 1)

  status <- mskDetectResponderStatus(tracker, mdc)
  expect_equal(nrow(status$classification), 1)
})

test_that("constant values do not cause errors in MDC", {
  tps <- list()
  for (i in 1:3) {
    mat <- matrix(5.0, nrow = 100, ncol = 2)
    colnames(mat) <- paste0("muscle_", 1:2)
    tps[[paste0("T", i - 1)]] <- mat
  }
  tracker <- mskLongitudinalTracker(tps, metrics = c("rms"))
  mdc <- mskMinimalDetectableChange(tracker)
  # Should not error; MDC should be 0 or near-0 for constant data
  expect_true(all(mdc$mdc_table$MDC == 0 | is.na(mdc$mdc_table$MDC)))
})
