# ===========================================================================
# bridge-imu.R -- IMU sensor data in MSK network context
# ===========================================================================
#
# Integrates inertial measurement unit (accelerometer + gyroscope) data
# with the musculoskeletal hypergraph. Complements bridge-mocap.R by
# providing direct IMU → bone stress pathways without requiring
# optical motion capture position data.
#
# Key differences from bridge-mocap.R:
#   - Works with orientation (quaternion/Euler) and acceleration, not position
#   - Bone stress derived from angular velocity and linear acceleration
#   - Sensor placement lookup maps IMU sensor names to bones
# ===========================================================================

# ---- Internal helpers ----

#' Curated IMU sensor placement to MSK bone lookup table
#'
#' Maps common IMU sensor placement names (body segment labels) to MSK bone
#' names. Covers naming conventions from Xsens, APDM, Shimmer, and generic
#' body-segment labels used in clinical and research IMU setups.
#'
#' @return A data.frame with columns: imu_name, bone_name.
#' @keywords internal
.imuBoneLookup <- function() {
  data.frame(
    imu_name = c(
      # Generic placement names
      "head", "forehead", "skull",
      "neck", "cervical",
      "chest", "sternum", "thorax", "trunk", "torso",
      "upper_back", "lower_back", "lumbar", "sacrum",
      "pelvis", "hip", "waist",
      # Upper extremity
      "shoulder", "r_shoulder", "l_shoulder",
      "upper_arm", "r_upper_arm", "l_upper_arm",
      "forearm", "r_forearm", "l_forearm",
      "wrist", "r_wrist", "l_wrist",
      "hand", "r_hand", "l_hand",
      # Lower extremity
      "thigh", "r_thigh", "l_thigh",
      "shank", "shin", "r_shank", "l_shank",
      "ankle", "r_ankle", "l_ankle",
      "foot", "r_foot", "l_foot",
      # Xsens MVN segment names
      "Head", "Sternum", "Pelvis",
      "RightUpperArm", "LeftUpperArm",
      "RightForeArm", "LeftForeArm",
      "RightHand", "LeftHand",
      "RightUpperLeg", "LeftUpperLeg",
      "RightLowerLeg", "LeftLowerLeg",
      "RightFoot", "LeftFoot",
      # APDM Opal names
      "lumbar_sensor", "sternum_sensor",
      "right_wrist", "left_wrist",
      "right_ankle", "left_ankle",
      "right_thigh", "left_thigh",
      "right_shank", "left_shank"
    ),
    bone_name = c(
      # Generic
      "Frontal Bone", "Frontal Bone", "Temporal Bone",
      "C1 (Atlas)", "C1 (Atlas)",
      "Sternum", "Sternum", "T1", "T1", "T1",
      "T1", "L1", "L1", "Sacrum",
      "Ilium", "Ilium", "Ilium",
      # Upper extremity
      "Clavicle", "Clavicle", "Clavicle",
      "Humerus", "Humerus", "Humerus",
      "Radius", "Radius", "Radius",
      "Hand Metacarpal 1", "Hand Metacarpal 1", "Hand Metacarpal 1",
      "Hand Metacarpal 1", "Hand Metacarpal 1", "Hand Metacarpal 1",
      # Lower extremity
      "Femur", "Femur", "Femur",
      "Tibia", "Tibia", "Tibia", "Tibia",
      "Calcaneus", "Calcaneus", "Calcaneus",
      "Tarsus", "Tarsus", "Tarsus",
      # Xsens MVN
      "Frontal Bone", "Sternum", "Ilium",
      "Humerus", "Humerus",
      "Radius", "Radius",
      "Hand Metacarpal 1", "Hand Metacarpal 1",
      "Femur", "Femur",
      "Tibia", "Tibia",
      "Tarsus", "Tarsus",
      # APDM
      "L1", "Sternum",
      "Hand Metacarpal 1", "Hand Metacarpal 1",
      "Calcaneus", "Calcaneus",
      "Femur", "Femur",
      "Tibia", "Tibia"
    ),
    stringsAsFactors = FALSE
  )
}


# ---- Exported functions ----

#' Map IMU Sensor Placements to MSK Bones
#'
#' Matches IMU sensor placement names to bones in the MSK hypergraph using
#' a curated lookup table with fuzzy matching fallback. Supports naming
#' conventions from Xsens, APDM, Shimmer, and generic body-segment labels.
#'
#' @param sensors Character vector of IMU sensor placement names
#'   (e.g., \code{c("upper_arm", "thigh", "lumbar")}).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param method Character, matching method: "exact" or "fuzzy".
#' @param threshold Numeric, fuzzy matching threshold (default: 0.7).
#' @return A data.frame with columns: sensor_name, bone_idx, bone_name,
#'   match_quality, match_method.
#' @export
#' @examples
#' \dontrun{
#' mapping <- imuToMSKMapping(c("upper_arm", "thigh", "lumbar"))
#' }
imuToMSKMapping <- function(sensors, hg = NULL,
                             method = c("exact", "fuzzy"),
                             threshold = 0.7) {
  method <- match.arg(method)
  hg <- .ensureHypergraph(hg)

  lookup <- .imuBoneLookup()
  bone_names_lower <- tolower(hg$bone_names)

  results <- list()
  for (i in seq_along(sensors)) {
    sensor <- sensors[i]
    sensor_lower <- tolower(trimws(gsub("^[rl]_", "", sensor)))
    # Also try without "_sensor" suffix
    sensor_clean <- gsub("_sensor$", "", sensor_lower)

    # Step 1: Curated lookup
    lookup_match <- lookup[tolower(lookup$imu_name) == sensor_lower |
                           tolower(lookup$imu_name) == sensor_clean |
                           tolower(lookup$imu_name) == tolower(sensor), ,
                           drop = FALSE]
    if (nrow(lookup_match) > 0) {
      for (r in seq_len(nrow(lookup_match))) {
        bone <- lookup_match$bone_name[r]
        bone_idx <- which(tolower(hg$bone_names) == tolower(bone))
        if (length(bone_idx) >= 1L) {
          results[[length(results) + 1L]] <- data.frame(
            sensor_name = sensor,
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
    exact_match <- which(bone_names_lower == sensor_lower |
                         bone_names_lower == sensor_clean)
    if (length(exact_match) >= 1L) {
      results[[length(results) + 1L]] <- data.frame(
        sensor_name = sensor,
        bone_idx = exact_match[1L],
        bone_name = hg$bone_names[exact_match[1L]],
        match_quality = 1.0,
        match_method = "exact",
        stringsAsFactors = FALSE
      )
      next
    }

    # Step 3: Fuzzy matching
    if (method == "fuzzy") {
      fuzzy_idx <- agrep(sensor_clean, bone_names_lower,
                         max.distance = 1 - threshold,
                         ignore.case = TRUE)
      if (length(fuzzy_idx) >= 1L) {
        dists <- vapply(fuzzy_idx, function(j) {
          adist(sensor_clean, bone_names_lower[j])
        }, numeric(1))
        best <- fuzzy_idx[which.min(dists)]
        quality <- 1 - min(dists) / max(nchar(sensor_clean),
                                         nchar(bone_names_lower[best]))
        results[[length(results) + 1L]] <- data.frame(
          sensor_name = sensor,
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
      sensor_name = character(0), bone_idx = integer(0),
      bone_name = character(0), match_quality = numeric(0),
      match_method = character(0), stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, results)
}


#' IMU-based Network Kinematics Analysis
#'
#' Computes pairwise kinematic coupling from IMU orientation or acceleration
#' data and compares it to the structural adjacency of the MSK bone graph
#' using a Mantel test.
#'
#' @param imu_data A named list of per-sensor data. Each element should be a
#'   matrix or data.frame with orientation/acceleration columns. The list names
#'   are sensor placement names (e.g., \code{"upper_arm"}, \code{"thigh"}).
#'   Alternatively, a single matrix where columns are named
#'   \code{"<sensor>_roll"}, \code{"<sensor>_pitch"}, \code{"<sensor>_yaw"} or
#'   \code{"<sensor>_ax"}, \code{"<sensor>_ay"}, \code{"<sensor>_az"}.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param mapping A pre-computed mapping from \code{imuToMSKMapping()} (optional).
#' @param signal Character, which signal to use for coupling:
#'   \code{"orientation"} (Euler angle differences) or
#'   \code{"acceleration"} (acceleration magnitude correlation).
#' @param method Character, coupling method: \code{"correlation"} or
#'   \code{"mutual_info"}.
#' @return A list with:
#'   \describe{
#'     \item{kinematic_coupling}{Pairwise coupling matrix between mapped bones}
#'     \item{structural_matrix}{Corresponding MSK bone graph adjacency}
#'     \item{correlation}{Mantel test correlation coefficient}
#'     \item{p_value}{Permutation p-value}
#'     \item{mapped_sensors}{Data frame of sensor-to-bone mapping used}
#'   }
#' @export
imuNetworkKinematics <- function(imu_data, hg = NULL, mapping = NULL,
                                  signal = c("orientation", "acceleration"),
                                  method = c("correlation", "mutual_info")) {
  signal <- match.arg(signal)
  method <- match.arg(method)
  hg <- .ensureHypergraph(hg)

  # Parse imu_data into per-sensor matrices
  sensor_signals <- .parseIMUData(imu_data, signal)

  if (length(sensor_signals) < 2L) {
    return(list(
      kinematic_coupling = matrix(0, 0, 0),
      structural_matrix = matrix(0, 0, 0),
      correlation = NA_real_,
      p_value = NA_real_,
      mapped_sensors = data.frame()
    ))
  }

  sensor_names <- names(sensor_signals)

  # Map sensors to bones
  if (is.null(mapping)) {
    mapping <- imuToMSKMapping(sensor_names, hg = hg)
  }
  if (nrow(mapping) < 2L) {
    return(list(
      kinematic_coupling = matrix(0, 0, 0),
      structural_matrix = matrix(0, 0, 0),
      correlation = NA_real_,
      p_value = NA_real_,
      mapped_sensors = mapping
    ))
  }

  # Deduplicate: one bone per sensor
  mapping <- mapping[!duplicated(mapping$bone_idx), ]
  matched_sensors <- mapping$sensor_name
  matched_bones <- mapping$bone_idx
  n_matched <- length(matched_bones)
  if (n_matched < 2L) {
    return(list(
      kinematic_coupling = matrix(0, 0, 0),
      structural_matrix = matrix(0, 0, 0),
      correlation = NA_real_, p_value = NA_real_,
      mapped_sensors = mapping
    ))
  }

  # Compute per-sensor summary signal (1D time series per sensor)
  summaries <- lapply(matched_sensors, function(s) {
    sig <- sensor_signals[[s]]
    if (is.null(sig)) {
      # Try case-insensitive match
      idx <- which(tolower(names(sensor_signals)) == tolower(s))
      if (length(idx) > 0) sig <- sensor_signals[[idx[1]]]
    }
    if (is.null(sig)) return(NULL)
    # Compute magnitude time series
    if (is.matrix(sig) && ncol(sig) >= 3) {
      sqrt(rowSums(sig[, 1:3, drop = FALSE]^2))
    } else if (is.matrix(sig)) {
      sqrt(rowSums(sig^2))
    } else {
      as.numeric(sig)
    }
  })

  # Remove NULLs
  valid <- !vapply(summaries, is.null, logical(1))
  if (sum(valid) < 2L) {
    return(list(
      kinematic_coupling = matrix(0, 0, 0),
      structural_matrix = matrix(0, 0, 0),
      correlation = NA_real_, p_value = NA_real_,
      mapped_sensors = mapping
    ))
  }

  matched_sensors <- matched_sensors[valid]
  matched_bones <- matched_bones[valid]
  summaries <- summaries[valid]
  n_matched <- length(matched_bones)

  # Truncate to minimum length
  min_len <- min(vapply(summaries, length, integer(1)))
  summaries <- lapply(summaries, function(x) x[seq_len(min_len)])

  # Compute pairwise coupling matrix
  coupling <- matrix(0, n_matched, n_matched)
  rownames(coupling) <- colnames(coupling) <- mapping$bone_name[valid]

  for (a in seq_len(n_matched - 1L)) {
    for (b in (a + 1L):n_matched) {
      if (method == "correlation") {
        val <- abs(cor(summaries[[a]], summaries[[b]]))
      } else {
        # Mutual information proxy via discretization
        nbins <- max(5, min(20, floor(sqrt(min_len))))
        ha <- cut(summaries[[a]], breaks = nbins)
        hb <- cut(summaries[[b]], breaks = nbins)
        joint <- table(ha, hb)
        joint_p <- joint / sum(joint)
        pa <- rowSums(joint_p)
        pb <- colSums(joint_p)
        mi <- 0
        for (ii in seq_len(nrow(joint_p))) {
          for (jj in seq_len(ncol(joint_p))) {
            if (joint_p[ii, jj] > 0 && pa[ii] > 0 && pb[jj] > 0) {
              mi <- mi + joint_p[ii, jj] * log(joint_p[ii, jj] / (pa[ii] * pb[jj]))
            }
          }
        }
        val <- mi
      }
      coupling[a, b] <- val
      coupling[b, a] <- val
    }
  }
  diag(coupling) <- 1

  # Extract structural adjacency submatrix
  B <- projectBoneGraph(hg)
  B_sub <- B[matched_bones, matched_bones, drop = FALSE]
  rownames(B_sub) <- colnames(B_sub) <- mapping$bone_name[valid]

  # Mantel test
  mantel <- .mantelTest(coupling, B_sub, n_perm = 999)

  list(
    kinematic_coupling = coupling,
    structural_matrix = B_sub,
    correlation = mantel$r,
    p_value = mantel$p_value,
    mapped_sensors = mapping
  )
}


#' IMU-based Impact Prediction
#'
#' Computes bone stress from IMU acceleration/angular velocity data and
#' propagates it through the MSK incidence matrix to predict muscle
#' vulnerability.
#'
#' @param imu_data A named list of per-sensor data, or a matrix (see
#'   \code{imuNetworkKinematics} for formats).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param mapping Pre-computed mapping (optional).
#' @param stress_metric Character: \code{"acceleration"} (peak linear
#'   acceleration), \code{"angular_velocity"} (peak angular velocity),
#'   \code{"jerk"} (peak rate of change of acceleration),
#'   \code{"composite"} (weighted combination of acceleration + angular velocity).
#' @param use_proxy Logical, use degree-based proxy for impact deviation
#'   (faster) or run full simulation.
#' @return A list with:
#'   \describe{
#'     \item{vulnerability}{Named numeric vector of muscle vulnerability scores}
#'     \item{bone_stress}{Named numeric vector of bone stress}
#'     \item{muscle_stress_exposure}{Named numeric of stress propagated to muscles}
#'     \item{ranking}{Data frame ranked by vulnerability (descending)}
#'   }
#' @export
imuImpactPrediction <- function(imu_data, hg = NULL, mapping = NULL,
                                 stress_metric = c("acceleration",
                                                    "angular_velocity",
                                                    "jerk", "composite"),
                                 use_proxy = TRUE) {
  stress_metric <- match.arg(stress_metric)
  hg <- .ensureHypergraph(hg)

  # Parse IMU data
  sensor_data <- .parseIMUDataRaw(imu_data)

  sensor_names <- names(sensor_data)
  if (is.null(mapping)) {
    mapping <- imuToMSKMapping(sensor_names, hg = hg)
  }
  if (nrow(mapping) == 0L) {
    return(list(
      vulnerability = numeric(0),
      bone_stress = numeric(0),
      muscle_stress_exposure = numeric(0),
      ranking = data.frame(muscle = character(0), vulnerability = numeric(0),
                           stress_exposure = numeric(0),
                           stringsAsFactors = FALSE)
    ))
  }
  mapping <- mapping[!duplicated(mapping$bone_idx), ]

  # Compute per-bone stress
  bone_stress <- numeric(hg$n_bones)
  names(bone_stress) <- hg$bone_names

  for (i in seq_len(nrow(mapping))) {
    sensor <- mapping$sensor_name[i]
    bone_idx <- mapping$bone_idx[i]

    sd <- sensor_data[[sensor]]
    if (is.null(sd)) {
      idx <- which(tolower(names(sensor_data)) == tolower(sensor))
      if (length(idx) > 0) sd <- sensor_data[[idx[1]]]
    }
    if (is.null(sd)) next

    stress_val <- .computeIMUStress(sd, stress_metric)
    bone_stress[bone_idx] <- stress_val
  }

  # Propagate through incidence matrix: muscle_stress = C' * bone_stress
  C <- as.matrix(hg$C)
  muscle_stress <- as.numeric(t(C) %*% bone_stress)
  names(muscle_stress) <- hg$muscle_names

  # Impact deviation (proxy or simulation)
  deg <- hyperedgeDegree(hg)
  if (use_proxy) {
    # Degree-based proxy: deviation proportional to degree
    mean_deg <- mean(deg)
    sd_deg <- sd(deg)
    if (sd_deg == 0) sd_deg <- 1
    impact_dev <- abs((deg - mean_deg) / sd_deg)
  } else {
    sim <- mskSimulate(hg)
    scores <- mskImpactScoreAll(sim)
    impact_dev <- abs(mskImpactDeviation(scores, hg))
  }

  # Vulnerability = stress_exposure * impact_deviation
  vulnerability <- muscle_stress * impact_dev
  names(vulnerability) <- hg$muscle_names

  # Ranking
  ord <- order(vulnerability, decreasing = TRUE)
  ranking <- data.frame(
    muscle = hg$muscle_names[ord],
    vulnerability = vulnerability[ord],
    stress_exposure = muscle_stress[ord],
    impact_deviation = impact_dev[ord],
    stringsAsFactors = FALSE
  )
  rownames(ranking) <- NULL

  list(
    vulnerability = vulnerability,
    bone_stress = bone_stress,
    muscle_stress_exposure = muscle_stress,
    ranking = ranking
  )
}


#' IMU-based Community Dynamics
#'
#' Analyzes movement synchrony from IMU sensors in the context of MSK network
#' communities. Computes within-community vs between-community sensor
#' synchrony and tests for significance.
#'
#' @param imu_data Named list of per-sensor data (see \code{imuNetworkKinematics}).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param gamma Numeric, resolution parameter for community detection (default 4.3).
#' @param mapping Pre-computed mapping (optional).
#' @param window_sec Numeric or NULL. If provided, computes time-resolved
#'   synchrony in sliding windows of this duration (seconds). Requires
#'   \code{sampling_rate} attribute on sensor data.
#' @return A list with:
#'   \describe{
#'     \item{within_community_sync}{Mean synchrony within communities}
#'     \item{between_community_sync}{Mean synchrony between communities}
#'     \item{ratio}{Within/between ratio}
#'     \item{p_value}{Wilcoxon test p-value}
#'     \item{time_resolved}{Data frame if window_sec provided, NULL otherwise}
#'   }
#' @export
imuCommunityDynamics <- function(imu_data, hg = NULL, gamma = 4.3,
                                  mapping = NULL, window_sec = NULL) {
  hg <- .ensureHypergraph(hg)

  sensor_signals <- .parseIMUData(imu_data, "acceleration")
  sensor_names <- names(sensor_signals)

  if (is.null(mapping)) {
    mapping <- imuToMSKMapping(sensor_names, hg = hg)
  }

  mapping <- mapping[!duplicated(mapping$bone_idx), ]
  if (nrow(mapping) < 2L) {
    return(list(
      within_community_sync = NA_real_,
      between_community_sync = NA_real_,
      ratio = NA_real_,
      p_value = NA_real_,
      time_resolved = NULL
    ))
  }

  matched_sensors <- mapping$sensor_name
  matched_bones <- mapping$bone_idx

  # Compute 1D summaries
  summaries <- lapply(matched_sensors, function(s) {
    sig <- sensor_signals[[s]]
    if (is.null(sig)) {
      idx <- which(tolower(names(sensor_signals)) == tolower(s))
      if (length(idx) > 0) sig <- sensor_signals[[idx[1]]]
    }
    if (is.null(sig)) return(NULL)
    if (is.matrix(sig) && ncol(sig) >= 3) {
      sqrt(rowSums(sig[, 1:3, drop = FALSE]^2))
    } else if (is.matrix(sig)) {
      sqrt(rowSums(sig^2))
    } else {
      as.numeric(sig)
    }
  })

  valid <- !vapply(summaries, is.null, logical(1))
  if (sum(valid) < 2L) {
    return(list(
      within_community_sync = NA_real_,
      between_community_sync = NA_real_,
      ratio = NA_real_, p_value = NA_real_,
      time_resolved = NULL
    ))
  }

  matched_sensors <- matched_sensors[valid]
  matched_bones <- matched_bones[valid]
  summaries <- summaries[valid]
  n_matched <- length(matched_bones)

  min_len <- min(vapply(summaries, length, integer(1)))
  summaries <- lapply(summaries, function(x) x[seq_len(min_len)])

  # Community detection on bone graph
  comm_result <- mskCommunityDetect(hg, gamma = gamma)
  # Map bone communities via incidence: each bone gets the community of

  # its most-connected muscle
  C <- as.matrix(hg$C)
  bone_communities <- integer(hg$n_bones)
  for (b in seq_len(hg$n_bones)) {
    muscles_on_bone <- which(C[b, ] > 0)
    if (length(muscles_on_bone) > 0) {
      bone_communities[b] <- as.integer(
        names(sort(table(comm_result$membership[muscles_on_bone]),
                   decreasing = TRUE))[1]
      )
    }
  }

  sensor_comms <- bone_communities[matched_bones]

  # Pairwise synchrony
  within_vals <- numeric(0)
  between_vals <- numeric(0)

  for (a in seq_len(n_matched - 1L)) {
    for (b in (a + 1L):n_matched) {
      sync <- abs(cor(summaries[[a]], summaries[[b]]))
      if (sensor_comms[a] == sensor_comms[b]) {
        within_vals <- c(within_vals, sync)
      } else {
        between_vals <- c(between_vals, sync)
      }
    }
  }

  within_sync <- if (length(within_vals) > 0) mean(within_vals) else NA_real_
  between_sync <- if (length(between_vals) > 0) mean(between_vals) else NA_real_
  ratio <- if (!is.na(within_sync) && !is.na(between_sync) && between_sync > 0) {
    within_sync / between_sync
  } else {
    NA_real_
  }

  # Wilcoxon test
  p_val <- if (length(within_vals) > 0 && length(between_vals) > 0) {
    tryCatch(
      wilcox.test(within_vals, between_vals,
                  alternative = "greater")$p.value,
      error = function(e) NA_real_
    )
  } else {
    NA_real_
  }

  # Time-resolved analysis (optional)
  time_resolved <- NULL
  if (!is.null(window_sec)) {
    sr <- attr(imu_data, "sr")
    if (is.null(sr)) sr <- attr(imu_data[[1]], "sr")
    if (is.null(sr)) sr <- 100  # default fallback

    win_samples <- max(10L, floor(window_sec * sr))
    n_windows <- floor(min_len / win_samples)

    if (n_windows >= 2L) {
      tr_list <- list()
      for (w in seq_len(n_windows)) {
        start <- (w - 1L) * win_samples + 1L
        end <- min(w * win_samples, min_len)
        w_within <- numeric(0)
        w_between <- numeric(0)

        for (a in seq_len(n_matched - 1L)) {
          for (b in (a + 1L):n_matched) {
            sync <- abs(cor(summaries[[a]][start:end],
                           summaries[[b]][start:end]))
            if (sensor_comms[a] == sensor_comms[b]) {
              w_within <- c(w_within, sync)
            } else {
              w_between <- c(w_between, sync)
            }
          }
        }

        tr_list[[w]] <- data.frame(
          window = w,
          time_start = (start - 1) / sr,
          within_sync = if (length(w_within) > 0) mean(w_within) else NA_real_,
          between_sync = if (length(w_between) > 0) mean(w_between) else NA_real_,
          stringsAsFactors = FALSE
        )
      }
      time_resolved <- do.call(rbind, tr_list)
    }
  }

  list(
    within_community_sync = within_sync,
    between_community_sync = between_sync,
    ratio = ratio,
    p_value = p_val,
    time_resolved = time_resolved
  )
}


# ---- Internal IMU data parsing helpers ----

#' Parse IMU data into per-sensor signal matrices
#'
#' Handles multiple input formats: named list of matrices, single wide matrix
#' with sensor-prefixed column names, etc.
#'
#' @param imu_data Input IMU data (list or matrix)
#' @param signal_type "orientation" or "acceleration"
#' @return Named list of per-sensor numeric matrices/vectors
#' @keywords internal
.parseIMUData <- function(imu_data, signal_type) {
  if (is.list(imu_data) && !is.data.frame(imu_data)) {
    # Already a named list
    return(imu_data)
  }

  if (is.matrix(imu_data) || is.data.frame(imu_data)) {
    cnames <- colnames(imu_data)
    if (is.null(cnames)) {
      return(list(sensor1 = as.matrix(imu_data)))
    }

    # Try to parse sensor_axis pattern (e.g., "upper_arm_ax", "thigh_roll")
    if (signal_type == "orientation") {
      suffixes <- c("_roll", "_pitch", "_yaw")
    } else {
      suffixes <- c("_ax", "_ay", "_az", "_x", "_y", "_z")
    }

    sensors <- unique(gsub(paste(suffixes, collapse = "|"), "", cnames))
    sensors <- sensors[nchar(sensors) > 0]

    if (length(sensors) > 0) {
      result <- list()
      for (s in sensors) {
        cols <- grep(paste0("^", s), cnames)
        if (length(cols) >= 1) {
          result[[s]] <- as.matrix(imu_data[, cols, drop = FALSE])
        }
      }
      return(result)
    }

    return(list(sensor1 = as.matrix(imu_data)))
  }

  stop("imu_data must be a named list or matrix", call. = FALSE)
}

#' Parse raw IMU data preserving all channels
#' @param imu_data Input IMU data
#' @return Named list of per-sensor data (lists or matrices)
#' @keywords internal
.parseIMUDataRaw <- function(imu_data) {
  if (is.list(imu_data) && !is.data.frame(imu_data)) {
    return(imu_data)
  }
  .parseIMUData(imu_data, "acceleration")
}


#' Compute bone stress from IMU sensor data
#'
#' @param sensor_data Per-sensor data (matrix, data.frame, or list with
#'   accel/gyro components)
#' @param metric Stress metric type
#' @return Numeric scalar stress value
#' @keywords internal
.computeIMUStress <- function(sensor_data, metric) {
  # Extract acceleration and angular velocity
  if (is.list(sensor_data) && !is.data.frame(sensor_data)) {
    accel <- sensor_data$accel
    gyro <- sensor_data$gyro
  } else if (is.data.frame(sensor_data)) {
    accel_cols <- grep("^(ax|ay|az|accel)", names(sensor_data), value = TRUE)
    gyro_cols <- grep("^(gx|gy|gz|gyro|angular)", names(sensor_data), value = TRUE)
    accel <- if (length(accel_cols) >= 3) as.matrix(sensor_data[, accel_cols[1:3]]) else NULL
    gyro <- if (length(gyro_cols) >= 3) as.matrix(sensor_data[, gyro_cols[1:3]]) else NULL

    if (is.null(accel) && is.null(gyro)) {
      # Treat all numeric columns as signal
      accel <- as.matrix(sensor_data[, vapply(sensor_data, is.numeric, logical(1))])
    }
  } else if (is.matrix(sensor_data)) {
    if (ncol(sensor_data) >= 6) {
      accel <- sensor_data[, 1:3]
      gyro <- sensor_data[, 4:6]
    } else {
      accel <- sensor_data[, seq_len(min(3, ncol(sensor_data))), drop = FALSE]
      gyro <- NULL
    }
  } else {
    return(0)
  }

  switch(metric,
    acceleration = {
      if (!is.null(accel)) {
        mag <- sqrt(rowSums(accel^2))
        max(mag, na.rm = TRUE)
      } else 0
    },
    angular_velocity = {
      if (!is.null(gyro)) {
        mag <- sqrt(rowSums(gyro^2))
        max(mag, na.rm = TRUE)
      } else if (!is.null(accel)) {
        # Fallback: estimate from acceleration differences
        diff_accel <- diff(accel)
        mag <- sqrt(rowSums(diff_accel^2))
        max(mag, na.rm = TRUE)
      } else 0
    },
    jerk = {
      if (!is.null(accel)) {
        diff_accel <- diff(accel)
        mag <- sqrt(rowSums(diff_accel^2))
        max(mag, na.rm = TRUE)
      } else 0
    },
    composite = {
      accel_stress <- if (!is.null(accel)) {
        max(sqrt(rowSums(accel^2)), na.rm = TRUE)
      } else 0
      gyro_stress <- if (!is.null(gyro)) {
        max(sqrt(rowSums(gyro^2)), na.rm = TRUE)
      } else 0
      0.6 * accel_stress + 0.4 * gyro_stress
    },
    0
  )
}
