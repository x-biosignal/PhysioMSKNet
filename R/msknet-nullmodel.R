#' Generate Null Hypergraph
#'
#' Creates a randomized version of the musculoskeletal hypergraph by
#' rewiring muscle-bone connections while preserving each muscle's degree
#' (number of bones it connects to). This is done by randomly reassigning
#' which bones each muscle attaches to, within anatomical categories if
#' specified.
#'
#' @param hg An MSKHypergraph object. If NULL, loads built-in data.
#' @param preserve_category Logical, whether to preserve anatomical
#'   category during rewiring (default: FALSE for the basic model).
#' @return An MSKHypergraph object with rewired connections.
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
mskNullHypergraph <- function(hg = NULL, preserve_category = FALSE) {
  if (is.null(hg)) hg <- MSKHypergraph()

  C <- as.matrix(hg$C)
  n_bones <- nrow(C)
  n_muscles <- ncol(C)

  # Get degree of each muscle (to preserve)
  muscle_deg <- colSums(C)

  # Create null incidence matrix
  C_null <- matrix(0L, nrow = n_bones, ncol = n_muscles)
  rownames(C_null) <- rownames(C)
  colnames(C_null) <- colnames(C)

  for (m in seq_len(n_muscles)) {
    deg_m <- muscle_deg[m]
    # Randomly sample deg_m bones
    selected <- sample(n_bones, size = min(deg_m, n_bones), replace = FALSE)
    C_null[selected, m] <- 1L
  }

  MSKHypergraph(C = C_null, muscle_meta = hg$muscle_meta)
}

#' Generate Null Hypergraph Ensemble
#'
#' Creates multiple null hypergraphs and computes impact scores for each.
#' This is used to compute impact deviations relative to the null distribution.
#'
#' @param hg An MSKHypergraph object.
#' @param n_null Number of null models to generate (default: 100).
#' @param sim_params List of simulation parameters (dt, n_steps, beta).
#' @param verbose Logical, print progress.
#' @return A list with:
#'   \describe{
#'     \item{null_scores}{Matrix of impact scores (n_muscles x n_null)}
#'     \item{null_degree_scores}{List, impact scores grouped by degree for each null}
#'     \item{n_null}{Number of null models}
#'   }
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
mskNullEnsemble <- function(hg = NULL, n_null = 100L, sim_params = list(),
                             verbose = TRUE) {
  if (is.null(hg)) hg <- MSKHypergraph()

  dt <- sim_params$dt %||% 0.01
  n_steps <- sim_params$n_steps %||% 500L
  beta <- sim_params$beta %||% 1.0

  n_muscles <- hg$n_muscles
  null_scores <- matrix(NA_real_, nrow = n_muscles, ncol = n_null)
  rownames(null_scores) <- hg$muscle_names

  deg <- hyperedgeDegree(hg)

  for (r in seq_len(n_null)) {
    if (verbose) message(sprintf("Null model %d/%d", r, n_null))

    null_hg <- mskNullHypergraph(hg)
    null_sim <- mskSimulate(null_hg, dt = dt, n_steps = n_steps, beta = beta)

    for (m in seq_len(n_muscles)) {
      null_scores[m, r] <- mskImpactScore(null_sim, m)
    }
  }

  # Group by degree
  null_degree_scores <- list()
  for (d in sort(unique(deg))) {
    idx <- which(deg == d)
    null_degree_scores[[as.character(d)]] <- null_scores[idx, , drop = FALSE]
  }

  list(
    null_scores = null_scores,
    null_degree_scores = null_degree_scores,
    n_null = n_null
  )
}

# Uses %||% from msknet-hypergraph.R
