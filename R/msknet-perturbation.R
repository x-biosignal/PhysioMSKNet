#' Compute Impact Score for One Muscle
#'
#' Perturbs a single muscle and simulates the network dynamics to compute
#' the total displacement of all bones (impact score). The perturbation
#' is applied in the 4th spatial dimension to avoid directional artifacts.
#'
#' @param sim An MSKSimulation object.
#' @param muscle_index Integer index of the muscle to perturb.
#' @return Numeric impact score (total displacement summed over all bones).
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
mskImpactScore <- function(sim, muscle_index) {
  stopifnot(inherits(sim, "MSKSimulation"))
  hg <- sim$hg
  C <- as.matrix(hg$C)
  n_bones <- hg$n_bones
  n_muscles <- hg$n_muscles
  k <- sim$spring_constants
  dt <- sim$params$dt
  n_steps <- sim$params$n_steps
  beta <- sim$params$beta
  pert_mag <- sim$params$perturbation_magnitude

  stopifnot(muscle_index >= 1 && muscle_index <= n_muscles)

  # State: position and velocity in 4D for each bone
  # Only simulate the 4th dimension (perturbation dimension)
  # since equilibrium in 3D is at origin
  pos <- rep(0.0, n_bones)  # 4th dimension position

  vel <- rep(0.0, n_bones)  # 4th dimension velocity

  # Apply perturbation: displace all bones connected to the target muscle
  connected_bones <- which(C[, muscle_index] == 1)
  pos[connected_bones] <- pert_mag

  # Pre-compute for each muscle: which bone pairs are connected
  # For a muscle connecting bones {b1, b2, ..., bk}, all pairs interact
  muscle_bone_lists <- lapply(seq_len(n_muscles), function(m) {
    which(C[, m] == 1)
  })

  # Velocity Verlet integration with damping
  # Paper model: each muscle m connecting d_m bones has (d_m choose 2)
  # pairwise springs, each with k_m = 1/(d_m - 1)
  total_displacement <- rep(0.0, n_bones)

  # Compute initial force
  .compute_force <- function(pos, vel) {
    force <- rep(0.0, n_bones)
    for (m in seq_len(n_muscles)) {
      bones_in_muscle <- muscle_bone_lists[[m]]
      nb <- length(bones_in_muscle)
      if (nb < 2) next
      km <- k[m]
      # Pairwise spring forces: F_i = -k_m * sum_{j!=i} (x_i - x_j)
      for (ii in seq_len(nb - 1)) {
        for (jj in (ii + 1):nb) {
          bi <- bones_in_muscle[ii]
          bj <- bones_in_muscle[jj]
          dx <- pos[bi] - pos[bj]
          force[bi] <- force[bi] - km * dx
          force[bj] <- force[bj] + km * dx
        }
      }
    }
    # Damping
    force - beta * vel
  }

  acc <- .compute_force(pos, vel)

  for (step in seq_len(n_steps)) {
    # Velocity Verlet step
    pos <- pos + vel * dt + 0.5 * acc * dt^2
    new_acc <- .compute_force(pos, vel + acc * dt)
    vel <- vel + 0.5 * (acc + new_acc) * dt
    acc <- new_acc

    # Accumulate total displacement (absolute)
    total_displacement <- total_displacement + abs(pos)
  }

  sum(total_displacement)
}

#' Compute Impact Scores for All Muscles
#'
#' Runs perturbation analysis for all 270 muscles and returns impact scores.
#' This is the main computational function for reproducing Fig. 3a of the paper.
#'
#' @param sim An MSKSimulation object. If NULL, creates one with default parameters.
#' @param verbose Logical, print progress (default: TRUE).
#' @return A named numeric vector of impact scores for each muscle.
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
mskImpactScoreAll <- function(sim = NULL, verbose = TRUE) {
  if (is.null(sim)) sim <- mskSimulate()
  n <- sim$hg$n_muscles
  scores <- numeric(n)

  if (verbose) message("Computing impact scores for ", n, " muscles...")

  for (i in seq_len(n)) {
    scores[i] <- mskImpactScore(sim, i)
    if (verbose && i %% 50 == 0) {
      message(sprintf("  %d/%d (%.0f%%)", i, n, 100 * i / n))
    }
  }

  names(scores) <- sim$hg$muscle_names
  if (verbose) message("Done.")
  scores
}

#' Compute Impact Deviation
#'
#' Computes the impact deviation for each muscle, which is the difference
#' between the observed impact score and the expected impact score for a
#' muscle of that degree, expressed in standard deviations.
#'
#' The expected impact score is estimated from null model simulations or
#' from a regression of impact score vs. degree.
#'
#' @param impact_scores Named numeric vector of impact scores (from mskImpactScoreAll).
#' @param hg An MSKHypergraph object.
#' @param null_scores Optional matrix of null model impact scores (muscles x null_runs).
#'   If NULL, deviation is computed relative to a degree-based regression.
#' @return A named numeric vector of impact deviations.
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
mskImpactDeviation <- function(impact_scores, hg, null_scores = NULL) {
  deg <- hyperedgeDegree(hg)

  if (!is.null(null_scores)) {
    # Compare to null model distribution
    dev <- numeric(length(impact_scores))
    for (i in seq_along(impact_scores)) {
      null_i <- null_scores[i, ]
      null_i <- null_i[!is.na(null_i)]
      if (length(null_i) < 2) {
        dev[i] <- NA_real_
        next
      }
      mu <- mean(null_i)
      sigma <- stats::sd(null_i)
      dev[i] <- if (sigma > 0) (impact_scores[i] - mu) / sigma else 0
    }
    names(dev) <- names(impact_scores)
    return(dev)
  }

  # Fallback: deviation from degree-based regression
  # Group muscles by degree
  unique_deg <- sort(unique(deg))
  expected <- numeric(length(impact_scores))
  sigma <- numeric(length(impact_scores))

  for (d in unique_deg) {
    idx <- which(deg == d)
    if (length(idx) < 2) {
      expected[idx] <- impact_scores[idx]
      sigma[idx] <- 1
    } else {
      mu <- mean(impact_scores[idx])
      sd_d <- stats::sd(impact_scores[idx])
      expected[idx] <- mu
      sigma[idx] <- if (sd_d > 0) sd_d else 1
    }
  }

  dev <- (impact_scores - expected) / sigma
  names(dev) <- names(impact_scores)
  dev
}
