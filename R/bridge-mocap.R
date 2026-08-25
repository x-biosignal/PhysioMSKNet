# ===========================================================================
# bridge-mocap.R -- MoCap kinematics in MSK network context
# ===========================================================================

# ---- Internal helper ----

#' Curated MoCap segment to MSK bone lookup table
#'
#' Maps common MoCap marker/segment naming conventions (BODY_25, PluginGait,
#' OpenSim, etc.) to MSK bone names. A single MoCap segment may map to
#' multiple MSK bones (e.g., "forearm" -> Radius + Ulna).
#'
#' @return A data.frame with columns: mocap_name, bone_name.
#' @keywords internal
.mocapBoneLookup <- function() {
  data.frame(
    mocap_name = c(
      # Head/neck
      "head", "skull", "cranium", "neck", "cervical",
      # Trunk
      "thorax", "chest", "trunk", "torso",
      "pelvis", "hip", "sacrum",
      "spine", "lumbar",
      "sternum",
      # Upper extremity
      "clavicle", "shoulder",
      "upper_arm", "upperarm", "humerus", "r_upper_arm", "l_upper_arm",
      "forearm", "lower_arm", "lowerarm", "r_forearm", "l_forearm",
      "hand", "wrist", "r_hand", "l_hand",
      "scapula",
      # Lower extremity
      "thigh", "upper_leg", "upperleg", "r_thigh", "l_thigh",
      "shank", "lower_leg", "lowerleg", "tibia", "r_shank", "l_shank",
      "foot", "ankle", "r_foot", "l_foot",
      "patella", "kneecap",
      "femur", "r_femur", "l_femur",
      # PluginGait specific
      "rsho", "lsho", "relb", "lelb", "rwra", "lwra",
      "rasi", "lasi", "rpsi", "lpsi",
      "rkne", "lkne", "rank", "lank",
      "rtoe", "ltoe", "rhee", "lhee"
    ),
    bone_name = c(
      # Head/neck -> actual dataset names
      "Frontal Bone", "Temporal Bone", "Occipital Bone",
      "C1 (Atlas)", "C1 (Atlas)",
      # Trunk
      "T1", "T1", "T1", "T1",
      "Ilium", "Ilium", "Sacrum",
      "L1", "L1",
      "Sternum",
      # Upper extremity
      "Clavicle", "Clavicle",
      "Humerus", "Humerus", "Humerus", "Humerus", "Humerus",
      "Radius", "Radius", "Radius", "Radius", "Radius",
      "Hand Metacarpal 1", "Hand Metacarpal 1",
      "Hand Metacarpal 1", "Hand Metacarpal 1",
      "Scapula",
      # Lower extremity
      "Femur", "Femur", "Femur", "Femur", "Femur",
      "Tibia", "Tibia", "Tibia", "Tibia", "Tibia", "Tibia",
      "Tarsus", "Calcaneus", "Tarsus", "Tarsus",
      "Patella", "Patella",
      "Femur", "Femur", "Femur",
      # PluginGait
      "Clavicle", "Clavicle", "Humerus", "Humerus",
      "Hand Metacarpal 1", "Hand Metacarpal 1",
      "Ilium", "Ilium", "Ilium", "Ilium",
      "Femur", "Femur", "Tarsus", "Tarsus",
      "Metatarsal 1", "Metatarsal 1", "Calcaneus", "Calcaneus"
    ),
    stringsAsFactors = FALSE
  )
}


# ---- Exported functions ----

#' Map MoCap Segments to MSK Bones
#'
#' Matches MoCap segment names from a SkeletonModel or character vector
#' to bones in an MSK hypergraph using a curated lookup table with
#' fuzzy matching fallback.
#'
#' @param skeleton A PhysioMoCap SkeletonModel object or character vector
#'   of segment names.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param method Character, matching method: "exact" or "fuzzy".
#' @param threshold Numeric, fuzzy matching threshold (default: 0.7).
#' @return A data.frame with columns: segment_name, bone_idx, bone_name,
#'   match_quality, match_method.
#' @export
#' @examples
#' \dontrun{
#' mapping <- mocapToMSKMapping(c("upper_arm", "forearm", "thigh"))
#' }
mocapToMSKMapping <- function(skeleton, hg = NULL,
                               method = c("exact", "fuzzy"),
                               threshold = 0.7) {
  method <- match.arg(method)
  hg <- .ensureHypergraph(hg)

  # Extract segment names
  if (is.character(skeleton)) {
    seg_names <- skeleton
  } else {
    # Try to extract from SkeletonModel
    seg_names <- tryCatch(
      skeleton$segment_names %||% skeleton$segments %||% names(skeleton),
      error = function(e) {
        stop("Cannot extract segment names from skeleton object")
      }
    )
  }

  lookup <- .mocapBoneLookup()
  bone_names_lower <- tolower(hg$bone_names)

  results <- list()
  for (i in seq_along(seg_names)) {
    seg <- seg_names[i]
    seg_lower <- tolower(trimws(gsub("^[rl]_", "", seg)))

    # Step 1: Curated lookup
    lookup_match <- lookup[tolower(lookup$mocap_name) == seg_lower, , drop = FALSE]
    if (nrow(lookup_match) > 0) {
      for (r in seq_len(nrow(lookup_match))) {
        bone <- lookup_match$bone_name[r]
        bone_idx <- which(tolower(hg$bone_names) == tolower(bone))
        if (length(bone_idx) >= 1L) {
          results[[length(results) + 1L]] <- data.frame(
            segment_name = seg,
            bone_idx = bone_idx[1L],
            bone_name = hg$bone_names[bone_idx[1L]],
            match_quality = 1.0,
            match_method = "lookup",
            stringsAsFactors = FALSE
          )
        }
      }
      next
    }

    # Step 2: Direct name match against bone names
    exact_match <- which(bone_names_lower == seg_lower)
    if (length(exact_match) >= 1L) {
      results[[length(results) + 1L]] <- data.frame(
        segment_name = seg,
        bone_idx = exact_match[1L],
        bone_name = hg$bone_names[exact_match[1L]],
        match_quality = 1.0,
        match_method = "exact",
        stringsAsFactors = FALSE
      )
      next
    }

    # Step 3: Fuzzy matching (if method allows)
    if (method == "fuzzy") {
      fuzzy_idx <- agrep(seg_lower, bone_names_lower,
                          max.distance = 1 - threshold,
                          ignore.case = TRUE)
      if (length(fuzzy_idx) >= 1L) {
        dists <- vapply(fuzzy_idx, function(j) {
          adist(seg_lower, bone_names_lower[j])
        }, numeric(1))
        best <- fuzzy_idx[which.min(dists)]
        quality <- 1 - min(dists) / max(nchar(seg_lower),
                                         nchar(bone_names_lower[best]))
        results[[length(results) + 1L]] <- data.frame(
          segment_name = seg,
          bone_idx = best,
          bone_name = hg$bone_names[best],
          match_quality = round(quality, 3),
          match_method = "fuzzy",
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(results) == 0L) {
    return(data.frame(
      segment_name = character(0),
      bone_idx = integer(0),
      bone_name = character(0),
      match_quality = numeric(0),
      match_method = character(0),
      stringsAsFactors = FALSE
    ))
  }

  do.call(rbind, results)
}


#' Compute Kinematic Coupling vs MSK Structure
#'
#' Computes pairwise movement coupling between MoCap segments and compares
#' the kinematic coupling matrix with MSK structural adjacency.
#'
#' @param pe_mocap A numeric matrix (frames x segments) or SummarizedExperiment
#'   with MoCap position data.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param mapping Optional data.frame from \code{mocapToMSKMapping()}.
#' @param method Character, coupling method: "correlation" or "mutual_info".
#' @return A list with:
#'   \describe{
#'     \item{kinematic_coupling}{Pairwise coupling matrix}
#'     \item{structural_matrix}{MSK bone adjacency (matched subset)}
#'     \item{correlation}{Mantel correlation coefficient}
#'     \item{p_value}{Permutation-based p-value}
#'   }
#' @export
mocapNetworkKinematics <- function(pe_mocap, hg = NULL, mapping = NULL,
                                    method = c("correlation", "mutual_info")) {
  method <- match.arg(method)
  hg <- .ensureHypergraph(hg)

  # Extract position matrix
  if (is.matrix(pe_mocap) || is.data.frame(pe_mocap)) {
    pos_mat <- as.matrix(pe_mocap)
    seg_names <- colnames(pe_mocap) %||% paste0("seg_", seq_len(ncol(pe_mocap)))
  } else {
    pos_mat <- tryCatch(
      as.matrix(pe_mocap@assays@data[[1]]),
      error = function(e) stop("Cannot extract position data")
    )
    seg_names <- tryCatch(
      colnames(pe_mocap@assays@data[[1]]),
      error = function(e) paste0("seg_", seq_len(ncol(pos_mat)))
    )
    colnames(pos_mat) <- seg_names
  }

  if (is.null(mapping)) {
    mapping <- mocapToMSKMapping(seg_names, hg = hg, method = "fuzzy")
  }

  if (nrow(mapping) < 3) {
    warning("Fewer than 3 segments mapped; results may be unreliable")
    if (nrow(mapping) == 0) {
      return(list(
        kinematic_coupling = matrix(nrow = 0, ncol = 0),
        structural_matrix = matrix(nrow = 0, ncol = 0),
        correlation = NA_real_,
        p_value = NA_real_
      ))
    }
  }

  # Deduplicate mapping (keep first match per segment)
  mapping <- mapping[!duplicated(mapping$segment_name), ]

  # Find which columns in pos_mat correspond to mapped segments
  seg_idx <- match(mapping$segment_name, seg_names)
  valid <- !is.na(seg_idx)
  mapping <- mapping[valid, ]
  seg_idx <- seg_idx[valid]

  if (length(seg_idx) < 2) {
    return(list(
      kinematic_coupling = matrix(nrow = 0, ncol = 0),
      structural_matrix = matrix(nrow = 0, ncol = 0),
      correlation = NA_real_,
      p_value = NA_real_
    ))
  }

  # Compute frame-to-frame displacement per segment
  displacement <- apply(pos_mat[, seg_idx, drop = FALSE], 2, function(x) {
    c(0, abs(diff(x)))
  })

  # Pairwise coupling
  n_seg <- ncol(displacement)
  coupling <- matrix(0, n_seg, n_seg)

  if (method == "correlation") {
    for (i in seq_len(n_seg - 1)) {
      for (j in (i + 1):n_seg) {
        r <- cor(displacement[, i], displacement[, j],
                 use = "complete.obs")
        coupling[i, j] <- coupling[j, i] <- abs(r)
      }
    }
  } else {
    # Mutual information via discretized bins
    nbins <- 10
    for (i in seq_len(n_seg - 1)) {
      for (j in (i + 1):n_seg) {
        xi <- cut(displacement[, i], breaks = nbins, labels = FALSE)
        xj <- cut(displacement[, j], breaks = nbins, labels = FALSE)
        valid <- !is.na(xi) & !is.na(xj)
        if (sum(valid) < 10) next
        tab <- table(xi[valid], xj[valid])
        p_xy <- tab / sum(tab)
        p_x <- rowSums(p_xy)
        p_y <- colSums(p_xy)
        mi <- 0
        for (a in seq_len(nrow(p_xy))) {
          for (b in seq_len(ncol(p_xy))) {
            if (p_xy[a, b] > 0 && p_x[a] > 0 && p_y[b] > 0) {
              mi <- mi + p_xy[a, b] * log(p_xy[a, b] / (p_x[a] * p_y[b]))
            }
          }
        }
        coupling[i, j] <- coupling[j, i] <- mi
      }
    }
  }

  diag(coupling) <- 1
  rownames(coupling) <- colnames(coupling) <- mapping$bone_name

  # Structural adjacency for matched bones
  A <- as.matrix(projectBoneGraph(hg))
  b_idx <- mapping$bone_idx
  struct_sub <- A[b_idx, b_idx]
  struct_bin <- (struct_sub > 0) * 1.0
  rownames(struct_bin) <- colnames(struct_bin) <- mapping$bone_name

  # Mantel test
  mantel <- .mantelTest(coupling, struct_bin, n_perm = 999L)

  list(
    kinematic_coupling = coupling,
    structural_matrix = struct_bin,
    correlation = mantel$correlation,
    p_value = mantel$p_value
  )
}


#' Kinematic Stress-based Impact Prediction
#'
#' Computes kinematic stress per bone from MoCap data and propagates it through
#' the MSK incidence matrix to estimate muscle vulnerability.
#'
#' @param pe_mocap A numeric matrix (frames x segments) with MoCap data.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param mapping Optional data.frame from \code{mocapToMSKMapping()}.
#' @param stress_metric Character, kinematic stress metric: "acceleration",
#'   "jerk", or "range".
#' @param use_proxy Logical, if TRUE uses degree-based proxy instead of full
#'   simulation for impact deviation (default: TRUE).
#' @return A list with:
#'   \describe{
#'     \item{vulnerability}{Named numeric vector of muscle vulnerability scores}
#'     \item{bone_stress}{Named numeric vector of bone stress values}
#'     \item{muscle_stress_exposure}{Named numeric vector of muscle stress exposure}
#'     \item{ranking}{Data frame ranking muscles by vulnerability}
#'   }
#' @export
mocapImpactPrediction <- function(pe_mocap, hg = NULL, mapping = NULL,
                                   stress_metric = c("acceleration", "jerk",
                                                      "range"),
                                   use_proxy = TRUE) {
  stress_metric <- match.arg(stress_metric)
  hg <- .ensureHypergraph(hg)

  # Extract position matrix
  if (is.matrix(pe_mocap) || is.data.frame(pe_mocap)) {
    pos_mat <- as.matrix(pe_mocap)
    seg_names <- colnames(pe_mocap) %||% paste0("seg_", seq_len(ncol(pe_mocap)))
  } else {
    pos_mat <- tryCatch(
      as.matrix(pe_mocap@assays@data[[1]]),
      error = function(e) stop("Cannot extract position data")
    )
    seg_names <- colnames(pe_mocap)
  }

  if (is.null(mapping)) {
    mapping <- mocapToMSKMapping(seg_names, hg = hg, method = "fuzzy")
  }

  # Deduplicate
  mapping <- mapping[!duplicated(mapping$segment_name), ]
  seg_idx <- match(mapping$segment_name, seg_names)
  valid <- !is.na(seg_idx)
  mapping <- mapping[valid, ]
  seg_idx <- seg_idx[valid]

  if (length(seg_idx) == 0) {
    return(list(
      vulnerability = numeric(0),
      bone_stress = numeric(0),
      muscle_stress_exposure = numeric(0),
      ranking = data.frame(muscle = character(0), vulnerability = numeric(0),
                           stringsAsFactors = FALSE)
    ))
  }

  # Compute kinematic stress per matched segment/bone
  bone_stress <- vapply(seq_along(seg_idx), function(k) {
    x <- pos_mat[, seg_idx[k]]
    switch(stress_metric,
      acceleration = {
        vel <- diff(x)
        acc <- diff(vel)
        max(abs(acc), na.rm = TRUE)
      },
      jerk = {
        vel <- diff(x)
        acc <- diff(vel)
        jrk <- diff(acc)
        max(abs(jrk), na.rm = TRUE)
      },
      range = {
        diff(range(x, na.rm = TRUE))
      }
    )
  }, numeric(1))
  names(bone_stress) <- mapping$bone_name

  # Propagate stress through incidence matrix:
  # muscle_stress[m] = sum(C[matched_bones, m] * bone_stress)
  C <- as.matrix(hg$C)
  b_idx <- mapping$bone_idx

  muscle_stress <- numeric(hg$n_muscles)
  for (m in seq_len(hg$n_muscles)) {
    muscle_stress[m] <- sum(C[b_idx, m] * bone_stress)
  }
  names(muscle_stress) <- hg$muscle_names

  # Impact deviation (proxy or full)
  if (use_proxy) {
    deg <- hyperedgeDegree(hg)
    # Normalize degree as proxy for impact deviation
    impact_dev <- (deg - mean(deg)) / max(sd(deg), 1)
  } else {
    sim <- mskSimulate(hg)
    scores <- mskImpactScoreAll(sim, verbose = FALSE)
    impact_dev <- mskImpactDeviation(scores, hg)
  }

  # Vulnerability = muscle_stress * |impact_deviation|
  vulnerability <- muscle_stress * abs(impact_dev)
  names(vulnerability) <- hg$muscle_names

  # Ranking
  ord <- order(vulnerability, decreasing = TRUE)
  ranking <- data.frame(
    muscle = hg$muscle_names[ord],
    vulnerability = round(vulnerability[ord], 4),
    stress_exposure = round(muscle_stress[ord], 4),
    impact_deviation = round(impact_dev[ord], 4),
    stringsAsFactors = FALSE
  )

  list(
    vulnerability = vulnerability,
    bone_stress = bone_stress,
    muscle_stress_exposure = muscle_stress,
    ranking = ranking
  )
}


#' Within vs Between Community Movement Synchrony
#'
#' Computes displacement synchrony (correlation) between matched bones and
#' tests whether within-community pairs are more synchronized than
#' between-community pairs using a Wilcoxon test.
#'
#' @param pe_mocap A numeric matrix (frames x segments) with MoCap data.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param gamma Resolution parameter for community detection (default: 4.3).
#' @param mapping Optional data.frame from \code{mocapToMSKMapping()}.
#' @param window_sec Optional numeric, window size in seconds for
#'   time-resolved analysis (NULL for global analysis only).
#' @return A list with:
#'   \describe{
#'     \item{within_community_sync}{Mean within-community synchrony}
#'     \item{between_community_sync}{Mean between-community synchrony}
#'     \item{ratio}{Within/between ratio}
#'     \item{p_value}{Wilcoxon test p-value}
#'     \item{time_resolved}{Data frame with per-window results (if window_sec set)}
#'   }
#' @export
mocapCommunityDynamics <- function(pe_mocap, hg = NULL, gamma = 4.3,
                                    mapping = NULL, window_sec = NULL) {
  hg <- .ensureHypergraph(hg)

  # Extract position matrix
  if (is.matrix(pe_mocap) || is.data.frame(pe_mocap)) {
    pos_mat <- as.matrix(pe_mocap)
    seg_names <- colnames(pe_mocap) %||% paste0("seg_", seq_len(ncol(pe_mocap)))
    sr <- attr(pe_mocap, "sr") %||% 100  # MoCap typical frame rate
  } else {
    pos_mat <- tryCatch(
      as.matrix(pe_mocap@assays@data[[1]]),
      error = function(e) stop("Cannot extract position data")
    )
    seg_names <- colnames(pe_mocap)
    sr <- tryCatch(pe_mocap@samplingRate %||% 100, error = function(e) 100)
  }

  if (is.null(mapping)) {
    mapping <- mocapToMSKMapping(seg_names, hg = hg, method = "fuzzy")
  }

  mapping <- mapping[!duplicated(mapping$segment_name), ]
  seg_idx <- match(mapping$segment_name, seg_names)
  valid <- !is.na(seg_idx)
  mapping <- mapping[valid, ]
  seg_idx <- seg_idx[valid]

  n_mapped <- length(seg_idx)
  if (n_mapped < 3) {
    return(list(
      within_community_sync = NA_real_,
      between_community_sync = NA_real_,
      ratio = NA_real_,
      p_value = NA_real_,
      time_resolved = NULL
    ))
  }

  # Community assignments for matched bones
  bone_comm <- mskCommunityDetect(hg, gamma = gamma, type = "bone")
  membership <- bone_comm$membership[mapping$bone_idx]

  # Helper: compute within/between synchrony for a data window
  .compute_sync <- function(data_window) {
    displacement <- apply(data_window, 2, function(x) c(0, abs(diff(x))))

    within_vals <- numeric(0)
    between_vals <- numeric(0)

    for (i in seq_len(n_mapped - 1)) {
      for (j in (i + 1):n_mapped) {
        r <- cor(displacement[, i], displacement[, j], use = "complete.obs")
        if (is.na(r)) next
        if (membership[i] == membership[j]) {
          within_vals <- c(within_vals, abs(r))
        } else {
          between_vals <- c(between_vals, abs(r))
        }
      }
    }
    list(within = within_vals, between = between_vals)
  }

  # Global analysis
  global <- .compute_sync(pos_mat[, seg_idx, drop = FALSE])

  within_mean <- if (length(global$within) > 0) mean(global$within) else NA_real_
  between_mean <- if (length(global$between) > 0) mean(global$between) else NA_real_
  ratio <- if (!is.na(within_mean) && !is.na(between_mean) && between_mean > 0) {
    within_mean / between_mean
  } else {
    NA_real_
  }

  # Wilcoxon test
  if (length(global$within) >= 2 && length(global$between) >= 2) {
    wt <- stats::wilcox.test(global$within, global$between,
                              alternative = "greater")
    p_val <- wt$p.value
  } else {
    p_val <- NA_real_
  }

  # Time-resolved analysis
  time_resolved <- NULL
  if (!is.null(window_sec) && window_sec > 0) {
    win_frames <- round(window_sec * sr)
    n_frames <- nrow(pos_mat)
    n_windows <- max(1, floor(n_frames / win_frames))

    tr_rows <- list()
    for (w in seq_len(n_windows)) {
      start <- (w - 1) * win_frames + 1
      end <- min(w * win_frames, n_frames)
      if (end - start < 3) next

      window_data <- pos_mat[start:end, seg_idx, drop = FALSE]
      ws <- .compute_sync(window_data)

      tr_rows[[length(tr_rows) + 1L]] <- data.frame(
        window = w,
        time_start = (start - 1) / sr,
        time_end = (end - 1) / sr,
        within_sync = if (length(ws$within) > 0) mean(ws$within) else NA,
        between_sync = if (length(ws$between) > 0) mean(ws$between) else NA,
        stringsAsFactors = FALSE
      )
    }

    if (length(tr_rows) > 0) {
      time_resolved <- do.call(rbind, tr_rows)
    }
  }

  list(
    within_community_sync = within_mean,
    between_community_sync = between_mean,
    ratio = ratio,
    p_value = p_val,
    time_resolved = time_resolved
  )
}
