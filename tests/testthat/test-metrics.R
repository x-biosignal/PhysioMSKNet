library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-metrics.R -- Tests for network metric computations
# ===========================================================================

test_that("mskNetworkMetrics for bone graph: 173 nodes, density ~0.093", {
  hg <- MSKHypergraph()
  metrics <- mskNetworkMetrics(hg, "bone")

  expect_type(metrics, "list")
  expect_equal(metrics$n_nodes, 173)

  # Density should be approximately 0.093
  expect_equal(metrics$density, 0.093, tolerance = 0.02)

  # Check all expected components are present
  expect_true("degree" %in% names(metrics))
  expect_true("strength" %in% names(metrics))
  expect_true("clustering_coef" %in% names(metrics))
  expect_true("density" %in% names(metrics))
  expect_true("n_edges" %in% names(metrics))

  # Degree should have correct length
  expect_length(metrics$degree, 173)

  # All degrees should be non-negative
  expect_true(all(metrics$degree >= 0))
})

test_that("mskNetworkMetrics for muscle graph: 270 nodes, density ~0.074", {
  hg <- MSKHypergraph()
  metrics <- mskNetworkMetrics(hg, "muscle")

  expect_type(metrics, "list")
  expect_equal(metrics$n_nodes, 270)

  # Density should be approximately 0.074
  expect_equal(metrics$density, 0.074, tolerance = 0.02)

  expect_length(metrics$degree, 270)
  expect_true(all(metrics$degree >= 0))
})

test_that("Clustering coefficients are in [0, 1]", {
  hg <- MSKHypergraph()

  metrics_bone <- mskNetworkMetrics(hg, "bone")
  expect_true(all(metrics_bone$clustering_coef >= 0))
  expect_true(all(metrics_bone$clustering_coef <= 1))

  metrics_muscle <- mskNetworkMetrics(hg, "muscle")
  expect_true(all(metrics_muscle$clustering_coef >= 0))
  expect_true(all(metrics_muscle$clustering_coef <= 1))
})

test_that("mskBetweenness returns named vector of correct length for bone graph", {
  hg <- MSKHypergraph()
  bc <- mskBetweenness(hg, "bone")

  expect_type(bc, "double")
  expect_length(bc, 173)
  expect_false(is.null(names(bc)))

  # All betweenness values should be non-negative
  expect_true(all(bc >= 0))
})

test_that("mskBetweenness returns named vector of correct length for muscle graph", {
  hg <- MSKHypergraph()
  bc <- mskBetweenness(hg, "muscle")

  expect_type(bc, "double")
  expect_length(bc, 270)
  expect_false(is.null(names(bc)))
  expect_true(all(bc >= 0))
})

test_that("mskCloseness returns named vector of correct length", {
  hg <- MSKHypergraph()

  cl_bone <- mskCloseness(hg, "bone")
  expect_type(cl_bone, "double")
  expect_length(cl_bone, 173)
  expect_false(is.null(names(cl_bone)))
  expect_true(all(cl_bone >= 0))

  cl_muscle <- mskCloseness(hg, "muscle")
  expect_type(cl_muscle, "double")
  expect_length(cl_muscle, 270)
  expect_false(is.null(names(cl_muscle)))
  expect_true(all(cl_muscle >= 0))
})

test_that("mskShortestPaths returns symmetric matrix with 0 diagonal for bone graph", {
  hg <- MSKHypergraph()
  D <- mskShortestPaths(hg, "bone")

  expect_true(is.matrix(D))
  expect_equal(nrow(D), 173)
  expect_equal(ncol(D), 173)

  # Symmetric
  expect_equal(D, t(D))

  # Zero diagonal
  expect_true(all(diag(D) == 0))

  # All off-diagonal should be positive (assuming connected graph)
  # or Inf for disconnected components
  off_diag <- D[row(D) != col(D)]
  expect_true(all(off_diag > 0))

  # Row and column names should be present
  expect_false(is.null(rownames(D)))
  expect_false(is.null(colnames(D)))
})

test_that("mskShortestPaths returns symmetric matrix with 0 diagonal for muscle graph", {
  hg <- MSKHypergraph()
  D <- mskShortestPaths(hg, "muscle")

  expect_true(is.matrix(D))
  expect_equal(nrow(D), 270)
  expect_equal(ncol(D), 270)

  # Symmetric
  expect_equal(D, t(D))

  # Zero diagonal
  expect_true(all(diag(D) == 0))
})

test_that("mskNetworkMetrics works with small custom hypergraph", {
  # Create a small hypergraph for a quick sanity check
  C_small <- matrix(c(1, 0, 1,
                       0, 1, 1,
                       1, 1, 0), nrow = 3, ncol = 3)
  rownames(C_small) <- paste0("bone_", 1:3)
  colnames(C_small) <- paste0("muscle_", 1:3)
  hg <- MSKHypergraph(C_small)

  metrics <- mskNetworkMetrics(hg, "bone")
  expect_equal(metrics$n_nodes, 3)
  expect_length(metrics$degree, 3)
})
