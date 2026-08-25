#' Community Detection on MSK Network
#'
#' Detects communities in the projected muscle-muscle graph using the
#' Louvain algorithm with a resolution parameter gamma.
#'
#' @param hg An MSKHypergraph object. If NULL, loads built-in data.
#' @param gamma Resolution parameter for modularity (default: 4.3, as in paper).
#'   Higher values produce more, smaller communities.
#' @param type Projection type: "muscle" (default, as in paper) or "bone".
#' @return A list with:
#'   \describe{
#'     \item{membership}{Named integer vector of community assignments}
#'     \item{n_communities}{Number of communities detected}
#'     \item{modularity}{Modularity value Q}
#'     \item{gamma}{Resolution parameter used}
#'     \item{sizes}{Table of community sizes}
#'   }
#' @references Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.
#' @export
mskCommunityDetect <- function(hg = NULL, gamma = 4.3, type = c("muscle", "bone")) {
  if (is.null(hg)) hg <- MSKHypergraph()
  type <- match.arg(type)

  A <- if (type == "muscle") projectMuscleGraph(hg) else projectBoneGraph(hg)
  A_dense <- as.matrix(A)

  if (requireNamespace("igraph", quietly = TRUE)) {
    g <- igraph::graph_from_adjacency_matrix(A_dense, mode = "undirected",
                                              weighted = TRUE, diag = FALSE)
    # Louvain with resolution parameter
    result <- igraph::cluster_louvain(g, resolution = gamma)
    membership <- igraph::membership(result)
    mod <- igraph::modularity(g, membership, resolution = gamma)
  } else {
    # Pure R Louvain implementation
    result <- .louvain_r(A_dense, gamma = gamma)
    membership <- result$membership
    mod <- result$modularity
  }

  node_names <- if (type == "muscle") hg$muscle_names else hg$bone_names
  names(membership) <- node_names

  list(
    membership = membership,
    n_communities = length(unique(membership)),
    modularity = mod,
    gamma = gamma,
    sizes = table(membership),
    type = type
  )
}

#' Consensus Partition
#'
#' Runs Louvain community detection multiple times and extracts a consensus
#' partition. The paper uses 100 runs and takes the most frequent partition
#' for each node pair.
#'
#' @param hg An MSKHypergraph object.
#' @param gamma Resolution parameter (default: 4.3).
#' @param n_runs Number of runs for consensus (default: 100).
#' @param type Projection type: "muscle" or "bone".
#' @return Same structure as mskCommunityDetect, but with consensus partition.
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
mskConsensusPartition <- function(hg = NULL, gamma = 4.3, n_runs = 100L,
                                   type = c("muscle", "bone")) {
  if (is.null(hg)) hg <- MSKHypergraph()
  type <- match.arg(type)

  A <- if (type == "muscle") projectMuscleGraph(hg) else projectBoneGraph(hg)
  A_dense <- as.matrix(A)
  n <- nrow(A_dense)

  # Run Louvain n_runs times
  all_memberships <- matrix(0L, nrow = n, ncol = n_runs)

  for (r in seq_len(n_runs)) {
    det <- mskCommunityDetect(hg, gamma = gamma, type = type)
    all_memberships[, r] <- det$membership
  }

  # Build co-assignment matrix (agreement matrix)
  agreement <- matrix(0, nrow = n, ncol = n)
  for (r in seq_len(n_runs)) {
    mem <- all_memberships[, r]
    for (i in seq_len(n - 1)) {
      for (j in (i + 1):n) {
        if (mem[i] == mem[j]) {
          agreement[i, j] <- agreement[i, j] + 1
          agreement[j, i] <- agreement[j, i] + 1
        }
      }
    }
  }
  agreement <- agreement / n_runs

  # Threshold at 0.5 and cluster the agreement matrix
  consensus_adj <- agreement
  consensus_adj[consensus_adj < 0.5] <- 0

  if (requireNamespace("igraph", quietly = TRUE)) {
    g <- igraph::graph_from_adjacency_matrix(consensus_adj, mode = "undirected",
                                              weighted = TRUE, diag = FALSE)
    result <- igraph::cluster_louvain(g)
    membership <- igraph::membership(result)
  } else {
    result <- .louvain_r(consensus_adj, gamma = 1.0)
    membership <- result$membership
  }

  node_names <- if (type == "muscle") hg$muscle_names else hg$bone_names
  names(membership) <- node_names
  mod <- mskModularity(A_dense, membership, gamma)

  list(
    membership = membership,
    n_communities = length(unique(membership)),
    modularity = mod,
    gamma = gamma,
    n_runs = n_runs,
    agreement = agreement,
    sizes = table(membership),
    type = type
  )
}

#' Compute Modularity
#'
#' Computes the modularity Q of a partition with resolution parameter.
#' Q = (1/2m) * sum_ij (A_ij - gamma * k_i * k_j / (2m)) * delta(c_i, c_j)
#'
#' @param A Adjacency matrix.
#' @param membership Integer vector of community assignments.
#' @param gamma Resolution parameter (default: 1.0).
#' @return Numeric modularity value.
#' @export
mskModularity <- function(A, membership, gamma = 1.0) {
  A <- as.matrix(A)
  m2 <- sum(A)  # 2m for weighted graph
  if (m2 == 0) return(0)
  k <- rowSums(A)
  n <- nrow(A)
  Q <- 0
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (membership[i] == membership[j]) {
        Q <- Q + (A[i, j] - gamma * k[i] * k[j] / m2)
      }
    }
  }
  Q / m2
}

#' Adjusted Rand Index (z-score)
#'
#' Computes the z-scored Rand index between two partitions.
#' Used to compare community structure with homunculus categories.
#'
#' @param partition1 Integer vector of community assignments.
#' @param partition2 Integer vector of category assignments.
#' @return Numeric z-Rand score. Values > 1.96 indicate significant similarity.
#' @references Traud et al. (2011) Physical Review E.
#' @export
mskZRand <- function(partition1, partition2) {
  stopifnot(length(partition1) == length(partition2))
  n <- length(partition1)

  # Contingency table
  tab <- table(partition1, partition2)
  a <- sum(choose(tab, 2))
  b_row <- sum(choose(rowSums(tab), 2))
  c_col <- sum(choose(colSums(tab), 2))
  d <- choose(n, 2)

  # Expected and variance under null
  expected <- b_row * c_col / d
  var_term1 <- 2 * b_row * c_col / (d * (d - 1))

  # Higher order terms for variance
  sum_ni2 <- sum(rowSums(tab)^2)
  sum_nj2 <- sum(colSums(tab)^2)
  sum_ni3 <- sum(rowSums(tab)^3)
  sum_nj3 <- sum(colSums(tab)^3)

  # Simplified variance formula (Hubert & Arabie)
  t1 <- d
  t2 <- sum_ni2 - n
  t3 <- sum_nj2 - n

  # Use a simplified but accurate formula
  variance <- (2 / (n * (n - 1))) * (
    2 * (n^2 - 3*n + 2) * b_row * c_col / (d * (d - 1)) +
    4 * (sum(rowSums(tab)^3) - sum(rowSums(tab)^2)) *
        (sum(colSums(tab)^3) - sum(colSums(tab)^2)) / (d * (d - 1) * (d - 2)) +
    (sum_ni2 - 2*n*b_row/(n-1) + b_row) * (sum_nj2 - 2*n*c_col/(n-1) + c_col) /
        (d * (d - 1) * (d - 2) * (d - 3)) * (n * (n - 1))
  )

  # Simpler, robust formula
  # z = (a - expected) / sqrt(variance)
  if (variance <= 0) return(0)
  (a - expected) / sqrt(abs(variance))
}

# Internal pure-R Louvain
.louvain_r <- function(A, gamma = 1.0, max_iter = 100L) {
  n <- nrow(A)
  membership <- seq_len(n)
  k <- rowSums(A)
  m2 <- sum(A)
  if (m2 == 0) return(list(membership = membership, modularity = 0))

  improved <- TRUE
  iter <- 0

  while (improved && iter < max_iter) {
    improved <- FALSE
    iter <- iter + 1

    # Random order
    order <- sample(n)
    for (i in order) {
      current_comm <- membership[i]
      neighbor_comms <- unique(membership[which(A[i, ] > 0)])
      candidate_comms <- unique(c(current_comm, neighbor_comms))

      best_comm <- current_comm
      best_delta <- 0

      for (cc in candidate_comms) {
        if (cc == current_comm) next
        # Compute delta Q for moving node i from current_comm to cc
        ki <- k[i]
        # Sum of weights from i to nodes in cc
        in_cc <- which(membership == cc)
        ki_in <- sum(A[i, in_cc])
        sum_tot <- sum(k[in_cc])

        # Sum of weights from i to nodes in current_comm (excluding i)
        in_cur <- which(membership == current_comm & seq_len(n) != i)
        ki_cur <- sum(A[i, in_cur])
        sum_cur <- sum(k[in_cur])

        delta <- (ki_in - gamma * ki * sum_tot / m2) -
                 (ki_cur - gamma * ki * sum_cur / m2)

        if (delta > best_delta) {
          best_delta <- delta
          best_comm <- cc
        }
      }

      if (best_comm != current_comm) {
        membership[i] <- best_comm
        improved <- TRUE
      }
    }
  }

  # Renumber communities
  ucomm <- sort(unique(membership))
  new_mem <- match(membership, ucomm)

  mod <- 0
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (new_mem[i] == new_mem[j]) {
        mod <- mod + (A[i, j] - gamma * k[i] * k[j] / m2)
      }
    }
  }
  mod <- mod / m2

  list(membership = new_mem, modularity = mod)
}
