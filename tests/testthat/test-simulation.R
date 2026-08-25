library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-simulation.R -- Tests for simulation and perturbation analysis
# ===========================================================================

test_that("mskSimulate creates MSKSimulation object", {
  hg <- MSKHypergraph()
  sim <- mskSimulate(hg)

  expect_s3_class(sim, "MSKSimulation")
  expect_type(sim, "list")

  # Check structure
  expect_true("hg" %in% names(sim))
  expect_true("spring_constants" %in% names(sim))
  expect_true("params" %in% names(sim))

  expect_s3_class(sim$hg, "MSKHypergraph")
  expect_length(sim$spring_constants, 270)

  # Check params
  expect_equal(sim$params$dt, 0.01)
  expect_equal(sim$params$n_steps, 500L)
  expect_equal(sim$params$beta, 1.0)
  expect_equal(sim$params$perturbation_magnitude, 1.0)
})

test_that("mskSimulate with NULL creates default hypergraph", {
  sim <- mskSimulate()
  expect_s3_class(sim, "MSKSimulation")
  expect_equal(sim$hg$n_bones, 173)
  expect_equal(sim$hg$n_muscles, 270)
})

test_that("mskSimulate accepts custom parameters", {
  hg <- MSKHypergraph()
  sim <- mskSimulate(hg, dt = 0.005, n_steps = 100L, beta = 2.0,
                      perturbation_magnitude = 0.5)

  expect_equal(sim$params$dt, 0.005)
  expect_equal(sim$params$n_steps, 100L)
  expect_equal(sim$params$beta, 2.0)
  expect_equal(sim$params$perturbation_magnitude, 0.5)
})

test_that("Spring constants follow k = 1/(deg-1) for deg > 1", {
  hg <- MSKHypergraph()
  sim <- mskSimulate(hg)

  deg <- hyperedgeDegree(hg)
  k <- sim$spring_constants

  expect_length(k, 270)
  expect_false(is.null(names(k)))

  # For muscles with degree > 1: k = 1/(deg - 1)
  high_deg_idx <- which(deg > 1)
  expect_true(length(high_deg_idx) > 0)

  expected_k <- 1.0 / (deg[high_deg_idx] - 1)
  expect_equal(k[high_deg_idx], expected_k, tolerance = 1e-10)

  # For muscles with degree 1: k = 1.0
  low_deg_idx <- which(deg == 1)
  if (length(low_deg_idx) > 0) {
    expect_true(all(k[low_deg_idx] == 1.0))
  }

  # All spring constants should be positive
  expect_true(all(k > 0))
})

test_that("mskImpactScore returns positive scalar", {
  # Use a small subset for speed
  C_small <- matrix(c(1, 0, 1, 0,
                       0, 1, 1, 0,
                       1, 1, 0, 1,
                       0, 0, 1, 1), nrow = 4, ncol = 4)
  rownames(C_small) <- paste0("bone_", 1:4)
  colnames(C_small) <- paste0("muscle_", 1:4)
  hg_small <- MSKHypergraph(C_small)
  sim_small <- mskSimulate(hg_small, n_steps = 100L)

  score <- mskImpactScore(sim_small, 1)

  expect_type(score, "double")
  expect_length(score, 1)
  expect_gt(score, 0)
})

test_that("mskImpactScore works for different muscles", {
  # Use asymmetric matrix with different degrees
  C_small <- matrix(c(1, 0, 0, 0,
                       1, 1, 0, 0,
                       1, 1, 1, 1), nrow = 4, ncol = 3)
  rownames(C_small) <- paste0("bone_", 1:4)
  colnames(C_small) <- paste0("muscle_", 1:3)
  hg_small <- MSKHypergraph(C_small)
  sim_small <- mskSimulate(hg_small, n_steps = 50L)

  scores <- numeric(3)
  for (i in 1:3) {
    scores[i] <- mskImpactScore(sim_small, i)
    expect_gt(scores[i], 0, label = paste("Impact score for muscle", i))
  }

  # Muscles with different degrees should have different impact scores
  expect_false(all(scores == scores[1]))
})

test_that("mskImpactScore rejects invalid muscle index", {
  C_small <- matrix(c(1, 0, 0, 1, 1, 0), nrow = 2, ncol = 3)
  rownames(C_small) <- paste0("bone_", 1:2)
  colnames(C_small) <- paste0("muscle_", 1:3)
  hg_small <- MSKHypergraph(C_small)
  sim_small <- mskSimulate(hg_small, n_steps = 10L)

  expect_error(mskImpactScore(sim_small, 0))
  expect_error(mskImpactScore(sim_small, 4))
})

test_that("Impact scores correlate with muscle degree (r > 0)", {
  # Use a small hypergraph with varying degrees
  C_small <- matrix(0, nrow = 6, ncol = 5)
  rownames(C_small) <- paste0("bone_", 1:6)
  colnames(C_small) <- paste0("muscle_", 1:5)

  # Muscle 1: connects 2 bones (low degree)
  C_small[1:2, 1] <- 1
  # Muscle 2: connects 2 bones
  C_small[3:4, 2] <- 1
  # Muscle 3: connects 3 bones
  C_small[1:3, 3] <- 1
  # Muscle 4: connects 4 bones
  C_small[1:4, 4] <- 1
  # Muscle 5: connects 5 bones (high degree)
  C_small[1:5, 5] <- 1

  hg_small <- MSKHypergraph(C_small)
  sim_small <- mskSimulate(hg_small, n_steps = 100L)

  scores <- numeric(5)
  for (i in 1:5) {
    scores[i] <- mskImpactScore(sim_small, i)
  }
  deg <- hyperedgeDegree(hg_small)

  # Impact should generally increase with degree
  r <- cor(deg, scores)
  expect_gt(r, 0, label = "Correlation between degree and impact score")
})

test_that("Small simulation (subset) runs without error", {
  C_sub <- matrix(c(1, 0, 1,
                     0, 1, 1,
                     1, 1, 0,
                     1, 0, 0), nrow = 4, ncol = 3)
  rownames(C_sub) <- paste0("bone_", 1:4)
  colnames(C_sub) <- paste0("muscle_", 1:3)
  hg_sub <- MSKHypergraph(C_sub)
  sim_sub <- mskSimulate(hg_sub, dt = 0.01, n_steps = 50L, beta = 1.0)

  expect_s3_class(sim_sub, "MSKSimulation")

  # Run all impact scores
  scores <- numeric(3)
  for (i in 1:3) {
    scores[i] <- mskImpactScore(sim_sub, i)
  }
  expect_true(all(scores > 0))
  expect_true(all(is.finite(scores)))
})

test_that("print.MSKSimulation produces output", {
  sim <- mskSimulate()
  expect_output(print(sim), "MSKSimulation")
  expect_output(print(sim), "Bones")
  expect_output(print(sim), "Muscles")
})

test_that("mskImpactDeviation works with regression fallback", {
  C_small <- matrix(0, nrow = 5, ncol = 6)
  rownames(C_small) <- paste0("bone_", 1:5)
  colnames(C_small) <- paste0("muscle_", 1:6)
  C_small[1:2, 1] <- 1
  C_small[1:2, 2] <- 1
  C_small[1:3, 3] <- 1
  C_small[1:3, 4] <- 1
  C_small[1:4, 5] <- 1
  C_small[1:4, 6] <- 1

  hg_small <- MSKHypergraph(C_small)
  sim_small <- mskSimulate(hg_small, n_steps = 50L)

  scores <- numeric(6)
  for (i in 1:6) scores[i] <- mskImpactScore(sim_small, i)
  names(scores) <- colnames(C_small)

  dev <- mskImpactDeviation(scores, hg_small)
  expect_length(dev, 6)
  expect_true(all(is.finite(dev)))
})
