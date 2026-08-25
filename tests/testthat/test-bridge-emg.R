library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-emg.R -- Tests for EMG bridge functions
# ===========================================================================

# ---- Helper: small hypergraph and mock signal ----

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

.make_mock_signal <- function(n_time = 500, sr = 1000) {
  set.seed(42)
  mat <- matrix(rnorm(n_time * 4), nrow = n_time, ncol = 4)
  colnames(mat) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Quadriceps")
  attr(mat, "sr") <- sr
  mat
}


# ---- .mantelTest ----

test_that(".mantelTest returns expected structure", {
  set.seed(1)
  m1 <- matrix(runif(16), 4, 4); m1 <- m1 + t(m1); diag(m1) <- 0
  m2 <- matrix(runif(16), 4, 4); m2 <- m2 + t(m2); diag(m2) <- 0

  result <- PhysioMSKNet:::.mantelTest(m1, m2, n_perm = 99)

  expect_type(result, "list")
  expect_true(all(c("correlation", "p_value", "n_perm") %in% names(result)))
  expect_true(is.numeric(result$correlation))
  expect_true(result$p_value >= 0 && result$p_value <= 1)
})

test_that(".mantelTest detects identical matrices", {
  m <- matrix(c(0, 1, 2, 1, 0, 3, 2, 3, 0), 3, 3)
  result <- PhysioMSKNet:::.mantelTest(m, m, n_perm = 199)
  expect_equal(result$correlation, 1.0)
})

test_that(".mantelTest handles small matrices", {
  m1 <- matrix(c(0, 1, 1, 0), 2, 2)
  m2 <- matrix(c(0, 2, 2, 0), 2, 2)
  result <- PhysioMSKNet:::.mantelTest(m1, m2, n_perm = 99)
  # Only 1 value in upper triangle, should return NA
  expect_true(is.na(result$correlation))
})


# ---- .minimalCoherence ----

test_that(".minimalCoherence returns square matrix", {
  set.seed(42)
  mat <- matrix(rnorm(500 * 3), 500, 3)
  colnames(mat) <- paste0("ch", 1:3)
  coh <- PhysioMSKNet:::.minimalCoherence(mat, sr = 1000, freq_band = c(20, 50))

  expect_equal(nrow(coh), 3)
  expect_equal(ncol(coh), 3)
  expect_true(all(coh >= 0))
  expect_true(all(coh <= 1 + 1e-10))  # Allow small floating point error
  expect_equal(unname(diag(coh)), rep(1, 3))
})


# ---- emgToMSKMapping ----

test_that("emgToMSKMapping exact match works", {
  hg <- .make_small_hg()
  mapping <- emgToMSKMapping(c("Biceps Brachii", "Deltoid"), hg = hg,
                              method = "exact")

  expect_s3_class(mapping, "data.frame")
  expect_equal(nrow(mapping), 2)
  expect_true("channel_idx" %in% names(mapping))
  expect_true("muscle_idx" %in% names(mapping))
  expect_equal(mapping$match_quality, c(1.0, 1.0))
})

test_that("emgToMSKMapping fuzzy match works", {
  hg <- .make_small_hg()
  # Slightly altered names
  mapping <- emgToMSKMapping(c("biceps brachii", "R_Deltoid"),
                              hg = hg, method = "fuzzy")

  expect_s3_class(mapping, "data.frame")
  expect_gte(nrow(mapping), 1)
})

test_that("emgToMSKMapping returns empty for no matches", {
  hg <- .make_small_hg()
  mapping <- emgToMSKMapping(c("XYZ", "ABC"), hg = hg, method = "exact")

  expect_s3_class(mapping, "data.frame")
  expect_equal(nrow(mapping), 0)
})

test_that("emgToMSKMapping strips EMG suffix", {
  hg <- .make_small_hg()
  mapping <- emgToMSKMapping("Deltoid_EMG", hg = hg, method = "fuzzy")

  expect_gte(nrow(mapping), 1)
  expect_equal(mapping$muscle_name[1], "Deltoid")
})


# ---- emgStructuralCoherence ----

test_that("emgStructuralCoherence returns expected structure", {
  hg <- .make_small_hg()
  signal <- .make_mock_signal()
  result <- emgStructuralCoherence(signal, hg = hg, freq_band = c(20, 50))

  expect_type(result, "list")
  expect_true(all(c("coherence_matrix", "structural_matrix", "correlation",
                     "p_value", "mapped_muscles") %in% names(result)))
})

test_that("emgStructuralCoherence coherence matrix is symmetric", {
  hg <- .make_small_hg()
  signal <- .make_mock_signal()
  result <- emgStructuralCoherence(signal, hg = hg)

  if (nrow(result$coherence_matrix) > 0) {
    expect_true(isSymmetric(result$coherence_matrix, tol = 1e-10))
  }
})

test_that("emgStructuralCoherence returns empty for no matches", {
  hg <- .make_small_hg()
  mat <- matrix(rnorm(100), 50, 2)
  colnames(mat) <- c("XYZ", "ABC")
  attr(mat, "sr") <- 1000

  result <- emgStructuralCoherence(mat, hg = hg)
  expect_true(is.na(result$correlation))
})


# ---- emgCommunityCompare ----

test_that("emgCommunityCompare returns z_rand value", {
  hg <- .make_small_hg()
  signal <- .make_mock_signal()
  result <- emgCommunityCompare(signal, hg = hg, gamma = 1.0)

  expect_type(result, "list")
  expect_true("z_rand" %in% names(result))
  expect_true(is.numeric(result$z_rand))
  expect_true("emg_communities" %in% names(result))
  expect_true("msk_communities" %in% names(result))
})

test_that("emgCommunityCompare errors with too few channels", {
  hg <- .make_small_hg()
  mat <- matrix(rnorm(500 * 2), 500, 2)
  colnames(mat) <- c("Biceps Brachii", "Deltoid")
  attr(mat, "sr") <- 1000

  expect_error(emgCommunityCompare(mat, hg = hg), "at least 3")
})


# ---- emgMSKEnrichment ----

test_that("emgMSKEnrichment returns per-community stats", {
  hg <- .make_small_hg()
  signal <- .make_mock_signal()
  result <- emgMSKEnrichment(signal, hg = hg, gamma = 1.0)

  expect_type(result, "list")
  expect_true(all(c("per_community", "overall_test", "activation_values")
                   %in% names(result)))
  expect_s3_class(result$per_community, "data.frame")
  expect_true("mean_activation" %in% names(result$per_community))
})

test_that("emgMSKEnrichment activation values are positive", {
  hg <- .make_small_hg()
  signal <- .make_mock_signal()
  result <- emgMSKEnrichment(signal, hg = hg)

  expect_true(all(result$activation_values > 0))
})
