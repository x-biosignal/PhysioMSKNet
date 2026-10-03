library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-community.R -- Tests for community detection functions
# ===========================================================================

test_that("mskCommunityDetect returns expected structure", {
  hg <- MSKHypergraph()
  result <- mskCommunityDetect(hg, gamma = 4.3, type = "muscle")

  expect_type(result, "list")

  # Check all expected components
  expect_true("membership" %in% names(result))
  expect_true("n_communities" %in% names(result))
  expect_true("modularity" %in% names(result))
  expect_true("gamma" %in% names(result))
  expect_true("sizes" %in% names(result))
  expect_true("type" %in% names(result))

  expect_equal(result$gamma, 4.3)
  expect_equal(result$type, "muscle")

  # n_communities should be a positive integer
  expect_true(result$n_communities > 0)
  expect_equal(result$n_communities, length(unique(result$membership)))
})

test_that("mskCommunityDetect membership has length 270 for muscle graph", {
  hg <- MSKHypergraph()
  result <- mskCommunityDetect(hg, type = "muscle")

  expect_length(result$membership, 270)
  expect_false(is.null(names(result$membership)))
  expect_equal(names(result$membership), hg$muscle_names)

  # All memberships should be positive integers
  expect_true(all(result$membership > 0))
  expect_true(all(result$membership == as.integer(result$membership)))
})

test_that("mskCommunityDetect works for bone graph", {
  hg <- MSKHypergraph()
  result <- mskCommunityDetect(hg, type = "bone")

  expect_length(result$membership, 173)
  expect_equal(result$type, "bone")
  expect_true(result$n_communities > 0)
})

test_that("Modularity is a scalar", {
  hg <- MSKHypergraph()
  result <- mskCommunityDetect(hg, type = "muscle")

  expect_type(result$modularity, "double")
  expect_length(result$modularity, 1)
  expect_true(is.finite(result$modularity))
})

test_that("mskModularity returns numeric value", {
  hg <- MSKHypergraph()
  A <- as.matrix(projectMuscleGraph(hg))

  # Create a simple partition: all in one community
  membership_one <- rep(1L, 270)
  Q_one <- mskModularity(A, membership_one, gamma = 1.0)

  expect_type(Q_one, "double")
  expect_length(Q_one, 1)
  expect_true(is.finite(Q_one))
})

test_that("mskModularity gives 0 for single community", {
  # For a single community with gamma=1, Q should be 0
  A_small <- matrix(c(0, 1, 1,
                       1, 0, 1,
                       1, 1, 0), nrow = 3)
  membership_all <- c(1L, 1L, 1L)
  Q <- mskModularity(A_small, membership_all, gamma = 1.0)

  # Single community modularity should be near 0
  expect_equal(Q, 0, tolerance = 0.01)
})

test_that("mskZRand returns numeric z-score", {
  # Two random partitions
  set.seed(42)
  p1 <- sample(1:5, 100, replace = TRUE)
  p2 <- sample(1:5, 100, replace = TRUE)

  z <- mskZRand(p1, p2)

  expect_type(z, "double")
  expect_length(z, 1)
  expect_true(is.finite(z))
})

test_that("Identical partitions have high z-Rand", {
  p1 <- rep(1:10, each = 10)
  p2 <- p1  # identical

  z <- mskZRand(p1, p2)

  # Identical partitions should have a very high z-score
  expect_gt(z, 1.96,
            label = "Identical partitions should have z-Rand > 1.96")
})

test_that("mskZRand rejects inputs of different lengths", {
  expect_error(mskZRand(1:10, 1:5))
})

test_that("Community sizes table sums to total number of nodes", {
  hg <- MSKHypergraph()
  result <- mskCommunityDetect(hg, type = "muscle")

  total <- sum(result$sizes)
  expect_equal(total, 270)
})

test_that("mskCommunityDetect with small custom hypergraph", {
  C_small <- matrix(0, nrow = 6, ncol = 6)
  # Two groups that share no bones
  C_small[1:3, 1:3] <- matrix(c(1, 1, 0,
                                  0, 1, 1,
                                  1, 0, 1), nrow = 3)
  C_small[4:6, 4:6] <- matrix(c(1, 1, 0,
                                  0, 1, 1,
                                  1, 0, 1), nrow = 3)
  rownames(C_small) <- paste0("bone_", 1:6)
  colnames(C_small) <- paste0("muscle_", 1:6)

  hg_small <- MSKHypergraph(C_small)
  result <- mskCommunityDetect(hg_small, gamma = 1.0, type = "muscle")

  expect_type(result, "list")
  expect_length(result$membership, 6)
  # Should detect at least 2 communities for this disconnected graph
  expect_gte(result$n_communities, 2)
})
