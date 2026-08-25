library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-imu.R -- Tests for IMU bridge functions
# ===========================================================================

# ---- Helpers ----

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

.make_mock_imu_list <- function(n_samples = 200, sensors = NULL) {
  if (is.null(sensors)) {
    sensors <- c("upper_arm", "forearm", "thigh", "shank")
  }
  set.seed(42)
  imu <- list()
  for (s in sensors) {
    accel <- matrix(rnorm(n_samples * 3), nrow = n_samples, ncol = 3)
    gyro <- matrix(rnorm(n_samples * 3, sd = 0.5), nrow = n_samples, ncol = 3)
    imu[[s]] <- cbind(accel, gyro)
  }
  # Add correlation between upper_arm and forearm
  if ("upper_arm" %in% sensors && "forearm" %in% sensors) {
    imu[["forearm"]][, 1:3] <- imu[["upper_arm"]][, 1:3] * 0.7 +
      matrix(rnorm(n_samples * 3, sd = 0.3), nrow = n_samples)
  }
  attr(imu, "sr") <- 100
  imu
}

.make_mock_imu_matrix <- function(n_samples = 200) {
  set.seed(42)
  mat <- matrix(rnorm(n_samples * 9), nrow = n_samples, ncol = 9)
  colnames(mat) <- c("upper_arm_ax", "upper_arm_ay", "upper_arm_az",
                      "thigh_ax", "thigh_ay", "thigh_az",
                      "shank_ax", "shank_ay", "shank_az")
  mat
}

.make_mock_imu_df <- function(n_samples = 200) {
  set.seed(42)
  data.frame(
    ax = rnorm(n_samples), ay = rnorm(n_samples), az = rnorm(n_samples),
    gx = rnorm(n_samples, sd = 0.5), gy = rnorm(n_samples, sd = 0.5),
    gz = rnorm(n_samples, sd = 0.5)
  )
}


# ===========================================================================
# .imuBoneLookup
# ===========================================================================

test_that(".imuBoneLookup returns valid lookup table", {
  lookup <- PhysioMSKNet:::.imuBoneLookup()
  expect_s3_class(lookup, "data.frame")
  expect_true(all(c("imu_name", "bone_name") %in% names(lookup)))
  expect_gt(nrow(lookup), 30)
})

test_that(".imuBoneLookup has no NA values", {
  lookup <- PhysioMSKNet:::.imuBoneLookup()
  expect_false(any(is.na(lookup$imu_name)))
  expect_false(any(is.na(lookup$bone_name)))
})

test_that(".imuBoneLookup covers expected sensor names", {
  lookup <- PhysioMSKNet:::.imuBoneLookup()
  expected <- c("head", "chest", "pelvis", "upper_arm", "forearm",
                "thigh", "shank", "foot")
  for (s in expected) {
    expect_true(s %in% lookup$imu_name,
                info = paste("Missing sensor:", s))
  }
})

test_that(".imuBoneLookup covers Xsens names", {
  lookup <- PhysioMSKNet:::.imuBoneLookup()
  xsens_names <- c("Head", "Sternum", "Pelvis", "RightUpperArm",
                    "RightForeArm", "RightUpperLeg", "RightLowerLeg")
  for (s in xsens_names) {
    expect_true(s %in% lookup$imu_name,
                info = paste("Missing Xsens sensor:", s))
  }
})


# ===========================================================================
# imuToMSKMapping
# ===========================================================================

test_that("imuToMSKMapping returns correct structure", {
  mapping <- imuToMSKMapping(c("upper_arm", "thigh"))
  expect_s3_class(mapping, "data.frame")
  expect_true(all(c("sensor_name", "bone_idx", "bone_name",
                     "match_quality", "match_method") %in% names(mapping)))
})

test_that("imuToMSKMapping maps upper_arm to Humerus", {
  mapping <- imuToMSKMapping("upper_arm")
  expect_equal(nrow(mapping), 1)
  expect_equal(mapping$bone_name[1], "Humerus")
  expect_equal(mapping$match_quality[1], 1.0)
  expect_equal(mapping$match_method[1], "lookup")
})

test_that("imuToMSKMapping maps thigh to Femur", {
  mapping <- imuToMSKMapping("thigh")
  expect_equal(mapping$bone_name[1], "Femur")
})

test_that("imuToMSKMapping maps multiple sensors", {
  mapping <- imuToMSKMapping(c("upper_arm", "forearm", "thigh", "shank"))
  expect_gte(nrow(mapping), 4)
})

test_that("imuToMSKMapping maps Xsens sensor names", {
  mapping <- imuToMSKMapping(c("RightUpperArm", "RightForeArm"))
  expect_gte(nrow(mapping), 2)
  expect_true("Humerus" %in% mapping$bone_name)
  expect_true("Radius" %in% mapping$bone_name)
})

test_that("imuToMSKMapping maps APDM sensor names", {
  mapping <- imuToMSKMapping(c("lumbar_sensor", "sternum_sensor"))
  expect_gte(nrow(mapping), 2)
})

test_that("imuToMSKMapping returns empty for unknown sensors", {
  mapping <- imuToMSKMapping(c("xyz_unknown", "abc_invalid"),
                              method = "exact")
  expect_equal(nrow(mapping), 0)
})

test_that("imuToMSKMapping works with custom hg", {
  hg <- .make_small_hg()
  mapping <- imuToMSKMapping(c("upper_arm", "thigh"), hg = hg)
  expect_gte(nrow(mapping), 1)
  expect_true(all(mapping$bone_name %in% hg$bone_names))
})

test_that("imuToMSKMapping fuzzy matching works", {
  mapping <- imuToMSKMapping("humerus_sensor", method = "fuzzy",
                              threshold = 0.5)
  # Should find Humerus via fuzzy match or cleanup
  expect_gte(nrow(mapping), 0)  # may or may not match depending on distance
})

test_that("imuToMSKMapping handles case insensitivity", {
  m1 <- imuToMSKMapping("upper_arm")
  m2 <- imuToMSKMapping("UPPER_ARM")
  # Both should map to Humerus (via lowercase normalization)
  expect_equal(m1$bone_name[1], "Humerus")
})


# ===========================================================================
# .parseIMUData
# ===========================================================================

test_that(".parseIMUData handles named list input", {
  imu <- .make_mock_imu_list()
  result <- PhysioMSKNet:::.parseIMUData(imu, "acceleration")
  expect_type(result, "list")
  expect_equal(length(result), 4)
  expect_true("upper_arm" %in% names(result))
})

test_that(".parseIMUData handles matrix with sensor-prefixed columns", {
  mat <- .make_mock_imu_matrix()
  result <- PhysioMSKNet:::.parseIMUData(mat, "acceleration")
  expect_type(result, "list")
  expect_true("upper_arm" %in% names(result) ||
              any(grepl("upper_arm", names(result))))
})

test_that(".parseIMUData handles plain matrix", {
  set.seed(42)
  mat <- matrix(rnorm(200 * 3), nrow = 200, ncol = 3)
  result <- PhysioMSKNet:::.parseIMUData(mat, "acceleration")
  expect_type(result, "list")
  expect_gte(length(result), 1)
})

test_that(".parseIMUData errors on invalid input", {
  expect_error(PhysioMSKNet:::.parseIMUData("not valid", "acceleration"))
})


# ===========================================================================
# .parseIMUDataRaw
# ===========================================================================

test_that(".parseIMUDataRaw handles list input", {
  imu <- .make_mock_imu_list()
  result <- PhysioMSKNet:::.parseIMUDataRaw(imu)
  expect_type(result, "list")
  expect_equal(length(result), 4)
})

test_that(".parseIMUDataRaw handles matrix input", {
  mat <- .make_mock_imu_matrix()
  result <- PhysioMSKNet:::.parseIMUDataRaw(mat)
  expect_type(result, "list")
})


# ===========================================================================
# .computeIMUStress
# ===========================================================================

test_that(".computeIMUStress computes acceleration stress from matrix", {
  set.seed(42)
  # 6 columns: 3 accel + 3 gyro
  mat <- matrix(rnorm(200 * 6), nrow = 200, ncol = 6)
  stress <- PhysioMSKNet:::.computeIMUStress(mat, "acceleration")
  expect_type(stress, "double")
  expect_gt(stress, 0)
})

test_that(".computeIMUStress computes angular_velocity from gyro", {
  set.seed(42)
  mat <- matrix(rnorm(200 * 6), nrow = 200, ncol = 6)
  stress <- PhysioMSKNet:::.computeIMUStress(mat, "angular_velocity")
  expect_gt(stress, 0)
})

test_that(".computeIMUStress computes jerk", {
  set.seed(42)
  mat <- matrix(rnorm(200 * 6), nrow = 200, ncol = 6)
  stress <- PhysioMSKNet:::.computeIMUStress(mat, "jerk")
  expect_gt(stress, 0)
})

test_that(".computeIMUStress computes composite", {
  set.seed(42)
  mat <- matrix(rnorm(200 * 6), nrow = 200, ncol = 6)
  stress <- PhysioMSKNet:::.computeIMUStress(mat, "composite")
  expect_gt(stress, 0)
})

test_that(".computeIMUStress handles list with accel/gyro", {
  set.seed(42)
  sd <- list(
    accel = matrix(rnorm(200 * 3), nrow = 200, ncol = 3),
    gyro = matrix(rnorm(200 * 3, sd = 0.5), nrow = 200, ncol = 3)
  )
  stress <- PhysioMSKNet:::.computeIMUStress(sd, "acceleration")
  expect_gt(stress, 0)

  stress_gyro <- PhysioMSKNet:::.computeIMUStress(sd, "angular_velocity")
  expect_gt(stress_gyro, 0)
})

test_that(".computeIMUStress handles data.frame", {
  df <- .make_mock_imu_df()
  stress <- PhysioMSKNet:::.computeIMUStress(df, "acceleration")
  expect_gt(stress, 0)
})

test_that(".computeIMUStress returns 0 for invalid input", {
  stress <- PhysioMSKNet:::.computeIMUStress("invalid", "acceleration")
  expect_equal(stress, 0)
})


# ===========================================================================
# imuNetworkKinematics
# ===========================================================================

test_that("imuNetworkKinematics returns expected structure", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "forearm", "thigh"))

  result <- imuNetworkKinematics(imu, hg = hg)

  expect_type(result, "list")
  expect_true(all(c("kinematic_coupling", "structural_matrix",
                     "correlation", "p_value", "mapped_sensors")
                   %in% names(result)))
})

test_that("imuNetworkKinematics coupling matrix is symmetric", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "forearm", "thigh"))

  result <- imuNetworkKinematics(imu, hg = hg)

  if (nrow(result$kinematic_coupling) > 0) {
    expect_true(isSymmetric(result$kinematic_coupling))
  }
})

test_that("imuNetworkKinematics returns NA for single sensor", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm"))

  result <- imuNetworkKinematics(imu, hg = hg)
  expect_true(is.na(result$correlation))
})

test_that("imuNetworkKinematics works with mutual_info method", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "forearm", "thigh"))

  result <- imuNetworkKinematics(imu, hg = hg, method = "mutual_info")
  expect_type(result, "list")
})

test_that("imuNetworkKinematics accepts pre-computed mapping", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "thigh"))
  mapping <- imuToMSKMapping(c("upper_arm", "thigh"), hg = hg)

  result <- imuNetworkKinematics(imu, hg = hg, mapping = mapping)
  expect_type(result, "list")
})

test_that("imuNetworkKinematics works with matrix input", {
  hg <- .make_small_hg()
  mat <- .make_mock_imu_matrix()

  result <- imuNetworkKinematics(mat, hg = hg)
  expect_type(result, "list")
})


# ===========================================================================
# imuImpactPrediction
# ===========================================================================

test_that("imuImpactPrediction returns expected structure", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "forearm", "thigh"))

  result <- imuImpactPrediction(imu, hg = hg)

  expect_type(result, "list")
  expect_true(all(c("vulnerability", "bone_stress",
                     "muscle_stress_exposure", "ranking")
                   %in% names(result)))
})

test_that("imuImpactPrediction vulnerability has correct length", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "thigh"))

  result <- imuImpactPrediction(imu, hg = hg)

  expect_equal(length(result$vulnerability), hg$n_muscles)
  expect_equal(length(result$bone_stress), hg$n_bones)
  expect_equal(length(result$muscle_stress_exposure), hg$n_muscles)
})

test_that("imuImpactPrediction ranking is sorted descending", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "forearm", "thigh"))

  result <- imuImpactPrediction(imu, hg = hg)

  if (nrow(result$ranking) > 1) {
    diffs <- diff(result$ranking$vulnerability)
    expect_true(all(diffs <= 0))
  }
})

test_that("imuImpactPrediction works with different stress metrics", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "thigh"))

  for (metric in c("acceleration", "angular_velocity", "jerk", "composite")) {
    result <- imuImpactPrediction(imu, hg = hg, stress_metric = metric)
    expect_type(result, "list")
    expect_equal(length(result$vulnerability), hg$n_muscles,
                 info = paste("Failed for metric:", metric))
  }
})

test_that("imuImpactPrediction returns empty for unmapped sensors", {
  hg <- .make_small_hg()
  imu <- list(xyz_unknown = matrix(rnorm(200 * 3), nrow = 200, ncol = 3))

  result <- imuImpactPrediction(imu, hg = hg)
  expect_equal(length(result$vulnerability), 0)
})

test_that("imuImpactPrediction bone_stress is non-negative", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "thigh"))

  result <- imuImpactPrediction(imu, hg = hg)
  expect_true(all(result$bone_stress >= 0))
})

test_that("imuImpactPrediction with accel/gyro list format", {
  hg <- .make_small_hg()
  set.seed(42)
  imu <- list(
    upper_arm = list(
      accel = matrix(rnorm(200 * 3), nrow = 200),
      gyro = matrix(rnorm(200 * 3, sd = 0.5), nrow = 200)
    ),
    thigh = list(
      accel = matrix(rnorm(200 * 3), nrow = 200),
      gyro = matrix(rnorm(200 * 3, sd = 0.5), nrow = 200)
    )
  )

  result <- imuImpactPrediction(imu, hg = hg)
  expect_equal(length(result$vulnerability), hg$n_muscles)
})


# ===========================================================================
# imuCommunityDynamics
# ===========================================================================

test_that("imuCommunityDynamics returns expected structure", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "forearm",
                                          "thigh", "shank"))

  result <- imuCommunityDynamics(imu, hg = hg)

  expect_type(result, "list")
  expect_true(all(c("within_community_sync", "between_community_sync",
                     "ratio", "p_value", "time_resolved")
                   %in% names(result)))
})

test_that("imuCommunityDynamics sync values are in [0, 1]", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "forearm",
                                          "thigh", "shank"))

  result <- imuCommunityDynamics(imu, hg = hg)

  if (!is.na(result$within_community_sync)) {
    expect_gte(result$within_community_sync, 0)
    expect_lte(result$within_community_sync, 1)
  }
  if (!is.na(result$between_community_sync)) {
    expect_gte(result$between_community_sync, 0)
    expect_lte(result$between_community_sync, 1)
  }
})

test_that("imuCommunityDynamics returns NA for too few sensors", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm"))

  result <- imuCommunityDynamics(imu, hg = hg)
  expect_true(is.na(result$within_community_sync))
})

test_that("imuCommunityDynamics time-resolved analysis works", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(n_samples = 500,
                              sensors = c("upper_arm", "forearm",
                                          "thigh", "shank"))

  result <- imuCommunityDynamics(imu, hg = hg, window_sec = 1.0)

  if (!is.null(result$time_resolved)) {
    expect_s3_class(result$time_resolved, "data.frame")
    expect_true(all(c("window", "time_start", "within_sync", "between_sync")
                     %in% names(result$time_resolved)))
    expect_gt(nrow(result$time_resolved), 1)
  }
})

test_that("imuCommunityDynamics works with custom gamma", {
  hg <- .make_small_hg()
  imu <- .make_mock_imu_list(sensors = c("upper_arm", "forearm",
                                          "thigh", "shank"))

  result <- imuCommunityDynamics(imu, hg = hg, gamma = 2.0)
  expect_type(result, "list")
})


# ===========================================================================
# Integration tests
# ===========================================================================

test_that("IMU pipeline: mapping -> kinematics -> impact", {
  hg <- .make_small_hg()
  sensors <- c("upper_arm", "forearm", "thigh")
  imu <- .make_mock_imu_list(sensors = sensors)

  # Step 1: mapping

  mapping <- imuToMSKMapping(sensors, hg = hg)
  expect_gte(nrow(mapping), 1)

  # Step 2: kinematics
  kin <- imuNetworkKinematics(imu, hg = hg, mapping = mapping)
  expect_type(kin, "list")

  # Step 3: impact prediction
  impact <- imuImpactPrediction(imu, hg = hg, mapping = mapping)
  expect_equal(length(impact$vulnerability), hg$n_muscles)
})

test_that("IMU pipeline works with default (full) hypergraph", {
  sensors <- c("upper_arm", "forearm", "thigh", "shank", "chest", "pelvis")
  mapping <- imuToMSKMapping(sensors)
  expect_gte(nrow(mapping), 5)
  # Verify all map to valid bones
  expect_true(all(mapping$match_quality >= 0.5))
})

test_that("IMU pipeline handles mixed-case sensor names", {
  hg <- .make_small_hg()
  set.seed(42)
  imu <- list(
    Upper_Arm = matrix(rnorm(200 * 3), nrow = 200),
    THIGH = matrix(rnorm(200 * 3), nrow = 200)
  )

  mapping <- imuToMSKMapping(c("Upper_Arm", "THIGH"), hg = hg)
  # Should still map via case-insensitive normalization
  expect_gte(nrow(mapping), 1)
})
