# ===========================================================================
# bridge-clinical.R -- Clinical prediction from MSK network topology
# ===========================================================================

# ---- Internal helpers ----

#' Resolve muscle identifiers to validated integer indices
#' @param injury_muscles Character or integer vector of muscle names/indices.
#' @param hg An MSKHypergraph object.
#' @return Integer vector of validated muscle indices.
#' @keywords internal
.resolveMuscleIndices <- function(injury_muscles, hg) {
  if (is.numeric(injury_muscles) || is.integer(injury_muscles)) {
    idx <- as.integer(injury_muscles)
    valid <- idx >= 1L & idx <= hg$n_muscles
    if (!all(valid)) {
      stop("Muscle indices out of range: ",
           paste(idx[!valid], collapse = ", "))
    }
    return(idx)
  }

  # Character: try exact match first, then fuzzy
  names_lower <- tolower(hg$muscle_names)
  idx <- integer(length(injury_muscles))
  for (i in seq_along(injury_muscles)) {
    m <- tolower(trimws(injury_muscles[i]))
    exact <- which(names_lower == m)
    if (length(exact) == 1L) {
      idx[i] <- exact
    } else if (length(exact) > 1L) {
      idx[i] <- exact[1L]
    } else {
      fuzzy <- agrep(m, names_lower, max.distance = 0.2, ignore.case = TRUE)
      if (length(fuzzy) >= 1L) {
        idx[i] <- fuzzy[1L]
      } else {
        stop("Could not match muscle name: '", injury_muscles[i],
             "'. Use hg$muscle_names to see available names.")
      }
    }
  }
  idx
}

#' Ensure an MSKHypergraph is available
#' @param hg An MSKHypergraph or NULL.
#' @return An MSKHypergraph object.
#' @keywords internal
.ensureHypergraph <- function(hg) {
  if (is.null(hg)) MSKHypergraph() else hg
}


# ---- Exported functions ----

#' Clinical Prediction from MSK Network Topology
#'
#' Predicts recovery time, identifies compensatory muscles, and estimates
#' secondary injury risk based on MSK network impact analysis.
#'
#' @param injury_muscles Character or integer vector identifying injured muscles.
#' @param hg An MSKHypergraph object (NULL loads default 173-bone/270-muscle network).
#' @param sim An MSKSimulation object (NULL creates one with default parameters).
#' @param verbose Logical, print progress messages (default: TRUE).
#' @return An S3 object of class \code{"MSKClinicalPrediction"} with:
#'   \describe{
#'     \item{recovery}{Data frame with predicted recovery weeks and CI per muscle}
#'     \item{compensatory}{List of compensatory muscles per injured muscle}
#'     \item{secondary_risk}{Data frame of secondary injury risk scores}
#'     \item{injury_muscles}{Resolved muscle names}
#'     \item{injury_indices}{Resolved integer indices}
#'   }
#'
#' @section Clinical Validity:
#' The recovery model was validated on 14 aggregate muscle groups, not individual
#' muscles. Patient factor adjustments are heuristic, not independently validated.
#' This is a research exploration tool, not a clinical diagnostic.
#'
#' @references Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.
#' @export
#' @examples
#' \dontrun{
#' pred <- mskClinicalPredictor(c("Biceps Brachii", "Deltoid"))
#' print(pred)
#' }
mskClinicalPredictor <- function(injury_muscles, hg = NULL, sim = NULL,
                                  verbose = TRUE) {
  hg <- .ensureHypergraph(hg)
  injury_idx <- .resolveMuscleIndices(injury_muscles, hg)
  injury_names <- hg$muscle_names[injury_idx]

  if (verbose) message("Computing impact scores for clinical prediction...")

  # Set up simulation if needed
  if (is.null(sim)) sim <- mskSimulate(hg)

  # Compute impact scores for injured muscles and their neighbors
  impact_scores <- vapply(injury_idx, function(i) mskImpactScore(sim, i),
                          numeric(1))
  names(impact_scores) <- injury_names

  # Impact deviation relative to degree-based expectation
  all_deg <- hyperedgeDegree(hg)
  impact_dev <- numeric(length(injury_idx))
  for (k in seq_along(injury_idx)) {
    mi <- injury_idx[k]
    deg_mi <- all_deg[mi]
    same_deg <- which(all_deg == deg_mi)
    if (length(same_deg) >= 3L) {
      scores_same <- vapply(same_deg, function(j) mskImpactScore(sim, j),
                            numeric(1))
      mu <- mean(scores_same)
      s <- sd(scores_same)
      impact_dev[k] <- if (s > 0) (impact_scores[k] - mu) / s else 0
    } else {
      impact_dev[k] <- 0
    }
  }
  names(impact_dev) <- injury_names

  # ---- Recovery prediction ----
  recovery_model <- mskImpactRecoveryModel()
  intercept <- recovery_model$coefficients[["(Intercept)"]]
  slope <- recovery_model$coefficients[["x"]]
  residual_se <- sd(recovery_model$residuals)

  recovery_weeks <- intercept + slope * impact_dev
  recovery_lower <- pmax(1, recovery_weeks - 1.96 * residual_se)
  recovery_upper <- recovery_weeks + 1.96 * residual_se

  recovery_df <- data.frame(
    muscle = injury_names,
    impact_deviation = round(impact_dev, 3),
    predicted_weeks = round(pmax(1, recovery_weeks), 1),
    ci_lower = round(recovery_lower, 1),
    ci_upper = round(recovery_upper, 1),
    stringsAsFactors = FALSE
  )

  # ---- Compensatory muscles ----
  B <- projectMuscleGraph(hg)
  compensatory <- lapply(injury_idx, function(mi) {
    neighbors <- which(B[mi, ] > 0)
    neighbors <- setdiff(neighbors, injury_idx)
    if (length(neighbors) == 0L) return(data.frame(
      muscle = character(0), edge_weight = numeric(0),
      stringsAsFactors = FALSE
    ))
    weights <- B[mi, neighbors]
    ord <- order(weights, decreasing = TRUE)
    data.frame(
      muscle = hg$muscle_names[neighbors[ord]],
      edge_weight = as.numeric(weights[ord]),
      stringsAsFactors = FALSE
    )
  })
  names(compensatory) <- injury_names

  # ---- Secondary injury risk ----
  # Compute displacement exposure via incidence matrix for nearby muscles
  all_neighbors <- unique(unlist(lapply(injury_idx, function(mi) {
    which(B[mi, ] > 0)
  })))
  all_neighbors <- setdiff(all_neighbors, injury_idx)

  if (length(all_neighbors) > 0L) {
    # Displacement exposure: sum of edge weights to injured muscles
    disp_exposure <- vapply(all_neighbors, function(ni) {
      sum(B[ni, injury_idx])
    }, numeric(1))

    # Impact deviation for neighbors (degree-based proxy)
    neighbor_deg <- all_deg[all_neighbors]
    neighbor_risk <- disp_exposure * (neighbor_deg / max(neighbor_deg))
    names(neighbor_risk) <- hg$muscle_names[all_neighbors]

    risk_ord <- order(neighbor_risk, decreasing = TRUE)
    secondary_risk <- data.frame(
      muscle = hg$muscle_names[all_neighbors[risk_ord]],
      displacement_exposure = round(disp_exposure[risk_ord], 3),
      risk_score = round(neighbor_risk[risk_ord] / max(neighbor_risk), 3),
      stringsAsFactors = FALSE
    )
  } else {
    secondary_risk <- data.frame(
      muscle = character(0),
      displacement_exposure = numeric(0),
      risk_score = numeric(0),
      stringsAsFactors = FALSE
    )
  }

  result <- structure(
    list(
      recovery = recovery_df,
      compensatory = compensatory,
      secondary_risk = secondary_risk,
      injury_muscles = injury_names,
      injury_indices = injury_idx,
      impact_scores = impact_scores,
      impact_deviation = impact_dev
    ),
    class = "MSKClinicalPrediction"
  )

  if (verbose) message("Done.")
  result
}

#' @export
print.MSKClinicalPrediction <- function(x, ...) {
  cat("MSK Clinical Prediction\n")
  cat("=======================\n")
  cat("Injured muscles:", paste(x$injury_muscles, collapse = ", "), "\n\n")

  cat("Recovery Prediction:\n")
  for (i in seq_len(nrow(x$recovery))) {
    r <- x$recovery[i, ]
    cat(sprintf("  %s: %.1f weeks (95%% CI: %.1f-%.1f)\n",
                r$muscle, r$predicted_weeks, r$ci_lower, r$ci_upper))
  }

  cat("\nTop Compensatory Muscles:\n")
  for (nm in names(x$compensatory)) {
    comp <- x$compensatory[[nm]]
    top <- head(comp, 5)
    if (nrow(top) > 0) {
      cat(sprintf("  %s: %s\n", nm,
                  paste(top$muscle, collapse = ", ")))
    }
  }

  if (nrow(x$secondary_risk) > 0) {
    cat("\nSecondary Injury Risk (top 5):\n")
    top_risk <- head(x$secondary_risk, 5)
    for (i in seq_len(nrow(top_risk))) {
      cat(sprintf("  %s: risk = %.3f\n",
                  top_risk$muscle[i], top_risk$risk_score[i]))
    }
  }

  invisible(x)
}


#' Recovery Timeline with Phase Assignment
#'
#' Generates a week-by-week recovery timeline based on exponential decay of
#' network impact, with clinical phase assignments.
#'
#' @param injury_muscles Character or integer vector identifying injured muscles.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param sim An MSKSimulation object (NULL creates default).
#' @param n_weeks Integer, number of weeks to project (default: 12).
#' @return A data.frame with columns: week, muscle, remaining_impact_pct, phase, milestone.
#'
#' @section Clinical Validity:
#' Phase assignments are based on exponential decay of network impact scores,
#' not empirical clinical data. They should be interpreted as model-based
#' estimates for research purposes only.
#'
#' @export
#' @examples
#' \dontrun{
#' timeline <- mskRecoveryTimeline("Biceps Brachii")
#' }
mskRecoveryTimeline <- function(injury_muscles, hg = NULL, sim = NULL,
                                 n_weeks = 12L) {

  hg <- .ensureHypergraph(hg)
  injury_idx <- .resolveMuscleIndices(injury_muscles, hg)
  injury_names <- hg$muscle_names[injury_idx]

  if (is.null(sim)) sim <- mskSimulate(hg)

  # Get recovery prediction to determine T (predicted recovery time)
  pred <- mskClinicalPredictor(injury_muscles = injury_idx, hg = hg,
                                sim = sim, verbose = FALSE)

  # Build timeline per muscle
  rows <- list()
  for (k in seq_along(injury_idx)) {
    T_pred <- max(1, pred$recovery$predicted_weeks[k])
    lambda <- -log(0.05) / T_pred  # 95% recovery by T_pred

    for (w in seq(0, n_weeks)) {
      remaining <- 100 * exp(-lambda * w)
      phase <- if (remaining > 60) {
        "Acute"
      } else if (remaining > 30) {
        "Subacute"
      } else if (remaining > 10) {
        "Remodeling"
      } else {
        "Return"
      }

      # Milestone: first week entering each phase
      milestone <- ""
      if (w > 0) {
        prev_remaining <- 100 * exp(-lambda * (w - 1))
        if (prev_remaining > 60 && remaining <= 60) milestone <- "Enter Subacute"
        if (prev_remaining > 30 && remaining <= 30) milestone <- "Enter Remodeling"
        if (prev_remaining > 10 && remaining <= 10) milestone <- "Enter Return"
      }

      rows[[length(rows) + 1L]] <- data.frame(
        week = w,
        muscle = injury_names[k],
        remaining_impact_pct = round(remaining, 1),
        phase = phase,
        milestone = milestone,
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(rbind, rows)
}


#' Patient-specific Injury Risk Profile
#'
#' Computes a personalized injury risk profile for all muscles based on
#' MSK network topology and patient characteristics.
#'
#' @param patient_data A list with patient characteristics:
#'   \describe{
#'     \item{age}{Numeric, patient age in years (required)}
#'     \item{bmi}{Numeric, body mass index (optional)}
#'     \item{activity_level}{Character: "sedentary", "moderate", "active", "elite" (optional)}
#'     \item{prior_injuries}{Character vector of previously injured muscle names (optional)}
#'   }
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param sim An MSKSimulation object (NULL creates default).
#' @return An S3 object of class \code{"MSKInjuryRiskProfile"} with:
#'   \describe{
#'     \item{risk_scores}{Data frame with muscle name, base risk, adjusted risk}
#'     \item{patient_data}{Input patient data}
#'     \item{factors}{Applied adjustment factors}
#'   }
#'
#' @section Clinical Validity:
#' Patient factor adjustments (age, BMI, activity level) are heuristic
#' multipliers, not derived from validated epidemiological models.
#' This is a research exploration tool, not a clinical diagnostic.
#'
#' @export
#' @examples
#' \dontrun{
#' profile <- mskInjuryRiskProfile(list(age = 45, activity_level = "active"))
#' }
mskInjuryRiskProfile <- function(patient_data, hg = NULL, sim = NULL) {
  stopifnot(is.list(patient_data))
  stopifnot("age" %in% names(patient_data))
  stopifnot(is.numeric(patient_data$age) && patient_data$age > 0)

  hg <- .ensureHypergraph(hg)

  # ---- Base risk from network topology ----
  # Use degree + betweenness as proxy for structural vulnerability
  deg <- hyperedgeDegree(hg)
  betw <- mskBetweenness(hg, type = "muscle")

  # Normalize each to [0, 1]
  deg_norm <- (deg - min(deg)) / max(max(deg) - min(deg), 1)
  betw_norm <- if (max(betw) > 0) betw / max(betw) else rep(0, length(betw))

  base_risk <- 0.5 * deg_norm + 0.5 * betw_norm

  # ---- Patient adjustment factors ----
  factors <- list()

  # Age factor: increasing risk with age
  age <- patient_data$age
  factors$age <- if (age < 25) {
    0.8
  } else if (age < 40) {
    1.0
  } else if (age < 55) {
    1.2
  } else {
    1.4
  }

  # Activity level factor
  activity <- patient_data$activity_level %||% "moderate"
  factors$activity <- switch(activity,
    sedentary = 0.7,
    moderate = 1.0,
    active = 1.2,
    elite = 1.5,
    1.0  # default
  )

  # BMI factor
  if (!is.null(patient_data$bmi)) {
    bmi <- patient_data$bmi
    factors$bmi <- if (bmi < 18.5) {
      1.1
    } else if (bmi < 25) {
      1.0
    } else if (bmi < 30) {
      1.15
    } else {
      1.3
    }
  } else {
    factors$bmi <- 1.0
  }

  # Prior injury factor: muscles in same community as prior injuries get boosted
  if (!is.null(patient_data$prior_injuries) &&
      length(patient_data$prior_injuries) > 0) {
    prior_idx <- tryCatch(
      .resolveMuscleIndices(patient_data$prior_injuries, hg),
      error = function(e) integer(0)
    )
    if (length(prior_idx) > 0) {
      comm <- mskCommunityDetect(hg, gamma = 4.3, type = "muscle")
      prior_comms <- unique(comm$membership[prior_idx])
      same_comm <- which(comm$membership %in% prior_comms)
      factors$prior_injury <- rep(1.0, hg$n_muscles)
      factors$prior_injury[same_comm] <- 1.3
      factors$prior_injury[prior_idx] <- 1.5
    } else {
      factors$prior_injury <- rep(1.0, hg$n_muscles)
    }
  } else {
    factors$prior_injury <- rep(1.0, hg$n_muscles)
  }

  # ---- Composite risk ----
  scalar_factors <- factors$age * factors$activity * factors$bmi
  adjusted_risk <- base_risk * scalar_factors * factors$prior_injury

  # Normalize to [0, 1]
  max_risk <- max(adjusted_risk)
  if (max_risk > 0) adjusted_risk <- adjusted_risk / max_risk

  risk_ord <- order(adjusted_risk, decreasing = TRUE)
  risk_df <- data.frame(
    muscle = hg$muscle_names[risk_ord],
    base_risk = round(base_risk[risk_ord], 4),
    adjusted_risk = round(adjusted_risk[risk_ord], 4),
    stringsAsFactors = FALSE
  )

  structure(
    list(
      risk_scores = risk_df,
      patient_data = patient_data,
      factors = list(
        age = factors$age,
        activity = factors$activity,
        bmi = factors$bmi
      )
    ),
    class = "MSKInjuryRiskProfile"
  )
}

#' @export
print.MSKInjuryRiskProfile <- function(x, ...) {
  cat("MSK Injury Risk Profile\n")
  cat("=======================\n")
  cat("Patient: age =", x$patient_data$age)
  if (!is.null(x$patient_data$bmi)) cat(", BMI =", x$patient_data$bmi)
  if (!is.null(x$patient_data$activity_level))
    cat(", activity =", x$patient_data$activity_level)
  cat("\n")
  cat("Adjustment factors: age =", x$factors$age,
      ", activity =", x$factors$activity,
      ", BMI =", x$factors$bmi, "\n\n")

  cat("Top 10 Risk Muscles:\n")
  top <- head(x$risk_scores, 10)
  for (i in seq_len(nrow(top))) {
    cat(sprintf("  %2d. %-30s risk = %.4f\n", i, top$muscle[i],
                top$adjusted_risk[i]))
  }
  invisible(x)
}


#' Rehabilitation Protocol Based on Network Topology
#'
#' Generates a phased rehabilitation protocol using MSK network community
#' structure and shortest path distances to determine exercise progression.
#'
#' @param injury_muscles Character or integer vector identifying injured muscles.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param n_phases Integer, number of rehabilitation phases (default: 3).
#' @return An S3 object of class \code{"MSKRehabProtocol"} with per-phase muscle lists.
#'
#' @section Clinical Validity:
#' Phase ordering is based on network topology (community membership and shortest
#' path distance), not validated rehabilitation protocols. Use as a research
#' exploration tool, not clinical guidance.
#'
#' @export
#' @examples
#' \dontrun{
#' protocol <- mskRehabProtocol("Biceps Brachii")
#' print(protocol)
#' }
mskRehabProtocol <- function(injury_muscles, hg = NULL, n_phases = 3L) {
  hg <- .ensureHypergraph(hg)
  injury_idx <- .resolveMuscleIndices(injury_muscles, hg)
  injury_names <- hg$muscle_names[injury_idx]

  # Community detection

  comm <- mskCommunityDetect(hg, gamma = 4.3, type = "muscle")
  membership <- comm$membership
  injury_comms <- unique(membership[injury_idx])

  # Muscle-muscle adjacency
  B <- projectMuscleGraph(hg)

  # ---- Phase 1: Isolated (injured muscles + safe same-community non-neighbors) ----
  # Same community as injured muscles but NOT directly connected
  same_comm_idx <- which(membership %in% injury_comms)
  same_comm_idx <- setdiff(same_comm_idx, injury_idx)

  # Non-neighbors among same community
  neighbor_idx <- unique(unlist(lapply(injury_idx, function(mi) {
    which(B[mi, ] > 0)
  })))

  safe_same_comm <- setdiff(same_comm_idx, neighbor_idx)
  phase1 <- data.frame(
    muscle = c(injury_names, hg$muscle_names[safe_same_comm]),
    type = c(rep("injured", length(injury_idx)),
             rep("safe_same_community", length(safe_same_comm))),
    community = membership[c(injury_idx, safe_same_comm)],
    stringsAsFactors = FALSE
  )

  # ---- Phase 2: Intra-community (same community, ordered by distance) ----
  # Compute shortest paths in muscle graph
  sp <- mskShortestPaths(hg, type = "muscle")

  # Same-community muscles that are neighbors
  intra_comm <- intersect(same_comm_idx, neighbor_idx)
  if (length(intra_comm) > 0) {
    # Average distance to all injured muscles
    avg_dist <- vapply(intra_comm, function(mi) {
      mean(sp[mi, injury_idx])
    }, numeric(1))
    ord <- order(avg_dist)
    phase2 <- data.frame(
      muscle = hg$muscle_names[intra_comm[ord]],
      avg_distance = round(avg_dist[ord], 2),
      community = membership[intra_comm[ord]],
      stringsAsFactors = FALSE
    )
  } else {
    phase2 <- data.frame(
      muscle = character(0),
      avg_distance = numeric(0),
      community = integer(0),
      stringsAsFactors = FALSE
    )
  }

  # ---- Phase 3: Cross-community (neighboring communities, lower impact first) ----
  # Muscles in other communities that are neighbors of injured muscles
  cross_comm <- setdiff(neighbor_idx, same_comm_idx)
  cross_comm <- setdiff(cross_comm, injury_idx)

  if (length(cross_comm) > 0) {
    # Use degree as proxy for impact score (avoids slow simulation)
    deg <- hyperedgeDegree(hg)
    cross_deg <- deg[cross_comm]
    ord <- order(cross_deg)  # lower degree = lower impact first
    phase3 <- data.frame(
      muscle = hg$muscle_names[cross_comm[ord]],
      degree = cross_deg[ord],
      community = membership[cross_comm[ord]],
      stringsAsFactors = FALSE
    )
  } else {
    phase3 <- data.frame(
      muscle = character(0),
      degree = integer(0),
      community = integer(0),
      stringsAsFactors = FALSE
    )
  }

  structure(
    list(
      phases = list(
        isolated = phase1,
        intra_community = phase2,
        cross_community = phase3
      ),
      injury_muscles = injury_names,
      injury_communities = injury_comms,
      n_phases = n_phases
    ),
    class = "MSKRehabProtocol"
  )
}

#' @export
print.MSKRehabProtocol <- function(x, ...) {
  cat("MSK Rehabilitation Protocol\n")
  cat("===========================\n")
  cat("Injured muscles:", paste(x$injury_muscles, collapse = ", "), "\n")
  cat("Injury communities:", paste(x$injury_communities, collapse = ", "), "\n\n")

  phases <- x$phases
  cat("Phase 1 - Isolated (", nrow(phases$isolated), " muscles):\n", sep = "")
  if (nrow(phases$isolated) > 0) {
    top <- head(phases$isolated, 10)
    for (i in seq_len(nrow(top))) {
      cat(sprintf("  %s [%s, comm %d]\n",
                  top$muscle[i], top$type[i], top$community[i]))
    }
    if (nrow(phases$isolated) > 10) cat("  ... and",
                                         nrow(phases$isolated) - 10, "more\n")
  }

  cat("\nPhase 2 - Intra-community (", nrow(phases$intra_community),
      " muscles):\n", sep = "")
  if (nrow(phases$intra_community) > 0) {
    top <- head(phases$intra_community, 10)
    for (i in seq_len(nrow(top))) {
      cat(sprintf("  %s [dist=%.1f, comm %d]\n",
                  top$muscle[i], top$avg_distance[i], top$community[i]))
    }
    if (nrow(phases$intra_community) > 10) cat("  ... and",
                                                nrow(phases$intra_community) - 10, "more\n")
  }

  cat("\nPhase 3 - Cross-community (", nrow(phases$cross_community),
      " muscles):\n", sep = "")
  if (nrow(phases$cross_community) > 0) {
    top <- head(phases$cross_community, 10)
    for (i in seq_len(nrow(top))) {
      cat(sprintf("  %s [deg=%d, comm %d]\n",
                  top$muscle[i], top$degree[i], top$community[i]))
    }
    if (nrow(phases$cross_community) > 10) cat("  ... and",
                                                nrow(phases$cross_community) - 10, "more\n")
  }

  invisible(x)
}


#' MSK Outcome Summary Report
#'
#' Orchestrator function that calls all clinical bridge functions with shared
#' hypergraph and simulation objects, producing a comprehensive report.
#'
#' @param injury_muscles Character or integer vector identifying injured muscles.
#' @param patient_data Optional list with patient characteristics (see
#'   \code{\link{mskInjuryRiskProfile}}).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param sim An MSKSimulation object (NULL creates default).
#' @return An S3 object of class \code{"MSKOutcomeSummary"} containing:
#'   \describe{
#'     \item{prediction}{MSKClinicalPrediction object}
#'     \item{timeline}{Recovery timeline data.frame}
#'     \item{risk_profile}{MSKInjuryRiskProfile object (if patient_data provided)}
#'     \item{rehab}{MSKRehabProtocol object}
#'   }
#'
#' @section Clinical Validity:
#' All predictions are model-based estimates using MSK network topology.
#' Recovery model was validated on 14 aggregate muscle groups. Patient factors
#' are heuristic. This is a research exploration tool, not a clinical diagnostic.
#'
#' @export
#' @examples
#' \dontrun{
#' summary <- mskOutcomeSummary("Trapezius")
#' print(summary)
#' }
mskOutcomeSummary <- function(injury_muscles, patient_data = NULL,
                               hg = NULL, sim = NULL) {
  hg <- .ensureHypergraph(hg)
  if (is.null(sim)) sim <- mskSimulate(hg)

  # Resolve indices once
  injury_idx <- .resolveMuscleIndices(injury_muscles, hg)

  prediction <- mskClinicalPredictor(injury_idx, hg = hg, sim = sim,
                                      verbose = FALSE)

  timeline <- mskRecoveryTimeline(injury_idx, hg = hg, sim = sim, n_weeks = 12L)

  risk_profile <- if (!is.null(patient_data)) {
    mskInjuryRiskProfile(patient_data, hg = hg, sim = sim)
  } else {
    NULL
  }

  rehab <- mskRehabProtocol(injury_idx, hg = hg, n_phases = 3L)

  structure(
    list(
      prediction = prediction,
      timeline = timeline,
      risk_profile = risk_profile,
      rehab = rehab,
      injury_muscles = hg$muscle_names[injury_idx]
    ),
    class = "MSKOutcomeSummary"
  )
}

#' @export
print.MSKOutcomeSummary <- function(x, ...) {
  cat("=== MSK Outcome Summary ===\n\n")
  cat("Injured muscles:", paste(x$injury_muscles, collapse = ", "), "\n\n")

  cat("--- Recovery Prediction ---\n")
  print(x$prediction$recovery)
  cat("\n")

  cat("--- Timeline (first 4 weeks) ---\n")
  early <- x$timeline[x$timeline$week <= 4, ]
  print(early, row.names = FALSE)
  cat("\n")

  if (!is.null(x$risk_profile)) {
    cat("--- Patient Risk Profile (top 5) ---\n")
    print(head(x$risk_profile$risk_scores, 5), row.names = FALSE)
    cat("\n")
  }

  cat("--- Rehabilitation Protocol ---\n")
  cat("Phase 1 (Isolated):", nrow(x$rehab$phases$isolated), "muscles\n")
  cat("Phase 2 (Intra-community):", nrow(x$rehab$phases$intra_community), "muscles\n")
  cat("Phase 3 (Cross-community):", nrow(x$rehab$phases$cross_community), "muscles\n")

  invisible(x)
}
