library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-mocap.R -- Tests for MoCap bridge functions
# ===========================================================================

# ---- Helper ----

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

.make_mock_mocap <- function(n_frames = 200) {
  set.seed(42)
  mat <- matrix(rnorm(n_frames * 4), nrow = n_frames, ncol = 4)
  # Add some correlated movement
  mat[, 2] <- mat[, 1] * 0.8 + rnorm(n_frames, sd = 0.3)
  colnames(mat) <- c("upper_arm", "forearm", "thigh", "shank")
  attr(mat, "sr") <- 100
  mat
}


# ---- .mocapBoneLookup ----

test_that(".mocapBoneLookup returns valid table", {
  lookup <- PhysioMSKNet:::.mocapBoneLookup()
  expect_s3_class(lookup, "data.frame")
  expect_true(all(c("mocap_name", "bone_name") %in% names(lookup)))
  expect_gt(nrow(lookup), 20)
})


# ---- mocapToMSKMapping ----

test_that("mocapToMSKMapping maps via curated lookup", {
  mapping <- mocapToMSKMapping(c("upper_arm", "thigh", "sternum"))

  expect_s3_class(mapping, "data.frame")
  expect_gte(nrow(mapping), 3)
  expect_true(all(c("segment_name", "bone_idx", "bone_name",
                     "match_quality", "match_method") %in% names(mapping)))
})

test_that("mocapToMSKMapping upper_arm maps to Humerus", {
  mapping <- mocapToMSKMapping("upper_arm")

  expect_equal(mapping$bone_name[1], "Humerus")
  expect_equal(mapping$match_method[1], "lookup")
})

test_that("mocapToMSKMapping returns empty for unknown segments", {
  mapping <- mocapToMSKMapping(c("xyz_unknown", "abc_invalid"),
                                method = "exact")
  expect_equal(nrow(mapping), 0)
})

test_that("mocapToMSKMapping works with small hg", {
  hg <- .make_small_hg()
  mapping <- mocapToMSKMapping(c("upper_arm", "forearm"), hg = hg)

  expect_gte(nrow(mapping), 1)
})


# ---- mocapNetworkKinematics ----

test_that("mocapNetworkKinematics returns expected structure", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapNetworkKinematics(mocap, hg = hg)

  expect_type(result, "list")
  expect_true(all(c("kinematic_coupling", "structural_matrix",
                     "correlation", "p_value") %in% names(result)))
})

test_that("mocapNetworkKinematics coupling matrix is symmetric", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapNetworkKinematics(mocap, hg = hg)

  if (nrow(result$kinematic_coupling) > 0) {
    expect_true(isSymmetric(result$kinematic_coupling, tol = 1e-10))
  }
})

test_that("mocapNetworkKinematics correlation is numeric", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapNetworkKinematics(mocap, hg = hg)

  expect_true(is.numeric(result$correlation))
})

test_that("mocapNetworkKinematics mutual_info method works", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapNetworkKinematics(mocap, hg = hg, method = "mutual_info")

  expect_type(result, "list")
  expect_true(is.numeric(result$correlation))
})


# ---- mocapImpactPrediction ----

test_that("mocapImpactPrediction returns vulnerability ranking", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapImpactPrediction(mocap, hg = hg, use_proxy = TRUE)

  expect_type(result, "list")
  expect_true(all(c("vulnerability", "bone_stress", "muscle_stress_exposure",
                     "ranking") %in% names(result)))
  expect_s3_class(result$ranking, "data.frame")
})

test_that("mocapImpactPrediction bone_stress is positive", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapImpactPrediction(mocap, hg = hg,
                                   stress_metric = "acceleration")

  expect_true(all(result$bone_stress >= 0))
})

test_that("mocapImpactPrediction works with jerk metric", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapImpactPrediction(mocap, hg = hg, stress_metric = "jerk")

  expect_true(all(result$bone_stress >= 0))
})

test_that("mocapImpactPrediction works with range metric", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapImpactPrediction(mocap, hg = hg, stress_metric = "range")

  expect_true(all(result$bone_stress >= 0))
})

test_that("mocapImpactPrediction ranking is sorted by vulnerability", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapImpactPrediction(mocap, hg = hg)

  if (nrow(result$ranking) > 1) {
    vuln <- result$ranking$vulnerability
    expect_true(all(diff(vuln) <= 0))  # descending
  }
})


# ---- mocapCommunityDynamics ----

test_that("mocapCommunityDynamics returns synchrony metrics", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapCommunityDynamics(mocap, hg = hg, gamma = 1.0)

  expect_type(result, "list")
  expect_true(all(c("within_community_sync", "between_community_sync",
                     "ratio", "p_value") %in% names(result)))
})

test_that("mocapCommunityDynamics time_resolved is NULL by default", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap()
  result <- mocapCommunityDynamics(mocap, hg = hg, gamma = 1.0)

  expect_null(result$time_resolved)
})

test_that("mocapCommunityDynamics time_resolved works with window_sec", {
  hg <- .make_small_hg()
  mocap <- .make_mock_mocap(n_frames = 500)
  result <- mocapCommunityDynamics(mocap, hg = hg, gamma = 1.0,
                                    window_sec = 1.0)

  if (!is.null(result$time_resolved)) {
    expect_s3_class(result$time_resolved, "data.frame")
    expect_true("window" %in% names(result$time_resolved))
  }
})

test_that("mocapCommunityDynamics handles too few segments", {
  hg <- .make_small_hg()
  mat <- matrix(rnorm(200), 100, 2)
  colnames(mat) <- c("upper_arm", "xyz_invalid")
  attr(mat, "sr") <- 100

  result <- mocapCommunityDynamics(mat, hg = hg, gamma = 1.0)
  expect_true(is.na(result$within_community_sync))
})
