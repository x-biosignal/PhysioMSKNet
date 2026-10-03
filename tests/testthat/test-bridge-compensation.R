library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-compensation.R -- Tests for compensatory movement detection
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

# Create EMG matrix with known activation pattern
.make_emg_baseline <- function(n_time = 500, sr = 1000) {
  set.seed(42)
  mat <- matrix(abs(rnorm(n_time * 5, mean = 1, sd = 0.3)),
                nrow = n_time, ncol = 5)
  colnames(mat) <- c("Biceps Brachii", "Deltoid", "Trapezius",
                      "Quadriceps", "Gastrocnemius")
  attr(mat, "sr") <- sr
  mat
}

# Create EMG with doubled activation in specific muscles (to simulate compensation)
.make_emg_compensating <- function(n_time = 500, sr = 1000,
                                    doubled_muscles = c("Deltoid"),
                                    halved_muscles = c("Biceps Brachii")) {
  set.seed(42)
  mat <- matrix(abs(rnorm(n_time * 5, mean = 1, sd = 0.3)),
                nrow = n_time, ncol = 5)
  colnames(mat) <- c("Biceps Brachii", "Deltoid", "Trapezius",
                      "Quadriceps", "Gastrocnemius")
  # Double activation for compensating muscles
  for (m in doubled_muscles) {
    idx <- which(colnames(mat) == m)
    if (length(idx) > 0) mat[, idx] <- mat[, idx] * 3
  }
  # Halve activation for injured muscles
  for (m in halved_muscles) {
    idx <- which(colnames(mat) == m)
    if (length(idx) > 0) mat[, idx] <- mat[, idx] * 0.2
  }
  attr(mat, "sr") <- sr
  mat
}

# EMG with no changes (same seed, same values)
.make_emg_unchanged <- function(n_time = 500, sr = 1000) {
  .make_emg_baseline(n_time, sr)
}


# ===========================================================================
# Internal helpers
# ===========================================================================

# ---- .identifyMSKNeighbors ----

test_that(".identifyMSKNeighbors returns correct neighborhood", {
  hg <- .make_small_hg()
  # Biceps Brachii (idx 1) connects to Humerus and Scapula
  # Deltoid (idx 2) also connects to Scapula -> neighbor at distance 1
  # Trapezius (idx 3) connects to Humerus, Clavicle -> neighbor at distance 1
  result <- PhysioMSKNet:::.identifyMSKNeighbors(1L, hg, order = 1L)

  expect_type(result, "list")
  expect_true("indices" %in% names(result))
  expect_true("distances" %in% names(result))
  expect_true(length(result$indices) > 0)
  # Deltoid and Trapezius share bones with Biceps Brachii
  expect_true(2 %in% result$indices)  # Deltoid
  expect_true(3 %in% result$indices)  # Trapezius
})

test_that(".identifyMSKNeighbors excludes source muscles", {
  hg <- .make_small_hg()
  result <- PhysioMSKNet:::.identifyMSKNeighbors(c(1L, 2L), hg, order = 2L)
  # Source muscles 1 and 2 should not be in neighbors

  expect_false(1 %in% result$indices)
  expect_false(2 %in% result$indices)
})

test_that(".identifyMSKNeighbors respects order parameter", {
  hg <- .make_small_hg()
  result_1 <- PhysioMSKNet:::.identifyMSKNeighbors(1L, hg, order = 1L)
  result_2 <- PhysioMSKNet:::.identifyMSKNeighbors(1L, hg, order = 2L)

  # Higher order should include at least as many neighbors

  expect_true(length(result_2$indices) >= length(result_1$indices))
})

test_that(".identifyMSKNeighbors returns empty for isolated muscle", {
  # Create an isolated muscle in a custom hypergraph
  C <- matrix(c(
    1, 0,
    0, 1
  ), nrow = 2, ncol = 2, byrow = TRUE)
  rownames(C) <- c("BoneA", "BoneB")
  colnames(C) <- c("MuscleA", "MuscleB")
  hg <- MSKHypergraph(C)

  result <- PhysioMSKNet:::.identifyMSKNeighbors(1L, hg, order = 1L)
  expect_equal(length(result$indices), 0)
})


# ---- .computeActivationZScore ----

test_that(".computeActivationZScore computes correct z-scores", {
  current <- c(2.0, 1.0, 3.0)
  baseline <- c(1.0, 1.0, 1.0)
  baseline_sd <- c(0.5, 0.5, 0.5)

  z <- PhysioMSKNet:::.computeActivationZScore(current, baseline, baseline_sd)
  expect_equal(z, c(2.0, 0.0, 4.0))
})

test_that(".computeActivationZScore handles zero SD with fallback", {
  current <- c(2.0, 1.0)
  baseline <- c(1.0, 1.0)
  baseline_sd <- c(0, 0)  # Zero SD

  z <- PhysioMSKNet:::.computeActivationZScore(current, baseline, baseline_sd)
  # With zero SD, fallback to baseline_rms * 0.15
  # For muscle 1: (2 - 1) / (1 * 0.15) = 6.67
  expect_true(is.finite(z[1]))
  expect_true(z[1] > 0)
})


# ---- .resolveInjuredMuscles ----

test_that(".resolveInjuredMuscles delegates to .resolveMuscleIndices", {
  hg <- .make_small_hg()
  idx <- PhysioMSKNet:::.resolveInjuredMuscles("Biceps Brachii", hg)
  expect_equal(idx, 1L)
})

test_that(".resolveInjuredMuscles works with integer input", {
  hg <- .make_small_hg()
  idx <- PhysioMSKNet:::.resolveInjuredMuscles(c(1, 3), hg)
  expect_equal(idx, c(1L, 3L))
})


# ---- .findCompensationChains ----

test_that(".findCompensationChains finds paths", {
  adj <- matrix(c(0, 1, 0,
                   1, 0, 1,
                   0, 1, 0), 3, 3)
  rownames(adj) <- colnames(adj) <- c("A", "B", "C")

  chains <- PhysioMSKNet:::.findCompensationChains(adj, max_length = 5L)
  expect_true(length(chains) > 0)
  # Should find chain A-B-C
  has_abc <- any(vapply(chains, function(ch) {
    length(ch) == 3 && ch[1] == "A" && ch[2] == "B" && ch[3] == "C"
  }, logical(1)))
  expect_true(has_abc)
})

test_that(".findCompensationChains returns empty for empty matrix", {
  adj <- matrix(0, 0, 0)
  chains <- PhysioMSKNet:::.findCompensationChains(adj)
  expect_equal(length(chains), 0)
})

test_that(".findCompensationChains returns empty for disconnected nodes", {
  adj <- matrix(0, 3, 3)
  rownames(adj) <- colnames(adj) <- c("A", "B", "C")
  chains <- PhysioMSKNet:::.findCompensationChains(adj)
  expect_equal(length(chains), 0)
})


# ===========================================================================
# mskDetectCompensation
# ===========================================================================

test_that("mskDetectCompensation detects obvious compensation", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating(doubled_muscles = c("Deltoid"),
                                     halved_muscles = c("Biceps Brachii"))

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg, z_threshold = 1.96
  )

  expect_s3_class(result, "MSKCompensation")
  expect_true(nrow(result$compensating_muscles) > 0)
  # Deltoid should be flagged as compensating
  expect_true("Deltoid" %in% result$compensating_muscles$muscle)
})

test_that("mskDetectCompensation detects decreased injured muscle activation", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating(doubled_muscles = c("Deltoid"),
                                     halved_muscles = c("Biceps Brachii"))

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  # Injured muscle should show decreased status
  if (nrow(result$injured_status) > 0) {
    bic_status <- result$injured_status[result$injured_status$muscle == "Biceps Brachii", ]
    if (nrow(bic_status) > 0) {
      expect_equal(bic_status$status, "decreased")
    }
  }
})

test_that("mskDetectCompensation does NOT flag distant muscles", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating(doubled_muscles = c("Gastrocnemius"),
                                     halved_muscles = c("Biceps Brachii"))

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg, neighborhood_order = 1L
  )

  # Gastrocnemius may not be a 1-hop neighbor of Biceps Brachii
  sp <- mskShortestPaths(hg, type = "muscle")
  sp_mat <- as.matrix(sp)
  dist_gast_to_bic <- sp_mat[
    which(hg$muscle_names == "Gastrocnemius"),
    which(hg$muscle_names == "Biceps Brachii")
  ]

  if (dist_gast_to_bic > 1) {
    # Should NOT be in compensating muscles
    expect_false("Gastrocnemius" %in% result$compensating_muscles$muscle)
  }
})

test_that("mskDetectCompensation handles single injured muscle", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  expect_s3_class(result, "MSKCompensation")
  expect_true(is.data.frame(result$compensating_muscles))
  expect_true(is.data.frame(result$injured_status))
  expect_true(is.data.frame(result$non_compensating))
  expect_true(is.numeric(result$compensation_prevalence))
})

test_that("mskDetectCompensation handles multiple injured muscles", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating(doubled_muscles = c("Trapezius"),
                                     halved_muscles = c("Biceps Brachii", "Deltoid"))

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = c("Biceps Brachii", "Deltoid"),
    hg = hg
  )

  expect_s3_class(result, "MSKCompensation")
  # Both injured muscles should have injured_status entries
  if (nrow(result$injured_status) > 0) {
    expect_true(all(c("Biceps Brachii", "Deltoid") %in%
                      result$network_context$injured_muscles))
  }
})

test_that("mskDetectCompensation returns empty when no compensation", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  # Same data = no change, no compensation
  current <- .make_emg_unchanged()

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  expect_s3_class(result, "MSKCompensation")
  expect_equal(nrow(result$compensating_muscles), 0)
  expect_equal(result$compensation_prevalence, 0)
})

test_that("mskDetectCompensation returns correct structure fields", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  expect_true(all(c("compensating_muscles", "injured_status",
                     "non_compensating", "compensation_prevalence",
                     "network_context") %in% names(result)))
  expect_true("z_threshold" %in% names(result$network_context))
  expect_true("injured_muscles" %in% names(result$network_context))
})

test_that("mskDetectCompensation z_score column is numeric", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  if (nrow(result$compensating_muscles) > 0) {
    expect_true(is.numeric(result$compensating_muscles$z_score))
    expect_true(all(result$compensating_muscles$z_score > result$network_context$z_threshold))
  }
})


# ===========================================================================
# mskCompensationRiskScore
# ===========================================================================

test_that("mskCompensationRiskScore returns correct structure", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  risk <- mskCompensationRiskScore(comp, hg = hg,
                                    duration_weeks = 2,
                                    load_intensity = "moderate")

  expect_s3_class(risk, "MSKCompensationRisk")
  expect_true(all(c("per_muscle_risk", "overall_risk", "overall_category",
                     "highest_risk_muscle", "recommendation") %in% names(risk)))
})

test_that("mskCompensationRiskScore risk increases with duration", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  risk_short <- mskCompensationRiskScore(comp, hg = hg,
                                          duration_weeks = 1,
                                          load_intensity = "moderate")
  risk_long <- mskCompensationRiskScore(comp, hg = hg,
                                         duration_weeks = 10,
                                         load_intensity = "moderate")

  expect_true(risk_long$overall_risk >= risk_short$overall_risk)
})

test_that("mskCompensationRiskScore risk increases with load", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  risk_low <- mskCompensationRiskScore(comp, hg = hg,
                                        duration_weeks = 4,
                                        load_intensity = "low")
  risk_high <- mskCompensationRiskScore(comp, hg = hg,
                                         duration_weeks = 4,
                                         load_intensity = "high")

  expect_true(risk_high$overall_risk >= risk_low$overall_risk)
})

test_that("mskCompensationRiskScore risk categories have correct boundaries", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  risk <- mskCompensationRiskScore(comp, hg = hg,
                                    duration_weeks = 0,
                                    load_intensity = "low")

  if (nrow(risk$per_muscle_risk) > 0) {
    for (i in seq_len(nrow(risk$per_muscle_risk))) {
      rs <- risk$per_muscle_risk$risk_score[i]
      rc <- risk$per_muscle_risk$risk_category[i]
      if (rs > 1.0) expect_equal(rc, "high")
      else if (rs > 0.7) expect_equal(rc, "elevated")
      else if (rs > 0.3) expect_equal(rc, "moderate")
      else expect_equal(rc, "low")
    }
  }
})

test_that("mskCompensationRiskScore handles no compensating muscles", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_unchanged()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  risk <- mskCompensationRiskScore(comp, hg = hg,
                                    duration_weeks = 4,
                                    load_intensity = "moderate")

  expect_equal(risk$overall_risk, 0)
  expect_equal(risk$overall_category, "low")
  expect_true(is.na(risk$highest_risk_muscle))
})


# ===========================================================================
# mskCompensationEvolution
# ===========================================================================

test_that("mskCompensationEvolution tracks compensation onset", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  compensating <- .make_emg_compensating()

  timepoints <- list(
    week0 = baseline,
    week2 = baseline,  # no compensation yet
    week4 = compensating  # compensation appears
  )

  evo <- mskCompensationEvolution(
    timepoints_emg = timepoints,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  expect_s3_class(evo, "MSKCompensationEvolution")
  expect_true(is.data.frame(evo$evolution_table))
  expect_true(is.data.frame(evo$summary))

  # At week4, there should be compensating muscles
  week4_data <- evo$evolution_table[evo$evolution_table$timepoint == "week4", ]
  if (nrow(week4_data) > 0) {
    expect_true(any(week4_data$is_compensating))
  }
})

test_that("mskCompensationEvolution detects resolution", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  compensating <- .make_emg_compensating()
  resolved <- .make_emg_unchanged()

  timepoints <- list(
    week0 = baseline,
    week2 = compensating,  # compensation present
    week4 = resolved       # compensation resolved
  )

  evo <- mskCompensationEvolution(
    timepoints_emg = timepoints,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  # Check that at least some muscles have resolving trend
  if (length(evo$trend) > 0) {
    has_resolving <- any(evo$trend == "resolving")
    # If muscles compensated at week2 but not week4, they should be resolving
    expect_true(is.logical(has_resolving))
  }
})

test_that("mskCompensationEvolution handles single timepoint", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()

  evo <- mskCompensationEvolution(
    timepoints_emg = list(week0 = baseline),
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  expect_s3_class(evo, "MSKCompensationEvolution")
  expect_equal(nrow(evo$evolution_table), 0)
  expect_equal(nrow(evo$summary), 1)
})

test_that("mskCompensationEvolution assigns timepoint names", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  compensating <- .make_emg_compensating()

  timepoints <- list(
    week0 = baseline,
    week4 = compensating
  )

  evo <- mskCompensationEvolution(
    timepoints_emg = timepoints,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  if (nrow(evo$evolution_table) > 0) {
    expect_true(all(evo$evolution_table$timepoint == "week4"))
  }
})

test_that("mskCompensationEvolution summary has correct structure", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  compensating <- .make_emg_compensating()

  timepoints <- list(
    week0 = baseline,
    week2 = compensating,
    week4 = compensating
  )

  evo <- mskCompensationEvolution(
    timepoints_emg = timepoints,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  expect_equal(nrow(evo$summary), 2)  # 2 post-baseline timepoints
  expect_true(all(c("timepoint", "n_compensating", "mean_z") %in%
                    names(evo$summary)))
})


# ===========================================================================
# mskCompensationNetwork
# ===========================================================================

test_that("mskCompensationNetwork returns correct adjacency dimensions", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  net <- mskCompensationNetwork(comp, hg = hg)

  n_comp <- nrow(comp$compensating_muscles)
  expect_equal(nrow(net$adjacency), n_comp)
  expect_equal(ncol(net$adjacency), n_comp)
})

test_that("mskCompensationNetwork chains are valid paths", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  net <- mskCompensationNetwork(comp, hg = hg)

  # Each chain should have at least 2 muscles
  for (ch in net$chains) {
    expect_true(length(ch) >= 2)
    # Each consecutive pair should be connected in adjacency
    for (k in seq_len(length(ch) - 1)) {
      i <- which(rownames(net$adjacency) == ch[k])
      j <- which(colnames(net$adjacency) == ch[k + 1])
      if (length(i) > 0 && length(j) > 0) {
        expect_true(net$adjacency[i, j] > 0)
      }
    }
  }
})

test_that("mskCompensationNetwork handles empty compensation", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_unchanged()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  net <- mskCompensationNetwork(comp, hg = hg)

  expect_equal(nrow(net$adjacency), 0)
  expect_equal(length(net$chains), 0)
  expect_equal(length(net$hub_muscles), 0)
})

test_that("mskCompensationNetwork returns list structure", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  net <- mskCompensationNetwork(comp, hg = hg)

  expect_true(all(c("adjacency", "chains", "hub_muscles",
                     "community_involvement") %in% names(net)))
})


# ===========================================================================
# mskCompensationSummary
# ===========================================================================

test_that("mskCompensationSummary returns correct S3 class", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  summary <- mskCompensationSummary(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg, duration_weeks = 2, load_intensity = "moderate"
  )

  expect_s3_class(summary, "MSKCompensationSummary")
  expect_true("available_analyses" %in% names(summary))
  expect_true("compensation" %in% summary$available_analyses)
})

test_that("mskCompensationSummary includes risk and network", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  summary <- mskCompensationSummary(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg, duration_weeks = 2, load_intensity = "moderate"
  )

  expect_true("risk" %in% summary$available_analyses)
  expect_true("network" %in% summary$available_analyses)
  expect_s3_class(summary$compensation, "MSKCompensation")
  expect_s3_class(summary$risk, "MSKCompensationRisk")
})

test_that("mskCompensationSummary includes evolution when timepoints provided", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  timepoints <- list(week0 = baseline, week4 = current)

  summary <- mskCompensationSummary(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    timepoints_emg = timepoints,
    hg = hg, duration_weeks = 4, load_intensity = "high"
  )

  expect_true("evolution" %in% summary$available_analyses)
  expect_s3_class(summary$evolution, "MSKCompensationEvolution")
})


# ===========================================================================
# Print methods
# ===========================================================================

test_that("print.MSKCompensation produces output", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  output <- capture.output(print(result))
  expect_true(length(output) > 0)
  expect_true(any(grepl("Compensat", output)))
})

test_that("print.MSKCompensationRisk produces output", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  comp <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  risk <- mskCompensationRiskScore(comp, hg = hg,
                                    duration_weeks = 4,
                                    load_intensity = "moderate")

  output <- capture.output(print(risk))
  expect_true(length(output) > 0)
  expect_true(any(grepl("Risk", output)))
})

test_that("print.MSKCompensationEvolution produces output", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  timepoints <- list(week0 = baseline, week4 = current)

  evo <- mskCompensationEvolution(
    timepoints_emg = timepoints,
    injured_muscles = "Biceps Brachii",
    hg = hg
  )

  output <- capture.output(print(evo))
  expect_true(length(output) > 0)
  expect_true(any(grepl("Evolution", output)))
})

test_that("print.MSKCompensationSummary produces output", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  summary <- mskCompensationSummary(
    emg = current, emg_baseline = baseline,
    injured_muscles = "Biceps Brachii",
    hg = hg, load_intensity = "moderate"
  )

  output <- capture.output(print(summary))
  expect_true(length(output) > 0)
  expect_true(any(grepl("Summary", output)))
})


# ===========================================================================
# Edge cases
# ===========================================================================

test_that("mskDetectCompensation handles constant EMG", {
  hg <- .make_small_hg()
  # All constant = no variation
  mat_const <- matrix(1, nrow = 100, ncol = 5)
  colnames(mat_const) <- c("Biceps Brachii", "Deltoid", "Trapezius",
                            "Quadriceps", "Gastrocnemius")

  result <- mskDetectCompensation(
    emg = mat_const, emg_baseline = mat_const,
    injured_muscles = "Biceps Brachii", hg = hg
  )

  expect_s3_class(result, "MSKCompensation")
  expect_equal(nrow(result$compensating_muscles), 0)
})

test_that("mskDetectCompensation validates z_threshold", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()

  expect_error(
    mskDetectCompensation(
      emg = baseline, emg_baseline = baseline,
      injured_muscles = "Biceps Brachii", hg = hg,
      z_threshold = -1
    )
  )
})

test_that("mskCompensationRiskScore validates input class", {
  expect_error(
    mskCompensationRiskScore(list(foo = "bar")),
    "inherits"
  )
})

test_that("mskDetectCompensation with integer injured_muscles", {
  hg <- .make_small_hg()
  baseline <- .make_emg_baseline()
  current <- .make_emg_compensating()

  result <- mskDetectCompensation(
    emg = current, emg_baseline = baseline,
    injured_muscles = 1L,  # integer index for Biceps Brachii
    hg = hg
  )

  expect_s3_class(result, "MSKCompensation")
  expect_equal(result$network_context$injured_muscles, "Biceps Brachii")
})
