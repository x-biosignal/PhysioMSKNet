# ===========================================================================
# bridge-emg.R -- EMG functional connectivity vs MSK structural connectivity
# ===========================================================================

# ---- Internal helpers ----

#' Permutation-based Mantel test for matrix correlation
#'
#' Computes Pearson correlation between upper triangles of two symmetric
#' matrices and tests significance via permutation.
#'
#' @param mat1 Numeric matrix (symmetric).
#' @param mat2 Numeric matrix (symmetric, same dimension as mat1).
#' @param n_perm Integer, number of permutations (default: 999).
#' @return A list with: correlation, p_value, n_perm.
#' @keywords internal
.mantelTest <- function(mat1, mat2, n_perm = 999L) {
  stopifnot(nrow(mat1) == nrow(mat2))
  stopifnot(ncol(mat1) == ncol(mat2))
  n <- nrow(mat1)
  if (n < 3) return(list(correlation = NA_real_, p_value = NA_real_, n_perm = 0L))

  # Extract upper triangles
  idx <- which(upper.tri(mat1))
  v1 <- mat1[idx]
  v2 <- mat2[idx]

  # Remove NA/Inf
  valid <- is.finite(v1) & is.finite(v2)
  v1 <- v1[valid]
  v2 <- v2[valid]

  if (length(v1) < 3 || sd(v1) == 0 || sd(v2) == 0) {
    return(list(correlation = 0, p_value = 1.0, n_perm = n_perm))
  }

  obs_cor <- cor(v1, v2)

  # Permutation test: permute rows/cols of mat2
  n_geq <- 0L
  for (p in seq_len(n_perm)) {
    perm <- sample(n)
    perm_mat2 <- mat2[perm, perm]
    perm_v2 <- perm_mat2[idx][valid]
    if (sd(perm_v2) == 0) next
    perm_cor <- cor(v1, perm_v2)
    if (perm_cor >= obs_cor) n_geq <- n_geq + 1L
  }

  list(
    correlation = obs_cor,
    p_value = (n_geq + 1L) / (n_perm + 1L),
    n_perm = n_perm
  )
}


#' Minimal Welch coherence estimation
#'
#' Fallback coherence computation when PhysioEMG is not installed.
#' Uses Welch's method with Hanning window.
#'
#' @param signal_matrix Numeric matrix (time x channels).
#' @param sr Numeric, sampling rate in Hz.
#' @param freq_band Numeric vector of length 2, frequency band in Hz.
#' @param nperseg Integer, segment length for Welch's method.
#' @return Symmetric coherence matrix (channels x channels) in \[0, 1\].
#' @keywords internal
.minimalCoherence <- function(signal_matrix, sr, freq_band = c(20, 50),
                               nperseg = 256L) {
  n_chan <- ncol(signal_matrix)
  n_time <- nrow(signal_matrix)

  if (n_time < nperseg) nperseg <- n_time

  # Hanning window
  window <- 0.5 * (1 - cos(2 * pi * seq(0, nperseg - 1) / (nperseg - 1)))

  # Frequency resolution
  freqs <- seq(0, sr / 2, length.out = floor(nperseg / 2) + 1)
  freq_idx <- which(freqs >= freq_band[1] & freqs <= freq_band[2])

  if (length(freq_idx) == 0) {
    # No frequencies in band, return zeros
    coh <- matrix(0, n_chan, n_chan)
    rownames(coh) <- colnames(coh) <- colnames(signal_matrix)
    return(coh)
  }

  # Compute segment-averaged cross/auto spectra
  n_segments <- max(1L, floor(2 * n_time / nperseg) - 1)
  hop <- max(1L, floor((n_time - nperseg) / max(1, n_segments - 1)))

  # Initialize power/cross spectral density accumulators
  n_freq <- length(freqs)
  Sxx <- matrix(0, n_freq, n_chan)
  Sxy <- matrix(0 + 0i, n_freq, n_chan * (n_chan - 1) / 2)

  seg_count <- 0L
  for (s in seq_len(n_segments)) {
    start <- (s - 1) * hop + 1
    end <- start + nperseg - 1
    if (end > n_time) break
    seg_count <- seg_count + 1L

    # Windowed FFT per channel
    fft_mat <- matrix(0 + 0i, n_freq, n_chan)
    for (ch in seq_len(n_chan)) {
      seg <- signal_matrix[start:end, ch] * window
      ft <- stats::fft(seg)
      fft_mat[, ch] <- ft[seq_len(n_freq)]
    }

    # Auto spectra
    Sxx <- Sxx + abs(fft_mat)^2

    # Cross spectra (upper triangle pairs)
    pair <- 0L
    for (i in seq_len(n_chan - 1)) {
      for (j in (i + 1):n_chan) {
        pair <- pair + 1L
        Sxy[, pair] <- Sxy[, pair] + fft_mat[, i] * Conj(fft_mat[, j])
      }
    }
  }

  if (seg_count == 0L) seg_count <- 1L
  Sxx <- Sxx / seg_count
  Sxy <- Sxy / seg_count

  # Build coherence matrix (average over freq band)
  coh <- diag(1, n_chan)
  pair <- 0L
  for (i in seq_len(n_chan - 1)) {
    for (j in (i + 1):n_chan) {
      pair <- pair + 1L
      num <- mean(abs(Sxy[freq_idx, pair])^2)
      denom <- mean(Sxx[freq_idx, i]) * mean(Sxx[freq_idx, j])
      coh[i, j] <- if (denom > 0) num / denom else 0
      coh[j, i] <- coh[i, j]
    }
  }

  rownames(coh) <- colnames(coh) <- colnames(signal_matrix)
  coh
}


# ---- Exported functions ----

#' Map EMG Channels to MSK Muscles
#'
#' Matches EMG channel names from a PhysioExperiment/SummarizedExperiment
#' object to muscles in an MSK hypergraph.
#'
#' @param pe A SummarizedExperiment-like object with channel names in
#'   \code{colData(pe)$name} or \code{colnames(assay(pe))}.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param method Character, matching method: "exact" or "fuzzy".
#' @param threshold Numeric, fuzzy matching threshold (default: 0.8).
#' @return A data.frame with columns: channel_idx, channel_name, muscle_idx,
#'   muscle_name, match_quality.
#' @export
#' @examples
#' \dontrun{
#' mapping <- emgToMSKMapping(pe_emg, method = "fuzzy")
#' }
emgToMSKMapping <- function(pe, hg = NULL,
                             method = c("exact", "fuzzy"),
                             threshold = 0.8) {
  method <- match.arg(method)
  hg <- .ensureHypergraph(hg)

  # Extract channel names
  if (is.character(pe)) {
    ch_names <- pe
  } else {
    ch_names <- tryCatch(
      {
        cd <- pe@colData
        if ("name" %in% colnames(cd)) as.character(cd$name)
        else colnames(pe@assays@data[[1]])
      },
      error = function(e) {
        if (!is.null(colnames(pe))) colnames(pe)
        else stop("Cannot extract channel names from pe")
      }
    )
  }

  # Normalize names: strip prefixes/suffixes, lowercase
  .normalize <- function(x) {
    x <- tolower(trimws(x))
    x <- gsub("^[rl]_", "", x)
    x <- gsub("_emg$", "", x)
    x <- gsub("\\s+", " ", x)
    x
  }

  ch_norm <- .normalize(ch_names)
  m_norm <- .normalize(hg$muscle_names)

  results <- list()
  for (i in seq_along(ch_names)) {
    if (method == "exact") {
      match_idx <- which(m_norm == ch_norm[i])
      if (length(match_idx) >= 1L) {
        results[[length(results) + 1L]] <- data.frame(
          channel_idx = i,
          channel_name = ch_names[i],
          muscle_idx = match_idx[1L],
          muscle_name = hg$muscle_names[match_idx[1L]],
          match_quality = 1.0,
          stringsAsFactors = FALSE
        )
      }
    } else {
      # Fuzzy matching
      match_idx <- agrep(ch_norm[i], m_norm,
                          max.distance = 1 - threshold,
                          ignore.case = TRUE)
      if (length(match_idx) >= 1L) {
        # Use best match (shortest edit distance)
        dists <- vapply(match_idx, function(j) {
          adist(ch_norm[i], m_norm[j])
        }, numeric(1))
        best <- match_idx[which.min(dists)]
        quality <- 1 - min(dists) / max(nchar(ch_norm[i]), nchar(m_norm[best]))
        results[[length(results) + 1L]] <- data.frame(
          channel_idx = i,
          channel_name = ch_names[i],
          muscle_idx = best,
          muscle_name = hg$muscle_names[best],
          match_quality = round(quality, 3),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(results) == 0L) {
    return(data.frame(
      channel_idx = integer(0),
      channel_name = character(0),
      muscle_idx = integer(0),
      muscle_name = character(0),
      match_quality = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  do.call(rbind, results)
}


#' Compare EMG Coherence with MSK Structural Connectivity
#'
#' Computes EMG functional coherence and compares it with structural
#' adjacency from the MSK muscle graph using a Mantel test.
#'
#' @param pe A SummarizedExperiment-like object or a numeric signal matrix
#'   (time x channels).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param freq_band Numeric vector of length 2, frequency band in Hz for
#'   coherence (default: c(20, 50) for EMG beta/gamma).
#' @param mapping Optional data.frame from \code{emgToMSKMapping()}.
#' @return A list with:
#'   \describe{
#'     \item{coherence_matrix}{EMG functional coherence matrix}
#'     \item{structural_matrix}{MSK structural adjacency (matched subset)}
#'     \item{correlation}{Mantel correlation coefficient}
#'     \item{p_value}{Permutation-based p-value}
#'     \item{mapped_muscles}{Names of matched muscles}
#'   }
#' @export
#' @examples
#' \dontrun{
#' result <- emgStructuralCoherence(pe_emg, freq_band = c(20, 50))
#' }
emgStructuralCoherence <- function(pe, hg = NULL, freq_band = c(20, 50),
                                    mapping = NULL) {
  hg <- .ensureHypergraph(hg)

  # Extract signal matrix and sampling rate
  if (is.matrix(pe) || is.data.frame(pe)) {
    signal_mat <- as.matrix(pe)
    sr <- attr(pe, "sr") %||% 1000
    ch_names <- colnames(pe) %||% paste0("ch_", seq_len(ncol(pe)))
  } else {
    # SummarizedExperiment-like
    signal_mat <- tryCatch(
      as.matrix(pe@assays@data[[1]]),
      error = function(e) stop("Cannot extract signal matrix from pe")
    )
    sr <- tryCatch(pe@samplingRate %||% 1000, error = function(e) 1000)
    ch_names <- tryCatch(
      colnames(pe@assays@data[[1]]),
      error = function(e) paste0("ch_", seq_len(ncol(signal_mat)))
    )
    colnames(signal_mat) <- ch_names
  }

  # Get mapping if not provided
  if (is.null(mapping)) {
    mapping <- emgToMSKMapping(ch_names, hg = hg, method = "fuzzy")
  }

  if (nrow(mapping) < 3) {
    warning("Fewer than 3 channels mapped to MSK muscles; results may be unreliable")
  }

  if (nrow(mapping) == 0) {
    return(list(
      coherence_matrix = matrix(nrow = 0, ncol = 0),
      structural_matrix = matrix(nrow = 0, ncol = 0),
      correlation = NA_real_,
      p_value = NA_real_,
      mapped_muscles = character(0)
    ))
  }

  # Compute coherence on matched channels
  matched_signal <- signal_mat[, mapping$channel_idx, drop = FALSE]
  colnames(matched_signal) <- mapping$muscle_name

  # Use PhysioEMG if available, otherwise fallback
  coh_mat <- if (requireNamespace("PhysioEMG", quietly = TRUE) &&
                 exists("emgCoherenceNetwork", where = asNamespace("PhysioEMG"))) {
    tryCatch(
      PhysioEMG::emgCoherenceNetwork(matched_signal, sr = sr,
                                      freq_band = freq_band),
      error = function(e) .minimalCoherence(matched_signal, sr, freq_band)
    )
  } else {
    .minimalCoherence(matched_signal, sr, freq_band)
  }

  # Extract structural adjacency for matched muscles
  B <- as.matrix(projectMuscleGraph(hg))
  m_idx <- mapping$muscle_idx
  struct_sub <- B[m_idx, m_idx, drop = FALSE]
  # Binarize structural adjacency
  struct_bin <- (struct_sub > 0) * 1.0
  rownames(struct_bin) <- colnames(struct_bin) <- mapping$muscle_name

  # Mantel test
  mantel <- .mantelTest(coh_mat, struct_bin, n_perm = 999L)

  list(
    coherence_matrix = coh_mat,
    structural_matrix = struct_bin,
    correlation = mantel$correlation,
    p_value = mantel$p_value,
    mapped_muscles = mapping$muscle_name
  )
}


#' Compare EMG and MSK Communities
#'
#' Detects functional communities from EMG coherence and compares them
#' with structural communities from the MSK network.
#'
#' @param pe A SummarizedExperiment-like object or numeric signal matrix.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param gamma Resolution parameter for MSK community detection (default: 4.3).
#' @param mapping Optional data.frame from \code{emgToMSKMapping()}.
#' @return A list with:
#'   \describe{
#'     \item{emg_communities}{Named integer vector of EMG community assignments}
#'     \item{msk_communities}{Named integer vector of MSK community assignments}
#'     \item{z_rand}{z-Rand score comparing the two partitions}
#'     \item{mapping}{The channel-to-muscle mapping used}
#'   }
#' @export
emgCommunityCompare <- function(pe, hg = NULL, gamma = 4.3, mapping = NULL) {
  hg <- .ensureHypergraph(hg)

  # Extract signal and compute coherence
  if (is.matrix(pe) || is.data.frame(pe)) {
    signal_mat <- as.matrix(pe)
    sr <- attr(pe, "sr") %||% 1000
    ch_names <- colnames(pe) %||% paste0("ch_", seq_len(ncol(pe)))
  } else {
    signal_mat <- tryCatch(
      as.matrix(pe@assays@data[[1]]),
      error = function(e) stop("Cannot extract signal matrix from pe")
    )
    sr <- tryCatch(pe@samplingRate %||% 1000, error = function(e) 1000)
    ch_names <- tryCatch(
      colnames(pe@assays@data[[1]]),
      error = function(e) paste0("ch_", seq_len(ncol(signal_mat)))
    )
    colnames(signal_mat) <- ch_names
  }

  if (is.null(mapping)) {
    mapping <- emgToMSKMapping(ch_names, hg = hg, method = "fuzzy")
  }
  if (nrow(mapping) < 3) {
    stop("Need at least 3 mapped channels for community comparison")
  }

  matched_signal <- signal_mat[, mapping$channel_idx, drop = FALSE]
  colnames(matched_signal) <- mapping$muscle_name
  coh_mat <- .minimalCoherence(matched_signal, sr)

  # EMG functional communities via Louvain on coherence matrix
  # Threshold coherence to create adjacency
  coh_adj <- coh_mat
  diag(coh_adj) <- 0
  coh_adj[coh_adj < 0.1] <- 0  # sparsify

  emg_comm <- .louvain_r(coh_adj, gamma = 1.0)
  emg_membership <- emg_comm$membership
  names(emg_membership) <- mapping$muscle_name

  # MSK structural communities (subset)
  msk_comm <- mskCommunityDetect(hg, gamma = gamma, type = "muscle")
  msk_membership_sub <- msk_comm$membership[mapping$muscle_idx]
  names(msk_membership_sub) <- mapping$muscle_name

  # Compare
  z_rand <- mskZRand(emg_membership, msk_membership_sub)

  list(
    emg_communities = emg_membership,
    msk_communities = msk_membership_sub,
    z_rand = z_rand,
    mapping = mapping
  )
}


#' EMG Activation Enrichment by MSK Community
#'
#' Tests whether EMG activation levels differ across MSK community
#' assignments using a Kruskal-Wallis test.
#'
#' @param pe A SummarizedExperiment-like object or numeric signal matrix.
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param gamma Resolution parameter for MSK community detection (default: 4.3).
#' @param mapping Optional data.frame from \code{emgToMSKMapping()}.
#' @return A list with:
#'   \describe{
#'     \item{per_community}{Data frame with community, mean/median activation}
#'     \item{overall_test}{Kruskal-Wallis test result}
#'     \item{activation_values}{Named numeric vector of RMS activation}
#'   }
#' @export
emgMSKEnrichment <- function(pe, hg = NULL, gamma = 4.3, mapping = NULL) {
  hg <- .ensureHypergraph(hg)

  # Extract signal matrix
  if (is.matrix(pe) || is.data.frame(pe)) {
    signal_mat <- as.matrix(pe)
    ch_names <- colnames(pe) %||% paste0("ch_", seq_len(ncol(pe)))
  } else {
    signal_mat <- tryCatch(
      as.matrix(pe@assays@data[[1]]),
      error = function(e) stop("Cannot extract signal matrix from pe")
    )
    ch_names <- tryCatch(
      colnames(pe@assays@data[[1]]),
      error = function(e) paste0("ch_", seq_len(ncol(signal_mat)))
    )
    colnames(signal_mat) <- ch_names
  }

  if (is.null(mapping)) {
    mapping <- emgToMSKMapping(ch_names, hg = hg, method = "fuzzy")
  }
  if (nrow(mapping) == 0) {
    stop("No channels mapped to MSK muscles")
  }

  # Compute RMS activation per channel
  rms <- vapply(mapping$channel_idx, function(ch) {
    sqrt(mean(signal_mat[, ch]^2))
  }, numeric(1))
  names(rms) <- mapping$muscle_name

  # MSK community assignments
  msk_comm <- mskCommunityDetect(hg, gamma = gamma, type = "muscle")
  membership <- msk_comm$membership[mapping$muscle_idx]
  names(membership) <- mapping$muscle_name

  # Per-community summary
  comms <- sort(unique(membership))
  per_comm <- data.frame(
    community = comms,
    n_muscles = vapply(comms, function(c) sum(membership == c), integer(1)),
    mean_activation = vapply(comms, function(c) mean(rms[membership == c]), numeric(1)),
    median_activation = vapply(comms, function(c) median(rms[membership == c]), numeric(1)),
    stringsAsFactors = FALSE
  )

  # Kruskal-Wallis test
  if (length(comms) >= 2 && length(rms) >= 3) {
    kw <- stats::kruskal.test(rms ~ factor(membership))
    overall_test <- list(
      statistic = kw$statistic,
      p_value = kw$p.value,
      df = kw$parameter,
      method = kw$method
    )
  } else {
    overall_test <- list(
      statistic = NA_real_,
      p_value = NA_real_,
      df = NA_real_,
      method = "Insufficient groups for Kruskal-Wallis"
    )
  }

  list(
    per_community = per_comm,
    overall_test = overall_test,
    activation_values = rms
  )
}
