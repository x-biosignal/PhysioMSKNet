# ===========================================================================
# bridge-neuromech.R -- Integrated neuromechanics pipeline
# ===========================================================================
#
# Orchestrates EEG -> EMG -> Force -> Kinematics analysis by connecting
# cortical signals (EEG), muscle activation (EMG), mechanical output
# (force/kinematics) through the MSK hypergraph structure.
#
# Reuses: emgToMSKMapping, mocapToMSKMapping, imuToMSKMapping,
#   .ensureHypergraph, .mantelTest, projectMuscleGraph, projectBoneGraph,
#   mskCommunityDetect, mskShortestPaths, hyperedgeDegree
# ===========================================================================

# ---- Internal helpers ----

#' Extract signal matrix from various input types
#'
#' Unified input extraction: accepts PhysioExperiment/SummarizedExperiment,
#' matrix, or numeric vector. Returns standardized list.
#'
#' @param pe Input data (SummarizedExperiment, matrix, or numeric vector).
#' @param type_label Character label for error messages (e.g., "EEG", "EMG").
#' @return A list with: signal_mat (time x channels matrix), sr (sampling rate),
#'   ch_names (channel name character vector).
#' @keywords internal
.extractSignalMatrix <- function(pe, type_label = "signal") {
  if (is.numeric(pe) && is.null(dim(pe))) {
    # Numeric vector -> single-channel matrix
    mat <- matrix(pe, ncol = 1)
    colnames(mat) <- paste0(type_label, "_1")
    return(list(signal_mat = mat, sr = NULL, ch_names = colnames(mat)))
  }

  if (is.matrix(pe) || is.data.frame(pe)) {
    mat <- as.matrix(pe)
    sr <- attr(pe, "sr")
    ch_names <- colnames(mat) %||% paste0(type_label, "_", seq_len(ncol(mat)))
    colnames(mat) <- ch_names
    return(list(signal_mat = mat, sr = sr, ch_names = ch_names))
  }

  # SummarizedExperiment-like
  mat <- tryCatch(
    as.matrix(pe@assays@data[[1]]),
    error = function(e) stop("Cannot extract signal matrix from ", type_label,
                             " input", call. = FALSE)
  )
  sr <- tryCatch(pe@samplingRate, error = function(e) NULL)
  ch_names <- tryCatch(
    colnames(pe@assays@data[[1]]),
    error = function(e) NULL
  )
  if (is.null(ch_names)) ch_names <- paste0(type_label, "_", seq_len(ncol(mat)))
  colnames(mat) <- ch_names

  list(signal_mat = mat, sr = sr, ch_names = ch_names)
}


#' Minimal corticomuscular coherence (Welch method)
#'
#' Fallback EEG-EMG coherence when PhysioCrossModal is unavailable.
#' Computes pairwise coherence between EEG and EMG channels using Welch's method.
#'
#' @param eeg_mat Numeric matrix (time x EEG channels).
#' @param emg_mat Numeric matrix (time x EMG channels).
#' @param sr Numeric, sampling rate in Hz.
#' @param freq_band Numeric vector of length 2, frequency band in Hz.
#' @param nperseg Integer, segment length for Welch's method.
#' @return Coherence matrix (n_eeg x n_emg) in \[0, 1\].
#' @keywords internal
.minimalCMC <- function(eeg_mat, emg_mat, sr, freq_band = c(15, 35),
                        nperseg = 256L) {
  n_eeg <- ncol(eeg_mat)
  n_emg <- ncol(emg_mat)
  n_time <- min(nrow(eeg_mat), nrow(emg_mat))

  eeg_mat <- eeg_mat[seq_len(n_time), , drop = FALSE]
  emg_mat <- emg_mat[seq_len(n_time), , drop = FALSE]

  if (n_time < nperseg) nperseg <- n_time

  # Hanning window
  window <- 0.5 * (1 - cos(2 * pi * seq(0, nperseg - 1) / (nperseg - 1)))

  # Frequency resolution
  freqs <- seq(0, sr / 2, length.out = floor(nperseg / 2) + 1)
  freq_idx <- which(freqs >= freq_band[1] & freqs <= freq_band[2])

  if (length(freq_idx) == 0) {
    coh <- matrix(0, n_eeg, n_emg)
    rownames(coh) <- colnames(eeg_mat)
    colnames(coh) <- colnames(emg_mat)
    return(coh)
  }

  n_freq <- length(freqs)
  n_segments <- max(1L, floor(2 * n_time / nperseg) - 1)
  hop <- max(1L, floor((n_time - nperseg) / max(1, n_segments - 1)))

  # Accumulators
  Sxx_eeg <- matrix(0, n_freq, n_eeg)
  Sxx_emg <- matrix(0, n_freq, n_emg)
  Sxy <- array(0 + 0i, dim = c(n_freq, n_eeg, n_emg))

  seg_count <- 0L
  for (s in seq_len(n_segments)) {
    start <- (s - 1) * hop + 1
    end <- start + nperseg - 1
    if (end > n_time) break
    seg_count <- seg_count + 1L

    # Windowed FFT for EEG
    fft_eeg <- matrix(0 + 0i, n_freq, n_eeg)
    for (ch in seq_len(n_eeg)) {
      seg <- eeg_mat[start:end, ch] * window
      ft <- stats::fft(seg)
      fft_eeg[, ch] <- ft[seq_len(n_freq)]
    }

    # Windowed FFT for EMG
    fft_emg <- matrix(0 + 0i, n_freq, n_emg)
    for (ch in seq_len(n_emg)) {
      seg <- emg_mat[start:end, ch] * window
      ft <- stats::fft(seg)
      fft_emg[, ch] <- ft[seq_len(n_freq)]
    }

    # Auto spectra
    Sxx_eeg <- Sxx_eeg + abs(fft_eeg)^2
    Sxx_emg <- Sxx_emg + abs(fft_emg)^2

    # Cross spectra
    for (i in seq_len(n_eeg)) {
      for (j in seq_len(n_emg)) {
        Sxy[, i, j] <- Sxy[, i, j] + fft_eeg[, i] * Conj(fft_emg[, j])
      }
    }
  }

  if (seg_count == 0L) seg_count <- 1L
  Sxx_eeg <- Sxx_eeg / seg_count
  Sxx_emg <- Sxx_emg / seg_count
  Sxy <- Sxy / seg_count

  # Build coherence matrix (average over freq band)
  coh <- matrix(0, n_eeg, n_emg)
  for (i in seq_len(n_eeg)) {
    for (j in seq_len(n_emg)) {
      num <- mean(abs(Sxy[freq_idx, i, j])^2)
      denom <- mean(Sxx_eeg[freq_idx, i]) * mean(Sxx_emg[freq_idx, j])
      coh[i, j] <- if (denom > 0) num / denom else 0
    }
  }

  # Clamp to [0, 1]
  coh <- pmin(pmax(coh, 0), 1)
  rownames(coh) <- colnames(eeg_mat)
  colnames(coh) <- colnames(emg_mat)
  coh
}


#' Minimal cross-correlation for electromechanical delay
#'
#' Fallback cross-correlation when PhysioCrossModal is unavailable.
#'
#' @param x Numeric vector (signal 1).
#' @param y Numeric vector (signal 2, same length as x).
#' @param max_lag Integer, maximum lag to compute.
#' @return A list with: peak_lag, peak_correlation, correlation (vector),
#'   lags (integer vector).
#' @keywords internal
.minimalCrossCorrelation <- function(x, y, max_lag) {
  n <- min(length(x), length(y))
  x <- x[seq_len(n)]
  y <- y[seq_len(n)]

  # Normalize
  x <- x - mean(x)
  y <- y - mean(y)
  sx <- sd(x)
  sy <- sd(y)

  if (sx == 0 || sy == 0) {
    return(list(
      peak_lag = 0L,
      peak_correlation = 0,
      correlation = rep(0, 2 * max_lag + 1),
      lags = seq(-max_lag, max_lag)
    ))
  }

  lags <- seq(-max_lag, max_lag)
  cors <- numeric(length(lags))

  for (k in seq_along(lags)) {
    lag <- lags[k]
    if (lag >= 0) {
      idx_x <- seq_len(n - lag)
      idx_y <- idx_x + lag
    } else {
      idx_y <- seq_len(n + lag)
      idx_x <- idx_y - lag
    }
    if (length(idx_x) < 3) {
      cors[k] <- 0
      next
    }
    cors[k] <- cor(x[idx_x], y[idx_y])
  }

  cors[is.na(cors)] <- 0
  peak_idx <- which.max(abs(cors))

  list(
    peak_lag = lags[peak_idx],
    peak_correlation = cors[peak_idx],
    correlation = cors,
    lags = lags
  )
}


#' Compute per-channel RMS
#'
#' @param signal_mat Numeric matrix (time x channels).
#' @return Named numeric vector of RMS values.
#' @keywords internal
.computeRMS <- function(signal_mat) {
  rms <- vapply(seq_len(ncol(signal_mat)), function(ch) {
    sqrt(mean(signal_mat[, ch]^2))
  }, numeric(1))
  names(rms) <- colnames(signal_mat)
  rms
}


#' Map 10-20 EEG channel names to cortical regions
#'
#' Maps standard 10-20 system EEG channel names to cortical regions
#' (motor, premotor, somatosensory, frontal, parietal, temporal, occipital).
#'
#' @return A data.frame with columns: eeg_name, region, is_motor.
#' @keywords internal
.eegChannelLookup <- function() {
  data.frame(
    eeg_name = c(
      # Motor cortex (C channels)
      "C1", "C2", "C3", "C4", "Cz", "C5", "C6",
      # Premotor / supplementary motor (FC channels)
      "FC1", "FC2", "FC3", "FC4", "FC5", "FC6", "FCz",
      # Somatosensory (CP channels)
      "CP1", "CP2", "CP3", "CP4", "CP5", "CP6", "CPz",
      # Frontal
      "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "Fz",
      "Fp1", "Fp2", "Fpz", "AF3", "AF4", "AFz",
      # Parietal
      "P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8", "Pz",
      # Temporal
      "T3", "T4", "T5", "T6", "T7", "T8",
      # Occipital
      "O1", "O2", "Oz"
    ),
    region = c(
      rep("motor", 7),
      rep("premotor", 7),
      rep("somatosensory", 7),
      rep("frontal", 15),
      rep("parietal", 9),
      rep("temporal", 6),
      rep("occipital", 3)
    ),
    is_motor = c(
      rep(TRUE, 7),   # motor cortex
      rep(TRUE, 7),   # premotor
      rep(TRUE, 7),   # somatosensory
      rep(FALSE, 15), # frontal
      rep(FALSE, 9),  # parietal
      rep(FALSE, 6),  # temporal
      rep(FALSE, 3)   # occipital
    ),
    stringsAsFactors = FALSE
  )
}


# ---- Exported functions ----

#' Corticomuscular Coherence in MSK Network Context
#'
#' Computes pairwise corticomuscular coherence (CMC) between EEG and EMG
#' channels, maps EMG channels to MSK muscles, builds a CMC-based
#' functional distance matrix, and compares it with the structural
#' muscle adjacency via Mantel test.
#'
#' @param eeg EEG data: a SummarizedExperiment, numeric matrix (time x channels),
#'   or numeric vector.
#' @param emg EMG data: a SummarizedExperiment, numeric matrix (time x channels),
#'   or numeric vector.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param freq_band Numeric vector of length 2, frequency band in Hz for CMC
#'   (default: c(15, 35) for beta range).
#' @param eeg_channels Optional character vector of EEG channel names to use.
#'   If NULL, motor cortex channels are auto-selected via \code{.eegChannelLookup()}.
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param sr_eeg Optional sampling rate for EEG (overrides detected value).
#' @param sr_emg Optional sampling rate for EMG (overrides detected value).
#' @param nperseg Integer, segment length for Welch's method (default: 256).
#' @param n_perm Integer, number of permutations for Mantel test (default: 999).
#' @return An S3 object of class \code{"MSKNeuromechCMC"} with:
#'   \describe{
#'     \item{cmc_matrix}{Coherence matrix (n_eeg x n_emg)}
#'     \item{structural_matrix}{MSK muscle adjacency (matched subset)}
#'     \item{emg_cmc_profile}{Per-muscle mean CMC across EEG channels}
#'     \item{significant_pairs}{Data.frame of significant EEG-EMG pairs}
#'     \item{mantel}{Mantel test result (correlation, p_value)}
#'     \item{mapping}{EMG-to-muscle mapping used}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- neuromechCorticomuscularCoupling(eeg_data, emg_data)
#' }
neuromechCorticomuscularCoupling <- function(eeg, emg, hg = NULL,
                                             freq_band = c(15, 35),
                                             eeg_channels = NULL,
                                             emg_mapping = NULL,
                                             sr_eeg = NULL, sr_emg = NULL,
                                             nperseg = 256L,
                                             n_perm = 999L) {
  hg <- .ensureHypergraph(hg)

  # Extract EEG signal
  eeg_data <- .extractSignalMatrix(eeg, "EEG")
  eeg_mat <- eeg_data$signal_mat
  sr_eeg <- sr_eeg %||% eeg_data$sr %||% 1000

  # Select motor cortex EEG channels if not specified
  if (!is.null(eeg_channels)) {
    keep <- which(eeg_data$ch_names %in% eeg_channels)
    if (length(keep) == 0) {
      warning("No specified eeg_channels found; using all channels")
    } else {
      eeg_mat <- eeg_mat[, keep, drop = FALSE]
    }
  } else {
    lookup <- .eegChannelLookup()
    motor_names <- lookup$eeg_name[lookup$is_motor]
    keep <- which(eeg_data$ch_names %in% motor_names)
    if (length(keep) > 0) {
      eeg_mat <- eeg_mat[, keep, drop = FALSE]
    }
    # If no motor channels found, use all channels
  }

  # Extract EMG signal
  emg_data <- .extractSignalMatrix(emg, "EMG")
  emg_mat <- emg_data$signal_mat
  sr_emg <- sr_emg %||% emg_data$sr %||% 1000

  # Resample if needed (simple: use minimum common rate)
  sr <- min(sr_eeg, sr_emg)

  # Get EMG-to-muscle mapping
  if (is.null(emg_mapping)) {
    emg_mapping <- emgToMSKMapping(colnames(emg_mat), hg = hg, method = "fuzzy")
  }

  # Compute CMC matrix (n_eeg x n_emg)
  if (requireNamespace("PhysioCrossModal", quietly = TRUE)) {
    cmc_matrix <- tryCatch(
      PhysioCrossModal::coherence(eeg_mat, emg_mat, sr = sr, nperseg = nperseg,
                                   freq_band = freq_band),
      error = function(e) .minimalCMC(eeg_mat, emg_mat, sr, freq_band, nperseg)
    )
  } else {
    cmc_matrix <- .minimalCMC(eeg_mat, emg_mat, sr, freq_band, nperseg)
  }

  # Per-muscle CMC profile (mean CMC across EEG channels per EMG channel)
  emg_cmc_profile <- colMeans(cmc_matrix)
  names(emg_cmc_profile) <- colnames(emg_mat)

  # Significant pairs (above median threshold)
  threshold <- median(cmc_matrix[cmc_matrix > 0])
  if (is.na(threshold) || threshold == 0) threshold <- 0.01
  sig_idx <- which(cmc_matrix > threshold, arr.ind = TRUE)
  if (nrow(sig_idx) > 0) {
    significant_pairs <- data.frame(
      eeg_channel = rownames(cmc_matrix)[sig_idx[, 1]],
      emg_channel = colnames(cmc_matrix)[sig_idx[, 2]],
      coherence = cmc_matrix[sig_idx],
      stringsAsFactors = FALSE
    )
    significant_pairs <- significant_pairs[order(significant_pairs$coherence,
                                                  decreasing = TRUE), ]
    rownames(significant_pairs) <- NULL
  } else {
    significant_pairs <- data.frame(
      eeg_channel = character(0),
      emg_channel = character(0),
      coherence = numeric(0),
      stringsAsFactors = FALSE
    )
  }

  # Build muscle-muscle functional distance from CMC profile
  # Only for mapped EMG channels
  mantel_result <- list(correlation = NA_real_, p_value = NA_real_)
  structural_matrix <- matrix(nrow = 0, ncol = 0)

  if (nrow(emg_mapping) >= 3) {
    mapped_emg_idx <- emg_mapping$channel_idx
    mapped_cmc <- emg_cmc_profile[mapped_emg_idx]

    # Functional distance: |cmc_i - cmc_j| (dissimilarity)
    n_mapped <- length(mapped_cmc)
    func_dist <- matrix(0, n_mapped, n_mapped)
    for (i in seq_len(n_mapped - 1)) {
      for (j in (i + 1):n_mapped) {
        func_dist[i, j] <- func_dist[j, i] <- abs(mapped_cmc[i] - mapped_cmc[j])
      }
    }
    rownames(func_dist) <- colnames(func_dist) <- emg_mapping$muscle_name

    # Structural adjacency
    B <- as.matrix(projectMuscleGraph(hg))
    m_idx <- emg_mapping$muscle_idx
    structural_matrix <- (B[m_idx, m_idx, drop = FALSE] > 0) * 1.0
    rownames(structural_matrix) <- colnames(structural_matrix) <- emg_mapping$muscle_name

    # Mantel test
    mantel_result <- .mantelTest(func_dist, structural_matrix, n_perm = n_perm)
  }

  structure(
    list(
      cmc_matrix = cmc_matrix,
      structural_matrix = structural_matrix,
      emg_cmc_profile = emg_cmc_profile,
      significant_pairs = significant_pairs,
      mantel = mantel_result,
      mapping = emg_mapping
    ),
    class = "MSKNeuromechCMC"
  )
}


#' Electromechanical Delay via Cross-Correlation
#'
#' Computes the electromechanical delay (EMD) between EMG and kinematic
#' signals for muscle-bone pairs connected in the MSK hypergraph. Optionally
#' correlates EMD with MSK network distance.
#'
#' @param emg EMG data: SummarizedExperiment, matrix (time x channels), or vector.
#' @param kinematics Kinematic data: matrix (time x segments) or SummarizedExperiment.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param kin_mapping Optional pre-computed data.frame from
#'   \code{mocapToMSKMapping()} or \code{imuToMSKMapping()}.
#' @param sr Optional sampling rate (overrides detected value).
#' @param max_lag_ms Numeric, maximum lag in milliseconds (default: 200).
#' @param window_sec Optional numeric, window size in seconds for sliding window
#'   EMD analysis (NULL for global only).
#' @param n_perm Integer, number of permutations for correlation test (default: 999).
#' @return A list with:
#'   \describe{
#'     \item{emd}{Data.frame with muscle, bone, emd_ms, peak_correlation per pair}
#'     \item{network_distance}{Corresponding MSK shortest path distance}
#'     \item{correlation}{Pearson correlation between EMD and network distance}
#'     \item{p_value}{Permutation p-value for the correlation}
#'     \item{time_varying}{Data.frame with per-window EMD (if window_sec set)}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- neuromechElectromechanicalDelay(emg_data, kin_data)
#' }
neuromechElectromechanicalDelay <- function(emg, kinematics, hg = NULL,
                                            emg_mapping = NULL,
                                            kin_mapping = NULL,
                                            sr = NULL,
                                            max_lag_ms = 200,
                                            window_sec = NULL,
                                            n_perm = 999L) {
  hg <- .ensureHypergraph(hg)

  # Extract EMG
  emg_data <- .extractSignalMatrix(emg, "EMG")
  emg_mat <- emg_data$signal_mat
  sr <- sr %||% emg_data$sr %||% 1000

  # Extract kinematics
  kin_data <- .extractSignalMatrix(kinematics, "KIN")
  kin_mat <- kin_data$signal_mat

  # Get mappings
  if (is.null(emg_mapping)) {
    emg_mapping <- emgToMSKMapping(colnames(emg_mat), hg = hg, method = "fuzzy")
  }
  if (is.null(kin_mapping)) {
    kin_mapping <- mocapToMSKMapping(colnames(kin_mat), hg = hg, method = "fuzzy")
    if (nrow(kin_mapping) == 0) {
      kin_mapping <- imuToMSKMapping(colnames(kin_mat), hg = hg, method = "fuzzy")
      if (nrow(kin_mapping) > 0) {
        # Rename to uniform column names
        names(kin_mapping)[names(kin_mapping) == "sensor_name"] <- "segment_name"
      }
    }
  }

  # Find muscle-bone pairs via incidence matrix
  C <- as.matrix(hg$C)
  max_lag_samples <- max(1L, round(max_lag_ms / 1000 * sr))

  emd_rows <- list()

  if (nrow(emg_mapping) > 0 && nrow(kin_mapping) > 0) {
    kin_mapping_dedup <- kin_mapping[!duplicated(kin_mapping$bone_idx), ]

    for (ei in seq_len(nrow(emg_mapping))) {
      muscle_idx <- emg_mapping$muscle_idx[ei]
      emg_ch_idx <- emg_mapping$channel_idx[ei]

      for (ki in seq_len(nrow(kin_mapping_dedup))) {
        bone_idx <- kin_mapping_dedup$bone_idx[ki]

        # Check if muscle connects to this bone
        if (C[bone_idx, muscle_idx] > 0) {
          seg_name <- kin_mapping_dedup$segment_name[ki]
          kin_col <- match(seg_name, colnames(kin_mat))
          if (is.na(kin_col)) next

          # Truncate to common length
          n_common <- min(nrow(emg_mat), nrow(kin_mat))
          emg_sig <- emg_mat[seq_len(n_common), emg_ch_idx]
          kin_sig <- kin_mat[seq_len(n_common), kin_col]

          # Use EMG envelope (rectified + smoothed) for cross-correlation
          emg_env <- abs(emg_sig)

          # Cross-correlation
          if (requireNamespace("PhysioCrossModal", quietly = TRUE)) {
            cc <- tryCatch(
              PhysioCrossModal::crossCorrelation(emg_env, kin_sig,
                                                  max_lag = max_lag_samples),
              error = function(e) {
                .minimalCrossCorrelation(emg_env, kin_sig, max_lag_samples)
              }
            )
          } else {
            cc <- .minimalCrossCorrelation(emg_env, kin_sig, max_lag_samples)
          }

          emd_ms <- abs(cc$peak_lag) / sr * 1000

          emd_rows[[length(emd_rows) + 1L]] <- data.frame(
            muscle = emg_mapping$muscle_name[ei],
            bone = kin_mapping_dedup$bone_name[ki],
            muscle_idx = muscle_idx,
            bone_idx = bone_idx,
            emd_ms = round(emd_ms, 2),
            peak_correlation = round(cc$peak_correlation, 4),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }

  if (length(emd_rows) == 0) {
    return(list(
      emd = data.frame(muscle = character(0), bone = character(0),
                        muscle_idx = integer(0), bone_idx = integer(0),
                        emd_ms = numeric(0), peak_correlation = numeric(0),
                        stringsAsFactors = FALSE),
      network_distance = numeric(0),
      correlation = NA_real_,
      p_value = NA_real_,
      time_varying = NULL
    ))
  }

  emd_df <- do.call(rbind, emd_rows)
  rownames(emd_df) <- NULL

  # MSK network distance between muscle-bone pairs
  sp <- mskShortestPaths(hg, type = "muscle")
  net_dist <- numeric(nrow(emd_df))
  for (i in seq_len(nrow(emd_df))) {
    # Distance via muscle graph: find muscles attached to the bone
    bone_muscles <- which(C[emd_df$bone_idx[i], ] > 0)
    if (length(bone_muscles) > 0 && emd_df$muscle_idx[i] <= nrow(sp)) {
      net_dist[i] <- min(sp[emd_df$muscle_idx[i], bone_muscles])
    } else {
      net_dist[i] <- NA_real_
    }
  }

  # Correlation between EMD and network distance
  valid <- is.finite(emd_df$emd_ms) & is.finite(net_dist)
  if (sum(valid) >= 3 && sd(emd_df$emd_ms[valid]) > 0 && sd(net_dist[valid]) > 0) {
    obs_cor <- cor(emd_df$emd_ms[valid], net_dist[valid])
    # Permutation test
    n_geq <- 0L
    for (p in seq_len(n_perm)) {
      perm_cor <- cor(sample(emd_df$emd_ms[valid]), net_dist[valid])
      if (abs(perm_cor) >= abs(obs_cor)) n_geq <- n_geq + 1L
    }
    p_val <- (n_geq + 1L) / (n_perm + 1L)
  } else {
    obs_cor <- NA_real_
    p_val <- NA_real_
  }

  # Sliding window EMD (optional)
  time_varying <- NULL
  if (!is.null(window_sec) && window_sec > 0 && nrow(emd_df) > 0) {
    win_samples <- max(10L, round(window_sec * sr))
    n_common <- min(nrow(emg_mat), nrow(kin_mat))
    n_windows <- max(1, floor(n_common / win_samples))

    if (n_windows >= 2) {
      tv_rows <- list()
      # Use first pair for time-varying analysis
      first_emg_ch <- emg_mapping$channel_idx[1]
      first_kin_seg <- kin_mapping[!duplicated(kin_mapping$bone_idx), ]
      # Find first connected bone
      first_muscle_idx <- emg_mapping$muscle_idx[1]
      connected_bones <- which(C[, first_muscle_idx] > 0)
      matched_bone <- intersect(connected_bones, first_kin_seg$bone_idx)

      if (length(matched_bone) > 0) {
        bone_row <- first_kin_seg[first_kin_seg$bone_idx == matched_bone[1], ]
        first_kin_col <- match(bone_row$segment_name[1], colnames(kin_mat))

        if (!is.na(first_kin_col)) {
          for (w in seq_len(n_windows)) {
            start <- (w - 1) * win_samples + 1
            end <- min(w * win_samples, n_common)
            if (end - start < max_lag_samples * 2) next

            emg_w <- abs(emg_mat[start:end, first_emg_ch])
            kin_w <- kin_mat[start:end, first_kin_col]
            cc_w <- .minimalCrossCorrelation(emg_w, kin_w, max_lag_samples)

            tv_rows[[length(tv_rows) + 1L]] <- data.frame(
              window = w,
              time_start = (start - 1) / sr,
              time_end = (end - 1) / sr,
              emd_ms = round(abs(cc_w$peak_lag) / sr * 1000, 2),
              peak_correlation = round(cc_w$peak_correlation, 4),
              stringsAsFactors = FALSE
            )
          }
        }
      }

      if (length(tv_rows) > 0) {
        time_varying <- do.call(rbind, tv_rows)
        rownames(time_varying) <- NULL
      }
    }
  }

  list(
    emd = emd_df,
    network_distance = net_dist,
    correlation = obs_cor,
    p_value = p_val,
    time_varying = time_varying
  )
}


#' Motor Drive Topography
#'
#' Maps cortical drive (CMC), muscle activation (EMG RMS), and force output
#' to the MSK hypergraph to compute per-muscle drive efficiency and
#' aggregate per community.
#'
#' @param eeg EEG data: SummarizedExperiment, matrix, or vector.
#' @param emg EMG data: SummarizedExperiment, matrix, or vector.
#' @param force_data Force data: named numeric vector (per muscle), data.frame
#'   with columns (muscle, force), or matrix (time x channels for RMS).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param freq_band Numeric vector of length 2, CMC frequency band (default: c(15, 35)).
#' @param gamma Numeric, resolution parameter for community detection (default: 4.3).
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param sr Optional sampling rate.
#' @return A list with:
#'   \describe{
#'     \item{per_muscle}{Data.frame with muscle, cortical_drive, emg_activation,
#'       force, drive_efficiency}
#'     \item{per_community}{Data.frame with community, mean drive/activation/force}
#'     \item{drive_force_correlation}{Pearson r between cortical drive and force}
#'     \item{drive_force_p_value}{p-value for the correlation}
#'   }
#' @importFrom stats cor.test
#' @export
#' @examples
#' \dontrun{
#' result <- neuromechMotorDriveTopography(eeg, emg, force)
#' }
neuromechMotorDriveTopography <- function(eeg, emg, force_data, hg = NULL,
                                          freq_band = c(15, 35),
                                          gamma = 4.3,
                                          emg_mapping = NULL,
                                          sr = NULL) {
  hg <- .ensureHypergraph(hg)

  # Extract EEG and EMG
  eeg_data <- .extractSignalMatrix(eeg, "EEG")
  eeg_mat <- eeg_data$signal_mat
  sr <- sr %||% eeg_data$sr %||% 1000

  emg_data <- .extractSignalMatrix(emg, "EMG")
  emg_mat <- emg_data$signal_mat

  # EMG-to-muscle mapping
  if (is.null(emg_mapping)) {
    emg_mapping <- emgToMSKMapping(colnames(emg_mat), hg = hg, method = "fuzzy")
  }

  if (nrow(emg_mapping) == 0) {
    return(list(
      per_muscle = data.frame(muscle = character(0), cortical_drive = numeric(0),
                               emg_activation = numeric(0), force = numeric(0),
                               drive_efficiency = numeric(0),
                               stringsAsFactors = FALSE),
      per_community = data.frame(community = integer(0),
                                  mean_drive = numeric(0),
                                  mean_activation = numeric(0),
                                  mean_force = numeric(0),
                                  stringsAsFactors = FALSE),
      drive_force_correlation = NA_real_,
      drive_force_p_value = NA_real_
    ))
  }

  # Compute CMC for cortical drive
  cmc <- .minimalCMC(eeg_mat, emg_mat, sr, freq_band)
  # Per-EMG-channel cortical drive = mean CMC across EEG channels
  cortical_drive <- colMeans(cmc)

  # EMG activation (RMS per channel)
  emg_rms <- .computeRMS(emg_mat)

  # Parse force data
  if (is.data.frame(force_data) && "force" %in% names(force_data)) {
    force_vec <- stats::setNames(force_data$force, force_data$muscle)
  } else if (is.numeric(force_data) && !is.null(names(force_data))) {
    force_vec <- force_data
  } else if (is.matrix(force_data) || is.data.frame(force_data)) {
    force_vec <- .computeRMS(as.matrix(force_data))
  } else if (is.numeric(force_data)) {
    force_vec <- force_data
    names(force_vec) <- colnames(emg_mat)[seq_along(force_vec)]
  } else {
    force_vec <- rep(NA_real_, ncol(emg_mat))
    names(force_vec) <- colnames(emg_mat)
  }

  # Align all to mapped muscles
  n_mapped <- nrow(emg_mapping)
  muscle_names <- emg_mapping$muscle_name
  emg_ch_idx <- emg_mapping$channel_idx

  cd_vals <- cortical_drive[emg_ch_idx]
  act_vals <- emg_rms[emg_ch_idx]

  # Match force to muscle names
  force_vals <- numeric(n_mapped)
  for (i in seq_len(n_mapped)) {
    # Try matching by muscle name
    fidx <- which(tolower(names(force_vec)) == tolower(muscle_names[i]))
    if (length(fidx) > 0) {
      force_vals[i] <- force_vec[fidx[1]]
    } else if (emg_ch_idx[i] <= length(force_vec)) {
      force_vals[i] <- force_vec[emg_ch_idx[i]]
    }
  }

  # Drive efficiency = force / (cortical_drive * emg_activation)
  denom <- cd_vals * act_vals
  drive_eff <- ifelse(denom > 0, force_vals / denom, NA_real_)

  per_muscle <- data.frame(
    muscle = muscle_names,
    cortical_drive = round(cd_vals, 6),
    emg_activation = round(act_vals, 6),
    force = round(force_vals, 4),
    drive_efficiency = round(drive_eff, 4),
    stringsAsFactors = FALSE
  )

  # Community aggregation
  comm <- mskCommunityDetect(hg, gamma = gamma, type = "muscle")
  membership <- comm$membership[emg_mapping$muscle_idx]

  comms <- sort(unique(membership))
  per_community <- data.frame(
    community = comms,
    n_muscles = vapply(comms, function(c) sum(membership == c), integer(1)),
    mean_drive = vapply(comms, function(c) mean(cd_vals[membership == c]), numeric(1)),
    mean_activation = vapply(comms, function(c) mean(act_vals[membership == c]), numeric(1)),
    mean_force = vapply(comms, function(c) mean(force_vals[membership == c]), numeric(1)),
    stringsAsFactors = FALSE
  )

  # Drive-force correlation
  valid <- is.finite(cd_vals) & is.finite(force_vals)
  if (sum(valid) >= 3 && sd(cd_vals[valid]) > 0 && sd(force_vals[valid]) > 0) {
    ct <- cor.test(cd_vals[valid], force_vals[valid])
    df_cor <- ct$estimate
    df_pval <- ct$p.value
  } else {
    df_cor <- NA_real_
    df_pval <- NA_real_
  }

  list(
    per_muscle = per_muscle,
    per_community = per_community,
    drive_force_correlation = as.numeric(df_cor),
    drive_force_p_value = as.numeric(df_pval)
  )
}


#' Integrated Neuromechanical Vulnerability
#'
#' Combines EMG activation, kinematic stress, and force data to compute
#' a multi-source vulnerability score for each muscle. Propagates kinematic
#' stress through the MSK incidence matrix and weights by impact deviation.
#'
#' @param emg EMG data: SummarizedExperiment, matrix, or vector.
#' @param kinematics Kinematic data: matrix (time x segments) or SummarizedExperiment.
#' @param force_data Force data: named numeric vector, data.frame, or matrix.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param kin_mapping Optional pre-computed data.frame from \code{mocapToMSKMapping()}.
#' @param weights Numeric vector of length 3, weights for EMG, kinematics, force
#'   components (default: c(1, 1, 1)).
#' @param use_proxy Logical, use degree-based proxy for impact deviation
#'   (default: TRUE).
#' @return A list with:
#'   \describe{
#'     \item{vulnerability}{Named numeric vector of muscle vulnerability scores}
#'     \item{ranking}{Data.frame sorted by vulnerability (descending)}
#'     \item{source_correlations}{Pairwise correlations between EMG, kin, force sources}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- neuromechIntegratedVulnerability(emg, kinematics, force)
#' }
neuromechIntegratedVulnerability <- function(emg, kinematics, force_data,
                                             hg = NULL,
                                             emg_mapping = NULL,
                                             kin_mapping = NULL,
                                             weights = c(1, 1, 1),
                                             use_proxy = TRUE) {
  hg <- .ensureHypergraph(hg)
  stopifnot(length(weights) == 3)

  # --- EMG activation per muscle ---
  emg_data <- .extractSignalMatrix(emg, "EMG")
  emg_mat <- emg_data$signal_mat

  if (is.null(emg_mapping)) {
    emg_mapping <- emgToMSKMapping(colnames(emg_mat), hg = hg, method = "fuzzy")
  }

  emg_activation <- rep(0, hg$n_muscles)
  names(emg_activation) <- hg$muscle_names
  if (nrow(emg_mapping) > 0) {
    rms <- .computeRMS(emg_mat)
    for (i in seq_len(nrow(emg_mapping))) {
      emg_activation[emg_mapping$muscle_idx[i]] <- rms[emg_mapping$channel_idx[i]]
    }
  }

  # --- Kinematic stress per muscle ---
  kin_data <- .extractSignalMatrix(kinematics, "KIN")
  kin_mat <- kin_data$signal_mat

  if (is.null(kin_mapping)) {
    kin_mapping <- mocapToMSKMapping(colnames(kin_mat), hg = hg, method = "fuzzy")
    if (nrow(kin_mapping) == 0) {
      kin_mapping <- imuToMSKMapping(colnames(kin_mat), hg = hg, method = "fuzzy")
    }
  }

  bone_stress <- rep(0, hg$n_bones)
  names(bone_stress) <- hg$bone_names

  if (nrow(kin_mapping) > 0) {
    kin_mapping_dedup <- kin_mapping[!duplicated(kin_mapping[["bone_idx"]]), ]
    seg_col_name <- if ("segment_name" %in% names(kin_mapping_dedup)) {
      "segment_name"
    } else {
      "sensor_name"
    }

    for (i in seq_len(nrow(kin_mapping_dedup))) {
      seg <- kin_mapping_dedup[[seg_col_name]][i]
      seg_col <- match(seg, colnames(kin_mat))
      if (is.na(seg_col)) next
      x <- kin_mat[, seg_col]
      # Acceleration-based stress
      vel <- diff(x)
      acc <- diff(vel)
      bone_stress[kin_mapping_dedup$bone_idx[i]] <- max(abs(acc), na.rm = TRUE)
    }
  }

  # Propagate through incidence matrix: muscle_stress = t(C) %*% bone_stress
  C <- as.matrix(hg$C)
  kin_muscle_stress <- as.numeric(t(C) %*% bone_stress)
  names(kin_muscle_stress) <- hg$muscle_names

  # --- Force per muscle ---
  force_muscle <- rep(0, hg$n_muscles)
  names(force_muscle) <- hg$muscle_names

  if (is.data.frame(force_data) && "force" %in% names(force_data) &&
      "muscle" %in% names(force_data)) {
    for (i in seq_len(nrow(force_data))) {
      fidx <- which(tolower(hg$muscle_names) == tolower(force_data$muscle[i]))
      if (length(fidx) > 0) force_muscle[fidx[1]] <- force_data$force[i]
    }
  } else if (is.numeric(force_data) && !is.null(names(force_data))) {
    for (nm in names(force_data)) {
      fidx <- which(tolower(hg$muscle_names) == tolower(nm))
      if (length(fidx) > 0) force_muscle[fidx[1]] <- force_data[nm]
    }
  } else if (is.numeric(force_data)) {
    # Assign force to mapped EMG muscles
    for (i in seq_along(force_data)) {
      if (i <= nrow(emg_mapping)) {
        force_muscle[emg_mapping$muscle_idx[i]] <- force_data[i]
      }
    }
  }

  # --- Normalize each source to [0, 1] ---
  .normalize01 <- function(x) {
    rng <- max(x) - min(x)
    if (rng == 0) return(rep(0, length(x)))
    (x - min(x)) / rng
  }

  emg_norm <- .normalize01(emg_activation)
  kin_norm <- .normalize01(kin_muscle_stress)
  force_norm <- .normalize01(force_muscle)

  # Combined score
  combined <- weights[1] * emg_norm + weights[2] * kin_norm + weights[3] * force_norm

  # Impact deviation
  deg <- hyperedgeDegree(hg)
  if (use_proxy) {
    mean_deg <- mean(deg)
    sd_deg <- max(sd(deg), 1)
    impact_dev <- abs((deg - mean_deg) / sd_deg)
  } else {
    sim <- mskSimulate(hg)
    scores <- mskImpactScoreAll(sim, verbose = FALSE)
    impact_dev <- abs(mskImpactDeviation(scores, hg))
  }

  # Vulnerability
  vulnerability <- combined * impact_dev
  names(vulnerability) <- hg$muscle_names

  # Ranking
  ord <- order(vulnerability, decreasing = TRUE)
  ranking <- data.frame(
    muscle = hg$muscle_names[ord],
    vulnerability = round(vulnerability[ord], 6),
    emg_score = round(emg_norm[ord], 6),
    kin_score = round(kin_norm[ord], 6),
    force_score = round(force_norm[ord], 6),
    combined = round(combined[ord], 6),
    impact_deviation = round(impact_dev[ord], 4),
    stringsAsFactors = FALSE
  )
  rownames(ranking) <- NULL

  # Source correlations
  # Only among muscles with non-zero values
  active <- emg_activation > 0 | kin_muscle_stress > 0 | force_muscle > 0
  if (sum(active) >= 3) {
    src_cor <- list(
      emg_kin = cor(emg_activation[active], kin_muscle_stress[active]),
      emg_force = cor(emg_activation[active], force_muscle[active]),
      kin_force = cor(kin_muscle_stress[active], force_muscle[active])
    )
  } else {
    src_cor <- list(emg_kin = NA_real_, emg_force = NA_real_, kin_force = NA_real_)
  }

  list(
    vulnerability = vulnerability,
    ranking = ranking,
    source_correlations = src_cor
  )
}


#' Neuromechanics Summary
#'
#' Orchestrator function that runs all available neuromechanics analyses
#' with shared mapping, skipping analyses when inputs are NULL.
#'
#' @param eeg Optional EEG data (NULL to skip CMC and motor drive analyses).
#' @param emg EMG data (required).
#' @param kinematics Optional kinematic data (NULL to skip EMD and vulnerability).
#' @param force_data Optional force data (NULL to skip motor drive and vulnerability).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param freq_band Numeric vector of length 2, CMC frequency band (default: c(15, 35)).
#' @param gamma Numeric, resolution parameter (default: 4.3).
#' @param sr Optional sampling rate.
#' @param n_synergies Integer, number of synergies for muscle synergy analysis
#'   (default: 4).
#' @param synergy_method Character, synergy decomposition method: "nmf" (default)
#'   or "pca".
#' @return An S3 object of class \code{"MSKNeuromechSummary"} with:
#'   \describe{
#'     \item{cmc}{CMC result or NULL}
#'     \item{emd}{EMD result or NULL}
#'     \item{motor_drive}{Motor drive result or NULL}
#'     \item{vulnerability}{Vulnerability result or NULL}
#'     \item{torque}{Joint torque result or NULL}
#'     \item{synergy}{Muscle synergy result or NULL}
#'     \item{directional}{Directional coupling result or NULL}
#'     \item{available_analyses}{Character vector of successfully computed analyses}
#'   }
#' @export
#' @examples
#' \dontrun{
#' summary <- neuromechSummary(eeg = eeg_data, emg = emg_data,
#'                              kinematics = kin_data, force_data = force)
#' }
neuromechSummary <- function(eeg = NULL, emg, kinematics = NULL,
                              force_data = NULL, hg = NULL,
                              freq_band = c(15, 35), gamma = 4.3,
                              sr = NULL, n_synergies = 4L,
                              synergy_method = "nmf") {
  hg <- .ensureHypergraph(hg)

  # Shared EMG mapping (computed once)
  emg_data <- .extractSignalMatrix(emg, "EMG")
  emg_mapping <- emgToMSKMapping(colnames(emg_data$signal_mat),
                                  hg = hg, method = "fuzzy")

  available <- character(0)

  # CMC (requires EEG)
  cmc <- NULL
  if (!is.null(eeg)) {
    cmc <- tryCatch({
      result <- neuromechCorticomuscularCoupling(
        eeg = eeg, emg = emg, hg = hg, freq_band = freq_band,
        emg_mapping = emg_mapping, sr_eeg = sr, sr_emg = sr
      )
      available <- c(available, "cmc")
      result
    }, error = function(e) NULL)
  }

  # EMD (requires kinematics)
  emd <- NULL
  if (!is.null(kinematics)) {
    emd <- tryCatch({
      result <- neuromechElectromechanicalDelay(
        emg = emg, kinematics = kinematics, hg = hg,
        emg_mapping = emg_mapping, sr = sr
      )
      available <- c(available, "emd")
      result
    }, error = function(e) NULL)
  }

  # Motor drive (requires EEG + force)
  motor_drive <- NULL
  if (!is.null(eeg) && !is.null(force_data)) {
    motor_drive <- tryCatch({
      result <- neuromechMotorDriveTopography(
        eeg = eeg, emg = emg, force_data = force_data, hg = hg,
        freq_band = freq_band, gamma = gamma,
        emg_mapping = emg_mapping, sr = sr
      )
      available <- c(available, "motor_drive")
      result
    }, error = function(e) NULL)
  }

  # Vulnerability (requires kinematics + force)
  vulnerability <- NULL
  if (!is.null(kinematics) && !is.null(force_data)) {
    vulnerability <- tryCatch({
      result <- neuromechIntegratedVulnerability(
        emg = emg, kinematics = kinematics, force_data = force_data,
        hg = hg, emg_mapping = emg_mapping
      )
      available <- c(available, "vulnerability")
      result
    }, error = function(e) NULL)
  }

  # Torque (requires EMG only)
  torque <- NULL
  torque <- tryCatch({
    result <- neuromechJointTorque(
      emg = emg, hg = hg, emg_mapping = emg_mapping, sr = sr
    )
    if (nrow(result$per_joint) > 0) {
      available <- c(available, "torque")
    }
    result
  }, error = function(e) NULL)

  # Synergy (requires EMG only)
  synergy <- NULL
  synergy <- tryCatch({
    result <- neuromechMuscleSynergy(
      emg = emg, hg = hg, emg_mapping = emg_mapping,
      method = synergy_method, n_synergies = n_synergies,
      gamma = gamma, sr = sr
    )
    available <- c(available, "synergy")
    result
  }, error = function(e) NULL)

  # Directional (requires EEG + EMG)
  directional <- NULL
  if (!is.null(eeg)) {
    directional <- tryCatch({
      result <- neuromechDirectionalCoupling(
        eeg = eeg, emg = emg, hg = hg,
        emg_mapping = emg_mapping, sr_eeg = sr, sr_emg = sr
      )
      available <- c(available, "directional")
      result
    }, error = function(e) NULL)
  }

  structure(
    list(
      cmc = cmc,
      emd = emd,
      motor_drive = motor_drive,
      vulnerability = vulnerability,
      torque = torque,
      synergy = synergy,
      directional = directional,
      available_analyses = available
    ),
    class = "MSKNeuromechSummary"
  )
}


#' @export
print.MSKNeuromechSummary <- function(x, ...) {
  cat("MSK Neuromechanics Summary\n")
  cat("=========================\n")
  cat("Available analyses:", paste(x$available_analyses, collapse = ", "), "\n\n")

  if (!is.null(x$cmc)) {
    cat("--- Corticomuscular Coherence ---\n")
    cat("  CMC matrix:", nrow(x$cmc$cmc_matrix), "EEG x",
        ncol(x$cmc$cmc_matrix), "EMG channels\n")
    cat("  Significant pairs:", nrow(x$cmc$significant_pairs), "\n")
    cat("  Mantel r =", round(x$cmc$mantel$correlation, 3),
        ", p =", round(x$cmc$mantel$p_value, 4), "\n\n")
  }

  if (!is.null(x$emd)) {
    cat("--- Electromechanical Delay ---\n")
    cat("  Pairs analyzed:", nrow(x$emd$emd), "\n")
    if (nrow(x$emd$emd) > 0) {
      cat("  Mean EMD:", round(mean(x$emd$emd$emd_ms), 1), "ms\n")
    }
    cat("  EMD-distance r =", round(x$emd$correlation, 3),
        ", p =", round(x$emd$p_value, 4), "\n\n")
  }

  if (!is.null(x$motor_drive)) {
    cat("--- Motor Drive Topography ---\n")
    cat("  Muscles analyzed:", nrow(x$motor_drive$per_muscle), "\n")
    cat("  Communities:", nrow(x$motor_drive$per_community), "\n")
    cat("  Drive-force r =", round(x$motor_drive$drive_force_correlation, 3),
        ", p =", round(x$motor_drive$drive_force_p_value, 4), "\n\n")
  }

  if (!is.null(x$vulnerability)) {
    cat("--- Integrated Vulnerability ---\n")
    top5 <- head(x$vulnerability$ranking, 5)
    for (i in seq_len(nrow(top5))) {
      cat(sprintf("  %s: %.4f\n", top5$muscle[i], top5$vulnerability[i]))
    }
    cat("\n")
  }

  if (!is.null(x$torque) && nrow(x$torque$per_joint) > 0) {
    cat("--- Joint Torque ---\n")
    cat("  Joints analyzed:", nrow(x$torque$per_joint), "\n")
    cat("  Muscles matched:", nrow(x$torque$per_muscle), "\n\n")
  }

  if (!is.null(x$synergy)) {
    cat("--- Muscle Synergy ---\n")
    cat("  Method:", x$synergy$method, "\n")
    cat("  Synergies:", x$synergy$n_synergies, "\n")
    cat("  VAF:", round(x$synergy$vaf, 4), "\n\n")
  }

  if (!is.null(x$directional)) {
    cat("--- Directional Coupling ---\n")
    cat("  Method:", x$directional$method, "\n")
    cat("  Descending pairs:", nrow(x$directional$significant_descending), "\n")
    cat("  Ascending pairs:", nrow(x$directional$significant_ascending), "\n\n")
  }

  invisible(x)
}


# ===========================================================================
# Capability 1: Joint Torque Modeling
# ===========================================================================

#' Curated moment arm lookup table
#'
#' Maps muscle-joint pairs to moment arm (meters) and direction (+1 agonist,
#' -1 antagonist). Covers 7 major joints: elbow, shoulder, knee, hip, ankle,
#' wrist, spine.
#'
#' @return A data.frame with columns: muscle_name, joint_name,
#'   bone_proximal, bone_distal, moment_arm_m, direction.
#' @keywords internal
.momentArmLookup <- function() {
  data.frame(
    muscle_name = c(
      # Elbow
      "Biceps Brachii", "Brachialis", "Brachioradialis",
      "Triceps Brachii", "Anconeus",
      # Shoulder
      "Deltoid", "Supraspinatus", "Infraspinatus",
      "Pectoralis Major", "Latissimus Dorsi", "Teres Major",
      "Subscapularis",
      # Knee
      "Quadriceps", "Rectus Femoris", "Vastus Lateralis",
      "Vastus Medialis", "Vastus Intermedius",
      "Biceps Femoris", "Semitendinosus", "Semimembranosus",
      # Hip
      "Iliopsoas", "Gluteus Maximus", "Gluteus Medius",
      "Adductor Magnus", "Adductor Longus",
      # Ankle
      "Gastrocnemius", "Soleus", "Tibialis Anterior",
      "Peroneus Longus", "Peroneus Brevis",
      # Wrist
      "Flexor Carpi Radialis", "Flexor Carpi Ulnaris",
      "Extensor Carpi Radialis Longus", "Extensor Carpi Ulnaris",
      # Spine
      "Erector Spinae", "Rectus Abdominis", "External Oblique"
    ),
    joint_name = c(
      rep("elbow", 5),
      rep("shoulder", 7),
      rep("knee", 8),
      rep("hip", 5),
      rep("ankle", 5),
      rep("wrist", 4),
      rep("spine", 3)
    ),
    bone_proximal = c(
      # Elbow
      "Humerus", "Humerus", "Humerus", "Humerus", "Humerus",
      # Shoulder
      "Scapula", "Scapula", "Scapula",
      "Clavicle", "T1", "Scapula", "Scapula",
      # Knee
      "Femur", "Ilium", "Femur",
      "Femur", "Femur",
      "Ischium", "Ischium", "Ischium",
      # Hip
      "L1", "Ilium", "Ilium", "Ischium", "Pubis",
      # Ankle
      "Femur", "Tibia", "Tibia", "Fibula", "Fibula",
      # Wrist
      "Radius", "Ulna", "Humerus", "Humerus",
      # Spine
      "Sacrum", "Pubis", "Ilium"
    ),
    bone_distal = c(
      # Elbow
      "Radius", "Ulna", "Radius", "Ulna", "Ulna",
      # Shoulder
      "Humerus", "Humerus", "Humerus",
      "Humerus", "Humerus", "Humerus", "Humerus",
      # Knee
      "Tibia", "Tibia", "Tibia",
      "Tibia", "Tibia",
      "Tibia", "Tibia", "Tibia",
      # Hip
      "Femur", "Femur", "Femur", "Femur", "Femur",
      # Ankle
      "Calcaneus", "Calcaneus", "Tarsus", "Metatarsal 1", "Metatarsal 1",
      # Wrist
      "Hand Metacarpal 1", "Hand Metacarpal 1",
      "Hand Metacarpal 1", "Hand Metacarpal 1",
      # Spine
      "T1", "Sternum", "T1"
    ),
    moment_arm_m = c(
      # Elbow (flexors positive, extensors negative)
      0.040, 0.030, 0.050,
      0.025, 0.015,
      # Shoulder
      0.050, 0.025, 0.030,
      0.060, 0.055, 0.035, 0.030,
      # Knee (extensors positive, flexors negative)
      0.045, 0.040, 0.042,
      0.043, 0.041,
      0.035, 0.030, 0.032,
      # Hip
      0.040, 0.060, 0.050, 0.035, 0.030,
      # Ankle (plantarflexors positive, dorsiflexors negative)
      0.050, 0.045, 0.030, 0.025, 0.022,
      # Wrist
      0.015, 0.012, 0.018, 0.014,
      # Spine
      0.050, 0.060, 0.040
    ),
    direction = c(
      # Elbow: flexors +1, extensors -1
      1L, 1L, 1L, -1L, -1L,
      # Shoulder: abductors/flexors +1, extensors/adductors -1
      1L, 1L, -1L, 1L, -1L, -1L, -1L,
      # Knee: extensors +1, flexors -1
      1L, 1L, 1L, 1L, 1L, -1L, -1L, -1L,
      # Hip: flexors +1, extensors -1
      1L, -1L, 1L, -1L, -1L,
      # Ankle: plantarflexors +1, dorsiflexors -1
      1L, 1L, -1L, 1L, 1L,
      # Wrist: flexors +1, extensors -1
      1L, 1L, -1L, -1L,
      # Spine: extensors +1, flexors -1
      1L, -1L, -1L
    ),
    stringsAsFactors = FALSE
  )
}


#' Joint name to bone pair lookup
#'
#' Maps joint names to proximal/distal bone pairs.
#'
#' @return A data.frame with columns: joint_name, bone_proximal, bone_distal.
#' @keywords internal
.jointLookup <- function() {
  data.frame(
    joint_name = c("elbow", "shoulder", "knee", "hip",
                    "ankle", "wrist", "spine"),
    bone_proximal = c("Humerus", "Scapula", "Femur", "Ilium",
                       "Tibia", "Radius", "Sacrum"),
    bone_distal = c("Radius", "Humerus", "Tibia", "Femur",
                     "Calcaneus", "Hand Metacarpal 1", "T1"),
    stringsAsFactors = FALSE
  )
}


#' Fuzzy-match muscle names to moment arm lookup
#'
#' @param muscle_names Character vector of muscle names from EMG channels.
#' @param hg An MSKHypergraph object.
#' @return A data.frame with matched entries and hg muscle indices.
#' @keywords internal
.matchMuscleToTorqueTable <- function(muscle_names, hg) {
  lookup <- .momentArmLookup()
  lookup_norm <- tolower(trimws(lookup$muscle_name))

  results <- list()
  for (i in seq_along(muscle_names)) {
    nm <- tolower(trimws(muscle_names[i]))
    # Try exact match first
    exact_idx <- which(lookup_norm == nm)
    if (length(exact_idx) == 0) {
      # Fuzzy match
      exact_idx <- agrep(nm, lookup_norm, max.distance = 0.2,
                          ignore.case = TRUE)
    }
    if (length(exact_idx) > 0) {
      for (j in exact_idx) {
        # Find muscle index in hg
        hg_idx <- which(tolower(trimws(hg$muscle_names)) == lookup_norm[j])
        if (length(hg_idx) == 0) {
          hg_idx <- agrep(lookup_norm[j], tolower(trimws(hg$muscle_names)),
                           max.distance = 0.2, ignore.case = TRUE)
        }
        m_idx <- if (length(hg_idx) > 0) hg_idx[1] else NA_integer_
        results[[length(results) + 1L]] <- data.frame(
          emg_name = muscle_names[i],
          emg_idx = i,
          muscle_name = lookup$muscle_name[j],
          muscle_idx = m_idx,
          joint_name = lookup$joint_name[j],
          moment_arm_m = lookup$moment_arm_m[j],
          direction = lookup$direction[j],
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(results) == 0) {
    return(data.frame(
      emg_name = character(0), emg_idx = integer(0),
      muscle_name = character(0), muscle_idx = integer(0),
      joint_name = character(0), moment_arm_m = numeric(0),
      direction = integer(0), stringsAsFactors = FALSE
    ))
  }

  do.call(rbind, results)
}


#' Compute net torque per joint
#'
#' @param activation Numeric vector of muscle activation values.
#' @param moment_arms Numeric vector of moment arm magnitudes.
#' @param directions Integer vector of +1/-1 directions.
#' @return Numeric scalar: net torque.
#' @keywords internal
.computeNetTorque <- function(activation, moment_arms, directions) {
  sum(activation * moment_arms * directions)
}


#' Joint Torque Modeling in MSK Context
#'
#' Estimates joint torques from EMG activation and anatomical moment arms,
#' computing per-muscle contributions, coactivation indices, and torque
#' balance ratios across joints.
#'
#' @param emg EMG data: SummarizedExperiment, matrix (time x channels), or vector.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param moment_arm_table Optional custom data.frame with columns: muscle_name,
#'   joint_name, moment_arm_m, direction. Overrides the built-in lookup.
#' @param activation_method Character, method for computing activation:
#'   "rms" (default), "mean_rectified", "peak".
#' @param sr Optional sampling rate.
#' @param joints Optional character vector of joint names to restrict analysis.
#' @param n_perm Integer, number of permutations for Mantel test (default: 999).
#' @return An S3 object of class \code{"MSKNeuromechTorque"} with:
#'   \describe{
#'     \item{per_muscle}{Data.frame: muscle, joint, activation, moment_arm,
#'       direction, torque_contribution}
#'     \item{per_joint}{Data.frame: joint, net_torque, agonist_sum,
#'       antagonist_sum, coactivation_index, n_muscles}
#'     \item{torque_balance}{Data.frame: joint, balance_ratio}
#'     \item{msk_correlation}{Mantel test result}
#'     \item{moment_arm_source}{Character: "lookup" or "custom"}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- neuromechJointTorque(emg_data, hg = hg)
#' }
neuromechJointTorque <- function(emg, hg = NULL, emg_mapping = NULL,
                                  moment_arm_table = NULL,
                                  activation_method = c("rms",
                                                         "mean_rectified",
                                                         "peak"),
                                  sr = NULL, joints = NULL,
                                  n_perm = 999L) {
  activation_method <- match.arg(activation_method)
  hg <- .ensureHypergraph(hg)

  # Extract EMG signal
  emg_data <- .extractSignalMatrix(emg, "EMG")
  emg_mat <- emg_data$signal_mat
  sr <- sr %||% emg_data$sr %||% 1000

  # EMG-to-muscle mapping
  if (is.null(emg_mapping)) {
    emg_mapping <- emgToMSKMapping(colnames(emg_mat), hg = hg, method = "fuzzy")
  }

  # Compute activation per channel
  act_vals <- switch(activation_method,
    "rms" = .computeRMS(emg_mat),
    "mean_rectified" = vapply(seq_len(ncol(emg_mat)), function(ch) {
      mean(abs(emg_mat[, ch]))
    }, numeric(1)),
    "peak" = vapply(seq_len(ncol(emg_mat)), function(ch) {
      max(abs(emg_mat[, ch]))
    }, numeric(1))
  )
  names(act_vals) <- colnames(emg_mat)

  # Determine moment arm source
  if (!is.null(moment_arm_table)) {
    ma_source <- "custom"
    # Match EMG channel names to custom table
    custom_norm <- tolower(trimws(moment_arm_table$muscle_name))
    emg_norm <- tolower(trimws(colnames(emg_mat)))

    match_rows <- list()
    for (i in seq_along(emg_norm)) {
      idx <- which(custom_norm == emg_norm[i])
      if (length(idx) == 0) {
        idx <- agrep(emg_norm[i], custom_norm, max.distance = 0.2,
                      ignore.case = TRUE)
      }
      for (j in idx) {
        match_rows[[length(match_rows) + 1L]] <- data.frame(
          emg_name = colnames(emg_mat)[i],
          emg_idx = i,
          muscle_name = moment_arm_table$muscle_name[j],
          muscle_idx = NA_integer_,
          joint_name = moment_arm_table$joint_name[j],
          moment_arm_m = moment_arm_table$moment_arm_m[j],
          direction = moment_arm_table$direction[j],
          stringsAsFactors = FALSE
        )
      }
    }
    if (length(match_rows) > 0) {
      torque_match <- do.call(rbind, match_rows)
    } else {
      torque_match <- data.frame(
        emg_name = character(0), emg_idx = integer(0),
        muscle_name = character(0), muscle_idx = integer(0),
        joint_name = character(0), moment_arm_m = numeric(0),
        direction = integer(0), stringsAsFactors = FALSE
      )
    }
  } else {
    ma_source <- "lookup"
    torque_match <- .matchMuscleToTorqueTable(colnames(emg_mat), hg)
  }

  # Filter by joints if specified
  if (!is.null(joints) && nrow(torque_match) > 0) {
    torque_match <- torque_match[torque_match$joint_name %in% joints, ,
                                  drop = FALSE]
  }

  # Empty result if no matches
  if (nrow(torque_match) == 0) {
    return(structure(
      list(
        per_muscle = data.frame(muscle = character(0), joint = character(0),
                                 activation = numeric(0),
                                 moment_arm = numeric(0),
                                 direction = integer(0),
                                 torque_contribution = numeric(0),
                                 stringsAsFactors = FALSE),
        per_joint = data.frame(joint = character(0), net_torque = numeric(0),
                                agonist_sum = numeric(0),
                                antagonist_sum = numeric(0),
                                coactivation_index = numeric(0),
                                n_muscles = integer(0),
                                stringsAsFactors = FALSE),
        torque_balance = data.frame(joint = character(0),
                                     balance_ratio = numeric(0),
                                     stringsAsFactors = FALSE),
        msk_correlation = list(correlation = NA_real_, p_value = NA_real_),
        moment_arm_source = ma_source
      ),
      class = "MSKNeuromechTorque"
    ))
  }

  # Per-muscle torque
  per_muscle <- data.frame(
    muscle = torque_match$emg_name,
    joint = torque_match$joint_name,
    activation = act_vals[torque_match$emg_idx],
    moment_arm = torque_match$moment_arm_m,
    direction = torque_match$direction,
    stringsAsFactors = FALSE
  )
  per_muscle$torque_contribution <- per_muscle$activation *
    per_muscle$moment_arm * per_muscle$direction
  rownames(per_muscle) <- NULL

  # Per-joint aggregation
  joint_names <- unique(per_muscle$joint)
  per_joint_rows <- list()
  for (jt in joint_names) {
    sub <- per_muscle[per_muscle$joint == jt, ]
    agonist_sum <- sum(sub$activation[sub$direction > 0] *
                        sub$moment_arm[sub$direction > 0])
    antagonist_sum <- sum(sub$activation[sub$direction < 0] *
                           sub$moment_arm[sub$direction < 0])
    total <- agonist_sum + antagonist_sum
    coact_idx <- if (total > 0) 2 * min(agonist_sum, antagonist_sum) / total
                 else 0

    per_joint_rows[[length(per_joint_rows) + 1L]] <- data.frame(
      joint = jt,
      net_torque = .computeNetTorque(sub$activation, sub$moment_arm,
                                      sub$direction),
      agonist_sum = agonist_sum,
      antagonist_sum = antagonist_sum,
      coactivation_index = round(coact_idx, 4),
      n_muscles = nrow(sub),
      stringsAsFactors = FALSE
    )
  }
  per_joint <- do.call(rbind, per_joint_rows)
  rownames(per_joint) <- NULL

  # Torque balance: agonist / (agonist + antagonist)
  torque_balance <- data.frame(
    joint = per_joint$joint,
    balance_ratio = ifelse(
      per_joint$agonist_sum + per_joint$antagonist_sum > 0,
      per_joint$agonist_sum /
        (per_joint$agonist_sum + per_joint$antagonist_sum),
      NA_real_
    ),
    stringsAsFactors = FALSE
  )

  # Mantel test: torque-based vs structural adjacency
  mantel_result <- list(correlation = NA_real_, p_value = NA_real_)
  if (nrow(emg_mapping) >= 3) {
    # Torque-based distance: |contribution_i - contribution_j|
    n_m <- nrow(emg_mapping)
    mapped_act <- act_vals[emg_mapping$channel_idx]
    torque_dist <- matrix(0, n_m, n_m)
    for (i in seq_len(n_m - 1)) {
      for (j in (i + 1):n_m) {
        torque_dist[i, j] <- torque_dist[j, i] <-
          abs(mapped_act[i] - mapped_act[j])
      }
    }
    rownames(torque_dist) <- colnames(torque_dist) <- emg_mapping$muscle_name

    B <- as.matrix(projectMuscleGraph(hg))
    m_idx <- emg_mapping$muscle_idx
    struct_mat <- (B[m_idx, m_idx, drop = FALSE] > 0) * 1.0
    rownames(struct_mat) <- colnames(struct_mat) <- emg_mapping$muscle_name

    mantel_result <- .mantelTest(torque_dist, struct_mat, n_perm = n_perm)
  }

  structure(
    list(
      per_muscle = per_muscle,
      per_joint = per_joint,
      torque_balance = torque_balance,
      msk_correlation = mantel_result,
      moment_arm_source = ma_source
    ),
    class = "MSKNeuromechTorque"
  )
}


#' @export
print.MSKNeuromechTorque <- function(x, ...) {
  cat("MSK Neuromech Joint Torque Analysis\n")
  cat("====================================\n")
  cat("Moment arm source:", x$moment_arm_source, "\n")
  cat("Joints analyzed:", nrow(x$per_joint), "\n")
  cat("Muscles matched:", nrow(x$per_muscle), "\n\n")

  if (nrow(x$per_joint) > 0) {
    cat("Per-joint summary:\n")
    for (i in seq_len(nrow(x$per_joint))) {
      cat(sprintf("  %s: net_torque=%.4f, coactivation=%.3f, n=%d\n",
                  x$per_joint$joint[i], x$per_joint$net_torque[i],
                  x$per_joint$coactivation_index[i],
                  x$per_joint$n_muscles[i]))
    }
    cat("\n")
  }

  if (!is.na(x$msk_correlation$correlation)) {
    cat("Mantel test: r =", round(x$msk_correlation$correlation, 3),
        ", p =", round(x$msk_correlation$p_value, 4), "\n")
  }

  invisible(x)
}


# ===========================================================================
# Capability 2: Muscle Synergy Decomposition
# ===========================================================================

#' NMF via multiplicative update rules (Lee & Seung 2001)
#'
#' @param V Non-negative matrix (n_muscles x n_time).
#' @param k Number of synergies.
#' @param max_iter Maximum iterations.
#' @param tol Convergence tolerance.
#' @param seed Random seed for reproducibility.
#' @return A list with: W, H, reconstruction_error, n_iter, converged.
#' @importFrom stats runif
#' @keywords internal
.nmfMultiplicativeUpdate <- function(V, k, max_iter = 500L, tol = 1e-6,
                                      seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  n <- nrow(V)
  m <- ncol(V)
  eps <- 1e-10

  # Ensure V is non-negative
  V <- abs(V) + eps

  # Initialize randomly (positive values)
  W <- matrix(runif(n * k, min = 0.1, max = 1.0), n, k)
  H <- matrix(runif(k * m, min = 0.1, max = 1.0), k, m)

  prev_err <- Inf
  converged <- FALSE
  final_iter <- 1L

  for (iter in seq_len(max_iter)) {
    final_iter <- iter

    # Update H
    WH <- W %*% H
    num_H <- crossprod(W, V)         # t(W) %*% V
    denom_H <- crossprod(W, WH)      # t(W) %*% W %*% H
    denom_H[denom_H < eps] <- eps
    H <- H * (num_H / denom_H)
    H[!is.finite(H)] <- eps
    H[H < eps] <- eps

    # Update W
    WH <- W %*% H
    num_W <- V %*% t(H)              # V %*% t(H)
    denom_W <- WH %*% t(H)           # W %*% H %*% t(H)
    denom_W[denom_W < eps] <- eps
    W <- W * (num_W / denom_W)
    W[!is.finite(W)] <- eps
    W[W < eps] <- eps

    # Check convergence
    err <- sum((V - W %*% H)^2)
    if (!is.finite(err)) {
      err <- prev_err
      break
    }
    if (is.finite(prev_err) && abs(prev_err - err) / (prev_err + eps) < tol) {
      converged <- TRUE
      break
    }
    prev_err <- err
  }

  recon_err <- sum((V - W %*% H)^2)
  if (!is.finite(recon_err)) recon_err <- prev_err

  list(
    W = W,
    H = H,
    reconstruction_error = recon_err,
    n_iter = final_iter,
    converged = converged
  )
}


#' PCA-based synergy extraction
#'
#' @param V Non-negative matrix (n_muscles x n_time).
#' @param k Number of components.
#' @return A list with: W, H, variance_explained, cumulative_variance.
#' @keywords internal
.pcaSynergy <- function(V, k) {
  pca <- stats::prcomp(t(V), center = TRUE, scale. = FALSE)

  # W = loadings (n_muscles x k), H = scores (k x n_time)
  W <- pca$rotation[, seq_len(k), drop = FALSE]
  H <- t(pca$x[, seq_len(k), drop = FALSE])

  var_exp <- pca$sdev^2 / sum(pca$sdev^2)

  list(
    W = W,
    H = H,
    variance_explained = var_exp[seq_len(k)],
    cumulative_variance = cumsum(var_exp)[seq_len(k)]
  )
}


#' Auto-select number of synergies by VAF criterion
#'
#' @param V Non-negative matrix (n_muscles x n_time).
#' @param max_k Maximum k to try.
#' @param threshold VAF threshold (default: 0.90).
#' @param seed Random seed.
#' @return A list with: optimal_k, vaf_curve.
#' @keywords internal
.selectNSynergies <- function(V, max_k = 10L, threshold = 0.90,
                                seed = NULL) {
  max_k <- min(max_k, nrow(V), ncol(V))
  total_var <- sum(V^2)
  vaf_curve <- numeric(max_k)

  for (k in seq_len(max_k)) {
    nmf <- .nmfMultiplicativeUpdate(V, k, max_iter = 200L, seed = seed)
    vaf_curve[k] <- 1 - nmf$reconstruction_error / total_var
  }

  optimal_k <- which(vaf_curve >= threshold)
  optimal_k <- if (length(optimal_k) > 0) min(optimal_k) else max_k

  list(optimal_k = optimal_k, vaf_curve = vaf_curve)
}


#' Map synergy weights to MSK communities
#'
#' @param W Synergy weight matrix (n_muscles x n_synergies).
#' @param emg_mapping Data.frame from emgToMSKMapping.
#' @param hg MSKHypergraph.
#' @param gamma Resolution parameter for community detection.
#' @return A data.frame: synergy, community, mean_weight, n_muscles.
#' @keywords internal
.mapSynergiesToCommunities <- function(W, emg_mapping, hg, gamma = 4.3) {
  comm <- mskCommunityDetect(hg, gamma = gamma, type = "muscle")
  membership <- comm$membership[emg_mapping$muscle_idx]

  n_syn <- ncol(W)
  comms <- sort(unique(membership))

  rows <- list()
  for (s in seq_len(n_syn)) {
    for (c_id in comms) {
      c_idx <- which(membership == c_id)
      if (length(c_idx) > 0) {
        rows[[length(rows) + 1L]] <- data.frame(
          synergy = s,
          community = c_id,
          mean_weight = mean(abs(W[c_idx, s])),
          n_muscles = length(c_idx),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(rows) == 0) {
    return(data.frame(synergy = integer(0), community = integer(0),
                       mean_weight = numeric(0), n_muscles = integer(0),
                       stringsAsFactors = FALSE))
  }

  do.call(rbind, rows)
}


#' Muscle Synergy Decomposition in MSK Context
#'
#' Extracts muscle synergies from EMG data via NMF or PCA, maps them to
#' MSK structural communities, and compares synergy-based partitioning
#' with structural communities via z-Rand.
#'
#' @param emg EMG data: SummarizedExperiment, matrix (time x channels), or vector.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param method Character, decomposition method: "nmf" (default) or "pca".
#' @param n_synergies Integer, number of synergies to extract (default: 4).
#' @param auto_select Logical, automatically select n_synergies via VAF criterion
#'   (default: FALSE).
#' @param vaf_threshold Numeric, VAF threshold for auto selection (default: 0.90).
#' @param max_k Integer, maximum k to try during auto selection (default: 10).
#' @param gamma Numeric, resolution parameter for MSK community detection
#'   (default: 4.3).
#' @param n_perm Integer, permutations for z-Rand (unused, reserved).
#' @param seed Optional integer seed for NMF reproducibility.
#' @param sr Optional sampling rate.
#' @return An S3 object of class \code{"MSKNeuromechSynergy"} with:
#'   \describe{
#'     \item{W}{Synergy weight matrix (n_muscles x n_synergies)}
#'     \item{H}{Activation coefficients (n_synergies x n_timepoints)}
#'     \item{n_synergies}{Number of synergies extracted}
#'     \item{vaf}{Variance accounted for}
#'     \item{vaf_curve}{VAF curve if auto_select (else NULL)}
#'     \item{method}{Decomposition method used}
#'     \item{community_mapping}{Synergy-to-community enrichment data.frame}
#'     \item{synergy_similarity}{Cosine similarity matrix (k x k)}
#'     \item{community_synergy_zrand}{z-Rand comparing synergy vs structural}
#'     \item{reconstruction_error}{Reconstruction error}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- neuromechMuscleSynergy(emg_data, method = "nmf", n_synergies = 4)
#' }
neuromechMuscleSynergy <- function(emg, hg = NULL, emg_mapping = NULL,
                                    method = c("nmf", "pca"),
                                    n_synergies = 4L,
                                    auto_select = FALSE,
                                    vaf_threshold = 0.90,
                                    max_k = 10L,
                                    gamma = 4.3,
                                    n_perm = 999L,
                                    seed = NULL, sr = NULL) {
  method <- match.arg(method)
  hg <- .ensureHypergraph(hg)

  # Extract EMG
  emg_data_ext <- .extractSignalMatrix(emg, "EMG")
  emg_mat <- emg_data_ext$signal_mat
  sr <- sr %||% emg_data_ext$sr %||% 1000

  if (is.null(emg_mapping)) {
    emg_mapping <- emgToMSKMapping(colnames(emg_mat), hg = hg, method = "fuzzy")
  }

  # Prepare V: muscles x time (abs EMG, transposed)
  V <- t(abs(emg_mat))

  # Cap n_synergies at number of muscles
  n_muscles <- nrow(V)
  if (n_synergies > n_muscles) {
    warning("n_synergies (", n_synergies, ") exceeds number of muscles (",
            n_muscles, "); capping to ", n_muscles)
    n_synergies <- n_muscles
  }

  vaf_curve_result <- NULL

  if (auto_select && method == "nmf") {
    sel <- .selectNSynergies(V, max_k = max_k, threshold = vaf_threshold,
                              seed = seed)
    n_synergies <- sel$optimal_k
    vaf_curve_result <- sel$vaf_curve
  }

  # Decompose
  if (method == "nmf") {
    result <- .nmfMultiplicativeUpdate(V, n_synergies, seed = seed)
    W <- result$W
    H <- result$H
    recon_err <- result$reconstruction_error
    total_var <- sum(V^2)
    vaf <- 1 - recon_err / total_var
  } else {
    result <- .pcaSynergy(V, n_synergies)
    W <- result$W
    H <- result$H
    recon_err <- sum((V - W %*% H)^2)
    total_var <- sum(V^2)
    vaf <- 1 - recon_err / total_var
  }

  rownames(W) <- colnames(emg_mat)
  colnames(W) <- paste0("S", seq_len(n_synergies))

  # Cosine similarity between synergies
  syn_sim <- matrix(0, n_synergies, n_synergies)
  for (i in seq_len(n_synergies)) {
    for (j in seq_len(n_synergies)) {
      ni <- sqrt(sum(W[, i]^2))
      nj <- sqrt(sum(W[, j]^2))
      if (ni > 0 && nj > 0) {
        syn_sim[i, j] <- sum(W[, i] * W[, j]) / (ni * nj)
      }
    }
  }
  rownames(syn_sim) <- colnames(syn_sim) <- paste0("S", seq_len(n_synergies))

  # Map synergies to communities
  community_mapping <- data.frame(synergy = integer(0),
                                    community = integer(0),
                                    mean_weight = numeric(0),
                                    n_muscles = integer(0),
                                    stringsAsFactors = FALSE)
  zrand <- NA_real_
  if (nrow(emg_mapping) >= 3) {
    community_mapping <- tryCatch(
      .mapSynergiesToCommunities(W, emg_mapping, hg, gamma),
      error = function(e) community_mapping
    )

    # z-Rand: synergy-based partition vs structural communities
    # Assign each muscle to its dominant synergy
    synergy_partition <- apply(abs(W), 1, which.max)
    comm <- mskCommunityDetect(hg, gamma = gamma, type = "muscle")
    struct_partition <- comm$membership[emg_mapping$muscle_idx]

    if (length(synergy_partition) == length(struct_partition) &&
        length(synergy_partition) >= 3) {
      zrand <- tryCatch(
        mskZRand(synergy_partition, struct_partition),
        error = function(e) NA_real_
      )
    }
  }

  structure(
    list(
      W = W,
      H = H,
      n_synergies = n_synergies,
      vaf = vaf,
      vaf_curve = vaf_curve_result,
      method = method,
      community_mapping = community_mapping,
      synergy_similarity = syn_sim,
      community_synergy_zrand = zrand,
      reconstruction_error = recon_err
    ),
    class = "MSKNeuromechSynergy"
  )
}


#' @export
print.MSKNeuromechSynergy <- function(x, ...) {
  cat("MSK Neuromech Muscle Synergy Decomposition\n")
  cat("============================================\n")
  cat("Method:", x$method, "\n")
  cat("Synergies:", x$n_synergies, "\n")
  cat("VAF:", round(x$vaf, 4), "\n")
  cat("W dimensions:", nrow(x$W), "muscles x", ncol(x$W), "synergies\n")
  cat("Reconstruction error:", round(x$reconstruction_error, 4), "\n")

  if (!is.na(x$community_synergy_zrand)) {
    cat("z-Rand (synergy vs structural):", round(x$community_synergy_zrand, 3),
        "\n")
  }

  if (nrow(x$community_mapping) > 0) {
    cat("\nSynergy-community enrichment:\n")
    top <- utils::head(x$community_mapping[order(-x$community_mapping$mean_weight), ], 5)
    for (i in seq_len(nrow(top))) {
      cat(sprintf("  S%d -> community %d: mean_weight=%.4f (n=%d)\n",
                  top$synergy[i], top$community[i],
                  top$mean_weight[i], top$n_muscles[i]))
    }
  }

  invisible(x)
}


# ===========================================================================
# Capability 3: Causal/Directional Connectivity
# ===========================================================================

#' Pairwise Granger causality test
#'
#' Tests if past of x improves prediction of y. Selects optimal model order
#' via AIC or BIC.
#'
#' @param x Numeric vector (predictor signal).
#' @param y Numeric vector (response signal).
#' @param max_order Integer, maximum lag order to test.
#' @param criterion Character, "aic" or "bic" for model order selection.
#' @return A list with: f_statistic, p_value, optimal_order, direction.
#' @keywords internal
.grangerCausalityPairwise <- function(x, y, max_order = 10L,
                                       criterion = c("aic", "bic")) {
  criterion <- match.arg(criterion)
  n <- min(length(x), length(y))

  if (n < 2 * max_order + 5) {
    return(list(f_statistic = NA_real_, p_value = NA_real_,
                optimal_order = NA_integer_, direction = "x->y"))
  }

  x <- x[seq_len(n)]
  y <- y[seq_len(n)]

  # Select optimal order via AIC/BIC on restricted model
  best_order <- 1L
  best_ic <- Inf
  for (p in seq_len(max_order)) {
    if (n - p < p + 2) break
    Y <- y[(p + 1):n]
    X_r <- matrix(NA, n - p, p)
    for (lag in seq_len(p)) {
      X_r[, lag] <- y[(p + 1 - lag):(n - lag)]
    }
    fit_r <- tryCatch(stats::lm(Y ~ X_r), error = function(e) NULL)
    if (is.null(fit_r)) next

    rss <- sum(stats::residuals(fit_r)^2)
    n_obs <- n - p
    k <- p + 1  # intercept + p lags
    ic <- if (criterion == "aic") {
      n_obs * log(rss / n_obs) + 2 * k
    } else {
      n_obs * log(rss / n_obs) + log(n_obs) * k
    }
    if (ic < best_ic) {
      best_ic <- ic
      best_order <- p
    }
  }

  p <- best_order
  if (n - p < 2 * p + 2) {
    return(list(f_statistic = NA_real_, p_value = NA_real_,
                optimal_order = p, direction = "x->y"))
  }

  # Build design matrices
  Y <- y[(p + 1):n]
  n_obs <- length(Y)

  # Restricted: y ~ y_lag1..p
  X_r <- matrix(NA, n_obs, p)
  for (lag in seq_len(p)) {
    X_r[, lag] <- y[(p + 1 - lag):(n - lag)]
  }

  # Unrestricted: y ~ y_lag1..p + x_lag1..p
  X_u <- cbind(X_r, matrix(NA, n_obs, p))
  for (lag in seq_len(p)) {
    X_u[, p + lag] <- x[(p + 1 - lag):(n - lag)]
  }

  fit_r <- tryCatch(stats::lm(Y ~ X_r), error = function(e) NULL)
  fit_u <- tryCatch(stats::lm(Y ~ X_u), error = function(e) NULL)

  if (is.null(fit_r) || is.null(fit_u)) {
    return(list(f_statistic = NA_real_, p_value = NA_real_,
                optimal_order = p, direction = "x->y"))
  }

  rss_r <- sum(stats::residuals(fit_r)^2)
  rss_u <- sum(stats::residuals(fit_u)^2)

  # F-test
  dof_diff <- p  # number of additional parameters
  dof_u <- n_obs - 2 * p - 1
  if (dof_u <= 0 || rss_u <= 0) {
    return(list(f_statistic = NA_real_, p_value = NA_real_,
                optimal_order = p, direction = "x->y"))
  }

  f_stat <- ((rss_r - rss_u) / dof_diff) / (rss_u / dof_u)
  p_val <- stats::pf(f_stat, dof_diff, dof_u, lower.tail = FALSE)

  list(
    f_statistic = f_stat,
    p_value = p_val,
    optimal_order = p,
    direction = "x->y"
  )
}


#' Pairwise transfer entropy
#'
#' Discretization-based transfer entropy from x to y.
#'
#' @param x Numeric vector (source signal).
#' @param y Numeric vector (target signal).
#' @param lag Integer, time lag.
#' @param n_bins Integer, number of bins for discretization (NULL for auto).
#' @return A list with: te_value, n_bins_used, effective_n.
#' @keywords internal
.transferEntropyPairwise <- function(x, y, lag = 1L, n_bins = NULL) {
  n <- min(length(x), length(y))
  if (n < lag + 3) {
    return(list(te_value = 0, n_bins_used = NA_integer_, effective_n = 0L))
  }
  x <- x[seq_len(n)]
  y <- y[seq_len(n)]

  # Auto bins
  if (is.null(n_bins)) {
    n_bins <- max(2L, min(20L, floor(sqrt(n / 5))))
  }

  # Discretize
  x_d <- cut(x, breaks = n_bins, labels = FALSE, include.lowest = TRUE)
  y_d <- cut(y, breaks = n_bins, labels = FALSE, include.lowest = TRUE)

  # Handle constant signals
  if (all(is.na(x_d)) || all(is.na(y_d)) ||
      length(unique(x_d[!is.na(x_d)])) < 2 ||
      length(unique(y_d[!is.na(y_d)])) < 2) {
    return(list(te_value = 0, n_bins_used = n_bins, effective_n = 0L))
  }

  # Build joint/conditional counts
  eff_n <- n - lag
  y_future <- y_d[(lag + 1):n]
  y_past <- y_d[1:eff_n]
  x_past <- x_d[1:eff_n]

  # Remove NAs
  valid <- !is.na(y_future) & !is.na(y_past) & !is.na(x_past)
  y_future <- y_future[valid]
  y_past <- y_past[valid]
  x_past <- x_past[valid]
  eff_n <- sum(valid)

  if (eff_n < 10) {
    return(list(te_value = 0, n_bins_used = n_bins, effective_n = eff_n))
  }

  # Count joint probabilities
  # p(y_f, y_p, x_p), p(y_f, y_p), p(y_p, x_p), p(y_p)
  joint3 <- table(y_future, y_past, x_past)
  joint_yfy <- table(y_future, y_past)
  joint_yx <- table(y_past, x_past)
  marg_y <- table(y_past)

  te <- 0
  for (yf in dimnames(joint3)[[1]]) {
    for (yp in dimnames(joint3)[[2]]) {
      for (xp in dimnames(joint3)[[3]]) {
        p_yfyxp <- joint3[yf, yp, xp] / eff_n
        if (p_yfyxp <= 0) next

        p_yf_yp <- if (yf %in% rownames(joint_yfy) &&
                        yp %in% colnames(joint_yfy)) {
          joint_yfy[yf, yp] / eff_n
        } else 0

        p_ypxp <- if (yp %in% rownames(joint_yx) &&
                       xp %in% colnames(joint_yx)) {
          joint_yx[yp, xp] / eff_n
        } else 0

        p_yp <- if (yp %in% names(marg_y)) marg_y[yp] / eff_n else 0

        if (p_yf_yp > 0 && p_ypxp > 0 && p_yp > 0) {
          # TE = sum p(yf,yp,xp) * log( p(yf|yp,xp) / p(yf|yp) )
          # = sum p(yf,yp,xp) * log( (p(yf,yp,xp) * p(yp)) / (p(yf,yp) * p(yp,xp)) )
          ratio <- (p_yfyxp * p_yp) / (p_yf_yp * p_ypxp)
          if (ratio > 0) {
            te <- te + p_yfyxp * log(ratio)
          }
        }
      }
    }
  }

  list(te_value = max(0, te), n_bins_used = n_bins, effective_n = eff_n)
}


#' Build directional connectivity matrices
#'
#' @param eeg_mat Matrix (time x n_eeg).
#' @param emg_mat Matrix (time x n_emg).
#' @param sr Sampling rate.
#' @param method "granger" or "transfer_entropy".
#' @param max_order For Granger.
#' @param lag For TE.
#' @param n_bins For TE.
#' @return A list with: descending (n_eeg x n_emg), ascending (n_emg x n_eeg).
#' @keywords internal
.directionalConnectivityMatrix <- function(eeg_mat, emg_mat, sr,
                                            method = "granger",
                                            max_order = 5L, lag = 1L,
                                            n_bins = NULL) {
  n_eeg <- ncol(eeg_mat)
  n_emg <- ncol(emg_mat)
  n_time <- min(nrow(eeg_mat), nrow(emg_mat))
  eeg_mat <- eeg_mat[seq_len(n_time), , drop = FALSE]
  emg_mat <- emg_mat[seq_len(n_time), , drop = FALSE]

  desc <- matrix(0, n_eeg, n_emg)
  asc <- matrix(0, n_emg, n_eeg)

  for (i in seq_len(n_eeg)) {
    for (j in seq_len(n_emg)) {
      if (method == "granger") {
        # Descending: EEG -> EMG
        gc_desc <- .grangerCausalityPairwise(
          eeg_mat[, i], emg_mat[, j], max_order = max_order
        )
        desc[i, j] <- if (!is.na(gc_desc$p_value) && gc_desc$p_value > 0) {
          -log10(gc_desc$p_value)
        } else 0

        # Ascending: EMG -> EEG
        gc_asc <- .grangerCausalityPairwise(
          emg_mat[, j], eeg_mat[, i], max_order = max_order
        )
        asc[j, i] <- if (!is.na(gc_asc$p_value) && gc_asc$p_value > 0) {
          -log10(gc_asc$p_value)
        } else 0
      } else {
        # Transfer entropy
        te_desc <- .transferEntropyPairwise(
          eeg_mat[, i], emg_mat[, j], lag = lag, n_bins = n_bins
        )
        desc[i, j] <- te_desc$te_value

        te_asc <- .transferEntropyPairwise(
          emg_mat[, j], eeg_mat[, i], lag = lag, n_bins = n_bins
        )
        asc[j, i] <- te_asc$te_value
      }
    }
  }

  rownames(desc) <- colnames(eeg_mat)
  colnames(desc) <- colnames(emg_mat)
  rownames(asc) <- colnames(emg_mat)
  colnames(asc) <- colnames(eeg_mat)

  list(descending = desc, ascending = asc)
}


#' Directional Cortico-Muscular Coupling
#'
#' Computes directional (causal) connectivity between EEG and EMG channels
#' using Granger causality or transfer entropy, distinguishing descending
#' (cortical->muscle) from ascending (proprioceptive) pathways.
#'
#' @param eeg EEG data: SummarizedExperiment, matrix (time x channels), or vector.
#' @param emg EMG data: SummarizedExperiment, matrix (time x channels), or vector.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param method Character: "granger" (default), "transfer_entropy", or "both".
#' @param max_order_ms Numeric, maximum lag in ms for Granger (default: 50).
#' @param lag_ms Numeric, TE lag in ms (default: 20).
#' @param n_bins Integer, bins for TE discretization (NULL for auto).
#' @param eeg_channels Optional character vector of EEG channels to use.
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param sr_eeg Optional sampling rate for EEG.
#' @param sr_emg Optional sampling rate for EMG.
#' @param n_perm Integer, permutations for Mantel test (default: 999).
#' @param alpha Numeric, significance threshold (default: 0.05).
#' @return An S3 object of class \code{"MSKNeuromechDirectional"} with:
#'   \describe{
#'     \item{descending}{Matrix (n_eeg x n_emg): EEG->EMG values}
#'     \item{ascending}{Matrix (n_emg x n_eeg): EMG->EEG values}
#'     \item{net_direction}{descending - t(ascending)}
#'     \item{significant_descending}{Data.frame of significant descending pairs}
#'     \item{significant_ascending}{Data.frame of significant ascending pairs}
#'     \item{dominance_ratio}{Per-muscle mean(descending)/mean(ascending)}
#'     \item{pathway_classification}{Data.frame classifying each pair}
#'     \item{msk_correlation}{Mantel test result}
#'     \item{method}{Method used}
#'     \item{parameters}{List of parameters used}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- neuromechDirectionalCoupling(eeg_data, emg_data, method = "granger")
#' }
neuromechDirectionalCoupling <- function(eeg, emg, hg = NULL,
                                          method = c("granger",
                                                      "transfer_entropy",
                                                      "both"),
                                          max_order_ms = 50,
                                          lag_ms = 20,
                                          n_bins = NULL,
                                          eeg_channels = NULL,
                                          emg_mapping = NULL,
                                          sr_eeg = NULL, sr_emg = NULL,
                                          n_perm = 999L, alpha = 0.05) {
  method <- match.arg(method)
  hg <- .ensureHypergraph(hg)

  # Extract signals
  eeg_data <- .extractSignalMatrix(eeg, "EEG")
  eeg_mat <- eeg_data$signal_mat
  sr_eeg <- sr_eeg %||% eeg_data$sr %||% 1000

  emg_data <- .extractSignalMatrix(emg, "EMG")
  emg_mat <- emg_data$signal_mat
  sr_emg <- sr_emg %||% emg_data$sr %||% 1000

  # Select EEG channels
  if (!is.null(eeg_channels)) {
    keep <- which(eeg_data$ch_names %in% eeg_channels)
    if (length(keep) > 0) {
      eeg_mat <- eeg_mat[, keep, drop = FALSE]
    }
  }

  # Convert ms to samples
  sr <- min(sr_eeg, sr_emg)
  max_order <- max(1L, round(max_order_ms / 1000 * sr))
  lag <- max(1L, round(lag_ms / 1000 * sr))

  if (is.null(emg_mapping)) {
    emg_mapping <- emgToMSKMapping(colnames(emg_mat), hg = hg, method = "fuzzy")
  }

  # Compute directional connectivity
  if (method == "both") {
    gc_result <- .directionalConnectivityMatrix(
      eeg_mat, emg_mat, sr, method = "granger", max_order = max_order
    )
    te_result <- .directionalConnectivityMatrix(
      eeg_mat, emg_mat, sr, method = "transfer_entropy",
      lag = lag, n_bins = n_bins
    )
    desc <- gc_result$descending
    asc <- gc_result$ascending
    desc_te <- te_result$descending
    asc_te <- te_result$ascending
  } else {
    dc <- .directionalConnectivityMatrix(
      eeg_mat, emg_mat, sr,
      method = if (method == "granger") "granger" else "transfer_entropy",
      max_order = max_order, lag = lag, n_bins = n_bins
    )
    desc <- dc$descending
    asc <- dc$ascending
  }

  # Net direction
  net_dir <- desc - t(asc)

  # Determine significance threshold
  if (method == "granger") {
    thresh <- -log10(alpha)
  } else {
    thresh <- median(c(desc[desc > 0], asc[asc > 0]))
    if (is.na(thresh) || thresh == 0) thresh <- 0.001
  }

  # Significant descending pairs
  sig_desc_idx <- which(desc > thresh, arr.ind = TRUE)
  if (nrow(sig_desc_idx) > 0) {
    sig_desc <- data.frame(
      eeg_channel = rownames(desc)[sig_desc_idx[, 1]],
      emg_channel = colnames(desc)[sig_desc_idx[, 2]],
      value = desc[sig_desc_idx],
      stringsAsFactors = FALSE
    )
    sig_desc <- sig_desc[order(sig_desc$value, decreasing = TRUE), ]
    rownames(sig_desc) <- NULL
  } else {
    sig_desc <- data.frame(eeg_channel = character(0),
                            emg_channel = character(0),
                            value = numeric(0), stringsAsFactors = FALSE)
  }

  # Significant ascending pairs
  sig_asc_idx <- which(asc > thresh, arr.ind = TRUE)
  if (nrow(sig_asc_idx) > 0) {
    sig_asc <- data.frame(
      emg_channel = rownames(asc)[sig_asc_idx[, 1]],
      eeg_channel = colnames(asc)[sig_asc_idx[, 2]],
      value = asc[sig_asc_idx],
      stringsAsFactors = FALSE
    )
    sig_asc <- sig_asc[order(sig_asc$value, decreasing = TRUE), ]
    rownames(sig_asc) <- NULL
  } else {
    sig_asc <- data.frame(emg_channel = character(0),
                            eeg_channel = character(0),
                            value = numeric(0), stringsAsFactors = FALSE)
  }

  # Dominance ratio per muscle
  dom_ratio <- numeric(ncol(emg_mat))
  names(dom_ratio) <- colnames(emg_mat)
  for (j in seq_len(ncol(emg_mat))) {
    d_mean <- mean(desc[, j])
    a_mean <- mean(asc[j, ])
    dom_ratio[j] <- if (a_mean > 0) d_mean / a_mean else Inf
  }

  # Pathway classification
  pathways <- list()
  for (i in seq_len(ncol(eeg_mat))) {
    for (j in seq_len(ncol(emg_mat))) {
      d_val <- desc[i, j]
      a_val <- asc[j, i]
      d_sig <- d_val > thresh
      a_sig <- a_val > thresh
      cls <- if (d_sig && a_sig) "bidirectional"
             else if (d_sig) "descending"
             else if (a_sig) "ascending"
             else "none"
      pathways[[length(pathways) + 1L]] <- data.frame(
        eeg_channel = colnames(eeg_mat)[i],
        emg_channel = colnames(emg_mat)[j],
        descending_value = d_val,
        ascending_value = a_val,
        classification = cls,
        stringsAsFactors = FALSE
      )
    }
  }
  pathway_df <- do.call(rbind, pathways)
  rownames(pathway_df) <- NULL

  # Mantel test
  mantel_result <- list(correlation = NA_real_, p_value = NA_real_)
  if (nrow(emg_mapping) >= 3) {
    n_m <- nrow(emg_mapping)
    emg_ch_idx <- emg_mapping$channel_idx
    # Functional distance from mean descending drive
    func_vals <- colMeans(desc)[emg_ch_idx]
    func_dist <- matrix(0, n_m, n_m)
    for (ii in seq_len(n_m - 1)) {
      for (jj in (ii + 1):n_m) {
        func_dist[ii, jj] <- func_dist[jj, ii] <-
          abs(func_vals[ii] - func_vals[jj])
      }
    }
    rownames(func_dist) <- colnames(func_dist) <- emg_mapping$muscle_name

    B <- as.matrix(projectMuscleGraph(hg))
    m_idx <- emg_mapping$muscle_idx
    struct_mat <- (B[m_idx, m_idx, drop = FALSE] > 0) * 1.0
    rownames(struct_mat) <- colnames(struct_mat) <- emg_mapping$muscle_name

    mantel_result <- .mantelTest(func_dist, struct_mat, n_perm = n_perm)
  }

  result <- list(
    descending = desc,
    ascending = asc,
    net_direction = net_dir,
    significant_descending = sig_desc,
    significant_ascending = sig_asc,
    dominance_ratio = dom_ratio,
    pathway_classification = pathway_df,
    msk_correlation = mantel_result,
    method = method,
    parameters = list(max_order_ms = max_order_ms, lag_ms = lag_ms,
                       alpha = alpha, sr = sr)
  )

  if (method == "both") {
    result$descending_te <- desc_te
    result$ascending_te <- asc_te
  }

  structure(result, class = "MSKNeuromechDirectional")
}


#' @export
print.MSKNeuromechDirectional <- function(x, ...) {
  cat("MSK Neuromech Directional Coupling\n")
  cat("===================================\n")
  cat("Method:", x$method, "\n")
  cat("EEG channels:", nrow(x$descending), "\n")
  cat("EMG channels:", ncol(x$descending), "\n")
  cat("Significant descending pairs:", nrow(x$significant_descending), "\n")
  cat("Significant ascending pairs:", nrow(x$significant_ascending), "\n\n")

  if (length(x$dominance_ratio) > 0) {
    cat("Dominance ratio (desc/asc) per muscle:\n")
    for (i in seq_along(x$dominance_ratio)) {
      val <- x$dominance_ratio[i]
      cat(sprintf("  %s: %.3f%s\n",
                  names(x$dominance_ratio)[i],
                  if (is.finite(val)) val else Inf,
                  if (val > 1) " [descending]"
                  else if (val < 1) " [ascending]"
                  else " [balanced]"))
    }
    cat("\n")
  }

  if (!is.na(x$msk_correlation$correlation)) {
    cat("Mantel test: r =", round(x$msk_correlation$correlation, 3),
        ", p =", round(x$msk_correlation$p_value, 4), "\n")
  }

  invisible(x)
}
