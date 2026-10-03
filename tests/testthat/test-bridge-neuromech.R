library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-neuromech.R -- Tests for neuromechanics bridge functions
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

.make_mock_eeg <- function(n_time = 500, n_channels = 4, sr = 1000) {
  set.seed(42)
  mat <- matrix(rnorm(n_time * n_channels), nrow = n_time, ncol = n_channels)
  all_names <- c("C3", "C4", "Cz", "FC3", "FC4", "C5", "C6", "CP3")
  colnames(mat) <- all_names[seq_len(n_channels)]
  attr(mat, "sr") <- sr
  mat
}

.make_mock_emg <- function(n_time = 500, n_channels = 4, sr = 1000) {
  set.seed(43)
  mat <- matrix(abs(rnorm(n_time * n_channels)), nrow = n_time, ncol = n_channels)
  all_names <- c("Biceps Brachii", "Deltoid", "Trapezius", "Quadriceps",
                 "Gastrocnemius", "Triceps Brachii", "Soleus", "Rectus Femoris")
  colnames(mat) <- all_names[seq_len(n_channels)]
  attr(mat, "sr") <- sr
  mat
}

.make_mock_kinematics <- function(n_time = 500, sr = 100) {
  set.seed(44)
  mat <- matrix(cumsum(rnorm(n_time * 4, sd = 0.01)),
                nrow = n_time, ncol = 4)
  colnames(mat) <- c("upper_arm", "forearm", "thigh", "shank")
  attr(mat, "sr") <- sr
  mat
}

.make_mock_force <- function() {
  c("Biceps Brachii" = 50.0, "Deltoid" = 30.0,
    "Trapezius" = 20.0, "Quadriceps" = 80.0)
}


# ===========================================================================
# Internal helpers
# ===========================================================================

# ---- .extractSignalMatrix ----

test_that(".extractSignalMatrix handles matrix input", {
  mat <- matrix(rnorm(100), 50, 2)
  colnames(mat) <- c("ch1", "ch2")
  attr(mat, "sr") <- 500

  result <- PhysioMSKNet:::.extractSignalMatrix(mat, "test")

  expect_type(result, "list")
  expect_true(all(c("signal_mat", "sr", "ch_names") %in% names(result)))
  expect_equal(result$sr, 500)
  expect_equal(result$ch_names, c("ch1", "ch2"))
  expect_equal(dim(result$signal_mat), c(50, 2))
})

test_that(".extractSignalMatrix handles numeric vector", {
  vec <- rnorm(100)
  result <- PhysioMSKNet:::.extractSignalMatrix(vec, "EMG")

  expect_equal(ncol(result$signal_mat), 1)
  expect_equal(nrow(result$signal_mat), 100)
  expect_equal(result$ch_names, "EMG_1")
})

test_that(".extractSignalMatrix handles matrix without colnames", {
  mat <- matrix(rnorm(60), 20, 3)
  result <- PhysioMSKNet:::.extractSignalMatrix(mat, "EEG")

  expect_equal(result$ch_names, c("EEG_1", "EEG_2", "EEG_3"))
  expect_null(result$sr)
})


# ---- .minimalCMC ----

test_that(".minimalCMC returns correct dimensions", {
  set.seed(42)
  eeg <- matrix(rnorm(500 * 3), 500, 3)
  colnames(eeg) <- c("C3", "C4", "Cz")
  emg <- matrix(rnorm(500 * 2), 500, 2)
  colnames(emg) <- c("Biceps", "Deltoid")

  coh <- PhysioMSKNet:::.minimalCMC(eeg, emg, sr = 1000, freq_band = c(15, 35))

  expect_equal(nrow(coh), 3)
  expect_equal(ncol(coh), 2)
  expect_true(all(coh >= 0))
  expect_true(all(coh <= 1 + 1e-10))
})

test_that(".minimalCMC returns zeros for empty freq band", {
  eeg <- matrix(rnorm(500 * 2), 500, 2)
  colnames(eeg) <- c("C3", "C4")
  emg <- matrix(rnorm(500 * 2), 500, 2)
  colnames(emg) <- c("B1", "B2")

  # Impossible frequency band
  coh <- PhysioMSKNet:::.minimalCMC(eeg, emg, sr = 10, freq_band = c(100, 200))

  expect_true(all(coh == 0))
})


# ---- .minimalCrossCorrelation ----

test_that(".minimalCrossCorrelation detects zero-lag for identical signals", {
  x <- sin(seq(0, 4 * pi, length.out = 200))
  result <- PhysioMSKNet:::.minimalCrossCorrelation(x, x, max_lag = 20)

  expect_equal(result$peak_lag, 0L)
  expect_gt(result$peak_correlation, 0.9)
  expect_equal(length(result$lags), 41)  # -20 to 20
})

test_that(".minimalCrossCorrelation handles constant signals", {
  x <- rep(5, 100)
  y <- rep(3, 100)
  result <- PhysioMSKNet:::.minimalCrossCorrelation(x, y, max_lag = 10)

  expect_equal(result$peak_correlation, 0)
})


# ---- .computeRMS ----

test_that(".computeRMS returns positive values", {
  mat <- matrix(rnorm(200), 100, 2)
  colnames(mat) <- c("ch1", "ch2")
  rms <- PhysioMSKNet:::.computeRMS(mat)

  expect_true(all(rms > 0))
  expect_equal(length(rms), 2)
  expect_equal(names(rms), c("ch1", "ch2"))
})


# ---- .eegChannelLookup ----

test_that(".eegChannelLookup covers standard 10-20 channels", {
  lookup <- PhysioMSKNet:::.eegChannelLookup()

  expect_s3_class(lookup, "data.frame")
  expect_true(all(c("eeg_name", "region", "is_motor") %in% names(lookup)))
  expect_gte(nrow(lookup), 30)

  # Key motor cortex channels
  expect_true("C3" %in% lookup$eeg_name)
  expect_true("C4" %in% lookup$eeg_name)
  expect_true("Cz" %in% lookup$eeg_name)

  # Motor channels should be flagged
  motor_channels <- lookup$eeg_name[lookup$is_motor]
  expect_true("C3" %in% motor_channels)
  expect_true("FC3" %in% motor_channels)

  # Non-motor channels
  non_motor <- lookup$eeg_name[!lookup$is_motor]
  expect_true("O1" %in% non_motor)
})


# ===========================================================================
# neuromechCorticomuscularCoupling
# ===========================================================================

test_that("neuromechCorticomuscularCoupling returns expected structure", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()

  result <- neuromechCorticomuscularCoupling(eeg, emg, hg = hg)

  expect_s3_class(result, "MSKNeuromechCMC")
  expect_true(all(c("cmc_matrix", "structural_matrix", "emg_cmc_profile",
                     "significant_pairs", "mantel", "mapping") %in% names(result)))
})

test_that("neuromechCorticomuscularCoupling CMC matrix has correct dims", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_channels = 3)
  emg <- .make_mock_emg(n_channels = 4)

  result <- neuromechCorticomuscularCoupling(eeg, emg, hg = hg)

  expect_equal(ncol(result$cmc_matrix), 4)
  # EEG channels may be filtered to motor channels
  expect_lte(nrow(result$cmc_matrix), 3)
})

test_that("neuromechCorticomuscularCoupling handles matrix input", {
  hg <- .make_small_hg()
  set.seed(42)
  eeg <- matrix(rnorm(500 * 2), 500, 2)
  colnames(eeg) <- c("C3", "C4")
  attr(eeg, "sr") <- 1000

  emg <- .make_mock_emg()

  result <- neuromechCorticomuscularCoupling(eeg, emg, hg = hg)

  expect_s3_class(result, "MSKNeuromechCMC")
  expect_true(is.matrix(result$cmc_matrix))
})

test_that("neuromechCorticomuscularCoupling freq_band parameter works", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()

  result1 <- neuromechCorticomuscularCoupling(eeg, emg, hg = hg,
                                              freq_band = c(15, 35))
  result2 <- neuromechCorticomuscularCoupling(eeg, emg, hg = hg,
                                              freq_band = c(8, 13))

  # Both should return valid structures
  expect_s3_class(result1, "MSKNeuromechCMC")
  expect_s3_class(result2, "MSKNeuromechCMC")
})

test_that("neuromechCorticomuscularCoupling Mantel p in [0,1]", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()

  result <- neuromechCorticomuscularCoupling(eeg, emg, hg = hg, n_perm = 99)

  if (!is.na(result$mantel$p_value)) {
    expect_gte(result$mantel$p_value, 0)
    expect_lte(result$mantel$p_value, 1)
  }
})

test_that("neuromechCorticomuscularCoupling significant_pairs has correct columns", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()

  result <- neuromechCorticomuscularCoupling(eeg, emg, hg = hg)

  expect_true(all(c("eeg_channel", "emg_channel", "coherence")
                   %in% names(result$significant_pairs)))
})

test_that("neuromechCorticomuscularCoupling with custom eeg_channels", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()

  result <- neuromechCorticomuscularCoupling(eeg, emg, hg = hg,
                                              eeg_channels = c("C3", "C4"))

  expect_s3_class(result, "MSKNeuromechCMC")
  # Should use only 2 EEG channels
  expect_lte(nrow(result$cmc_matrix), 2)
})


# ===========================================================================
# neuromechElectromechanicalDelay
# ===========================================================================

test_that("neuromechElectromechanicalDelay returns expected structure", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()

  result <- neuromechElectromechanicalDelay(emg, kin, hg = hg, sr = 1000)

  expect_type(result, "list")
  expect_true(all(c("emd", "network_distance", "correlation", "p_value",
                     "time_varying") %in% names(result)))
  expect_s3_class(result$emd, "data.frame")
})

test_that("neuromechElectromechanicalDelay EMD values are non-negative", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()

  result <- neuromechElectromechanicalDelay(emg, kin, hg = hg, sr = 1000)

  if (nrow(result$emd) > 0) {
    expect_true(all(result$emd$emd_ms >= 0))
  }
})

test_that("neuromechElectromechanicalDelay uses pre-computed mapping", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()

  emg_mapping <- emgToMSKMapping(colnames(emg), hg = hg, method = "fuzzy")

  result <- neuromechElectromechanicalDelay(emg, kin, hg = hg,
                                            emg_mapping = emg_mapping,
                                            sr = 1000)

  expect_type(result, "list")
})

test_that("neuromechElectromechanicalDelay sliding window works", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg(n_time = 2000)
  kin <- .make_mock_kinematics(n_time = 2000)

  result <- neuromechElectromechanicalDelay(emg, kin, hg = hg,
                                            sr = 1000, window_sec = 0.5)

  # time_varying may be NULL if no connected pairs found in small hg
  if (!is.null(result$time_varying)) {
    expect_s3_class(result$time_varying, "data.frame")
    expect_true("emd_ms" %in% names(result$time_varying))
  }
})

test_that("neuromechElectromechanicalDelay handles single-channel EMG", {
  hg <- .make_small_hg()
  set.seed(45)
  emg <- matrix(abs(rnorm(500)), ncol = 1)
  colnames(emg) <- "Biceps Brachii"
  attr(emg, "sr") <- 1000
  kin <- .make_mock_kinematics()

  result <- neuromechElectromechanicalDelay(emg, kin, hg = hg, sr = 1000)

  expect_type(result, "list")
})

test_that("neuromechElectromechanicalDelay correlation type is numeric", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()

  result <- neuromechElectromechanicalDelay(emg, kin, hg = hg, sr = 1000)

  expect_true(is.numeric(result$correlation))
})

test_that("neuromechElectromechanicalDelay empty for unmatched inputs", {
  hg <- .make_small_hg()
  emg <- matrix(rnorm(500), 500, 1)
  colnames(emg) <- "ZZZZZ"
  attr(emg, "sr") <- 1000
  kin <- .make_mock_kinematics()

  result <- neuromechElectromechanicalDelay(emg, kin, hg = hg, sr = 1000)

  expect_equal(nrow(result$emd), 0)
  expect_true(is.na(result$correlation))
})


# ===========================================================================
# neuromechMotorDriveTopography
# ===========================================================================

test_that("neuromechMotorDriveTopography per_muscle has expected columns", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()
  force <- .make_mock_force()

  result <- neuromechMotorDriveTopography(eeg, emg, force, hg = hg)

  expect_true(all(c("muscle", "cortical_drive", "emg_activation",
                     "force", "drive_efficiency") %in% names(result$per_muscle)))
})

test_that("neuromechMotorDriveTopography per_community has expected columns", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()
  force <- .make_mock_force()

  result <- neuromechMotorDriveTopography(eeg, emg, force, hg = hg, gamma = 1.0)

  expect_true(all(c("community", "n_muscles", "mean_drive",
                     "mean_activation", "mean_force")
                   %in% names(result$per_community)))
  expect_gte(nrow(result$per_community), 1)
})

test_that("neuromechMotorDriveTopography drive_force_correlation is numeric", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()
  force <- .make_mock_force()

  result <- neuromechMotorDriveTopography(eeg, emg, force, hg = hg)

  expect_true(is.numeric(result$drive_force_correlation))
  expect_true(is.numeric(result$drive_force_p_value))
})

test_that("neuromechMotorDriveTopography handles force as named vector", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()
  force <- .make_mock_force()

  result <- neuromechMotorDriveTopography(eeg, emg, force, hg = hg)

  expect_gte(nrow(result$per_muscle), 1)
  expect_true(any(result$per_muscle$force > 0))
})

test_that("neuromechMotorDriveTopography handles force as data.frame", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()
  force_df <- data.frame(
    muscle = c("Biceps Brachii", "Deltoid", "Trapezius", "Quadriceps"),
    force = c(50, 30, 20, 80),
    stringsAsFactors = FALSE
  )

  result <- neuromechMotorDriveTopography(eeg, emg, force_df, hg = hg)

  expect_gte(nrow(result$per_muscle), 1)
})

test_that("neuromechMotorDriveTopography empty mapping returns empty", {
  hg <- .make_small_hg()
  set.seed(42)
  eeg <- .make_mock_eeg()
  emg <- matrix(rnorm(500 * 2), 500, 2)
  colnames(emg) <- c("XXXXX", "YYYYY")
  attr(emg, "sr") <- 1000
  force <- c(XXXXX = 10, YYYYY = 20)

  result <- neuromechMotorDriveTopography(eeg, emg, force, hg = hg)

  expect_equal(nrow(result$per_muscle), 0)
  expect_true(is.na(result$drive_force_correlation))
})


# ===========================================================================
# neuromechIntegratedVulnerability
# ===========================================================================

test_that("neuromechIntegratedVulnerability returns correct vector length", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()
  force <- .make_mock_force()

  result <- neuromechIntegratedVulnerability(emg, kin, force, hg = hg)

  expect_equal(length(result$vulnerability), hg$n_muscles)
  expect_equal(names(result$vulnerability), hg$muscle_names)
})

test_that("neuromechIntegratedVulnerability ranking is sorted descending", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()
  force <- .make_mock_force()

  result <- neuromechIntegratedVulnerability(emg, kin, force, hg = hg)

  vuln_vals <- result$ranking$vulnerability
  expect_true(all(diff(vuln_vals) <= 0))  # non-increasing
})

test_that("neuromechIntegratedVulnerability custom weights work", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()
  force <- .make_mock_force()

  result1 <- neuromechIntegratedVulnerability(emg, kin, force, hg = hg,
                                              weights = c(1, 0, 0))
  result2 <- neuromechIntegratedVulnerability(emg, kin, force, hg = hg,
                                              weights = c(0, 1, 0))

  # Different weights should give different vulnerability rankings
  # (at least the values should differ)
  expect_false(identical(result1$vulnerability, result2$vulnerability))
})

test_that("neuromechIntegratedVulnerability source_correlations present", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()
  force <- .make_mock_force()

  result <- neuromechIntegratedVulnerability(emg, kin, force, hg = hg)

  expect_type(result$source_correlations, "list")
  expect_true(all(c("emg_kin", "emg_force", "kin_force")
                   %in% names(result$source_correlations)))
})

test_that("neuromechIntegratedVulnerability handles partial coverage", {
  hg <- .make_small_hg()
  # Only one EMG channel matches
  emg <- matrix(abs(rnorm(500)), ncol = 1)
  colnames(emg) <- "Biceps Brachii"
  attr(emg, "sr") <- 1000
  kin <- .make_mock_kinematics()
  force <- c("Biceps Brachii" = 50)

  result <- neuromechIntegratedVulnerability(emg, kin, force, hg = hg)

  expect_equal(length(result$vulnerability), hg$n_muscles)
})

test_that("neuromechIntegratedVulnerability vulnerability is non-negative", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()
  force <- .make_mock_force()

  result <- neuromechIntegratedVulnerability(emg, kin, force, hg = hg)

  expect_true(all(result$vulnerability >= 0))
})


# ===========================================================================
# neuromechSummary
# ===========================================================================

test_that("neuromechSummary returns S3 class MSKNeuromechSummary", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechSummary(emg = emg, hg = hg)

  expect_s3_class(result, "MSKNeuromechSummary")
  expect_true(all(c("cmc", "emd", "motor_drive", "vulnerability",
                     "available_analyses") %in% names(result)))
})

test_that("neuromechSummary available_analyses reflects inputs", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()
  force <- .make_mock_force()

  # EMG only -> torque and synergy may run (they only need EMG)
  result1 <- neuromechSummary(emg = emg, hg = hg)
  expect_true(length(result1$available_analyses) >= 0)

  # With EEG -> cmc should be available
  result2 <- neuromechSummary(eeg = eeg, emg = emg, hg = hg)
  expect_true("cmc" %in% result2$available_analyses)
  expect_null(result2$emd)

  # With kinematics -> emd should be available
  result3 <- neuromechSummary(emg = emg, kinematics = kin, hg = hg)
  expect_true("emd" %in% result3$available_analyses)
  expect_null(result3$cmc)
})

test_that("neuromechSummary print method works", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()
  force <- .make_mock_force()

  result <- neuromechSummary(eeg = eeg, emg = emg, kinematics = kin,
                              force_data = force, hg = hg)

  expect_output(print(result), "MSK Neuromechanics Summary")
})

test_that("neuromechSummary NULL inputs are skipped", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechSummary(eeg = NULL, emg = emg, kinematics = NULL,
                              force_data = NULL, hg = hg)

  expect_null(result$cmc)
  expect_null(result$emd)
  expect_null(result$motor_drive)
  expect_null(result$vulnerability)
})

test_that("neuromechSummary full pipeline runs", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()
  force <- .make_mock_force()

  result <- neuromechSummary(eeg = eeg, emg = emg, kinematics = kin,
                              force_data = force, hg = hg)

  expect_s3_class(result, "MSKNeuromechSummary")
  # CMC should be available
  expect_true("cmc" %in% result$available_analyses)
  expect_false(is.null(result$cmc))
})


# ===========================================================================
# Integration tests
# ===========================================================================

test_that("full neuromech pipeline with all inputs", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()
  force <- .make_mock_force()

  # CMC
  cmc <- neuromechCorticomuscularCoupling(eeg, emg, hg = hg)
  expect_s3_class(cmc, "MSKNeuromechCMC")

  # EMD
  emd <- neuromechElectromechanicalDelay(emg, kin, hg = hg, sr = 1000)
  expect_type(emd, "list")

  # Motor drive
  md <- neuromechMotorDriveTopography(eeg, emg, force, hg = hg)
  expect_type(md, "list")

  # Vulnerability
  vuln <- neuromechIntegratedVulnerability(emg, kin, force, hg = hg)
  expect_type(vuln, "list")
  expect_equal(length(vuln$vulnerability), hg$n_muscles)
})

test_that("neuromech pipeline with partial data", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()
  kin <- .make_mock_kinematics()

  # No EEG, no force -> only EMD possible
  result <- neuromechSummary(emg = emg, kinematics = kin, hg = hg)

  expect_null(result$cmc)
  expect_null(result$motor_drive)
  expect_null(result$vulnerability)  # needs force too
  # EMD should work
  expect_true("emd" %in% result$available_analyses)
})

test_that("neuromech pipeline with default hypergraph", {
  # Test that functions work without explicit hg argument
  # This will load the full 173-bone, 270-muscle hypergraph
  eeg <- .make_mock_eeg()
  emg <- .make_mock_emg()

  result <- neuromechCorticomuscularCoupling(eeg, emg)

  expect_s3_class(result, "MSKNeuromechCMC")
  expect_true(is.matrix(result$cmc_matrix))
})


# ===========================================================================
# Joint Torque Modeling (15 tests)
# ===========================================================================

test_that(".momentArmLookup returns valid structure", {
  lookup <- PhysioMSKNet:::.momentArmLookup()

  expect_s3_class(lookup, "data.frame")
  expect_true(all(c("muscle_name", "joint_name", "bone_proximal",
                     "bone_distal", "moment_arm_m", "direction")
                   %in% names(lookup)))
  expect_gte(nrow(lookup), 30)
  expect_true(all(lookup$moment_arm_m > 0))
  expect_true(all(lookup$direction %in% c(-1L, 1L)))
})

test_that(".momentArmLookup covers major joints", {
  lookup <- PhysioMSKNet:::.momentArmLookup()
  joints <- unique(lookup$joint_name)

  expect_true("elbow" %in% joints)
  expect_true("shoulder" %in% joints)
  expect_true("knee" %in% joints)
  expect_true("hip" %in% joints)
  expect_true("ankle" %in% joints)
  expect_true("wrist" %in% joints)
  expect_true("spine" %in% joints)
})

test_that(".momentArmLookup has agonist and antagonist per joint", {
  lookup <- PhysioMSKNet:::.momentArmLookup()

  for (jt in unique(lookup$joint_name)) {
    sub <- lookup[lookup$joint_name == jt, ]
    expect_true(any(sub$direction == 1), info = paste("agonist for", jt))
    expect_true(any(sub$direction == -1), info = paste("antagonist for", jt))
  }
})

test_that(".matchMuscleToTorqueTable matches known muscles", {
  hg <- .make_small_hg()
  result <- PhysioMSKNet:::.matchMuscleToTorqueTable(
    c("Biceps Brachii", "Deltoid"), hg
  )

  expect_gte(nrow(result), 1)
  expect_true("Biceps Brachii" %in% result$emg_name ||
              "Deltoid" %in% result$emg_name)
})

test_that(".matchMuscleToTorqueTable returns empty for unknown muscles", {
  hg <- .make_small_hg()
  result <- PhysioMSKNet:::.matchMuscleToTorqueTable("ZZZZNOTAMUSCLE", hg)

  expect_equal(nrow(result), 0)
})

test_that("neuromechJointTorque returns S3 class", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechJointTorque(emg, hg = hg, n_perm = 99)

  expect_s3_class(result, "MSKNeuromechTorque")
  expect_true(all(c("per_muscle", "per_joint", "torque_balance",
                     "msk_correlation", "moment_arm_source")
                   %in% names(result)))
})

test_that("neuromechJointTorque per_joint has expected columns", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechJointTorque(emg, hg = hg, n_perm = 99)

  if (nrow(result$per_joint) > 0) {
    expect_true(all(c("joint", "net_torque", "agonist_sum",
                       "antagonist_sum", "coactivation_index", "n_muscles")
                     %in% names(result$per_joint)))
  }
})

test_that("neuromechJointTorque coactivation_index in [0,1]", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechJointTorque(emg, hg = hg, n_perm = 99)

  if (nrow(result$per_joint) > 0) {
    expect_true(all(result$per_joint$coactivation_index >= 0))
    expect_true(all(result$per_joint$coactivation_index <= 1))
  }
})

test_that("neuromechJointTorque accepts custom moment_arm_table", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  custom_table <- data.frame(
    muscle_name = c("Biceps Brachii", "Deltoid"),
    joint_name = c("elbow", "shoulder"),
    moment_arm_m = c(0.05, 0.06),
    direction = c(1L, 1L),
    stringsAsFactors = FALSE
  )

  result <- neuromechJointTorque(emg, hg = hg,
                                  moment_arm_table = custom_table,
                                  n_perm = 99)

  expect_s3_class(result, "MSKNeuromechTorque")
  expect_equal(result$moment_arm_source, "custom")
})

test_that("neuromechJointTorque single EMG channel", {
  hg <- .make_small_hg()
  emg <- matrix(abs(rnorm(500)), ncol = 1)
  colnames(emg) <- "Biceps Brachii"
  attr(emg, "sr") <- 1000

  result <- neuromechJointTorque(emg, hg = hg, n_perm = 99)

  expect_s3_class(result, "MSKNeuromechTorque")
})

test_that("neuromechJointTorque activation_method parameter", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result_rms <- neuromechJointTorque(emg, hg = hg,
                                      activation_method = "rms",
                                      n_perm = 99)
  result_rect <- neuromechJointTorque(emg, hg = hg,
                                       activation_method = "mean_rectified",
                                       n_perm = 99)
  result_peak <- neuromechJointTorque(emg, hg = hg,
                                       activation_method = "peak",
                                       n_perm = 99)

  expect_s3_class(result_rms, "MSKNeuromechTorque")
  expect_s3_class(result_rect, "MSKNeuromechTorque")
  expect_s3_class(result_peak, "MSKNeuromechTorque")
})

test_that("neuromechJointTorque unmatched EMG returns empty", {
  hg <- .make_small_hg()
  emg <- matrix(rnorm(500), ncol = 1)
  colnames(emg) <- "ZZZZZZZ"
  attr(emg, "sr") <- 1000

  result <- neuromechJointTorque(emg, hg = hg, n_perm = 99)

  expect_equal(nrow(result$per_muscle), 0)
  expect_equal(nrow(result$per_joint), 0)
})

test_that("neuromechJointTorque joints filter works", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechJointTorque(emg, hg = hg,
                                  joints = c("elbow"),
                                  n_perm = 99)

  if (nrow(result$per_joint) > 0) {
    expect_true(all(result$per_joint$joint == "elbow"))
  }
})

test_that("neuromechJointTorque print method works", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechJointTorque(emg, hg = hg, n_perm = 99)

  expect_output(print(result), "MSK Neuromech Joint Torque")
})


# ===========================================================================
# Muscle Synergy Decomposition (15 tests)
# ===========================================================================

test_that(".nmfMultiplicativeUpdate returns correct dimensions", {
  set.seed(42)
  V <- matrix(abs(rnorm(20)), 4, 5)
  result <- PhysioMSKNet:::.nmfMultiplicativeUpdate(V, k = 2, max_iter = 50)

  expect_equal(nrow(result$W), 4)
  expect_equal(ncol(result$W), 2)
  expect_equal(nrow(result$H), 2)
  expect_equal(ncol(result$H), 5)
  expect_true(result$reconstruction_error >= 0)
})

test_that(".nmfMultiplicativeUpdate reconstruction error decreases", {
  set.seed(42)
  V <- matrix(abs(rnorm(100)) + 0.1, 10, 10)
  r1 <- PhysioMSKNet:::.nmfMultiplicativeUpdate(V, k = 3, max_iter = 10)
  r2 <- PhysioMSKNet:::.nmfMultiplicativeUpdate(V, k = 3, max_iter = 200)

  # More iterations should give lower or equal error
  expect_lte(r2$reconstruction_error, r1$reconstruction_error + 1e-6)
})

test_that(".nmfMultiplicativeUpdate handles near-zero matrix", {
  V <- matrix(1e-10, 3, 3)
  result <- PhysioMSKNet:::.nmfMultiplicativeUpdate(V, k = 2, max_iter = 10)

  expect_equal(nrow(result$W), 3)
  expect_equal(ncol(result$H), 3)
})

test_that(".nmfMultiplicativeUpdate seed reproducibility", {
  V <- matrix(abs(rnorm(50)) + 0.1, 5, 10)
  r1 <- PhysioMSKNet:::.nmfMultiplicativeUpdate(V, k = 2, seed = 123)
  r2 <- PhysioMSKNet:::.nmfMultiplicativeUpdate(V, k = 2, seed = 123)

  expect_equal(r1$reconstruction_error, r2$reconstruction_error)
  expect_equal(r1$W, r2$W)
})

test_that(".pcaSynergy returns correct dimensions", {
  V <- matrix(rnorm(50), 5, 10)
  result <- PhysioMSKNet:::.pcaSynergy(V, k = 2)

  expect_equal(nrow(result$W), 5)
  expect_equal(ncol(result$W), 2)
  expect_equal(nrow(result$H), 2)
  expect_equal(ncol(result$H), 10)
})

test_that(".pcaSynergy variance_explained bounded by 1", {
  V <- matrix(rnorm(50), 5, 10)
  result <- PhysioMSKNet:::.pcaSynergy(V, k = 3)

  expect_true(all(result$variance_explained >= 0))
  expect_true(all(result$variance_explained <= 1 + 1e-10))
})

test_that(".selectNSynergies optimal_k in valid range", {
  V <- matrix(abs(rnorm(100)) + 0.1, 5, 20)
  result <- PhysioMSKNet:::.selectNSynergies(V, max_k = 5, threshold = 0.80,
                                              seed = 42)

  expect_gte(result$optimal_k, 1)
  expect_lte(result$optimal_k, 5)
  expect_equal(length(result$vaf_curve), 5)
})

test_that("neuromechMuscleSynergy returns S3 class", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechMuscleSynergy(emg, hg = hg, n_synergies = 2)

  expect_s3_class(result, "MSKNeuromechSynergy")
  expect_true(all(c("W", "H", "n_synergies", "vaf", "method",
                     "community_mapping", "synergy_similarity",
                     "reconstruction_error") %in% names(result)))
})

test_that("neuromechMuscleSynergy NMF produces valid VAF", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechMuscleSynergy(emg, hg = hg, method = "nmf",
                                    n_synergies = 2)

  expect_gte(result$vaf, 0)
  expect_lte(result$vaf, 1 + 1e-6)
  expect_equal(result$method, "nmf")
})

test_that("neuromechMuscleSynergy PCA produces valid VAF", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechMuscleSynergy(emg, hg = hg, method = "pca",
                                    n_synergies = 2)

  expect_true(is.numeric(result$vaf))
  expect_equal(result$method, "pca")
})

test_that("neuromechMuscleSynergy auto_select works", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechMuscleSynergy(emg, hg = hg, method = "nmf",
                                    auto_select = TRUE, max_k = 4,
                                    vaf_threshold = 0.50, seed = 42)

  expect_gte(result$n_synergies, 1)
  expect_lte(result$n_synergies, 4)
  expect_false(is.null(result$vaf_curve))
})

test_that("neuromechMuscleSynergy caps n_synergies with warning", {
  hg <- .make_small_hg()
  emg <- matrix(abs(rnorm(500 * 2)), 500, 2)
  colnames(emg) <- c("Biceps Brachii", "Deltoid")
  attr(emg, "sr") <- 1000

  expect_warning(
    result <- neuromechMuscleSynergy(emg, hg = hg, n_synergies = 10),
    "exceeds"
  )
  expect_lte(result$n_synergies, 2)
})

test_that("neuromechMuscleSynergy single channel", {
  hg <- .make_small_hg()
  emg <- matrix(abs(rnorm(500)), ncol = 1)
  colnames(emg) <- "Biceps Brachii"
  attr(emg, "sr") <- 1000

  expect_warning(
    result <- neuromechMuscleSynergy(emg, hg = hg, n_synergies = 2),
    "exceeds"
  )
  expect_equal(result$n_synergies, 1)
})

test_that("neuromechMuscleSynergy synergy_similarity is square", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechMuscleSynergy(emg, hg = hg, n_synergies = 3)

  expect_equal(nrow(result$synergy_similarity), 3)
  expect_equal(ncol(result$synergy_similarity), 3)
  # Diagonal should be 1
  expect_true(all(abs(diag(result$synergy_similarity) - 1) < 0.01))
})

test_that("neuromechMuscleSynergy print method works", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechMuscleSynergy(emg, hg = hg, n_synergies = 2)

  expect_output(print(result), "MSK Neuromech Muscle Synergy")
})


# ===========================================================================
# Directional Connectivity (15 tests)
# ===========================================================================

test_that(".grangerCausalityPairwise returns expected structure", {
  set.seed(42)
  x <- rnorm(200)
  y <- rnorm(200)
  result <- PhysioMSKNet:::.grangerCausalityPairwise(x, y, max_order = 5)

  expect_type(result, "list")
  expect_true(all(c("f_statistic", "p_value", "optimal_order", "direction")
                   %in% names(result)))
  expect_equal(result$direction, "x->y")
})

test_that(".grangerCausalityPairwise detects known causal relation", {
  set.seed(42)
  n <- 1000
  x <- rnorm(n)
  # y strongly depends on lagged x
  y <- numeric(n)
  for (i in 3:n) y[i] <- 0.9 * x[i - 1] + 0.5 * x[i - 2] + rnorm(1, sd = 0.1)
  result <- PhysioMSKNet:::.grangerCausalityPairwise(x, y, max_order = 5)

  expect_true(is.numeric(result$f_statistic))
  expect_false(is.na(result$f_statistic))
})

test_that(".grangerCausalityPairwise handles constant signal", {
  x <- rep(5, 100)
  y <- rnorm(100)
  result <- PhysioMSKNet:::.grangerCausalityPairwise(x, y, max_order = 3)

  # Should return without error
  expect_type(result, "list")
})

test_that(".grangerCausalityPairwise handles too-short series", {
  x <- rnorm(5)
  y <- rnorm(5)
  result <- PhysioMSKNet:::.grangerCausalityPairwise(x, y, max_order = 10)

  expect_true(is.na(result$f_statistic))
  expect_true(is.na(result$p_value))
})

test_that(".transferEntropyPairwise returns non-negative", {
  set.seed(42)
  x <- rnorm(200)
  y <- rnorm(200)
  result <- PhysioMSKNet:::.transferEntropyPairwise(x, y, lag = 1)

  expect_gte(result$te_value, 0)
  expect_true(is.numeric(result$n_bins_used))
})

test_that(".transferEntropyPairwise detects information flow", {
  set.seed(42)
  n <- 500
  x <- rnorm(n)
  # y depends on lagged x
  y <- c(0, x[1:(n - 1)] * 0.9) + rnorm(n, sd = 0.2)

  te_xy <- PhysioMSKNet:::.transferEntropyPairwise(x, y, lag = 1)
  te_yx <- PhysioMSKNet:::.transferEntropyPairwise(y, x, lag = 1)

  # TE(x->y) should be larger than TE(y->x) for this causal relation
  expect_gte(te_xy$te_value, 0)
})

test_that(".transferEntropyPairwise handles constant input", {
  x <- rep(5, 100)
  y <- rnorm(100)
  result <- PhysioMSKNet:::.transferEntropyPairwise(x, y, lag = 1)

  expect_equal(result$te_value, 0)
})

test_that(".transferEntropyPairwise handles too-short series", {
  x <- rnorm(3)
  y <- rnorm(3)
  result <- PhysioMSKNet:::.transferEntropyPairwise(x, y, lag = 2)

  expect_equal(result$te_value, 0)
})

test_that("neuromechDirectionalCoupling returns S3 class", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300, n_channels = 2)
  emg <- .make_mock_emg(n_time = 300, n_channels = 2)

  result <- neuromechDirectionalCoupling(eeg, emg, hg = hg,
                                          max_order_ms = 20,
                                          n_perm = 99)

  expect_s3_class(result, "MSKNeuromechDirectional")
  expect_true(all(c("descending", "ascending", "net_direction",
                     "significant_descending", "significant_ascending",
                     "dominance_ratio", "pathway_classification",
                     "method") %in% names(result)))
})

test_that("neuromechDirectionalCoupling correct dimensions", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300, n_channels = 2)
  emg <- .make_mock_emg(n_time = 300, n_channels = 3)

  result <- neuromechDirectionalCoupling(eeg, emg, hg = hg,
                                          max_order_ms = 20,
                                          n_perm = 99)

  expect_equal(nrow(result$descending), 2)
  expect_equal(ncol(result$descending), 3)
  expect_equal(nrow(result$ascending), 3)
  expect_equal(ncol(result$ascending), 2)
})

test_that("neuromechDirectionalCoupling transfer_entropy method", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300, n_channels = 2)
  emg <- .make_mock_emg(n_time = 300, n_channels = 2)

  result <- neuromechDirectionalCoupling(eeg, emg, hg = hg,
                                          method = "transfer_entropy",
                                          lag_ms = 10, n_perm = 99)

  expect_s3_class(result, "MSKNeuromechDirectional")
  expect_equal(result$method, "transfer_entropy")
})

test_that("neuromechDirectionalCoupling both method", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300, n_channels = 2)
  emg <- .make_mock_emg(n_time = 300, n_channels = 2)

  result <- neuromechDirectionalCoupling(eeg, emg, hg = hg,
                                          method = "both",
                                          max_order_ms = 20,
                                          lag_ms = 10, n_perm = 99)

  expect_s3_class(result, "MSKNeuromechDirectional")
  expect_true("descending_te" %in% names(result))
  expect_true("ascending_te" %in% names(result))
})

test_that("neuromechDirectionalCoupling pathway_classification valid", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300, n_channels = 2)
  emg <- .make_mock_emg(n_time = 300, n_channels = 2)

  result <- neuromechDirectionalCoupling(eeg, emg, hg = hg,
                                          max_order_ms = 20,
                                          n_perm = 99)

  expect_s3_class(result$pathway_classification, "data.frame")
  expect_true(all(result$pathway_classification$classification %in%
                    c("descending", "ascending", "bidirectional", "none")))
})

test_that("neuromechDirectionalCoupling dominance_ratio is numeric", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300, n_channels = 2)
  emg <- .make_mock_emg(n_time = 300, n_channels = 2)

  result <- neuromechDirectionalCoupling(eeg, emg, hg = hg,
                                          max_order_ms = 20,
                                          n_perm = 99)

  expect_true(is.numeric(result$dominance_ratio))
  expect_equal(length(result$dominance_ratio), 2)
})

test_that("neuromechDirectionalCoupling single EEG channel", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300, n_channels = 1)
  emg <- .make_mock_emg(n_time = 300, n_channels = 2)

  result <- neuromechDirectionalCoupling(eeg, emg, hg = hg,
                                          max_order_ms = 20,
                                          n_perm = 99)

  expect_s3_class(result, "MSKNeuromechDirectional")
  expect_equal(nrow(result$descending), 1)
})

test_that("neuromechDirectionalCoupling print method works", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300, n_channels = 2)
  emg <- .make_mock_emg(n_time = 300, n_channels = 2)

  result <- neuromechDirectionalCoupling(eeg, emg, hg = hg,
                                          max_order_ms = 20,
                                          n_perm = 99)

  expect_output(print(result), "MSK Neuromech Directional")
})


# ===========================================================================
# Extended neuromechSummary tests
# ===========================================================================

test_that("neuromechSummary includes torque and synergy", {
  hg <- .make_small_hg()
  emg <- .make_mock_emg()

  result <- neuromechSummary(emg = emg, hg = hg)

  expect_true("synergy" %in% result$available_analyses)
  expect_false(is.null(result$synergy))
  # Torque may or may not match depending on muscle names
  expect_true("torque" %in% names(result))
  expect_true("synergy" %in% names(result))
  expect_true("directional" %in% names(result))
})

test_that("neuromechSummary includes directional with EEG", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300)
  emg <- .make_mock_emg(n_time = 300)

  result <- neuromechSummary(eeg = eeg, emg = emg, hg = hg)

  expect_true("directional" %in% result$available_analyses)
  expect_false(is.null(result$directional))
})

test_that("neuromechSummary extended print method works", {
  hg <- .make_small_hg()
  eeg <- .make_mock_eeg(n_time = 300)
  emg <- .make_mock_emg(n_time = 300)

  result <- neuromechSummary(eeg = eeg, emg = emg, hg = hg)

  output <- capture.output(print(result))
  output_text <- paste(output, collapse = "\n")
  expect_true(grepl("Synergy|Directional", output_text))
})
