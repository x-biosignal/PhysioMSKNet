# ===========================================================================
# bridge-compensation.R -- Compensatory movement pattern detection
# ===========================================================================
#
# Detects compensatory movement patterns that are invisible to the naked eye
# but critical for preventing secondary injuries during rehabilitation.
#
# Reuses: .ensureHypergraph (bridge-clinical.R),
#   .extractSignalMatrix, .computeRMS (bridge-neuromech.R),
#   emgToMSKMapping (bridge-emg.R),
#   projectMuscleGraph, hyperedgeDegree (msknet-hypergraph.R),
#   mskCommunityDetect (msknet-community.R),
#   mskShortestPaths (msknet-metrics.R),
#   .resolveMuscleIndices (bridge-clinical.R)
# ===========================================================================


# ---- Internal helpers ----

#' Identify MSK neighbors within N hops
#'
#' Finds all muscle indices reachable from a set of source muscles
#' within a specified number of hops in the MSK muscle graph.
#'
#' @param muscle_indices Integer vector of source muscle indices.
#' @param hg An MSKHypergraph object.
#' @param order Integer, maximum number of hops (default: 2).
#' @return A list with: indices (integer vector of neighbor indices,
#'   excluding sources), distances (named numeric vector of shortest
#'   distances from any source to each neighbor).
#' @keywords internal
.identifyMSKNeighbors <- function(muscle_indices, hg, order = 2L) {
  sp <- mskShortestPaths(hg, type = "muscle")
  sp_mat <- as.matrix(sp)

  # For each non-source muscle, compute min distance to any source
  all_muscles <- seq_len(hg$n_muscles)
  non_source <- setdiff(all_muscles, muscle_indices)

  min_dist <- vapply(non_source, function(m) {
    min(sp_mat[m, muscle_indices])
  }, numeric(1))

  # Keep only those within `order` hops
  within_range <- which(min_dist <= order & is.finite(min_dist))
  neighbor_idx <- non_source[within_range]
  neighbor_dist <- min_dist[within_range]
  names(neighbor_dist) <- hg$muscle_names[neighbor_idx]

  list(indices = neighbor_idx, distances = neighbor_dist)
}


#' Compute activation z-scores
#'
#' Computes z-score of activation change between current and baseline.
#'
#' @param current_rms Numeric vector of current RMS values.
#' @param baseline_rms Numeric vector of baseline RMS values.
#' @param baseline_sd Numeric vector of baseline standard deviations.
#' @return Numeric vector of z-scores.
#' @keywords internal
.computeActivationZScore <- function(current_rms, baseline_rms, baseline_sd) {
  # Guard against zero SD
  baseline_sd[baseline_sd <= 0] <- baseline_rms[baseline_sd <= 0] * 0.15
  baseline_sd[baseline_sd <= 0] <- 1e-10
  (current_rms - baseline_rms) / baseline_sd
}


#' Resolve injured muscle names/indices with fuzzy matching
#'
#' Resolves muscle identifiers (names or indices) against hypergraph,
#' delegating to \code{.resolveMuscleIndices} from bridge-clinical.R.
#'
#' @param injured_muscles Character or integer vector of muscle names/indices.
#' @param hg An MSKHypergraph object.
#' @return Integer vector of validated muscle indices.
#' @keywords internal
.resolveInjuredMuscles <- function(injured_muscles, hg) {
  .resolveMuscleIndices(injured_muscles, hg)
}


#' Find compensation chains via DFS
#'
#' Finds paths through compensating muscles in the compensation adjacency
#' matrix using depth-first search.
#'
#' @param adj_matrix Numeric matrix (square, weighted adjacency).
#' @param max_length Integer, maximum chain length (default: 5).
#' @return A list of character vectors, each representing a compensation chain.
#' @keywords internal
.findCompensationChains <- function(adj_matrix, max_length = 5L) {
  n <- nrow(adj_matrix)
  if (n == 0) return(list())

  node_names <- rownames(adj_matrix)
  if (is.null(node_names)) node_names <- as.character(seq_len(n))

  chains <- list()

  # DFS from each node
  .dfs <- function(node, path, visited) {
    if (length(path) >= max_length) {
      if (length(path) >= 2) chains[[length(chains) + 1L]] <<- node_names[path]
      return()
    }
    neighbors <- which(adj_matrix[node, ] > 0)
    neighbors <- setdiff(neighbors, visited)
    if (length(neighbors) == 0) {
      if (length(path) >= 2) chains[[length(chains) + 1L]] <<- node_names[path]
      return()
    }
    for (nb in neighbors) {
      .dfs(nb, c(path, nb), c(visited, nb))
    }
  }

  for (start in seq_len(n)) {
    .dfs(start, start, start)
  }

  # Remove duplicates (chains that are reversed versions of each other)
  unique_chains <- list()
  seen <- character(0)
  for (ch in chains) {
    key1 <- paste(ch, collapse = "->")
    key2 <- paste(rev(ch), collapse = "->")
    if (!(key1 %in% seen) && !(key2 %in% seen)) {
      unique_chains[[length(unique_chains) + 1L]] <- ch
      seen <- c(seen, key1)
    }
  }

  unique_chains
}


# ---- Exported functions ----

#' Detect Compensatory Activation Patterns
#'
#' Detects compensatory movement patterns by comparing current EMG activation
#' against a baseline, using MSK network topology to identify muscles that
#' are structurally positioned to compensate for injured muscles.
#'
#' @param emg Current EMG data (matrix, SummarizedExperiment, or numeric vector).
#' @param emg_baseline Baseline/pre-injury EMG data (same format as \code{emg}).
#' @param injured_muscles Character vector of injured muscle names or integer indices.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param sr Optional sampling rate override.
#' @param z_threshold Numeric, z-score threshold for flagging compensation (default: 1.96).
#' @param neighborhood_order Integer, MSK graph distance to search for compensators (default: 2).
#' @return An S3 object of class \code{"MSKCompensation"} with:
#'   \describe{
#'     \item{compensating_muscles}{Data.frame of muscles showing compensatory activation}
#'     \item{injured_status}{Data.frame of injured muscle activation status}
#'     \item{non_compensating}{Data.frame of neighbors that did NOT compensate}
#'     \item{compensation_prevalence}{Proportion of neighbors showing compensation}
#'     \item{network_context}{List with neighborhood info}
#'   }
#'
#' @section Algorithm:
#' 1. Map EMG channels to MSK muscles via emgToMSKMapping
#' 2. Compute RMS activation for both current and baseline
#' 3. Compute z-score of change: z = (current_rms - baseline_rms) / baseline_sd
#' 4. Identify MSK neighbors of injured muscles within \code{neighborhood_order} hops
#' 5. Flag muscles where they are neighbors AND z-score > z_threshold
#' 6. Also detect decreased activation in injured muscles (z < -z_threshold)
#'
#' @export
#' @examples
#' \dontrun{
#' result <- mskDetectCompensation(
#'   emg = emg_current, emg_baseline = emg_pre,
#'   injured_muscles = c("Biceps Brachii"),
#'   z_threshold = 1.96
#' )
#' print(result)
#' }
mskDetectCompensation <- function(emg, emg_baseline, injured_muscles,
                                   hg = NULL, emg_mapping = NULL,
                                   sr = NULL, z_threshold = 1.96,
                                   neighborhood_order = 2L) {
  hg <- .ensureHypergraph(hg)
  stopifnot(is.numeric(z_threshold) && z_threshold > 0)
  neighborhood_order <- as.integer(neighborhood_order)
  stopifnot(neighborhood_order >= 1L)


  # Extract signal matrices
  emg_data <- .extractSignalMatrix(emg, "EMG")
  emg_mat <- emg_data$signal_mat
  sr <- sr %||% emg_data$sr %||% 1000

  baseline_data <- .extractSignalMatrix(emg_baseline, "EMG")
  baseline_mat <- baseline_data$signal_mat

  # Get EMG-to-muscle mapping
  if (is.null(emg_mapping)) {
    emg_mapping <- emgToMSKMapping(colnames(emg_mat), hg = hg, method = "fuzzy")
  }

  if (nrow(emg_mapping) == 0) {
    warning("No EMG channels mapped to MSK muscles")
    return(structure(list(
      compensating_muscles = data.frame(
        muscle = character(0), z_score = numeric(0),
        activation_current = numeric(0), activation_baseline = numeric(0),
        network_distance_to_injury = numeric(0), joint_shared = numeric(0),
        stringsAsFactors = FALSE
      ),
      injured_status = data.frame(
        muscle = character(0), z_score = numeric(0),
        activation_current = numeric(0), activation_baseline = numeric(0),
        status = character(0), stringsAsFactors = FALSE
      ),
      non_compensating = data.frame(muscle = character(0), z_score = numeric(0),
                                     stringsAsFactors = FALSE),
      compensation_prevalence = 0,
      network_context = list()
    ), class = "MSKCompensation"))
  }

  # Compute RMS for current and baseline
  matched_current <- emg_mat[, emg_mapping$channel_idx, drop = FALSE]
  colnames(matched_current) <- emg_mapping$muscle_name
  matched_baseline <- baseline_mat[, emg_mapping$channel_idx, drop = FALSE]
  colnames(matched_baseline) <- emg_mapping$muscle_name

  current_rms <- .computeRMS(matched_current)
  baseline_rms <- .computeRMS(matched_baseline)

  # Compute baseline SD: use column-wise SD if multiple timepoints,
  # else use baseline_rms * 0.15 as estimate
  if (nrow(matched_baseline) > 1) {
    baseline_sd <- vapply(seq_len(ncol(matched_baseline)), function(ch) {
      sd(matched_baseline[, ch])
    }, numeric(1))
    # If SD is still zero (constant signal), use the 0.15 fallback
    zero_sd <- baseline_sd <= 0
    baseline_sd[zero_sd] <- baseline_rms[zero_sd] * 0.15
  } else {
    baseline_sd <- baseline_rms * 0.15
  }

  # Compute z-scores
  z_scores <- .computeActivationZScore(current_rms, baseline_rms, baseline_sd)
  names(z_scores) <- emg_mapping$muscle_name

  # Resolve injured muscles
  injured_idx <- .resolveInjuredMuscles(injured_muscles, hg)
  injured_names <- hg$muscle_names[injured_idx]

  # Find neighbors within neighborhood_order hops
  neighbors <- .identifyMSKNeighbors(injured_idx, hg, order = neighborhood_order)

  # Get shared joint info from muscle adjacency
  B <- as.matrix(projectMuscleGraph(hg))

  # Map between neighbor indices and mapped muscle names
  mapped_muscle_idx <- emg_mapping$muscle_idx
  mapped_muscle_names <- emg_mapping$muscle_name

  # --- Compensating muscles ---
  # Muscles that are neighbors AND have z > z_threshold AND are in our mapping
  comp_rows <- list()
  non_comp_rows <- list()

  for (i in seq_along(neighbors$indices)) {
    nidx <- neighbors$indices[i]
    nname <- hg$muscle_names[nidx]
    ndist <- neighbors$distances[i]

    # Check if this neighbor is in our EMG mapping
    map_match <- which(mapped_muscle_idx == nidx)
    if (length(map_match) == 0) next

    z_val <- z_scores[map_match[1]]
    cur_act <- current_rms[map_match[1]]
    base_act <- baseline_rms[map_match[1]]

    # Shared joints with injured muscles
    shared_joints <- sum(vapply(injured_idx, function(ii) {
      B[nidx, ii]
    }, numeric(1)))

    if (z_val > z_threshold) {
      comp_rows[[length(comp_rows) + 1L]] <- data.frame(
        muscle = nname,
        z_score = round(z_val, 3),
        activation_current = round(cur_act, 4),
        activation_baseline = round(base_act, 4),
        network_distance_to_injury = ndist,
        joint_shared = shared_joints,
        stringsAsFactors = FALSE
      )
    } else {
      non_comp_rows[[length(non_comp_rows) + 1L]] <- data.frame(
        muscle = nname,
        z_score = round(z_val, 3),
        stringsAsFactors = FALSE
      )
    }
  }

  compensating_muscles <- if (length(comp_rows) > 0) {
    do.call(rbind, comp_rows)
  } else {
    data.frame(
      muscle = character(0), z_score = numeric(0),
      activation_current = numeric(0), activation_baseline = numeric(0),
      network_distance_to_injury = numeric(0), joint_shared = numeric(0),
      stringsAsFactors = FALSE
    )
  }

  non_compensating <- if (length(non_comp_rows) > 0) {
    do.call(rbind, non_comp_rows)
  } else {
    data.frame(muscle = character(0), z_score = numeric(0),
               stringsAsFactors = FALSE)
  }

  # --- Injured muscle status ---
  injured_rows <- list()
  for (i in seq_along(injured_idx)) {
    iidx <- injured_idx[i]
    iname <- injured_names[i]

    map_match <- which(mapped_muscle_idx == iidx)
    if (length(map_match) == 0) next

    z_val <- z_scores[map_match[1]]
    cur_act <- current_rms[map_match[1]]
    base_act <- baseline_rms[map_match[1]]

    status <- if (z_val < -z_threshold) {
      "decreased"
    } else if (z_val > z_threshold) {
      "paradoxical_increase"
    } else {
      "unchanged"
    }

    injured_rows[[length(injured_rows) + 1L]] <- data.frame(
      muscle = iname,
      z_score = round(z_val, 3),
      activation_current = round(cur_act, 4),
      activation_baseline = round(base_act, 4),
      status = status,
      stringsAsFactors = FALSE
    )
  }

  injured_status <- if (length(injured_rows) > 0) {
    do.call(rbind, injured_rows)
  } else {
    data.frame(
      muscle = character(0), z_score = numeric(0),
      activation_current = numeric(0), activation_baseline = numeric(0),
      status = character(0), stringsAsFactors = FALSE
    )
  }

  # Compensation prevalence
  n_mapped_neighbors <- nrow(compensating_muscles) + nrow(non_compensating)
  prevalence <- if (n_mapped_neighbors > 0) {
    nrow(compensating_muscles) / n_mapped_neighbors
  } else {
    0
  }

  structure(
    list(
      compensating_muscles = compensating_muscles,
      injured_status = injured_status,
      non_compensating = non_compensating,
      compensation_prevalence = prevalence,
      network_context = list(
        injured_muscles = injured_names,
        injured_indices = injured_idx,
        neighborhood_order = neighborhood_order,
        z_threshold = z_threshold,
        n_neighbors_total = length(neighbors$indices),
        n_neighbors_mapped = n_mapped_neighbors,
        neighbor_distances = neighbors$distances
      )
    ),
    class = "MSKCompensation"
  )
}


#' @export
print.MSKCompensation <- function(x, ...) {
  cat("MSK Compensatory Movement Detection\n")
  cat("====================================\n")
  cat("Injured muscles:", paste(x$network_context$injured_muscles, collapse = ", "), "\n")
  cat("Neighborhood order:", x$network_context$neighborhood_order, "\n")
  cat("Z-score threshold:", x$network_context$z_threshold, "\n\n")

  if (nrow(x$compensating_muscles) > 0) {
    cat("Compensating muscles (", nrow(x$compensating_muscles), "):\n", sep = "")
    for (i in seq_len(min(nrow(x$compensating_muscles), 10))) {
      r <- x$compensating_muscles[i, ]
      cat(sprintf("  %s: z=%.2f, dist=%d, shared_joints=%d\n",
                  r$muscle, r$z_score,
                  as.integer(r$network_distance_to_injury),
                  as.integer(r$joint_shared)))
    }
  } else {
    cat("No compensating muscles detected.\n")
  }

  if (nrow(x$injured_status) > 0) {
    cat("\nInjured muscle status:\n")
    for (i in seq_len(nrow(x$injured_status))) {
      r <- x$injured_status[i, ]
      cat(sprintf("  %s: z=%.2f (%s)\n", r$muscle, r$z_score, r$status))
    }
  }

  cat(sprintf("\nCompensation prevalence: %.1f%%\n", x$compensation_prevalence * 100))
  invisible(x)
}


#' Compensation Risk Score
#'
#' Computes risk scores for compensating muscles based on biomechanical
#' overuse principles, integrating network topology, duration of compensation,
#' and loading intensity.
#'
#' @param compensation_result An \code{"MSKCompensation"} object from
#'   \code{mskDetectCompensation()}.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param duration_weeks Numeric, how long compensation has been occurring.
#' @param load_intensity Character, one of "low", "moderate", "high".
#' @return An S3 object of class \code{"MSKCompensationRisk"} with:
#'   \describe{
#'     \item{per_muscle_risk}{Data.frame of per-muscle risk scores}
#'     \item{overall_risk}{Numeric overall risk score}
#'     \item{overall_category}{Character risk category}
#'     \item{highest_risk_muscle}{Name of highest-risk muscle}
#'     \item{recommendation}{Clinical action recommendation}
#'   }
#'
#' @section Risk Model:
#' Per compensating muscle: risk = z_excess * degree_normalized * duration_factor * load_factor
#' where z_excess = max(0, z_score - z_threshold),
#' degree_normalized = hyperedgeDegree / mean_degree,
#' duration_factor = 1 + log(1 + duration_weeks),
#' load_factor = intensity multiplier (0.5, 1.0, 1.5).
#'
#' @export
#' @examples
#' \dontrun{
#' risk <- mskCompensationRiskScore(compensation_result,
#'   duration_weeks = 4, load_intensity = "moderate")
#' }
mskCompensationRiskScore <- function(compensation_result, hg = NULL,
                                      duration_weeks = 0,
                                      load_intensity = c("low", "moderate", "high")) {
  stopifnot(inherits(compensation_result, "MSKCompensation"))
  stopifnot(is.numeric(duration_weeks) && duration_weeks >= 0)
  load_intensity <- match.arg(load_intensity)

  hg <- .ensureHypergraph(hg)

  # Load factor
  load_factor <- switch(load_intensity,
    low = 0.5,
    moderate = 1.0,
    high = 1.5
  )

  # Duration factor (logarithmic accumulation)
  duration_factor <- 1 + log(1 + duration_weeks)

  # Hyperedge degrees
  deg <- hyperedgeDegree(hg)
  mean_deg <- mean(deg)
  if (mean_deg == 0) mean_deg <- 1

  z_threshold <- compensation_result$network_context$z_threshold

  comp <- compensation_result$compensating_muscles

  if (nrow(comp) == 0) {
    return(structure(
      list(
        per_muscle_risk = data.frame(
          muscle = character(0), risk_score = numeric(0),
          risk_category = character(0), z_excess = numeric(0),
          degree = numeric(0), duration_factor = numeric(0),
          stringsAsFactors = FALSE
        ),
        overall_risk = 0,
        overall_category = "low",
        highest_risk_muscle = NA_character_,
        recommendation = "No compensating muscles detected. Continue monitoring."
      ),
      class = "MSKCompensationRisk"
    ))
  }

  # Compute per-muscle risk
  risk_rows <- list()
  for (i in seq_len(nrow(comp))) {
    muscle_name <- comp$muscle[i]
    z_score <- comp$z_score[i]
    z_excess <- max(0, z_score - z_threshold)

    # Find degree for this muscle
    muscle_match <- which(hg$muscle_names == muscle_name)
    muscle_deg <- if (length(muscle_match) > 0) deg[muscle_match[1]] else mean_deg
    degree_normalized <- muscle_deg / mean_deg

    risk_score <- z_excess * degree_normalized * duration_factor * load_factor

    risk_category <- if (risk_score > 1.0) {
      "high"
    } else if (risk_score > 0.7) {
      "elevated"
    } else if (risk_score > 0.3) {
      "moderate"
    } else {
      "low"
    }

    risk_rows[[length(risk_rows) + 1L]] <- data.frame(
      muscle = muscle_name,
      risk_score = round(risk_score, 3),
      risk_category = risk_category,
      z_excess = round(z_excess, 3),
      degree = muscle_deg,
      duration_factor = round(duration_factor, 3),
      stringsAsFactors = FALSE
    )
  }

  per_muscle_risk <- do.call(rbind, risk_rows)

  # Overall risk: weakest-link model (maximum individual risk)
  overall_risk <- max(per_muscle_risk$risk_score)
  overall_category <- if (overall_risk > 1.0) {
    "high"
  } else if (overall_risk > 0.7) {
    "elevated"
  } else if (overall_risk > 0.3) {
    "moderate"
  } else {
    "low"
  }

  highest_risk_muscle <- per_muscle_risk$muscle[which.max(per_muscle_risk$risk_score)]

  # Clinical recommendation
  recommendation <- switch(overall_category,
    high = paste0("HIGH RISK: Immediate intervention recommended for ",
                  highest_risk_muscle,
                  ". Consider reducing training load and targeted rehabilitation."),
    elevated = paste0("ELEVATED RISK: Close monitoring of ", highest_risk_muscle,
                      ". Consider load modification and preventive strengthening."),
    moderate = paste0("MODERATE RISK: Regular monitoring recommended. ",
                      "Address muscle imbalances with targeted exercises."),
    low = "LOW RISK: Continue current rehabilitation program with routine monitoring."
  )

  structure(
    list(
      per_muscle_risk = per_muscle_risk,
      overall_risk = overall_risk,
      overall_category = overall_category,
      highest_risk_muscle = highest_risk_muscle,
      recommendation = recommendation
    ),
    class = "MSKCompensationRisk"
  )
}


#' @export
print.MSKCompensationRisk <- function(x, ...) {
  cat("MSK Compensation Risk Assessment\n")
  cat("=================================\n")
  cat(sprintf("Overall risk: %.3f (%s)\n", x$overall_risk, toupper(x$overall_category)))

  if (!is.na(x$highest_risk_muscle)) {
    cat("Highest risk muscle:", x$highest_risk_muscle, "\n\n")
    cat("Per-muscle risk:\n")
    for (i in seq_len(min(nrow(x$per_muscle_risk), 10))) {
      r <- x$per_muscle_risk[i, ]
      cat(sprintf("  %s: risk=%.3f (%s), z_excess=%.2f, degree=%d\n",
                  r$muscle, r$risk_score, r$risk_category,
                  r$z_excess, as.integer(r$degree)))
    }
  }

  cat("\nRecommendation:", x$recommendation, "\n")
  invisible(x)
}


#' Track Compensation Pattern Evolution Over Time
#'
#' Tracks changes in compensation patterns across multiple timepoints,
#' identifying onset, resolution, and trends.
#'
#' @param timepoints_emg Named list of EMG matrices. The first element
#'   is treated as baseline.
#' @param injured_muscles Character vector of injured muscle names or integer indices.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param sr Optional sampling rate override.
#' @param z_threshold Numeric, z-score threshold (default: 1.96).
#' @return An S3 object of class \code{"MSKCompensationEvolution"} with:
#'   \describe{
#'     \item{evolution_table}{Data.frame of per-timepoint per-muscle z-scores}
#'     \item{onset_timepoint}{Per-muscle first timepoint of compensation}
#'     \item{resolution_timepoint}{Per-muscle first timepoint of resolution}
#'     \item{trend}{Per-muscle trend classification}
#'     \item{summary}{Data.frame of per-timepoint summary statistics}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' evolution <- mskCompensationEvolution(
#'   timepoints_emg = list(week0 = emg0, week2 = emg2, week4 = emg4),
#'   injured_muscles = c("Biceps Brachii")
#' )
#' }
mskCompensationEvolution <- function(timepoints_emg, injured_muscles,
                                      hg = NULL, emg_mapping = NULL,
                                      sr = NULL, z_threshold = 1.96) {
  stopifnot(is.list(timepoints_emg))
  stopifnot(length(timepoints_emg) >= 1)

  hg <- .ensureHypergraph(hg)

  tp_names <- names(timepoints_emg)
  if (is.null(tp_names)) tp_names <- paste0("T", seq_along(timepoints_emg))

  baseline <- timepoints_emg[[1]]

  # If only 1 timepoint, return minimal result
  if (length(timepoints_emg) == 1) {
    return(structure(
      list(
        evolution_table = data.frame(
          timepoint = character(0), muscle = character(0),
          z_score = numeric(0), is_compensating = logical(0),
          activation = numeric(0), stringsAsFactors = FALSE
        ),
        onset_timepoint = setNames(character(0), character(0)),
        resolution_timepoint = setNames(character(0), character(0)),
        trend = setNames(character(0), character(0)),
        summary = data.frame(
          timepoint = tp_names[1], n_compensating = 0L,
          mean_z = 0, stringsAsFactors = FALSE
        )
      ),
      class = "MSKCompensationEvolution"
    ))
  }

  # Compute compensation for each post-baseline timepoint
  all_results <- list()
  for (t in seq(2, length(timepoints_emg))) {
    res <- mskDetectCompensation(
      emg = timepoints_emg[[t]],
      emg_baseline = baseline,
      injured_muscles = injured_muscles,
      hg = hg,
      emg_mapping = emg_mapping,
      sr = sr,
      z_threshold = z_threshold
    )
    all_results[[t - 1]] <- res
  }

  # Build evolution table
  evo_rows <- list()
  for (t in seq_along(all_results)) {
    res <- all_results[[t]]
    tp_name <- tp_names[t + 1]

    # Compensating muscles
    if (nrow(res$compensating_muscles) > 0) {
      for (i in seq_len(nrow(res$compensating_muscles))) {
        evo_rows[[length(evo_rows) + 1L]] <- data.frame(
          timepoint = tp_name,
          muscle = res$compensating_muscles$muscle[i],
          z_score = res$compensating_muscles$z_score[i],
          is_compensating = TRUE,
          activation = res$compensating_muscles$activation_current[i],
          stringsAsFactors = FALSE
        )
      }
    }

    # Non-compensating neighbors
    if (nrow(res$non_compensating) > 0) {
      for (i in seq_len(nrow(res$non_compensating))) {
        evo_rows[[length(evo_rows) + 1L]] <- data.frame(
          timepoint = tp_name,
          muscle = res$non_compensating$muscle[i],
          z_score = res$non_compensating$z_score[i],
          is_compensating = FALSE,
          activation = NA_real_,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  evolution_table <- if (length(evo_rows) > 0) {
    do.call(rbind, evo_rows)
  } else {
    data.frame(
      timepoint = character(0), muscle = character(0),
      z_score = numeric(0), is_compensating = logical(0),
      activation = numeric(0), stringsAsFactors = FALSE
    )
  }

  # Compute onset and resolution per muscle
  muscles <- unique(evolution_table$muscle)
  onset_tp <- setNames(rep(NA_character_, length(muscles)), muscles)
  resolution_tp <- setNames(rep(NA_character_, length(muscles)), muscles)
  trend <- setNames(rep("absent", length(muscles)), muscles)

  for (m in muscles) {
    m_data <- evolution_table[evolution_table$muscle == m, ]
    m_data <- m_data[match(tp_names[-1], m_data$timepoint), ]

    comp_status <- m_data$is_compensating
    comp_status[is.na(comp_status)] <- FALSE

    # Onset: first TRUE
    first_comp <- which(comp_status)
    if (length(first_comp) > 0) {
      onset_tp[m] <- m_data$timepoint[first_comp[1]]

      # Resolution: first FALSE after onset
      after_onset <- which(!comp_status & seq_along(comp_status) > first_comp[1])
      if (length(after_onset) > 0) {
        resolution_tp[m] <- m_data$timepoint[after_onset[1]]
      }
    }

    # Trend classification
    if (all(!comp_status)) {
      trend[m] <- "absent"
    } else if (!is.na(resolution_tp[m])) {
      trend[m] <- "resolving"
    } else if (length(first_comp) > 0 && first_comp[1] == length(comp_status)) {
      trend[m] <- "emerging"
    } else {
      trend[m] <- "stable"
    }
  }

  # Per-timepoint summary
  summary_rows <- list()
  for (tp_name in tp_names[-1]) {
    tp_data <- evolution_table[evolution_table$timepoint == tp_name, ]
    n_comp <- sum(tp_data$is_compensating, na.rm = TRUE)
    mean_z <- if (nrow(tp_data) > 0) mean(tp_data$z_score, na.rm = TRUE) else 0
    summary_rows[[length(summary_rows) + 1L]] <- data.frame(
      timepoint = tp_name,
      n_compensating = n_comp,
      mean_z = round(mean_z, 3),
      stringsAsFactors = FALSE
    )
  }

  summary_df <- do.call(rbind, summary_rows)

  structure(
    list(
      evolution_table = evolution_table,
      onset_timepoint = onset_tp,
      resolution_timepoint = resolution_tp,
      trend = trend,
      summary = summary_df
    ),
    class = "MSKCompensationEvolution"
  )
}


#' @export
print.MSKCompensationEvolution <- function(x, ...) {
  cat("MSK Compensation Evolution\n")
  cat("==========================\n")

  if (nrow(x$summary) > 0) {
    cat("Timepoint summary:\n")
    for (i in seq_len(nrow(x$summary))) {
      r <- x$summary[i, ]
      cat(sprintf("  %s: %d compensating, mean z = %.2f\n",
                  r$timepoint, r$n_compensating, r$mean_z))
    }
  }

  if (length(x$trend) > 0) {
    cat("\nMuscle trends:\n")
    for (m in names(x$trend)) {
      onset <- x$onset_timepoint[m]
      res <- x$resolution_timepoint[m]
      cat(sprintf("  %s: %s (onset: %s, resolution: %s)\n",
                  m, x$trend[m],
                  if (is.na(onset)) "none" else onset,
                  if (is.na(res)) "ongoing" else res))
    }
  }

  invisible(x)
}


#' Build Compensation Network
#'
#' Constructs a compensation-weighted subgraph from compensation detection
#' results, identifying compensation chains and hub muscles.
#'
#' @param compensation_result An \code{"MSKCompensation"} object.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @return A list with:
#'   \describe{
#'     \item{adjacency}{Weighted compensation adjacency matrix}
#'     \item{chains}{List of compensation chains}
#'     \item{hub_muscles}{Muscles in multiple compensation chains}
#'     \item{community_involvement}{MSK communities affected by compensation}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' net <- mskCompensationNetwork(compensation_result, hg)
#' }
mskCompensationNetwork <- function(compensation_result, hg = NULL,
                                    emg_mapping = NULL) {
  stopifnot(inherits(compensation_result, "MSKCompensation"))
  hg <- .ensureHypergraph(hg)

  comp <- compensation_result$compensating_muscles

  if (nrow(comp) == 0) {
    return(list(
      adjacency = matrix(0, 0, 0),
      chains = list(),
      hub_muscles = character(0),
      community_involvement = integer(0)
    ))
  }

  # Build adjacency: muscle-muscle edges weighted by product of z-scores
  comp_names <- comp$muscle
  n_comp <- length(comp_names)

  # Get muscle adjacency from MSK graph
  B <- as.matrix(projectMuscleGraph(hg))

  adj <- matrix(0, n_comp, n_comp)
  rownames(adj) <- colnames(adj) <- comp_names

  for (i in seq_len(n_comp)) {
    for (j in seq_len(n_comp)) {
      if (i == j) next
      mi <- which(hg$muscle_names == comp_names[i])
      mj <- which(hg$muscle_names == comp_names[j])
      if (length(mi) > 0 && length(mj) > 0 && B[mi[1], mj[1]] > 0) {
        adj[i, j] <- comp$z_score[i] * comp$z_score[j]
      }
    }
  }

  # Find compensation chains
  chains <- .findCompensationChains(adj, max_length = 5L)

  # Hub muscles: appearing in multiple chains
  muscle_chain_count <- table(unlist(chains))
  hub_muscles <- names(muscle_chain_count[muscle_chain_count >= 2])

  # Community involvement
  comm_result <- tryCatch(
    mskCommunityDetect(hg, type = "muscle"),
    error = function(e) NULL
  )

  community_involvement <- if (!is.null(comm_result)) {
    membership <- comm_result$membership
    comp_idx <- vapply(comp_names, function(nm) {
      match(nm, hg$muscle_names)
    }, integer(1))
    comp_idx <- comp_idx[!is.na(comp_idx)]
    if (length(comp_idx) > 0) {
      unique(membership[comp_idx])
    } else {
      integer(0)
    }
  } else {
    integer(0)
  }

  list(
    adjacency = adj,
    chains = chains,
    hub_muscles = hub_muscles,
    community_involvement = community_involvement
  )
}


#' Comprehensive Compensation Analysis Summary
#'
#' Orchestrator that runs all compensation analyses and returns a unified
#' summary. Uses tryCatch for each sub-analysis so partial results are
#' available even if some analyses fail.
#'
#' @param emg Current EMG data (matrix or SummarizedExperiment).
#' @param emg_baseline Baseline/pre-injury EMG data.
#' @param injured_muscles Character vector of injured muscle names or integer indices.
#' @param timepoints_emg Optional named list of EMG matrices for evolution analysis.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param sr Optional sampling rate override.
#' @param z_threshold Numeric, z-score threshold (default: 1.96).
#' @param duration_weeks Numeric, compensation duration for risk scoring.
#' @param load_intensity Character, load intensity for risk scoring.
#' @return An S3 object of class \code{"MSKCompensationSummary"} with
#'   sub-results and available_analyses vector.
#'
#' @export
#' @examples
#' \dontrun{
#' summary <- mskCompensationSummary(
#'   emg = emg_current, emg_baseline = emg_pre,
#'   injured_muscles = c("Biceps Brachii"),
#'   duration_weeks = 4, load_intensity = "moderate"
#' )
#' }
mskCompensationSummary <- function(emg, emg_baseline, injured_muscles,
                                    timepoints_emg = NULL, hg = NULL,
                                    sr = NULL, z_threshold = 1.96,
                                    duration_weeks = 0,
                                    load_intensity = c("low", "moderate", "high")) {
  load_intensity <- match.arg(load_intensity)
  hg <- .ensureHypergraph(hg)

  available <- character(0)

  # 1. Core compensation detection
  compensation <- tryCatch({
    result <- mskDetectCompensation(
      emg = emg, emg_baseline = emg_baseline,
      injured_muscles = injured_muscles,
      hg = hg, sr = sr, z_threshold = z_threshold
    )
    available <- c(available, "compensation")
    result
  }, error = function(e) NULL)

  # 2. Risk scoring
  risk <- NULL
  if (!is.null(compensation)) {
    risk <- tryCatch({
      result <- mskCompensationRiskScore(
        compensation_result = compensation, hg = hg,
        duration_weeks = duration_weeks,
        load_intensity = load_intensity
      )
      available <- c(available, "risk")
      result
    }, error = function(e) NULL)
  }

  # 3. Compensation network
  network <- NULL
  if (!is.null(compensation)) {
    network <- tryCatch({
      result <- mskCompensationNetwork(
        compensation_result = compensation, hg = hg
      )
      available <- c(available, "network")
      result
    }, error = function(e) NULL)
  }

  # 4. Evolution (if timepoints provided)
  evolution <- NULL
  if (!is.null(timepoints_emg)) {
    evolution <- tryCatch({
      result <- mskCompensationEvolution(
        timepoints_emg = timepoints_emg,
        injured_muscles = injured_muscles,
        hg = hg, sr = sr, z_threshold = z_threshold
      )
      available <- c(available, "evolution")
      result
    }, error = function(e) NULL)
  }

  structure(
    list(
      compensation = compensation,
      risk = risk,
      network = network,
      evolution = evolution,
      available_analyses = available
    ),
    class = "MSKCompensationSummary"
  )
}


#' @export
print.MSKCompensationSummary <- function(x, ...) {
  cat("MSK Compensation Analysis Summary\n")
  cat("==================================\n")
  cat("Available analyses:", paste(x$available_analyses, collapse = ", "), "\n\n")

  if (!is.null(x$compensation)) {
    n_comp <- nrow(x$compensation$compensating_muscles)
    cat(sprintf("Compensation: %d muscles compensating (prevalence: %.1f%%)\n",
                n_comp, x$compensation$compensation_prevalence * 100))
  }

  if (!is.null(x$risk)) {
    cat(sprintf("Risk: %.3f (%s) - %s\n",
                x$risk$overall_risk, toupper(x$risk$overall_category),
                if (!is.na(x$risk$highest_risk_muscle))
                  x$risk$highest_risk_muscle else "none"))
  }

  if (!is.null(x$network)) {
    n_chains <- length(x$network$chains)
    n_hubs <- length(x$network$hub_muscles)
    cat(sprintf("Network: %d chains, %d hub muscles\n", n_chains, n_hubs))
  }

  if (!is.null(x$evolution)) {
    n_tp <- nrow(x$evolution$summary)
    cat(sprintf("Evolution: %d timepoints tracked\n", n_tp))
  }

  invisible(x)
}
