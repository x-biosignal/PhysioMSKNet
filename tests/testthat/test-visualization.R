library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-visualization.R -- Tests that plotting functions run without error
# ===========================================================================

test_that("plotDegreeDistribution produces output for muscle", {
  hg <- MSKHypergraph()

  expect_no_error({
    pdf(NULL)  # suppress graphical output
    on.exit(dev.off(), add = TRUE)
    plotDegreeDistribution(hg, type = "muscle", log_scale = FALSE)
  })
})

test_that("plotDegreeDistribution produces output for bone", {
  hg <- MSKHypergraph()

  expect_no_error({
    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    plotDegreeDistribution(hg, type = "bone", log_scale = TRUE)
  })
})

test_that("plotDegreeDistribution with default (NULL) hypergraph", {
  expect_no_error({
    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    plotDegreeDistribution(NULL, type = "muscle")
  })
})

test_that("plotImpactVsRecovery produces output", {
  expect_no_error({
    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    result <- plotImpactVsRecovery()
  })
})

test_that("plotImpactVsRecovery returns regression result invisibly", {
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  result <- plotImpactVsRecovery()

  expect_type(result, "list")
  expect_true("r_squared" %in% names(result))
  expect_true("coefficients" %in% names(result))
})

test_that("plotHomunculus produces output", {
  expect_no_error({
    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    result <- plotHomunculus()
  })
})

test_that("plotHomunculus returns regression result invisibly", {
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  result <- plotHomunculus()

  expect_type(result, "list")
  expect_true("r_squared" %in% names(result))
})

test_that("plotCommunityStructure with mock community result", {
  # Create a mock community detection result
  mock_community <- list(
    membership = rep(1:5, each = 54),
    n_communities = 5,
    modularity = 0.35,
    gamma = 4.3,
    sizes = table(rep(1:5, each = 54)),
    type = "muscle"
  )

  expect_no_error({
    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    plotCommunityStructure(mock_community)
  })
})

test_that("plotCommunityStructure works with real community detection", {
  skip_if_not_installed("igraph")

  hg <- MSKHypergraph()
  comm <- mskCommunityDetect(hg, gamma = 4.3, type = "muscle")

  expect_no_error({
    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    plotCommunityStructure(comm)
  })
})

test_that("plotImpactVsDegree produces output", {
  # Use a small hypergraph with precomputed scores
  C_small <- matrix(0, nrow = 5, ncol = 4)
  C_small[1:2, 1] <- 1
  C_small[2:3, 2] <- 1
  C_small[1:3, 3] <- 1
  C_small[1:4, 4] <- 1
  rownames(C_small) <- paste0("bone_", 1:5)
  colnames(C_small) <- paste0("muscle_", 1:4)
  hg_small <- MSKHypergraph(C_small)
  sim_small <- mskSimulate(hg_small, n_steps = 50L)

  scores <- numeric(4)
  for (i in 1:4) scores[i] <- mskImpactScore(sim_small, i)
  names(scores) <- colnames(C_small)

  expect_no_error({
    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    plotImpactVsDegree(scores, hg_small, show_regression = TRUE)
  })
})

test_that("plotImpactVsDegree without regression line", {
  C_small <- matrix(0, nrow = 4, ncol = 3)
  C_small[1:2, 1] <- 1
  C_small[2:3, 2] <- 1
  C_small[1:3, 3] <- 1
  rownames(C_small) <- paste0("bone_", 1:4)
  colnames(C_small) <- paste0("muscle_", 1:3)
  hg_small <- MSKHypergraph(C_small)
  sim_small <- mskSimulate(hg_small, n_steps = 30L)

  scores <- numeric(3)
  for (i in 1:3) scores[i] <- mskImpactScore(sim_small, i)
  names(scores) <- colnames(C_small)

  expect_no_error({
    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    result <- plotImpactVsDegree(scores, hg_small, show_regression = FALSE)
  })
})

test_that("plotImpactVsRecovery with custom data", {
  custom_data <- data.frame(
    impact_deviation = rnorm(10),
    recovery_time = runif(10, 2, 20),
    weight = rep(1, 10)
  )

  expect_no_error({
    pdf(NULL)
    on.exit(dev.off(), add = TRUE)
    plotImpactVsRecovery(recovery_data = custom_data)
  })
})
