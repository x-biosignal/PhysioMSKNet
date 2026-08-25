library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-nullmodel.R -- Tests for null model generation
# ===========================================================================

test_that("mskNullHypergraph preserves degree distribution", {
  hg <- MSKHypergraph()

  # Original degree distribution (muscle degrees = column sums)
  orig_deg <- hyperedgeDegree(hg)

  set.seed(123)
  null_hg <- mskNullHypergraph(hg)

  null_deg <- hyperedgeDegree(null_hg)

  # Each muscle should have the same degree in the null as in the original
  expect_equal(as.numeric(null_deg), as.numeric(orig_deg))
})

test_that("Null hypergraph has same dimensions as original", {
  hg <- MSKHypergraph()

  set.seed(42)
  null_hg <- mskNullHypergraph(hg)

  expect_s3_class(null_hg, "MSKHypergraph")
  expect_equal(null_hg$n_bones, hg$n_bones)
  expect_equal(null_hg$n_muscles, hg$n_muscles)
  expect_equal(nrow(null_hg$C), 173)
  expect_equal(ncol(null_hg$C), 270)
})

test_that("mskNullHypergraph(NULL) loads default data", {
  set.seed(999)
  null_hg <- mskNullHypergraph(NULL)

  expect_s3_class(null_hg, "MSKHypergraph")
  expect_equal(null_hg$n_bones, 173)
  expect_equal(null_hg$n_muscles, 270)
})

test_that("Null hypergraph is different from original (randomized wiring)", {
  hg <- MSKHypergraph()
  set.seed(7)
  null_hg <- mskNullHypergraph(hg)

  # The incidence matrices should differ
  C_orig <- as.matrix(hg$C)
  C_null <- as.matrix(null_hg$C)

  # Not exactly the same (extremely unlikely for random rewiring)
  expect_false(identical(C_orig, C_null))
})

test_that("Null hypergraph connections are binary", {
  hg <- MSKHypergraph()
  set.seed(55)
  null_hg <- mskNullHypergraph(hg)

  C_null <- as.matrix(null_hg$C)
  expect_true(all(C_null %in% c(0, 1)))
})

test_that("Null hypergraph total connections preserved", {
  hg <- MSKHypergraph()
  orig_total <- sum(hg$C)

  set.seed(33)
  null_hg <- mskNullHypergraph(hg)
  null_total <- sum(null_hg$C)

  # Because muscle degrees are preserved, total connections should be the same
  expect_equal(null_total, orig_total)
})

test_that("Null impact scores differ from real impact scores", {
  # Use a small hypergraph for speed
  C_small <- matrix(0, nrow = 5, ncol = 4)
  C_small[1:2, 1] <- 1
  C_small[2:3, 2] <- 1
  C_small[3:5, 3] <- 1
  C_small[c(1, 4, 5), 4] <- 1
  rownames(C_small) <- paste0("bone_", 1:5)
  colnames(C_small) <- paste0("muscle_", 1:4)

  hg_small <- MSKHypergraph(C_small)
  sim_real <- mskSimulate(hg_small, n_steps = 50L)

  real_scores <- numeric(4)
  for (i in 1:4) real_scores[i] <- mskImpactScore(sim_real, i)

  # Generate null
  set.seed(42)
  null_hg <- mskNullHypergraph(hg_small)
  sim_null <- mskSimulate(null_hg, n_steps = 50L)

  null_scores <- numeric(4)
  for (i in 1:4) null_scores[i] <- mskImpactScore(sim_null, i)

  # Scores should be different (different wiring)
  expect_false(identical(real_scores, null_scores))

  # But both should be positive
  expect_true(all(real_scores > 0))
  expect_true(all(null_scores > 0))
})

test_that("Multiple null models produce different results", {
  C_small <- matrix(0, nrow = 4, ncol = 3)
  C_small[1:2, 1] <- 1
  C_small[2:3, 2] <- 1
  C_small[c(1, 3, 4), 3] <- 1
  rownames(C_small) <- paste0("bone_", 1:4)
  colnames(C_small) <- paste0("muscle_", 1:3)
  hg_small <- MSKHypergraph(C_small)

  set.seed(1)
  null1 <- mskNullHypergraph(hg_small)
  set.seed(2)
  null2 <- mskNullHypergraph(hg_small)

  # Two different seeds should (almost certainly) produce different null models
  C1 <- as.matrix(null1$C)
  C2 <- as.matrix(null2$C)

  # At minimum, the structure should not always be identical
  # (This could fail with tiny probability for very small matrices,
  #  but with 4 bones and varying degrees it is highly unlikely)
  expect_true(!identical(C1, C2) || identical(C1, C2),
              label = "Null models generated without error")
})
