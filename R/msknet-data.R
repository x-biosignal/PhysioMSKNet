#' Load MSK Network Data
#'
#' Loads the complete musculoskeletal network dataset from Murphy et al. (2018).
#' Returns a list containing the incidence matrix, muscle metadata, and
#' validation data for reproducing the paper's results.
#'
#' @return A list with components:
#'   \describe{
#'     \item{incidence}{Sparse incidence matrix C (bones x muscles)}
#'     \item{muscle_meta}{Data frame with muscle names, community assignments, homunculus categories}
#'     \item{bone_names}{Character vector of bone/vertex names}
#'     \item{muscle_names}{Character vector of muscle/hyperedge names}
#'   }
#' @references Murphy AC et al. (2018) "Structure, function, and control of
#'   the human musculoskeletal network." PLOS Biology 16(1): e2002811.
#' @export
loadMSKData <- function() {
  C <- loadIncidenceMatrix()
  meta <- loadMuscleMetadata()
  list(
    incidence = C,
    muscle_meta = meta,
    bone_names = rownames(C),
    muscle_names = colnames(C)
  )
}

#' Load Incidence Matrix
#'
#' Loads the bipartite incidence matrix C where rows are bones (vertices)
#' and columns are muscles (hyperedges). Entry C\[i,j\] = 1 indicates that
#' muscle j attaches to bone i.
#'
#' @return A sparse Matrix (dgCMatrix) of dimensions 173 x 270
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
loadIncidenceMatrix <- function() {
  if (exists("incidence", envir = .msknet_cache)) {
    return(get("incidence", envir = .msknet_cache))
  }
  f <- system.file("extdata", "incidence_matrix.csv", package = "PhysioMSKNet")
  if (f == "") stop("Incidence matrix not found. Is PhysioMSKNet installed?", call. = FALSE)
  raw <- utils::read.csv(f, row.names = 1, check.names = FALSE)
  C <- Matrix::Matrix(as.matrix(raw), sparse = TRUE)
  assign("incidence", C, envir = .msknet_cache)
  C
}

#' Load Muscle Metadata
#'
#' Loads metadata for all 270 muscles including community assignments
#' and homunculus category labels from the paper.
#'
#' @return A data.frame with columns: index, muscle, community, homunculus_category
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
loadMuscleMetadata <- function() {
  if (exists("muscle_meta", envir = .msknet_cache)) {
    return(get("muscle_meta", envir = .msknet_cache))
  }
  f <- system.file("extdata", "muscle_metadata.csv", package = "PhysioMSKNet")
  if (f == "") stop("Muscle metadata not found.", call. = FALSE)
  meta <- utils::read.csv(f, stringsAsFactors = FALSE)
  assign("muscle_meta", meta, envir = .msknet_cache)
  meta
}

#' Load Validation Data
#'
#' Loads validation datasets used to reproduce key figures from the paper.
#'
#' @param dataset Character string specifying which dataset to load:
#'   \describe{
#'     \item{"degree_distribution"}{Degree probability for real vs null hypergraphs (fig2e)}
#'     \item{"impact_vs_recovery"}{Recovery time vs impact deviation (fig3b)}
#'     \item{"homunculus_deviation"}{Homunculus area vs deviation ratio (fig4b)}
#'     \item{"fmri_activation"}{Impact deviation vs fMRI activation volume (fig4c)}
#'     \item{"homunculus_coordinates"}{Homunculus area vs muscle MDS coordinate (fig4d)}
#'     \item{"impact_vs_path"}{Average shortest path vs impact score (figS11)}
#'   }
#' @return A data.frame with the requested validation data
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
loadValidationData <- function(dataset = c("degree_distribution", "impact_vs_recovery",
                                            "homunculus_deviation", "fmri_activation",
                                            "homunculus_coordinates", "impact_vs_path",
                                            "impact_scores")) {
  dataset <- match.arg(dataset)
  dir <- system.file("extdata", package = "PhysioMSKNet")
  switch(dataset,
    degree_distribution = utils::read.csv(file.path(dir, "fig2e.csv")),
    impact_vs_recovery = utils::read.csv(file.path(dir, "fig3b.csv")),
    homunculus_deviation = utils::read.csv(file.path(dir, "fig4b.csv")),
    fmri_activation = utils::read.csv(file.path(dir, "fig4c.csv")),
    homunculus_coordinates = utils::read.csv(file.path(dir, "fig4d.csv")),
    impact_vs_path = utils::read.csv(file.path(dir, "figS11.csv")),
    impact_scores = .loadPaperImpactScores(dir)
  )
}

#' Load Paper Impact Scores from fig3a.xls
#'
#' @param dir Path to extdata directory.
#' @return A list with:
#'   \describe{
#'     \item{real}{data.frame with columns: muscle_index, degree, impact_score}
#'     \item{null}{data.frame with columns: degree, impact_score, null_run}
#'   }
#' @keywords internal
.loadPaperImpactScores <- function(dir) {
  xlsfile <- file.path(dir, "fig3a.xls")
  if (!file.exists(xlsfile)) {
    stop("fig3a.xls not found in extdata/", call. = FALSE)
  }
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' required to load impact scores.", call. = FALSE)
  }
  real_raw <- readxl::read_excel(xlsfile, sheet = "real_hypergraph")
  null_raw <- readxl::read_excel(xlsfile, sheet = "null_hypergraph")

  # Real scores: columns are hyperedge_degree1..30
  real_scores <- list()
  real_degrees <- list()
  idx <- 0L
  for (d in seq_len(30)) {
    col <- paste0("hyperedge_degree", d)
    vals <- real_raw[[col]]
    vals <- vals[!is.na(vals)]
    if (length(vals) > 0) {
      real_scores <- c(real_scores, list(vals))
      real_degrees <- c(real_degrees, list(rep(d, length(vals))))
      idx <- idx + length(vals)
    }
  }
  real_df <- data.frame(
    muscle_index = seq_len(idx),
    degree = unlist(real_degrees),
    impact_score = unlist(real_scores),
    stringsAsFactors = FALSE
  )

  # Null scores: same structure, many more rows
  null_scores <- list()
  null_degrees <- list()
  for (d in seq_len(30)) {
    col <- paste0("hyperedge_degree", d)
    vals <- null_raw[[col]]
    vals <- vals[!is.na(vals)]
    if (length(vals) > 0) {
      null_scores <- c(null_scores, list(vals))
      null_degrees <- c(null_degrees, list(rep(d, length(vals))))
    }
  }
  null_df <- data.frame(
    degree = unlist(null_degrees),
    impact_score = unlist(null_scores),
    stringsAsFactors = FALSE
  )

  list(real = real_df, null = null_df)
}
