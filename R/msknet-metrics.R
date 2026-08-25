#' MSK Network Metrics
#'
#' Computes standard graph metrics for the projected bone or muscle graph.
#'
#' @param hg An MSKHypergraph object.
#' @param type Character, "bone" or "muscle" projection.
#' @return A list with: degree, strength, clustering_coef, density
#' @export
mskNetworkMetrics <- function(hg, type = c("bone", "muscle")) {
  type <- match.arg(type)
  A <- if (type == "bone") projectBoneGraph(hg) else projectMuscleGraph(hg)
  A_bin <- A
  A_bin[A_bin > 0] <- 1
  n <- nrow(A)

  degree <- Matrix::rowSums(A_bin)
  strength <- Matrix::rowSums(A)
  density <- sum(A_bin) / (n * (n - 1))

  # Local clustering coefficient
  cc <- numeric(n)
  for (i in seq_len(n)) {
    neighbors <- which(A_bin[i, ] > 0)
    k <- length(neighbors)
    if (k < 2) { cc[i] <- 0; next }
    submat <- A_bin[neighbors, neighbors]
    cc[i] <- sum(submat) / (k * (k - 1))
  }
  names(cc) <- rownames(A)

  list(
    degree = degree,
    strength = strength,
    clustering_coef = cc,
    density = density,
    n_nodes = n,
    n_edges = sum(A_bin) / 2
  )
}

#' Betweenness Centrality via BFS
#'
#' Computes betweenness centrality for the projected graph.
#' Uses igraph if available, otherwise a pure-R BFS implementation.
#'
#' @param hg An MSKHypergraph object.
#' @param type Character, "bone" or "muscle" projection.
#' @return Named numeric vector of betweenness centrality values.
#' @export
mskBetweenness <- function(hg, type = c("bone", "muscle")) {
  type <- match.arg(type)
  A <- if (type == "bone") projectBoneGraph(hg) else projectMuscleGraph(hg)
  A_bin <- as.matrix(A)
  A_bin[A_bin > 0] <- 1

  if (requireNamespace("igraph", quietly = TRUE)) {
    g <- igraph::graph_from_adjacency_matrix(A_bin, mode = "undirected", diag = FALSE)
    bc <- igraph::betweenness(g, normalized = FALSE)
    names(bc) <- rownames(A)
    return(bc)
  }

  # Pure R fallback: Brandes algorithm
  n <- nrow(A_bin)
  bc <- numeric(n)
  for (s in seq_len(n)) {
    S <- integer(0)
    P <- vector("list", n)
    sigma <- rep(0, n); sigma[s] <- 1
    d <- rep(-1L, n); d[s] <- 0L
    Q <- s
    while (length(Q) > 0) {
      v <- Q[1]; Q <- Q[-1]; S <- c(S, v)
      neighbors <- which(A_bin[v, ] > 0)
      for (w in neighbors) {
        if (d[w] < 0) { Q <- c(Q, w); d[w] <- d[v] + 1L }
        if (d[w] == d[v] + 1L) { sigma[w] <- sigma[w] + sigma[v]; P[[w]] <- c(P[[w]], v) }
      }
    }
    delta <- rep(0, n)
    for (w in rev(S)) {
      for (v in P[[w]]) {
        delta[v] <- delta[v] + (sigma[v] / sigma[w]) * (1 + delta[w])
      }
      if (w != s) bc[w] <- bc[w] + delta[w]
    }
  }
  bc <- bc / 2
  names(bc) <- rownames(A)
  bc
}

#' Closeness Centrality
#'
#' @param hg An MSKHypergraph object.
#' @param type Character, "bone" or "muscle" projection.
#' @return Named numeric vector of closeness centrality values.
#' @export
mskCloseness <- function(hg, type = c("bone", "muscle")) {
  type <- match.arg(type)
  A <- if (type == "bone") projectBoneGraph(hg) else projectMuscleGraph(hg)
  A_bin <- as.matrix(A)
  A_bin[A_bin > 0] <- 1

  if (requireNamespace("igraph", quietly = TRUE)) {
    g <- igraph::graph_from_adjacency_matrix(A_bin, mode = "undirected", diag = FALSE)
    cl <- igraph::closeness(g, normalized = FALSE)
    names(cl) <- rownames(A)
    return(cl)
  }

  # BFS-based
  n <- nrow(A_bin)
  cl <- numeric(n)
  for (s in seq_len(n)) {
    d <- .bfs_distances(A_bin, s)
    reachable <- d[d < Inf & d > 0]
    cl[s] <- if (length(reachable) > 0) 1 / sum(reachable) else 0
  }
  names(cl) <- rownames(A)
  cl
}

#' Shortest Path Distances
#'
#' Computes shortest path distance matrix for the projected graph.
#'
#' @param hg An MSKHypergraph object.
#' @param type Character, "bone" or "muscle" projection.
#' @return A numeric matrix of shortest path distances.
#' @export
mskShortestPaths <- function(hg, type = c("bone", "muscle")) {
  type <- match.arg(type)
  A <- if (type == "bone") projectBoneGraph(hg) else projectMuscleGraph(hg)
  A_bin <- as.matrix(A)
  A_bin[A_bin > 0] <- 1

  if (requireNamespace("igraph", quietly = TRUE)) {
    g <- igraph::graph_from_adjacency_matrix(A_bin, mode = "undirected", diag = FALSE)
    d <- igraph::distances(g)
    rownames(d) <- colnames(d) <- rownames(A)
    return(d)
  }

  n <- nrow(A_bin)
  D <- matrix(Inf, n, n)
  diag(D) <- 0
  for (s in seq_len(n)) {
    D[s, ] <- .bfs_distances(A_bin, s)
  }
  rownames(D) <- colnames(D) <- rownames(A)
  D
}

# Internal BFS
.bfs_distances <- function(adj, source) {
  n <- nrow(adj)
  d <- rep(Inf, n)
  d[source] <- 0
  Q <- source
  while (length(Q) > 0) {
    v <- Q[1]; Q <- Q[-1]
    neighbors <- which(adj[v, ] > 0)
    for (w in neighbors) {
      if (d[w] == Inf) { d[w] <- d[v] + 1; Q <- c(Q, w) }
    }
  }
  d
}
