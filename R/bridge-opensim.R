# ===========================================================================
# bridge-opensim.R -- Build MSKHypergraph from OpenSim models
# ===========================================================================

# ---- Internal helpers ----

#' Parse muscle-bone attachments from .osim XML
#'
#' Extracts PathPoint body references per muscle from an OpenSim .osim file.
#'
#' @param model_path Character, path to .osim file.
#' @return A data.frame with columns: muscle_name, body_name (deduplicated pairs).
#' @keywords internal
.parseOsimAttachments <- function(model_path) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop("Package 'xml2' is required to parse .osim files. ",
         "Install with: install.packages('xml2')")
  }

  doc <- xml2::read_xml(model_path)

  # Find all muscle elements (Thelen2003Muscle, Millard2012EquilibriumMuscle, etc.)
  # They are under ForceSet/objects
  muscles <- xml2::xml_find_all(doc, ".//ForceSet//objects//*[GeometryPath]")

  if (length(muscles) == 0) {
    # Try alternative path structures
    muscles <- xml2::xml_find_all(doc, ".//ForceSet//*[.//PathPoint]")
  }

  if (length(muscles) == 0) {
    warning("No muscles with PathPoints found in .osim file")
    return(data.frame(muscle_name = character(0), body_name = character(0),
                      stringsAsFactors = FALSE))
  }

  rows <- list()
  for (m in muscles) {
    muscle_name <- xml2::xml_attr(m, "name")
    if (is.na(muscle_name)) next

    # Find all PathPoint elements under this muscle
    path_points <- xml2::xml_find_all(m, ".//PathPoint")
    if (length(path_points) == 0) {
      path_points <- xml2::xml_find_all(m, ".//ConditionalPathPoint")
    }

    bodies <- character(0)
    for (pp in path_points) {
      # socket_parent_frame or body attribute
      body <- xml2::xml_text(xml2::xml_find_first(pp, ".//socket_parent_frame"))
      if (is.na(body) || body == "") {
        body <- xml2::xml_text(xml2::xml_find_first(pp, ".//body"))
      }
      if (!is.na(body) && body != "") {
        # Strip path prefix (e.g., "/bodyset/" or "../")
        body <- gsub("^.*[/]", "", body)
        bodies <- c(bodies, body)
      }
    }

    # Deduplicate per muscle
    bodies <- unique(bodies)
    for (b in bodies) {
      rows[[length(rows) + 1L]] <- data.frame(
        muscle_name = muscle_name,
        body_name = b,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(rows) == 0) {
    return(data.frame(muscle_name = character(0), body_name = character(0),
                      stringsAsFactors = FALSE))
  }

  do.call(rbind, rows)
}


#' Read OpenSim .sto file
#'
#' Parses an OpenSim storage (.sto) file with header and tab/space-delimited
#' data.
#'
#' @param path Character, path to .sto file.
#' @return A data.frame with all columns from the .sto file.
#' @keywords internal
.readStoFile <- function(path) {
  lines <- readLines(path, warn = FALSE)

  # Find the end of header (line with "endheader")
  header_end <- grep("^endheader", lines, ignore.case = TRUE)
  if (length(header_end) == 0) {
    # Try to find the first line that looks like column names
    header_end <- 0
    for (i in seq_along(lines)) {
      if (grepl("^time\\b", lines[i], ignore.case = TRUE)) {
        header_end <- i - 1
        break
      }
    }
    if (header_end == 0) header_end <- 0
  } else {
    header_end <- header_end[1]
  }

  # Column names are on the line after endheader
  col_line <- header_end + 1
  if (col_line > length(lines)) {
    stop("Could not find data in .sto file")
  }

  col_names <- strsplit(trimws(lines[col_line]), "\\s+")[[1]]

  # Data starts after column names
  data_start <- col_line + 1
  if (data_start > length(lines)) {
    return(data.frame(matrix(ncol = length(col_names), nrow = 0,
                              dimnames = list(NULL, col_names))))
  }

  data_lines <- lines[data_start:length(lines)]
  data_lines <- data_lines[nchar(trimws(data_lines)) > 0]

  if (length(data_lines) == 0) {
    return(data.frame(matrix(ncol = length(col_names), nrow = 0,
                              dimnames = list(NULL, col_names))))
  }

  values <- strsplit(trimws(data_lines), "\\s+")
  mat <- do.call(rbind, values)

  # Ensure correct number of columns
  if (ncol(mat) != length(col_names)) {
    warning("Column count mismatch in .sto file")
    col_names <- paste0("V", seq_len(ncol(mat)))
  }

  df <- as.data.frame(mat, stringsAsFactors = FALSE)
  colnames(df) <- col_names

  # Convert numeric columns
  for (i in seq_len(ncol(df))) {
    num_val <- suppressWarnings(as.numeric(df[[i]]))
    if (!all(is.na(num_val))) df[[i]] <- num_val
  }

  df
}


# ---- Exported functions ----

#' Build MSKHypergraph from OpenSim Model
#'
#' Parses an OpenSim .osim file to extract muscle-bone attachment points
#' and constructs a subject-specific MSKHypergraph.
#'
#' @param model An optional PhysioOpenSimModel object. If provided, the
#'   model's path is used and results are cross-validated.
#' @param model_path Character, path to a .osim file. Required if \code{model}
#'   is NULL.
#' @return An \code{MSKHypergraph} object with subject-specific anatomy.
#' @note Requires the \code{xml2} package.
#' @export
#' @examples
#' \dontrun{
#' hg <- opensimToMSKHypergraph(model_path = "gait2392.osim")
#' print(hg)
#' }
opensimToMSKHypergraph <- function(model = NULL, model_path = NULL) {
  # Resolve model path
  if (!is.null(model)) {
    if (is.null(model_path)) {
      model_path <- tryCatch(
        model$path %||% model@path %||% attr(model, "path"),
        error = function(e) NULL
      )
    }
  }

  if (is.null(model_path) || !file.exists(model_path)) {
    stop("A valid .osim model_path is required")
  }

  # Parse attachments
  attachments <- .parseOsimAttachments(model_path)

  if (nrow(attachments) == 0) {
    stop("No muscle-bone attachments found in .osim file")
  }

  # Build incidence matrix
  all_bodies <- sort(unique(attachments$body_name))
  all_muscles <- sort(unique(attachments$muscle_name))

  C <- Matrix::Matrix(0, nrow = length(all_bodies), ncol = length(all_muscles),
                      sparse = TRUE)
  rownames(C) <- all_bodies
  colnames(C) <- all_muscles

  for (i in seq_len(nrow(attachments))) {
    body_i <- which(all_bodies == attachments$body_name[i])
    muscle_i <- which(all_muscles == attachments$muscle_name[i])
    if (length(body_i) == 1 && length(muscle_i) == 1) {
      C[body_i, muscle_i] <- 1
    }
  }

  # Build muscle metadata
  muscle_meta <- data.frame(
    index = seq_along(all_muscles),
    muscle = all_muscles,
    community = NA_integer_,
    homunculus_category = NA_character_,
    stringsAsFactors = FALSE
  )

  # Cross-validate with PhysioOpenSim if model is provided
  if (!is.null(model) &&
      requireNamespace("PhysioOpenSim", quietly = TRUE) &&
      exists("opensimModelComponents", where = asNamespace("PhysioOpenSim"))) {
    tryCatch({
      components <- PhysioOpenSim::opensimModelComponents(model)
      if (!is.null(components$muscles)) {
        msg <- sprintf("OpenSim model: %d muscles, parsed: %d muscles",
                       length(components$muscles), length(all_muscles))
        message(msg)
      }
    }, error = function(e) NULL)
  }

  MSKHypergraph(C, muscle_meta)
}


#' Full Network Analysis on OpenSim Model
#'
#' Builds a hypergraph from an OpenSim model and runs complete network analysis
#' including metrics, community detection, and optionally impact scoring.
#'
#' @param model An optional PhysioOpenSimModel object.
#' @param model_path Character, path to .osim file.
#' @param gamma Resolution parameter for community detection (default: 4.3).
#' @param run_simulation Logical, whether to run full impact simulation
#'   (default: TRUE; set to FALSE for faster analysis).
#' @return An S3 object of class \code{"MSKOpenSimAnalysis"} with:
#'   \describe{
#'     \item{hypergraph}{The MSKHypergraph object}
#'     \item{metrics}{Network metrics from mskNetworkMetrics}
#'     \item{communities}{Community detection results}
#'     \item{impact_scores}{Impact scores (if run_simulation = TRUE)}
#'   }
#' @export
opensimNetworkAnalysis <- function(model = NULL, model_path = NULL,
                                    gamma = 4.3, run_simulation = TRUE) {
  hg <- opensimToMSKHypergraph(model = model, model_path = model_path)

  metrics_bone <- mskNetworkMetrics(hg, type = "bone")
  metrics_muscle <- mskNetworkMetrics(hg, type = "muscle")
  communities <- mskCommunityDetect(hg, gamma = gamma, type = "muscle")

  impact_scores <- NULL
  if (run_simulation) {
    sim <- mskSimulate(hg)
    impact_scores <- mskImpactScoreAll(sim, verbose = FALSE)
  }

  result <- structure(
    list(
      hypergraph = hg,
      metrics = list(bone = metrics_bone, muscle = metrics_muscle),
      communities = communities,
      impact_scores = impact_scores,
      gamma = gamma
    ),
    class = "MSKOpenSimAnalysis"
  )

  result
}

#' @export
print.MSKOpenSimAnalysis <- function(x, ...) {
  hg <- x$hypergraph
  cat("MSK OpenSim Network Analysis\n")
  cat("============================\n")
  cat("Bodies:", hg$n_bones, "\n")
  cat("Muscles:", hg$n_muscles, "\n")
  cat("Connections:", sum(hg$C), "\n")
  cat("Communities:", x$communities$n_communities,
      "(gamma =", x$gamma, ")\n")
  cat("Bone graph density:", round(x$metrics$bone$density, 4), "\n")
  cat("Muscle graph density:", round(x$metrics$muscle$density, 4), "\n")
  if (!is.null(x$impact_scores)) {
    cat("Impact scores: computed for", length(x$impact_scores), "muscles\n")
    cat("  Range:", round(min(x$impact_scores), 2), "-",
        round(max(x$impact_scores), 2), "\n")
  }
  invisible(x)
}


#' Compare Multiple OpenSim Models
#'
#' Runs network analysis on multiple OpenSim models and performs statistical
#' comparisons of their network properties.
#'
#' @param model_paths Character vector of paths to .osim files.
#' @param names Optional character vector of model names.
#' @param gamma Resolution parameter for community detection (default: 4.3).
#' @return An S3 object of class \code{"MSKModelComparison"} with:
#'   \describe{
#'     \item{analyses}{List of MSKOpenSimAnalysis objects}
#'     \item{comparisons}{Data frame of pairwise comparison statistics}
#'   }
#' @export
opensimCompareModels <- function(model_paths, names = NULL, gamma = 4.3) {
  stopifnot(length(model_paths) >= 2)

  if (is.null(names)) {
    names <- basename(model_paths)
  }
  stopifnot(length(names) == length(model_paths))

  # Run analysis per model
  analyses <- lapply(seq_along(model_paths), function(i) {
    opensimNetworkAnalysis(model_path = model_paths[i], gamma = gamma,
                           run_simulation = FALSE)
  })
  names(analyses) <- names

  # Pairwise comparisons
  n_models <- length(analyses)
  comp_rows <- list()

  for (i in seq_len(n_models - 1)) {
    for (j in (i + 1):n_models) {
      # Degree distribution comparison (KS test)
      deg_i <- analyses[[i]]$metrics$muscle$degree
      deg_j <- analyses[[j]]$metrics$muscle$degree
      ks <- stats::ks.test(deg_i, deg_j)

      # Community comparison (z-Rand on common muscles)
      mem_i <- analyses[[i]]$communities$membership
      mem_j <- analyses[[j]]$communities$membership
      common <- intersect(names(mem_i), names(mem_j))

      z_rand <- if (length(common) >= 3) {
        mskZRand(mem_i[common], mem_j[common])
      } else {
        NA_real_
      }

      comp_rows[[length(comp_rows) + 1L]] <- data.frame(
        model_a = names[i],
        model_b = names[j],
        ks_statistic = round(ks$statistic, 4),
        ks_p_value = round(ks$p.value, 4),
        z_rand = round(z_rand, 4),
        n_common_muscles = length(common),
        n_bones_a = analyses[[i]]$hypergraph$n_bones,
        n_bones_b = analyses[[j]]$hypergraph$n_bones,
        n_muscles_a = analyses[[i]]$hypergraph$n_muscles,
        n_muscles_b = analyses[[j]]$hypergraph$n_muscles,
        stringsAsFactors = FALSE
      )
    }
  }

  comparisons <- do.call(rbind, comp_rows)

  structure(
    list(
      analyses = analyses,
      comparisons = comparisons,
      names = names
    ),
    class = "MSKModelComparison"
  )
}

#' @export
print.MSKModelComparison <- function(x, ...) {
  cat("MSK Model Comparison\n")
  cat("====================\n")
  cat("Models:", paste(x$names, collapse = ", "), "\n\n")
  print(x$comparisons, row.names = FALSE)
  invisible(x)
}


#' OpenSim Force-weighted Impact Analysis
#'
#' Combines muscle force data from OpenSim simulations with MSK network
#' impact scores to compute force-weighted vulnerability.
#'
#' @param model_path Character, path to .osim file.
#' @param force_data Force data as a data.frame (with muscle name column),
#'   named numeric vector, or path to an OpenSim .sto file.
#' @param hg An optional pre-built MSKHypergraph (if NULL, built from model).
#' @param method Character, weighting method:
#'   \describe{
#'     \item{"weighted_simulation"}{Modify spring constants k_m = force_m / (deg_m - 1)}
#'     \item{"weighted_scores"}{Post-hoc weighted_impact = impact * force}
#'   }
#' @return A list with:
#'   \describe{
#'     \item{weighted_impact_scores}{Force-weighted impact scores}
#'     \item{force_weights}{Force values used for weighting}
#'     \item{unweighted_scores}{Original (unweighted) impact scores}
#'   }
#' @export
opensimForceToImpact <- function(model_path, force_data, hg = NULL,
                                  method = c("weighted_simulation",
                                              "weighted_scores")) {
  method <- match.arg(method)

  # Build hypergraph if needed
  if (is.null(hg)) {
    hg <- opensimToMSKHypergraph(model_path = model_path)
  }

  # Parse force data
  if (is.character(force_data) && length(force_data) == 1 &&
      file.exists(force_data)) {
    # .sto file path
    force_df <- .readStoFile(force_data)
    # Average force per muscle (excluding time column)
    numeric_cols <- vapply(force_df, is.numeric, logical(1))
    if ("time" %in% names(force_df)) numeric_cols["time"] <- FALSE
    force_vec <- colMeans(force_df[, numeric_cols, drop = FALSE], na.rm = TRUE)
  } else if (is.data.frame(force_data)) {
    # Data frame with muscle names and force values
    if ("muscle" %in% names(force_data) && "force" %in% names(force_data)) {
      force_vec <- setNames(force_data$force, force_data$muscle)
    } else {
      # Use first two columns (name, value)
      force_vec <- setNames(as.numeric(force_data[[2]]),
                            as.character(force_data[[1]]))
    }
  } else if (is.numeric(force_data)) {
    force_vec <- force_data
  } else {
    stop("force_data must be a named vector, data.frame, or .sto file path")
  }

  # Match force muscles to hypergraph muscles
  force_matched <- rep(1.0, hg$n_muscles)
  names(force_matched) <- hg$muscle_names

  for (nm in names(force_vec)) {
    # Exact match
    idx <- which(tolower(hg$muscle_names) == tolower(nm))
    if (length(idx) == 0) {
      # Fuzzy match
      idx <- agrep(tolower(nm), tolower(hg$muscle_names),
                    max.distance = 0.2, ignore.case = TRUE)
    }
    if (length(idx) >= 1) {
      force_matched[idx[1]] <- force_vec[nm]
    }
  }

  # Normalize forces to [0, max]
  if (max(force_matched) > 0) {
    force_weights <- force_matched / max(force_matched)
  } else {
    force_weights <- force_matched
  }

  deg <- hyperedgeDegree(hg)

  if (method == "weighted_simulation") {
    # Modify spring constants: k_m = force_m / (deg_m - 1)
    sim <- mskSimulate(hg)
    sim$spring_constants <- ifelse(
      deg > 1,
      pmax(force_weights, 0.01) / (deg - 1),
      pmax(force_weights, 0.01)
    )

    weighted_scores <- numeric(hg$n_muscles)
    for (i in seq_len(hg$n_muscles)) {
      weighted_scores[i] <- mskImpactScore(sim, i)
    }
    names(weighted_scores) <- hg$muscle_names

    # Unweighted for comparison
    sim_uw <- mskSimulate(hg)
    unweighted_scores <- mskImpactScoreAll(sim_uw, verbose = FALSE)

  } else {
    # weighted_scores method: post-hoc weighting
    sim <- mskSimulate(hg)
    unweighted_scores <- mskImpactScoreAll(sim, verbose = FALSE)
    weighted_scores <- unweighted_scores * force_weights
  }

  list(
    weighted_impact_scores = weighted_scores,
    force_weights = force_weights,
    unweighted_scores = unweighted_scores
  )
}
