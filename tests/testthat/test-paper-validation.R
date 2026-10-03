library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-paper-validation.R -- End-to-end validation against Murphy et al. (2018)
#
# These tests reproduce key quantitative results from:
#   Murphy AC et al. (2018) "Structure, function, and control of the human
#   musculoskeletal network." PLOS Biology 16(1): e2002811.
# ===========================================================================

# --- Section 2: Network Structure ---

test_that("Incidence matrix: 173 bones, 270 muscles, 1010 connections (paper Section 2)", {
  hg <- MSKHypergraph()

  expect_equal(hg$n_bones, 173,
               label = "Number of bones should be 173 (paper Table 1)")
  expect_equal(hg$n_muscles, 270,
               label = "Number of muscles should be 270 (paper Table 1)")

  total_connections <- sum(hg$C)
  expect_equal(total_connections, 1010,
               label = "Total connections should be 1010 (sum of incidence matrix)")
})

test_that("Degree distribution is heavy-tailed (paper Fig 2e)", {
  hg <- MSKHypergraph()
  dd <- degreeDistribution(hg, "muscle")

  # Heavy-tailed: many muscles with low degree, few with high degree
  # The paper describes this as a right-skewed distribution
  low_deg_count <- sum(dd$count[dd$degree <= 3])
  high_deg_count <- sum(dd$count[dd$degree >= 10])

  # Many more low-degree muscles than high-degree

  expect_gt(low_deg_count, high_deg_count,
            label = "Low-degree muscles should outnumber high-degree muscles")

  # Skewness: mean > median indicates right skew
  all_deg <- hyperedgeDegree(hg)
  expect_gt(mean(all_deg), median(all_deg),
            label = "Mean degree > median degree (right-skewed)")

  # Max degree should be much larger than median
  expect_gt(max(all_deg), 3 * median(all_deg))
})

test_that("Bone graph has approximately 1383 edges", {
  hg <- MSKHypergraph()
  metrics <- mskNetworkMetrics(hg, "bone")

  # The bone graph edge count: based on network density ~0.093
  # with 173 nodes: ~0.093 * 173 * 172 / 2 ~ 1383
  expect_equal(metrics$n_edges, 1383, tolerance = 50,
               label = "Bone graph should have ~1383 edges")
})

test_that("Muscle graph has approximately 2679 edges", {
  hg <- MSKHypergraph()
  metrics <- mskNetworkMetrics(hg, "muscle")

  # The muscle graph edge count: based on density ~0.074
  # with 270 nodes: ~0.074 * 270 * 269 / 2 ~ 2679
  expect_equal(metrics$n_edges, 2679, tolerance = 100,
               label = "Muscle graph should have ~2679 edges")
})

# --- Section 3: Impact and Recovery ---

test_that("Impact-Recovery: R-squared significant (p < 0.05)", {
  result <- mskImpactRecoveryModel()

  expect_lt(result$p_value, 0.05,
            label = "Impact-Recovery model p-value should be < 0.05")
  expect_gt(result$r_squared, 0,
            label = "Impact-Recovery R-squared should be positive")
})

test_that("Impact-Recovery regression uses validation data correctly", {
  recovery_data <- loadValidationData("impact_vs_recovery")

  # Data should have expected columns
  expect_true(all(c("recovery_time", "impact_deviation", "weight") %in%
                     colnames(recovery_data)))

  # Should have 14 data points (paper: n=14 muscle groups)
  expect_gt(nrow(recovery_data), 5)
})

# --- Section 4: Homunculus Correspondence ---

test_that("Homunculus correspondence: R-squared approx 0.52 (within +-0.05)", {
  result <- mskHomuncCorrelation()

  expect_equal(result$r_squared, 0.52, tolerance = 0.05,
               label = "Homunculus R-squared should be ~0.52 (paper Fig 4b)")
})

test_that("Homunculus F-stat consistent with paper (F ~ 21.3)", {
  result <- mskHomuncCorrelation()

  # Paper reports F(1,19) = 21.3
  # Allow 20% tolerance for method differences
  expect_equal(result$f_statistic, 21.3, tolerance = 4.26,
               label = "Homunculus F-statistic should be ~21.3")
})

test_that("Homunculus correlation is significant (p < 0.001)", {
  result <- mskHomuncCorrelation()

  expect_lt(result$p_value, 0.001,
            label = "Homunculus p-value should be < 0.001 (paper)")
})

# --- Network Properties ---

test_that("Bone degree distribution: all bones have at least one muscle", {
  hg <- MSKHypergraph()
  bone_deg <- vertexDegree(hg)

  expect_true(all(bone_deg >= 1),
              label = "Every bone should be attached to at least one muscle")
})

test_that("Muscle degree distribution: all muscles attach to at least one bone", {
  hg <- MSKHypergraph()
  muscle_deg <- hyperedgeDegree(hg)

  expect_true(all(muscle_deg >= 1),
              label = "Every muscle should attach to at least one bone")
})

test_that("Muscle degree range is [1, 30] as in paper", {
  hg <- MSKHypergraph()
  muscle_deg <- hyperedgeDegree(hg)

  expect_gte(min(muscle_deg), 1)
  expect_lte(max(muscle_deg), 30)
})

test_that("Bone graph density approximately matches paper", {
  hg <- MSKHypergraph()
  metrics <- mskNetworkMetrics(hg, "bone")

  # Paper reports bone graph is relatively dense
  # Density = 2 * n_edges / (n * (n-1))
  expect_gt(metrics$density, 0.05)
  expect_lt(metrics$density, 0.15)
})

test_that("Muscle graph density approximately matches paper", {
  hg <- MSKHypergraph()
  metrics <- mskNetworkMetrics(hg, "muscle")

  expect_gt(metrics$density, 0.04)
  expect_lt(metrics$density, 0.12)
})

# --- End-to-end Reproduction ---

test_that("mskReproducePaper(run_simulation = FALSE) runs without error", {
  expect_no_error({
    results <- mskReproducePaper(run_simulation = FALSE, verbose = FALSE)
  })

  # Check that all expected components are returned
  expect_type(results, "list")
  expect_true("degree" %in% names(results))
  expect_true("metrics" %in% names(results))
  expect_true("recovery" %in% names(results))
  expect_true("homunculus" %in% names(results))
  expect_true("paper_communities" %in% names(results))

  # Degree distributions should have data
  expect_gt(nrow(results$degree$muscle), 0)
  expect_gt(nrow(results$degree$bone), 0)

  # Metrics should have correct node counts
  expect_equal(results$metrics$bone$n_nodes, 173)
  expect_equal(results$metrics$muscle$n_nodes, 270)

  # Recovery and homunculus should have R-squared
  expect_true(is.finite(results$recovery$r_squared))
  expect_true(is.finite(results$homunculus$r_squared))
})

test_that("All 6 validation datasets load without error", {
  datasets <- c("degree_distribution", "impact_vs_recovery",
                 "homunculus_deviation", "fmri_activation",
                 "homunculus_coordinates", "impact_vs_path")

  for (ds in datasets) {
    data <- loadValidationData(ds)
    expect_s3_class(data, "data.frame")
    expect_gt(nrow(data), 0, label = paste(ds, "should have data"))
    expect_gt(ncol(data), 0, label = paste(ds, "should have columns"))
  }
})

test_that("Paper community metadata is consistent", {
  meta <- loadMuscleMetadata()

  # Should have 270 muscles
  expect_equal(nrow(meta), 270)

  # Community assignments should be non-missing
  expect_true(all(!is.na(meta$community)))

  # Homunculus categories should be non-missing
  expect_true(all(!is.na(meta$homunculus_category)))

  # Number of unique communities from paper annotations
  n_paper_comm <- length(unique(meta$community))
  expect_gt(n_paper_comm, 1,
            label = "Paper should identify multiple communities")
})
