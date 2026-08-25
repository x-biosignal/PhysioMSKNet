#' Plot Impact Score vs Degree
#'
#' Recreates Fig 3a: scatter plot of impact scores by hyperedge degree.
#' Target: R^2 = 0.45 for the relationship.
#'
#' @param impact_scores Named numeric vector of impact scores.
#' @param hg An MSKHypergraph object.
#' @param show_regression Logical, overlay regression line.
#' @param ... Additional arguments.
#' @return Invisible the regression result.
#' @export
plotImpactVsDegree <- function(impact_scores, hg = NULL, show_regression = TRUE, ...) {
  if (is.null(hg)) hg <- MSKHypergraph()
  deg <- hyperedgeDegree(hg)

  graphics::plot(deg, impact_scores,
                 xlab = "Hyperedge degree (# bones)",
                 ylab = "Impact score",
                 main = "Impact Score vs Muscle Degree",
                 pch = 16, col = grDevices::rgb(0, 0, 0.8, 0.4),
                 ...)

  if (show_regression) {
    fit <- stats::lm(impact_scores ~ deg)
    graphics::abline(fit, col = "red", lwd = 2)
    r2 <- summary(fit)$r.squared
    graphics::legend("topleft",
                     legend = sprintf("R^2 = %.3f (paper: 0.45)", r2),
                     bty = "n", text.col = "red")
  }
  invisible(if (show_regression) summary(fit) else NULL)
}

#' Plot Impact Deviation vs Recovery Time
#'
#' Recreates Fig 3b: weighted regression of impact deviation vs clinical
#' recovery time. Target: R^2 = 0.757.
#'
#' @param recovery_data Optional data.frame. If NULL, uses built-in data.
#' @param ... Additional arguments.
#' @return Invisible the regression result.
#' @export
plotImpactVsRecovery <- function(recovery_data = NULL, ...) {
  if (is.null(recovery_data)) {
    recovery_data <- loadValidationData("impact_vs_recovery")
  }

  fit <- mskRobustRegression(
    x = recovery_data$impact_deviation,
    y = recovery_data$recovery_time,
    weights = recovery_data$weight
  )

  # Size points by weight
  max_w <- max(recovery_data$weight)
  pt_size <- 1 + 3 * recovery_data$weight / max_w

  graphics::plot(recovery_data$impact_deviation, recovery_data$recovery_time,
                 xlab = "Impact deviation",
                 ylab = "Recovery time (weeks)",
                 main = "Impact Deviation vs Clinical Recovery",
                 pch = 16, cex = pt_size,
                 col = grDevices::rgb(0, 0, 0.8, 0.6),
                 ...)

  x_seq <- seq(min(recovery_data$impact_deviation),
               max(recovery_data$impact_deviation), length.out = 100)
  y_pred <- fit$coefficients[1] + fit$coefficients[2] * x_seq
  graphics::lines(x_seq, y_pred, col = "red", lwd = 2)

  graphics::legend("topleft",
                   legend = c(
                     sprintf("R^2 = %.3f (paper: 0.757)", fit$r_squared),
                     sprintf("p = %.2e", fit$p_value)
                   ),
                   bty = "n", text.col = "red")
  invisible(fit)
}

#' Plot Homunculus Correspondence
#'
#' Recreates Fig 4b: deviation ratio vs homunculus area.
#' Target: F(1,19) = 21.3, R^2 = 0.52
#'
#' @param homunculus_data Optional data.frame. If NULL, uses built-in data.
#' @param ... Additional arguments.
#' @return Invisible the regression result.
#' @export
plotHomunculus <- function(homunculus_data = NULL, ...) {
  if (is.null(homunculus_data)) {
    homunculus_data <- loadValidationData("homunculus_deviation")
  }

  fit <- mskRobustRegression(
    x = homunculus_data$homunc_area,
    y = homunculus_data$dev_ratio
  )

  graphics::plot(homunculus_data$homunc_area, homunculus_data$dev_ratio,
                 xlab = "Homunculus area (rank)",
                 ylab = "Deviation ratio",
                 main = "Community-Homunculus Correspondence",
                 pch = 16, cex = 1.5,
                 col = grDevices::rgb(0, 0, 0.8, 0.6),
                 ...)

  x_seq <- seq(min(homunculus_data$homunc_area),
               max(homunculus_data$homunc_area), length.out = 100)
  y_pred <- fit$coefficients[1] + fit$coefficients[2] * x_seq
  graphics::lines(x_seq, y_pred, col = "red", lwd = 2)

  graphics::legend("topright",
                   legend = c(
                     sprintf("R^2 = %.3f (paper: 0.52)", fit$r_squared),
                     sprintf("F(1,%d) = %.1f", fit$n - 2, fit$f_statistic)
                   ),
                   bty = "n", text.col = "red")
  invisible(fit)
}

#' Reproduce Paper Results
#'
#' Master function that runs the complete analysis pipeline and compares
#' results to the paper's reported values. This is the main validation function.
#'
#' @param run_simulation Logical, run the full simulation (slow, default: FALSE).
#'   If FALSE, uses validation data to reproduce statistical analyses.
#' @param verbose Logical, print progress and comparison.
#' @return A list with all results and paper comparisons.
#' @export
mskReproducePaper <- function(run_simulation = FALSE, verbose = TRUE) {
  results <- list()

  # 1. Load data and build hypergraph
  if (verbose) message("=== Building MSK Hypergraph ===")
  hg <- MSKHypergraph()
  if (verbose) print(hg)

  # 2. Degree distributions
  if (verbose) message("\n=== Degree Distributions ===")
  dd_muscle <- degreeDistribution(hg, "muscle")
  dd_bone <- degreeDistribution(hg, "bone")
  if (verbose) {
    cat("Muscle degree range:", range(dd_muscle$degree), "\n")
    cat("Bone degree range:", range(dd_bone$degree), "\n")
    cat("Paper: heavy-tailed distribution\n")
  }
  results$degree <- list(muscle = dd_muscle, bone = dd_bone)

  # 3. Network metrics
  if (verbose) message("\n=== Network Metrics ===")
  metrics_bone <- mskNetworkMetrics(hg, "bone")
  metrics_muscle <- mskNetworkMetrics(hg, "muscle")
  if (verbose) {
    cat("Bone graph: ", metrics_bone$n_nodes, "nodes,",
        metrics_bone$n_edges, "edges\n")
    cat("Muscle graph:", metrics_muscle$n_nodes, "nodes,",
        metrics_muscle$n_edges, "edges\n")
  }
  results$metrics <- list(bone = metrics_bone, muscle = metrics_muscle)

  # 4. Impact vs recovery (from validation data)
  if (verbose) message("\n=== Impact-Recovery Model (Fig 3b) ===")
  recovery_model <- mskImpactRecoveryModel()
  if (verbose) {
    cat(sprintf("R^2 = %.3f (paper: 0.757)\n", recovery_model$r_squared))
    cat(sprintf("F = %.1f (paper: 37.3)\n", recovery_model$f_statistic))
    cat(sprintf("p = %.2e (paper: <0.0001)\n", recovery_model$p_value))
  }
  results$recovery <- recovery_model

  # 5. Homunculus correspondence (from validation data)
  if (verbose) message("\n=== Homunculus Correspondence (Fig 4b) ===")
  homunc_model <- mskHomuncCorrelation()
  if (verbose) {
    cat(sprintf("R^2 = %.3f (paper: 0.52)\n", homunc_model$r_squared))
    cat(sprintf("F = %.1f (paper: 21.3)\n", homunc_model$f_statistic))
    cat(sprintf("p = %.2e (paper: <0.001)\n", homunc_model$p_value))
  }
  results$homunculus <- homunc_model

  # 6. Community detection
  if (verbose) message("\n=== Community Detection ===")
  meta <- loadMuscleMetadata()
  if (verbose) {
    paper_communities <- length(unique(meta$community))
    cat("Paper communities:", paper_communities, "\n")
    cat("Paper gamma:", 4.3, "\n")
  }
  results$paper_communities <- meta$community

  # 7. Full simulation if requested
  if (run_simulation) {
    if (verbose) message("\n=== Running Full Simulation ===")
    sim <- mskSimulate(hg)
    scores <- mskImpactScoreAll(sim, verbose = verbose)
    results$impact_scores <- scores

    deg <- hyperedgeDegree(hg)
    fit <- stats::lm(scores ~ deg)
    r2 <- summary(fit)$r.squared
    if (verbose) {
      cat(sprintf("Impact vs degree R^2 = %.3f (paper: 0.45)\n", r2))
    }
    results$impact_degree_r2 <- r2
  }

  if (verbose) message("\n=== Validation Complete ===")
  invisible(results)
}
