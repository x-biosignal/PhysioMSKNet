#' Create MSK Hypergraph Object
#'
#' Constructs a musculoskeletal hypergraph from an incidence matrix.
#' In this hypergraph, bones are vertices and muscles are hyperedges.
#' A muscle (hyperedge) connects all bones it attaches to.
#'
#' @param C A matrix or sparse Matrix (bones x muscles) where C\[i,j\]=1
#'   means muscle j attaches to bone i. If NULL, loads the built-in data.
#' @param muscle_meta Optional data.frame with muscle metadata.
#' @return An S3 object of class "MSKHypergraph" containing:
#'   \describe{
#'     \item{C}{Sparse incidence matrix (bones x muscles)}
#'     \item{n_bones}{Number of bones (vertices)}
#'     \item{n_muscles}{Number of muscles (hyperedges)}
#'     \item{bone_names}{Character vector of bone names}
#'     \item{muscle_names}{Character vector of muscle names}
#'     \item{muscle_meta}{Muscle metadata if provided}
#'   }
#' @references Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.
#' @export
MSKHypergraph <- function(C = NULL, muscle_meta = NULL) {
  if (is.null(C)) {
    data <- loadMSKData()
    C <- data$incidence
    if (is.null(muscle_meta)) muscle_meta <- data$muscle_meta
  }
  if (!inherits(C, "Matrix")) {
    C <- Matrix::Matrix(as.matrix(C), sparse = TRUE)
  }
  stopifnot(all(C@x %in% c(0, 1)))

  structure(
    list(
      C = C,
      n_bones = nrow(C),
      n_muscles = ncol(C),
      bone_names = rownames(C) %||% paste0("bone_", seq_len(nrow(C))),
      muscle_names = colnames(C) %||% paste0("muscle_", seq_len(ncol(C))),
      muscle_meta = muscle_meta
    ),
    class = "MSKHypergraph"
  )
}

#' @export
print.MSKHypergraph <- function(x, ...) {
  cat("MSKHypergraph\n")
  cat("  Bones (vertices):", x$n_bones, "\n")
  cat("  Muscles (hyperedges):", x$n_muscles, "\n")
  cat("  Connections:", sum(x$C), "\n")
  cat("  Sparsity:", round(1 - sum(x$C) / (x$n_bones * x$n_muscles), 4), "\n")
  cat("  Muscle degree range:", paste(range(Matrix::colSums(x$C)), collapse = "-"), "\n")
  cat("  Bone degree range:", paste(range(Matrix::rowSums(x$C)), collapse = "-"), "\n")
  invisible(x)
}

#' Project to Bone-centric Graph
#'
#' Creates the bone-bone weighted adjacency matrix A = t(C) %*% C where
#' A\[i,j\] counts the number of muscles shared between bones i and j.
#' This is the one-mode projection onto the bone (vertex) space.
#'
#' @param hg An MSKHypergraph object, or a sparse incidence matrix.
#' @return A symmetric sparse Matrix (n_bones x n_bones)
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
projectBoneGraph <- function(hg) {
  C <- if (inherits(hg, "MSKHypergraph")) hg$C else Matrix::Matrix(as.matrix(hg), sparse = TRUE)
  A <- Matrix::tcrossprod(C)
  # Zero diagonal (self-loops not meaningful)
  diag(A) <- 0
  A
}

#' Project to Muscle-centric Graph
#'
#' Creates the muscle-muscle weighted adjacency matrix B = C %*% t(C) where
#' B\[i,j\] counts the number of bones shared between muscles i and j.
#' This is the one-mode projection onto the muscle (hyperedge) space.
#'
#' @param hg An MSKHypergraph object, or a sparse incidence matrix.
#' @return A symmetric sparse Matrix (n_muscles x n_muscles)
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
projectMuscleGraph <- function(hg) {
  C <- if (inherits(hg, "MSKHypergraph")) hg$C else Matrix::Matrix(as.matrix(hg), sparse = TRUE)
  B <- Matrix::crossprod(C)
  diag(B) <- 0
  B
}

#' Hyperedge (Muscle) Degree
#'
#' Returns the degree of each hyperedge (muscle), i.e., the number of
#' bones each muscle attaches to.
#'
#' @param hg An MSKHypergraph object or incidence matrix.
#' @return Named numeric vector of muscle degrees.
#' @export
hyperedgeDegree <- function(hg) {
  C <- if (inherits(hg, "MSKHypergraph")) hg$C else Matrix::Matrix(as.matrix(hg), sparse = TRUE)
  deg <- Matrix::colSums(C)
  names(deg) <- colnames(C)
  deg
}

#' Vertex (Bone) Degree
#'
#' Returns the degree of each vertex (bone), i.e., the number of
#' muscles attached to each bone.
#'
#' @param hg An MSKHypergraph object or incidence matrix.
#' @return Named numeric vector of bone degrees.
#' @export
vertexDegree <- function(hg) {
  C <- if (inherits(hg, "MSKHypergraph")) hg$C else Matrix::Matrix(as.matrix(hg), sparse = TRUE)
  deg <- Matrix::rowSums(C)
  names(deg) <- rownames(C)
  deg
}

#' Degree Distribution
#'
#' Computes the degree distribution for bones or muscles.
#'
#' @param hg An MSKHypergraph object.
#' @param type Character, either "muscle" (hyperedge degree) or "bone" (vertex degree).
#' @return A data.frame with columns: degree, count, probability
#' @export
degreeDistribution <- function(hg, type = c("muscle", "bone")) {
  type <- match.arg(type)
  deg <- if (type == "muscle") hyperedgeDegree(hg) else vertexDegree(hg)
  tab <- table(deg)
  data.frame(
    degree = as.integer(names(tab)),
    count = as.integer(tab),
    probability = as.numeric(tab) / sum(tab),
    stringsAsFactors = FALSE
  )
}

# Null coalesce operator
`%||%` <- function(a, b) if (!is.null(a)) a else b
