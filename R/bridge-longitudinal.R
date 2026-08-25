# ===========================================================================
# bridge-longitudinal.R -- Longitudinal rehabilitation effectiveness measurement
# ===========================================================================
#
# Tracks musculoskeletal recovery across timepoints using EMG activation,
# muscle synergy decomposition, neural adaptation indices, and coordination
# quality scores. Provides clinimetric tools: ICC, MDC, recovery trajectory
# fitting, responder classification, and plateau detection.
#
# Reuses: .extractSignalMatrix, .computeRMS, .ensureHypergraph,
#   neuromechMuscleSynergy, neuromechCorticomuscularCoupling,
#   neuromechDirectionalCoupling, .mantelTest, emgToMSKMapping
# ===========================================================================

# ---- Internal helpers ----

#' Compute ICC(2,1) from a values matrix
#'
#' Uses one-way random ANOVA decomposition:
#' ICC = (BMS - WMS) / (BMS + (k-1)*WMS)
#'
#' @param values_matrix Numeric matrix (subjects x timepoints).
#' @return Numeric ICC value clamped to the range 0 to 1.
#' @keywords internal
.computeICC <- function(values_matrix) {
  values_matrix <- as.matrix(values_matrix)
  n <- nrow(values_matrix)  # subjects (muscles)
  k <- ncol(values_matrix)  # timepoints

  if (n < 2 || k < 2) return(0)

  # Remove rows with any NA
  complete <- complete.cases(values_matrix)
  values_matrix <- values_matrix[complete, , drop = FALSE]
  n <- nrow(values_matrix)
  if (n < 2) return(0)

  # Grand mean
  grand_mean <- mean(values_matrix)

  # Row means (subject means)
  row_means <- rowMeans(values_matrix)

  # Between-subjects mean square
  BMS <- k * sum((row_means - grand_mean)^2) / (n - 1)

  # Within-subjects mean square (residual)
  WMS <- sum((values_matrix - row_means)^2) / (n * (k - 1))

  # ICC(2,1)
  icc <- if (BMS + (k - 1) * WMS > 0) {
    (BMS - WMS) / (BMS + (k - 1) * WMS)
  } else {
    0
  }

  # Clamp to [0, 1]
  max(0, min(1, icc))
}


#' Fit exponential recovery curve with NLS fallback to linear
#'
#' Model: y = a * (1 - exp(-b * t)) + c
#'
#' @param t Numeric vector of time indices.
#' @param y Numeric vector of observed values.
#' @return A list with: coefficients, residuals, r_squared, aic, model_type,
#'   predicted, converged.
#' @keywords internal
.fitExponentialRecovery <- function(t, y) {
  n <- length(t)
  if (n < 3) return(.fitLinearRecovery(t, y))

  # Starting values
  y_range <- diff(range(y))
  if (y_range == 0) return(.fitLinearRecovery(t, y))

  a_start <- y_range
  c_start <- min(y)
  b_start <- 1 / max(t, 1)

  result <- tryCatch({
    fit <- stats::nls(
      y ~ a * (1 - exp(-b * t)) + c,
      start = list(a = a_start, b = b_start, c = c_start),
      control = stats::nls.control(maxiter = 200, warnOnly = TRUE)
    )
    pred <- stats::predict(fit)
    res <- stats::residuals(fit)
    ss_res <- sum(res^2)
    ss_tot <- sum((y - mean(y))^2)
    r_sq <- if (ss_tot > 0) 1 - ss_res / ss_tot else 0

    list(
      coefficients = as.list(stats::coef(fit)),
      residuals = as.numeric(res),
      r_squared = r_sq,
      aic = stats::AIC(fit),
      model_type = "exponential",
      predicted = as.numeric(pred),
      converged = TRUE
    )
  }, error = function(e) NULL)

  if (is.null(result)) return(.fitLinearRecovery(t, y))
  result
}


#' Fit sigmoid recovery curve with NLS fallback to linear
#'
#' Model: y = L / (1 + exp(-k * (t - t0)))
#'
#' @param t Numeric vector of time indices.
#' @param y Numeric vector of observed values.
#' @return A list with: coefficients, residuals, r_squared, aic, model_type,
#'   predicted, converged.
#' @keywords internal
.fitSigmoidRecovery <- function(t, y) {
  n <- length(t)
  if (n < 3) return(.fitLinearRecovery(t, y))

  y_range <- diff(range(y))
  if (y_range == 0) return(.fitLinearRecovery(t, y))

  L_start <- max(y)
  t0_start <- mean(t)
  k_start <- 4 / (max(t) - min(t) + 1e-6)

  result <- tryCatch({
    fit <- stats::nls(
      y ~ L / (1 + exp(-k * (t - t0))),
      start = list(L = L_start, k = k_start, t0 = t0_start),
      control = stats::nls.control(maxiter = 200, warnOnly = TRUE)
    )
    pred <- stats::predict(fit)
    res <- stats::residuals(fit)
    ss_res <- sum(res^2)
    ss_tot <- sum((y - mean(y))^2)
    r_sq <- if (ss_tot > 0) 1 - ss_res / ss_tot else 0

    list(
      coefficients = as.list(stats::coef(fit)),
      residuals = as.numeric(res),
      r_squared = r_sq,
      aic = stats::AIC(fit),
      model_type = "sigmoid",
      predicted = as.numeric(pred),
      converged = TRUE
    )
  }, error = function(e) NULL)

  if (is.null(result)) return(.fitLinearRecovery(t, y))
  result
}


#' Fit linear recovery model
#'
#' Model: y = a + b * t
#'
#' @param t Numeric vector of time indices.
#' @param y Numeric vector of observed values.
#' @return A list with: coefficients, residuals, r_squared, aic, model_type,
#'   predicted, converged.
#' @keywords internal
.fitLinearRecovery <- function(t, y) {
  if (length(t) < 2 || length(unique(t)) < 2) {
    return(list(
      coefficients = list(a = mean(y), b = 0),
      residuals = y - mean(y),
      r_squared = 0,
      aic = NA_real_,
      model_type = "linear",
      predicted = rep(mean(y), length(y)),
      converged = TRUE
    ))
  }

  fit <- stats::lm(y ~ t)
  pred <- stats::fitted(fit)
  res <- stats::residuals(fit)
  ss_res <- sum(res^2)
  ss_tot <- sum((y - mean(y))^2)
  r_sq <- if (ss_tot > 0) 1 - ss_res / ss_tot else 0

  list(
    coefficients = list(a = unname(stats::coef(fit)[1]),
                        b = unname(stats::coef(fit)[2])),
    residuals = as.numeric(res),
    r_squared = r_sq,
    aic = stats::AIC(fit),
    model_type = "linear",
    predicted = as.numeric(pred),
    converged = TRUE
  )
}


#' Greedy cosine alignment of two synergy weight matrices
#'
#' Aligns columns of W2 to best match columns of W1 using greedy
#' maximum cosine similarity (Hungarian algorithm approximation).
#'
#' @param W1 Numeric matrix (muscles x synergies).
#' @param W2 Numeric matrix (muscles x synergies, same dimensions as W1).
#' @return A list with: permutation (integer vector), cosine_similarities
#'   (numeric vector per aligned pair), mean_cosine (scalar).
#' @keywords internal
.alignSynergies <- function(W1, W2) {
  k1 <- ncol(W1)
  k2 <- ncol(W2)
  k <- min(k1, k2)

  # Compute cosine similarity matrix
  cos_mat <- matrix(0, k1, k2)
  for (i in seq_len(k1)) {
    n1 <- sqrt(sum(W1[, i]^2))
    if (n1 == 0) next
    for (j in seq_len(k2)) {
      n2 <- sqrt(sum(W2[, j]^2))
      if (n2 == 0) next
      cos_mat[i, j] <- sum(W1[, i] * W2[, j]) / (n1 * n2)
    }
  }

  # Greedy matching: pick highest cosine similarity pairs
  perm <- integer(k)
  cosines <- numeric(k)
  used_rows <- logical(k1)
  used_cols <- logical(k2)

  for (step in seq_len(k)) {
    # Find best remaining pair
    best_val <- -Inf
    best_i <- 0L
    best_j <- 0L
    for (i in seq_len(k1)) {
      if (used_rows[i]) next
      for (j in seq_len(k2)) {
        if (used_cols[j]) next
        if (cos_mat[i, j] > best_val) {
          best_val <- cos_mat[i, j]
          best_i <- i
          best_j <- j
        }
      }
    }
    perm[best_i] <- best_j
    cosines[best_i] <- best_val
    used_rows[best_i] <- TRUE
    used_cols[best_j] <- TRUE
  }

  # Fill unmatched (if k1 != k2)
  if (k1 > k2) {
    unmatched <- which(perm == 0L)
    for (i in unmatched) {
      perm[i] <- NA_integer_
      cosines[i] <- 0
    }
  }

  list(
    permutation = perm,
    cosine_similarities = cosines,
    mean_cosine = mean(cosines[!is.na(perm)])
  )
}


#' Rolling linear regression slope
#'
#' Computes the slope of a linear fit over a sliding window.
#'
#' @param x Numeric vector of values.
#' @param window Integer, window size.
#' @return Numeric vector of slopes (length = length(x) - window + 1).
#'   Returns empty numeric if window > length(x).
#' @keywords internal
.rollingSlope <- function(x, window) {
  n <- length(x)
  if (n < window || window < 2) return(numeric(0))

  n_windows <- n - window + 1
  slopes <- numeric(n_windows)
  t_vec <- seq_len(window)

  for (i in seq_len(n_windows)) {
    y_win <- x[i:(i + window - 1)]
    if (all(is.finite(y_win))) {
      fit <- stats::lm(y_win ~ t_vec)
      slopes[i] <- unname(stats::coef(fit)[2])
    } else {
      slopes[i] <- NA_real_
    }
  }

  slopes
}


# ---- Exported functions ----

#' Track Longitudinal MSK Metrics Across Timepoints
#'
#' Computes per-timepoint RMS activation, synergy decomposition (W/H/VAF),
#' and optionally CMC for a series of EMG measurements taken at different
#' timepoints during rehabilitation.
#'
#' @param timepoints Named list of EMG matrices (time x channels). Names
#'   should be timepoint labels (e.g., "T0", "T1", "T2").
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param emg_mapping Optional pre-computed data.frame from \code{emgToMSKMapping()}.
#' @param metrics Character vector of metrics to compute (default: c("rms", "synergy")).
#'   Options: "rms", "synergy", "mean_activation", "peak_activation".
#' @param sr Optional sampling rate in Hz (overrides detected values).
#' @return An S3 object of class \code{"MSKLongitudinalTracker"} with:
#'   \describe{
#'     \item{metrics_table}{data.frame (timepoint, muscle, metric_name, value)}
#'     \item{timepoint_labels}{character vector}
#'     \item{n_timepoints}{integer}
#'     \item{synergy_series}{list of synergy results per timepoint}
#'     \item{activation_series}{matrix (n_muscles x n_timepoints)}
#'   }
#' @export
#' @examples
#' \dontrun{
#' emg_t0 <- matrix(abs(rnorm(400)), 100, 4)
#' emg_t1 <- matrix(abs(rnorm(400)), 100, 4)
#' colnames(emg_t0) <- colnames(emg_t1) <- paste0("muscle_", 1:4)
#' tracker <- mskLongitudinalTracker(list(T0 = emg_t0, T1 = emg_t1))
#' }
mskLongitudinalTracker <- function(timepoints, hg = NULL, emg_mapping = NULL,
                                    metrics = c("rms", "synergy"),
                                    sr = NULL) {
  stopifnot(is.list(timepoints))
  stopifnot(length(timepoints) >= 1L)

  # Ensure names

  tp_labels <- names(timepoints)
  if (is.null(tp_labels)) {
    tp_labels <- paste0("T", seq_along(timepoints) - 1L)
    names(timepoints) <- tp_labels
  }

  n_tp <- length(timepoints)

  # Extract first timepoint to determine channel structure
  first_ext <- .extractSignalMatrix(timepoints[[1]], "EMG")
  muscle_names <- first_ext$ch_names
  n_muscles <- length(muscle_names)
  sr <- sr %||% first_ext$sr %||% 1000

  metrics_rows <- list()
  activation_mat <- matrix(NA_real_, nrow = n_muscles, ncol = n_tp)
  rownames(activation_mat) <- muscle_names
  colnames(activation_mat) <- tp_labels

  synergy_series <- vector("list", n_tp)
  names(synergy_series) <- tp_labels

  for (tp_idx in seq_len(n_tp)) {
    tp_label <- tp_labels[tp_idx]
    ext <- .extractSignalMatrix(timepoints[[tp_idx]], "EMG")
    mat <- ext$signal_mat

    # Ensure column names match
    if (is.null(colnames(mat))) {
      colnames(mat) <- muscle_names
    }

    # RMS activation
    if ("rms" %in% metrics) {
      rms_vals <- .computeRMS(mat)
      activation_mat[, tp_idx] <- rms_vals[seq_len(n_muscles)]
      for (m_idx in seq_len(n_muscles)) {
        metrics_rows[[length(metrics_rows) + 1L]] <- data.frame(
          timepoint = tp_label,
          muscle = muscle_names[m_idx],
          metric_name = "rms",
          value = rms_vals[m_idx],
          stringsAsFactors = FALSE
        )
      }
    }

    # Mean activation
    if ("mean_activation" %in% metrics) {
      mean_vals <- colMeans(abs(mat))
      if (!("rms" %in% metrics)) {
        activation_mat[, tp_idx] <- mean_vals[seq_len(n_muscles)]
      }
      for (m_idx in seq_len(n_muscles)) {
        metrics_rows[[length(metrics_rows) + 1L]] <- data.frame(
          timepoint = tp_label,
          muscle = muscle_names[m_idx],
          metric_name = "mean_activation",
          value = mean_vals[m_idx],
          stringsAsFactors = FALSE
        )
      }
    }

    # Peak activation
    if ("peak_activation" %in% metrics) {
      peak_vals <- apply(abs(mat), 2, max)
      for (m_idx in seq_len(n_muscles)) {
        metrics_rows[[length(metrics_rows) + 1L]] <- data.frame(
          timepoint = tp_label,
          muscle = muscle_names[m_idx],
          metric_name = "peak_activation",
          value = peak_vals[m_idx],
          stringsAsFactors = FALSE
        )
      }
    }

    # Synergy decomposition
    if ("synergy" %in% metrics && ncol(mat) >= 2) {
      n_syn <- min(ncol(mat), 4L)
      syn_result <- tryCatch(
        neuromechMuscleSynergy(
          emg = mat, hg = hg, emg_mapping = emg_mapping,
          method = "nmf", n_synergies = n_syn, sr = sr
        ),
        error = function(e) NULL
      )
      synergy_series[[tp_idx]] <- syn_result

      if (!is.null(syn_result)) {
        metrics_rows[[length(metrics_rows) + 1L]] <- data.frame(
          timepoint = tp_label,
          muscle = "global",
          metric_name = "synergy_vaf",
          value = syn_result$vaf,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  # Fill activation_mat from mean if rms not computed
  if (!("rms" %in% metrics) && !("mean_activation" %in% metrics)) {
    for (tp_idx in seq_len(n_tp)) {
      ext <- .extractSignalMatrix(timepoints[[tp_idx]], "EMG")
      activation_mat[, tp_idx] <- .computeRMS(ext$signal_mat)[seq_len(n_muscles)]
    }
  }

  metrics_table <- if (length(metrics_rows) > 0) {
    do.call(rbind, metrics_rows)
  } else {
    data.frame(timepoint = character(0), muscle = character(0),
               metric_name = character(0), value = numeric(0),
               stringsAsFactors = FALSE)
  }
  rownames(metrics_table) <- NULL

  structure(
    list(
      metrics_table = metrics_table,
      timepoint_labels = tp_labels,
      n_timepoints = n_tp,
      synergy_series = synergy_series,
      activation_series = activation_mat
    ),
    class = "MSKLongitudinalTracker"
  )
}


#' @export
print.MSKLongitudinalTracker <- function(x, ...) {
  cat("MSK Longitudinal Tracker\n")
  cat("========================\n")
  cat("Timepoints:", x$n_timepoints,
      "(", paste(x$timepoint_labels, collapse = ", "), ")\n")
  cat("Muscles:", nrow(x$activation_series), "\n")
  cat("Metrics recorded:", nrow(x$metrics_table), "observations\n")

  if (!is.null(x$synergy_series) && any(!vapply(x$synergy_series, is.null, logical(1)))) {
    vafs <- vapply(x$synergy_series, function(s) {
      if (!is.null(s)) s$vaf else NA_real_
    }, numeric(1))
    cat("Synergy VAF range:", round(min(vafs, na.rm = TRUE), 3), "-",
        round(max(vafs, na.rm = TRUE), 3), "\n")
  }

  invisible(x)
}


#' Compute Minimal Detectable Change from Longitudinal Tracker
#'
#' Computes ICC (intraclass correlation coefficient) across timepoints for
#' each metric, then derives SEM and MDC values for clinimetric assessment.
#'
#' @param tracker An \code{MSKLongitudinalTracker} object.
#' @param method Character, method for MDC computation (default: "standard").
#' @param confidence Numeric, confidence level for MDC (default: 0.95).
#' @param icc_method Character, ICC formula variant (default: "ICC(2,1)").
#' @return An S3 object of class \code{"MSKMinimalDetectableChange"} with:
#'   \describe{
#'     \item{mdc_table}{data.frame (muscle, metric, ICC, SEM, MDC, pooled_SD)}
#'     \item{confidence_level}{numeric}
#'     \item{method}{character}
#'   }
#' @export
#' @examples
#' \dontrun{
#' mdc <- mskMinimalDetectableChange(tracker, confidence = 0.95)
#' }
mskMinimalDetectableChange <- function(tracker, method = "standard",
                                        confidence = 0.95,
                                        icc_method = "ICC(2,1)") {
  stopifnot(inherits(tracker, "MSKLongitudinalTracker"))
  stopifnot(is.numeric(confidence) && confidence > 0 && confidence < 1)

  activation <- tracker$activation_series
  muscle_names <- rownames(activation)
  n_muscles <- nrow(activation)
  n_tp <- ncol(activation)

  z_alpha <- stats::qnorm(1 - (1 - confidence) / 2)

  mdc_rows <- list()

  # Compute ICC, SEM, MDC for RMS activation per muscle
  for (m_idx in seq_len(n_muscles)) {
    vals <- activation[m_idx, ]

    if (n_tp < 2 || all(is.na(vals))) {
      mdc_rows[[length(mdc_rows) + 1L]] <- data.frame(
        muscle = muscle_names[m_idx],
        metric = "rms",
        ICC = NA_real_,
        SEM = NA_real_,
        MDC = NA_real_,
        pooled_SD = NA_real_,
        stringsAsFactors = FALSE
      )
      next
    }

    pooled_sd <- sd(vals, na.rm = TRUE)

    # For ICC we need a subjects x timepoints matrix
    # In single-subject case, treat each muscle-value pair as a "measurement"
    # Use the full activation matrix with this muscle as one row
    icc_mat <- matrix(vals, nrow = 1)

    # ICC requires multiple subjects - use all muscles together
    icc_val <- .computeICC(activation)

    sem <- pooled_sd * sqrt(1 - icc_val)
    mdc_val <- sem * z_alpha * sqrt(2)

    mdc_rows[[length(mdc_rows) + 1L]] <- data.frame(
      muscle = muscle_names[m_idx],
      metric = "rms",
      ICC = round(icc_val, 4),
      SEM = round(sem, 4),
      MDC = round(mdc_val, 4),
      pooled_SD = round(pooled_sd, 4),
      stringsAsFactors = FALSE
    )
  }

  mdc_table <- do.call(rbind, mdc_rows)
  rownames(mdc_table) <- NULL

  structure(
    list(
      mdc_table = mdc_table,
      confidence_level = confidence,
      method = method
    ),
    class = "MSKMinimalDetectableChange"
  )
}


#' @export
print.MSKMinimalDetectableChange <- function(x, ...) {
  cat("MSK Minimal Detectable Change\n")
  cat("==============================\n")
  cat("Confidence level:", x$confidence_level, "\n")
  cat("Method:", x$method, "\n\n")

  if (nrow(x$mdc_table) > 0) {
    cat("MDC Table:\n")
    print(x$mdc_table, row.names = FALSE)
  }

  invisible(x)
}


# Population-NLME recovery across muscles (delegates to PhysioClinStats), mapping
# the shared partial-pooling fit back into the per-muscle MSKRecoveryTrajectory
# structure. Returns NULL on failure so the caller can fall back to per-muscle NLS.
.mskRecoveryNLME <- function(activation, muscle_names, t_vec) {
  n_muscles <- nrow(activation); n_tp <- length(t_vec)
  df <- data.frame(
    subject = factor(rep(muscle_names, each = n_tp), levels = muscle_names),
    time = rep(t_vec, times = n_muscles),
    y = as.numeric(t(activation)))
  ar <- PhysioClinStats::recoveryTrajectoryLME(df, "subject", "time", "y",
                                               model = "exponential")
  cf <- stats::coef(ar@result$fit)                       # per-muscle Asym/R0/lrc
  cf <- cf[match(muscle_names, rownames(cf)), , drop = FALSE]
  mid_t <- (n_tp + 1) / 2
  predicted <- matrix(NA_real_, n_muscles, n_tp,
                      dimnames = list(muscle_names, colnames(activation)))
  fits <- vector("list", n_muscles); names(fits) <- muscle_names
  recovery_rate <- stats::setNames(numeric(n_muscles), muscle_names)
  time_to_90 <- stats::setNames(numeric(n_muscles), muscle_names)
  for (i in seq_len(n_muscles)) {
    Asym <- cf[i, "Asym"]; R0 <- cf[i, "R0"]; b <- exp(cf[i, "lrc"])
    a <- Asym - R0                                       # a*(1-exp(-b t)) + c form
    pred <- Asym + (R0 - Asym) * exp(-b * t_vec)
    predicted[i, ] <- pred
    y <- activation[i, ]
    ss_tot <- sum((y - mean(y))^2)
    fits[[i]] <- list(
      coefficients = list(a = a, b = b, c = R0),
      residuals = as.numeric(y - pred),
      r_squared = if (ss_tot > 0) 1 - sum((y - pred)^2) / ss_tot else 0,
      aic = NA_real_,           # AIC is a population-fit quantity, not per-muscle
      model_type = "exponential", predicted = pred, converged = TRUE,
      method = "nlme_partial_pool")
    recovery_rate[i] <- a * b * exp(-b * mid_t)          # slope at midpoint
    time_to_90[i] <- if (b > 0) -log(0.1) / b else NA_real_
  }
  structure(list(fits = fits, predicted = predicted, model_type = "exponential",
                 recovery_rate = recovery_rate, time_to_90pct = time_to_90,
                 partial_pool = TRUE),
            class = "MSKRecoveryTrajectory")
}


#' Fit Recovery Trajectory to Longitudinal Activation Data
#'
#' Fits parametric recovery curves (exponential, sigmoid, or linear) to
#' longitudinal muscle activation data from an MSKLongitudinalTracker.
#'
#' @param tracker An \code{MSKLongitudinalTracker} object.
#' @param model Character, recovery curve model: "exponential" (default),
#'   "sigmoid", or "linear".
#' @param muscle_subset Optional character vector of muscle names to fit
#'   (NULL = all muscles).
#' @param partial_pool Logical; when \code{TRUE} and there is more than one
#'   muscle, an exponential fit is estimated by partial pooling across muscles
#'   via a population NLME (\code{PhysioClinStats::recoveryTrajectoryLME}, if
#'   installed), rather than one independent NLS per muscle. Defaults to
#'   \code{FALSE} (the independent-NLS behaviour), which is also the fallback if
#'   the NLME is unavailable or fails to converge.
#' @return An S3 object of class \code{"MSKRecoveryTrajectory"} with:
#'   \describe{
#'     \item{fits}{list per muscle with coefficients, residuals, R-squared, AIC}
#'     \item{predicted}{matrix of predicted values (muscles x timepoints)}
#'     \item{model_type}{character}
#'     \item{recovery_rate}{numeric vector (slope at midpoint for each muscle)}
#'     \item{time_to_90pct}{estimated time to 90 percent of asymptotic recovery}
#'   }
#' @export
#' @examples
#' \dontrun{
#' traj <- mskRecoveryTrajectoryFit(tracker, model = "exponential")
#' }
mskRecoveryTrajectoryFit <- function(tracker, model = c("exponential",
                                                          "sigmoid",
                                                          "linear"),
                                      muscle_subset = NULL,
                                      partial_pool = FALSE) {
  stopifnot(inherits(tracker, "MSKLongitudinalTracker"))
  model <- match.arg(model)

  activation <- tracker$activation_series
  muscle_names <- rownames(activation)
  n_tp <- ncol(activation)
  t_vec <- seq_len(n_tp)

  if (!is.null(muscle_subset)) {
    keep <- muscle_names %in% muscle_subset
    if (!any(keep)) stop("None of the specified muscles found in tracker")
    activation <- activation[keep, , drop = FALSE]
    muscle_names <- muscle_names[keep]
  }

  n_muscles <- nrow(activation)

  # Partial pooling across muscles via a population NLME (PhysioClinStats), when
  # requested and applicable; otherwise the per-muscle NLS path below runs.
  if (partial_pool && model == "exponential" && n_muscles > 1L &&
      requireNamespace("PhysioClinStats", quietly = TRUE)) {
    # recoveryTrajectoryLME() itself requires nlme; if it (or nlme) is
    # unavailable or fails to converge, fall through to the independent-NLS path.
    pooled <- tryCatch(
      .mskRecoveryNLME(activation, muscle_names, t_vec),
      error = function(e) NULL)
    if (!is.null(pooled)) return(pooled)
  }
  fits <- vector("list", n_muscles)
  names(fits) <- muscle_names
  predicted <- matrix(NA_real_, n_muscles, n_tp)
  rownames(predicted) <- muscle_names
  colnames(predicted) <- colnames(activation)
  recovery_rate <- numeric(n_muscles)
  names(recovery_rate) <- muscle_names
  time_to_90 <- numeric(n_muscles)
  names(time_to_90) <- muscle_names

  for (m_idx in seq_len(n_muscles)) {
    y <- activation[m_idx, ]

    fit <- switch(model,
      "exponential" = .fitExponentialRecovery(t_vec, y),
      "sigmoid" = .fitSigmoidRecovery(t_vec, y),
      "linear" = .fitLinearRecovery(t_vec, y)
    )

    fits[[m_idx]] <- fit
    predicted[m_idx, ] <- fit$predicted

    # Recovery rate: slope at midpoint
    mid_t <- (n_tp + 1) / 2
    if (fit$model_type == "exponential" && !is.null(fit$coefficients$a)) {
      a <- fit$coefficients$a
      b <- fit$coefficients$b
      recovery_rate[m_idx] <- a * b * exp(-b * mid_t)
    } else if (fit$model_type == "sigmoid" && !is.null(fit$coefficients$L)) {
      L <- fit$coefficients$L
      k <- fit$coefficients$k
      t0 <- fit$coefficients$t0
      e_val <- exp(-k * (mid_t - t0))
      recovery_rate[m_idx] <- L * k * e_val / (1 + e_val)^2
    } else {
      recovery_rate[m_idx] <- fit$coefficients$b %||% 0
    }

    # Time to 90% of asymptotic recovery
    if (fit$model_type == "exponential" && !is.null(fit$coefficients$b)) {
      b <- fit$coefficients$b
      if (b > 0) {
        time_to_90[m_idx] <- -log(0.1) / b
      } else {
        time_to_90[m_idx] <- NA_real_
      }
    } else if (fit$model_type == "sigmoid" && !is.null(fit$coefficients$k)) {
      L <- fit$coefficients$L
      k <- fit$coefficients$k
      t0 <- fit$coefficients$t0
      if (k > 0) {
        # y = 0.9*L => solve for t
        time_to_90[m_idx] <- t0 - log(1 / 0.9 - 1) / k
      } else {
        time_to_90[m_idx] <- NA_real_
      }
    } else {
      # Linear: time to reach 90% of max observed
      b_coef <- fit$coefficients$b %||% 0
      a_coef <- fit$coefficients$a %||% mean(y)
      if (b_coef != 0) {
        target <- a_coef + 0.9 * abs(b_coef * n_tp)
        time_to_90[m_idx] <- (target - a_coef) / b_coef
      } else {
        time_to_90[m_idx] <- NA_real_
      }
    }
  }

  structure(
    list(
      fits = fits,
      predicted = predicted,
      model_type = model,
      recovery_rate = recovery_rate,
      time_to_90pct = time_to_90
    ),
    class = "MSKRecoveryTrajectory"
  )
}


#' @export
print.MSKRecoveryTrajectory <- function(x, ...) {
  cat("MSK Recovery Trajectory\n")
  cat("=======================\n")
  cat("Model:", x$model_type, "\n")
  cat("Muscles:", length(x$fits), "\n")

  r_sq <- vapply(x$fits, function(f) f$r_squared, numeric(1))
  cat("R-squared range:", round(min(r_sq, na.rm = TRUE), 3), "-",
      round(max(r_sq, na.rm = TRUE), 3), "\n")

  actual_models <- vapply(x$fits, function(f) f$model_type, character(1))
  if (any(actual_models != x$model_type)) {
    n_fallback <- sum(actual_models != x$model_type)
    cat("Note:", n_fallback, "muscle(s) fell back to linear fit\n")
  }

  invisible(x)
}


#' Classify Muscles as Responders, Non-Responders, or Deteriorated
#'
#' Compares first and last timepoint to determine if each muscle shows
#' clinically meaningful change beyond the MDC threshold.
#'
#' When a validated \code{instrument} and \code{population} are supplied and the
#' \pkg{PhysioClinical} package is available, classification is delegated to
#' \code{PhysioClinical::classifyResponder()}, which applies the published dual
#' MDC-vs-MCID rule (adding a \code{clinical_class} column). Otherwise the
#' single-threshold path (MDC or effect size) is used.
#'
#' @param tracker An \code{MSKLongitudinalTracker} object.
#' @param mdc_result An \code{MSKMinimalDetectableChange} object (or NULL to
#'   use effect size threshold).
#' @param threshold_type Character, "mdc" (default) or "effect_size"
#'   (Cohen's d > 0.8).
#' @param instrument Optional validated instrument id (e.g. \code{"fma_ue"}) to
#'   delegate dual MDC-vs-MCID classification to \pkg{PhysioClinical}.
#' @param population Optional population stratum for the instrument's clinimetric
#'   lookup (used only with \code{instrument}).
#' @param direction \code{"increase"} (default) or \code{"decrease"} — the
#'   direction of clinical benefit, passed to the clinimetric classifier.
#' @return An S3 object of class \code{"MSKResponderStatus"} with:
#'   \describe{
#'     \item{classification}{data.frame (muscle, status, change, threshold, effect_size_d; plus clinical_class when delegated)}
#'     \item{summary}{counts of responders/non-responders/deteriorated}
#'     \item{overall_status}{"responder" if majority of muscles improve}
#'     \item{method}{"clinimetric" (delegated) or "threshold"}
#'   }
#' @export
#' @examples
#' \dontrun{
#' status <- mskDetectResponderStatus(tracker, mdc_result)
#' status <- mskDetectResponderStatus(tracker, instrument = "fma_ue",
#'                                    population = "stroke")
#' }
mskDetectResponderStatus <- function(tracker, mdc_result = NULL,
                                      threshold_type = c("mdc",
                                                          "effect_size"),
                                      instrument = NULL, population = NULL,
                                      direction = c("increase", "decrease")) {
  stopifnot(inherits(tracker, "MSKLongitudinalTracker"))
  threshold_type <- match.arg(threshold_type)
  direction <- match.arg(direction)

  # delegate to the published dual MDC-vs-MCID rule when an instrument+population
  # is supplied and PhysioClinical is installed; otherwise fall back below.
  use_clin <- !is.null(instrument) && !is.null(population)
  if (use_clin && !requireNamespace("PhysioClinical", quietly = TRUE)) {
    message("PhysioClinical not installed; using the single-threshold path.")
    use_clin <- FALSE
  }

  activation <- tracker$activation_series
  muscle_names <- rownames(activation)
  n_muscles <- nrow(activation)
  n_tp <- ncol(activation)

  if (n_tp < 2) {
    warning("Need at least 2 timepoints for responder classification")
    classification <- data.frame(
      muscle = muscle_names,
      status = rep("unknown", n_muscles),
      change = rep(NA_real_, n_muscles),
      threshold = rep(NA_real_, n_muscles),
      effect_size_d = rep(NA_real_, n_muscles),
      stringsAsFactors = FALSE
    )
    return(structure(
      list(
        classification = classification,
        summary = c(responder = 0L, non_responder = n_muscles, deteriorated = 0L),
        overall_status = "unknown",
        method = "threshold"
      ),
      class = "MSKResponderStatus"
    ))
  }

  first_vals <- activation[, 1]
  last_vals <- activation[, n_tp]
  changes <- last_vals - first_vals

  # Compute effect sizes (Cohen's d using pooled SD across timepoints)
  effect_sizes <- numeric(n_muscles)
  for (m_idx in seq_len(n_muscles)) {
    pooled_sd <- sd(activation[m_idx, ], na.rm = TRUE)
    effect_sizes[m_idx] <- if (pooled_sd > 0) {
      changes[m_idx] / pooled_sd
    } else {
      0
    }
  }

  thresholds <- numeric(n_muscles)
  statuses <- character(n_muscles)
  clinical_class <- NULL
  method <- "threshold"

  # Delegate to PhysioClinical's dual MDC-vs-MCID classifier when possible; the
  # instrument's published MDC/MCID (for `population`) is applied to each muscle.
  rc <- NULL
  if (use_clin) {
    rc <- tryCatch(
      PhysioClinical::classifyResponder(
        baseline = first_vals, followup = last_vals,
        instrument = instrument, population = population, direction = direction),
      error = function(e) {
        message("clinimetric classification unavailable (", conditionMessage(e),
                "); using the single-threshold path.")
        NULL
      })
  }

  if (!is.null(rc)) {
    method <- "clinimetric"
    clinical_class <- as.character(rc$classification)
    thresholds <- rep(rc$mdc[1], n_muscles)
    # map the 4-level clinimetric label onto responder/non_responder/deteriorated
    statuses <- ifelse(clinical_class == "true_responder", "responder",
                ifelse(rc$improvement <= -rc$mdc[1], "deteriorated",
                       "non_responder"))
  } else {
    # Determine thresholds (single-threshold fallback)
    if (threshold_type == "mdc" && !is.null(mdc_result)) {
      stopifnot(inherits(mdc_result, "MSKMinimalDetectableChange"))
      for (m_idx in seq_len(n_muscles)) {
        match_row <- which(mdc_result$mdc_table$muscle == muscle_names[m_idx])
        if (length(match_row) > 0) {
          thresholds[m_idx] <- mdc_result$mdc_table$MDC[match_row[1]]
        } else {
          thresholds[m_idx] <- median(mdc_result$mdc_table$MDC, na.rm = TRUE)
        }
      }
    } else {
      # Effect size threshold: Cohen's d > 0.8, converted to absolute units
      for (m_idx in seq_len(n_muscles)) {
        pooled_sd <- sd(activation[m_idx, ], na.rm = TRUE)
        thresholds[m_idx] <- 0.8 * pooled_sd
      }
    }
    # Classify
    for (m_idx in seq_len(n_muscles)) {
      thresh <- thresholds[m_idx]
      if (is.na(thresh) || thresh == 0) thresh <- abs(changes[m_idx]) + 1
      if (changes[m_idx] > thresh) {
        statuses[m_idx] <- "responder"
      } else if (changes[m_idx] < -thresh) {
        statuses[m_idx] <- "deteriorated"
      } else {
        statuses[m_idx] <- "non_responder"
      }
    }
  }

  classification <- data.frame(
    muscle = muscle_names,
    status = statuses,
    change = round(changes, 4),
    threshold = round(thresholds, 4),
    effect_size_d = round(effect_sizes, 4),
    stringsAsFactors = FALSE
  )
  if (!is.null(clinical_class)) classification$clinical_class <- clinical_class

  summary_counts <- c(
    responder = sum(statuses == "responder"),
    non_responder = sum(statuses == "non_responder"),
    deteriorated = sum(statuses == "deteriorated")
  )

  overall <- if (summary_counts["responder"] > n_muscles / 2) {
    "responder"
  } else if (summary_counts["deteriorated"] > n_muscles / 2) {
    "deteriorated"
  } else {
    "non_responder"
  }

  structure(
    list(
      classification = classification,
      summary = summary_counts,
      overall_status = overall,
      method = method
    ),
    class = "MSKResponderStatus"
  )
}


#' @export
print.MSKResponderStatus <- function(x, ...) {
  cat("MSK Responder Status\n")
  cat("====================\n")
  cat("Overall:", x$overall_status, "\n\n")
  cat("Summary:\n")
  cat("  Responders:", x$summary["responder"], "\n")
  cat("  Non-responders:", x$summary["non_responder"], "\n")
  cat("  Deteriorated:", x$summary["deteriorated"], "\n\n")

  if (nrow(x$classification) > 0) {
    cat("Per-muscle classification:\n")
    print(x$classification, row.names = FALSE)
  }

  invisible(x)
}


#' Detect Recovery Plateau in Longitudinal Data
#'
#' Identifies when recovery has plateaued using rolling window slope
#' analysis or change rate assessment.
#'
#' @param tracker An \code{MSKLongitudinalTracker} object.
#' @param window Integer, number of consecutive timepoints to assess
#'   (default: 3).
#' @param min_slope Numeric, minimum slope to be considered "improving"
#'   (default: NULL, auto-computed from data variability).
#' @param method Character, "slope" (default) or "change_rate".
#' @return An S3 object of class \code{"MSKRecoveryPlateau"} with:
#'   \describe{
#'     \item{plateau_detected}{logical per muscle}
#'     \item{plateau_onset}{timepoint index where plateau begins (NA if none)}
#'     \item{details}{data.frame with per-window slopes}
#'     \item{recommendation}{character ("continue", "modify_protocol", "reassess")}
#'   }
#' @export
#' @examples
#' \dontrun{
#' plateau <- mskDetectRecoveryPlateau(tracker, window = 3)
#' }
mskDetectRecoveryPlateau <- function(tracker, window = 3L,
                                      min_slope = NULL,
                                      method = c("slope", "change_rate")) {
  stopifnot(inherits(tracker, "MSKLongitudinalTracker"))
  method <- match.arg(method)
  window <- as.integer(window)

  activation <- tracker$activation_series
  muscle_names <- rownames(activation)
  n_muscles <- nrow(activation)
  n_tp <- ncol(activation)

  if (n_tp < window) {
    warning("Not enough timepoints (", n_tp, ") for window size (", window, ")")
    return(structure(
      list(
        plateau_detected = setNames(rep(NA, n_muscles), muscle_names),
        plateau_onset = setNames(rep(NA_integer_, n_muscles), muscle_names),
        details = data.frame(muscle = character(0), window_start = integer(0),
                             slope = numeric(0), stringsAsFactors = FALSE),
        recommendation = "reassess"
      ),
      class = "MSKRecoveryPlateau"
    ))
  }

  # Auto-compute min_slope if not provided
  if (is.null(min_slope)) {
    # Use 5% of the mean range across muscles as threshold
    ranges <- apply(activation, 1, function(x) diff(range(x, na.rm = TRUE)))
    min_slope <- mean(ranges) * 0.05
    if (min_slope == 0 || !is.finite(min_slope)) min_slope <- 1e-6
  }

  plateau_detected <- logical(n_muscles)
  names(plateau_detected) <- muscle_names
  plateau_onset <- rep(NA_integer_, n_muscles)
  names(plateau_onset) <- muscle_names
  detail_rows <- list()

  for (m_idx in seq_len(n_muscles)) {
    y <- activation[m_idx, ]

    if (method == "slope") {
      slopes <- .rollingSlope(y, window)
    } else {
      # Change rate: percent change per window
      n_windows <- n_tp - window + 1
      slopes <- numeric(n_windows)
      for (w in seq_len(n_windows)) {
        y_win <- y[w:(w + window - 1)]
        base_val <- y_win[1]
        if (abs(base_val) > 0) {
          slopes[w] <- (y_win[window] - y_win[1]) / abs(base_val)
        } else {
          slopes[w] <- 0
        }
      }
    }

    for (w in seq_along(slopes)) {
      detail_rows[[length(detail_rows) + 1L]] <- data.frame(
        muscle = muscle_names[m_idx],
        window_start = w,
        slope = slopes[w],
        stringsAsFactors = FALSE
      )
    }

    # Detect plateau: slope below threshold
    below_thresh <- abs(slopes) < min_slope
    if (any(below_thresh)) {
      plateau_detected[m_idx] <- TRUE
      plateau_onset[m_idx] <- which(below_thresh)[1]
    } else {
      plateau_detected[m_idx] <- FALSE
    }
  }

  details <- if (length(detail_rows) > 0) {
    do.call(rbind, detail_rows)
  } else {
    data.frame(muscle = character(0), window_start = integer(0),
               slope = numeric(0), stringsAsFactors = FALSE)
  }
  rownames(details) <- NULL

  # Recommendation
  n_plateau <- sum(plateau_detected, na.rm = TRUE)
  if (n_plateau == 0) {
    recommendation <- "continue"
  } else if (n_plateau < n_muscles / 2) {
    recommendation <- "modify_protocol"
  } else {
    recommendation <- "reassess"
  }

  structure(
    list(
      plateau_detected = plateau_detected,
      plateau_onset = plateau_onset,
      details = details,
      recommendation = recommendation
    ),
    class = "MSKRecoveryPlateau"
  )
}


#' @export
print.MSKRecoveryPlateau <- function(x, ...) {
  cat("MSK Recovery Plateau Detection\n")
  cat("===============================\n")
  n_plateau <- sum(x$plateau_detected, na.rm = TRUE)
  n_total <- length(x$plateau_detected)
  cat("Plateau detected:", n_plateau, "of", n_total, "muscles\n")
  cat("Recommendation:", x$recommendation, "\n")

  if (n_plateau > 0) {
    cat("\nMuscles at plateau:\n")
    for (nm in names(which(x$plateau_detected))) {
      onset <- x$plateau_onset[nm]
      cat("  ", nm, ": onset at window", onset, "\n")
    }
  }

  invisible(x)
}


#' Compute Synergy Change Index Between Two Timepoints
#'
#' Compares two synergy decompositions by aligning synergy weight vectors
#' and computing a change index reflecting structural reorganization.
#'
#' @param synergy_t0 An \code{MSKNeuromechSynergy} object or a W matrix
#'   (muscles x synergies) at baseline.
#' @param synergy_t1 An \code{MSKNeuromechSynergy} object or a W matrix
#'   at follow-up.
#' @param method Character, comparison method: "cosine" (default),
#'   "correlation", or "procrustes".
#' @return A list with: global_change_index (0=identical, 1=maximally different),
#'   per_synergy_change, alignment (permutation used).
#' @export
#' @examples
#' \dontrun{
#' sci <- mskSynergyChangeIndex(synergy_t0, synergy_t1, method = "cosine")
#' }
mskSynergyChangeIndex <- function(synergy_t0, synergy_t1,
                                    method = c("cosine", "correlation",
                                                "procrustes")) {
  method <- match.arg(method)

  # Extract W matrices
  W1 <- if (inherits(synergy_t0, "MSKNeuromechSynergy")) synergy_t0$W
        else as.matrix(synergy_t0)
  W2 <- if (inherits(synergy_t1, "MSKNeuromechSynergy")) synergy_t1$W
        else as.matrix(synergy_t1)

  stopifnot(is.matrix(W1), is.matrix(W2))
  stopifnot(nrow(W1) == nrow(W2))

  k <- min(ncol(W1), ncol(W2))

  if (method == "cosine") {
    alignment <- .alignSynergies(W1, W2)
    per_synergy <- 1 - alignment$cosine_similarities[seq_len(k)]
    per_synergy <- pmax(0, pmin(1, per_synergy))
    global_idx <- 1 - alignment$mean_cosine

    list(
      global_change_index = max(0, min(1, global_idx)),
      per_synergy_change = per_synergy,
      alignment = alignment$permutation
    )

  } else if (method == "correlation") {
    alignment <- .alignSynergies(W1, W2)
    perm <- alignment$permutation[seq_len(k)]
    perm <- perm[!is.na(perm)]

    per_synergy <- numeric(length(perm))
    for (i in seq_along(perm)) {
      r <- cor(W1[, i], W2[, perm[i]])
      per_synergy[i] <- 1 - max(0, r)
    }
    per_synergy <- pmax(0, pmin(1, per_synergy))
    global_idx <- mean(per_synergy)

    list(
      global_change_index = max(0, min(1, global_idx)),
      per_synergy_change = per_synergy,
      alignment = alignment$permutation
    )

  } else {
    # Procrustes rotation
    # Trim to same number of synergies
    W1_k <- W1[, seq_len(k), drop = FALSE]
    W2_k <- W2[, seq_len(k), drop = FALSE]

    # SVD of W1' %*% W2
    svd_result <- svd(t(W1_k) %*% W2_k)
    R <- svd_result$v %*% t(svd_result$u)
    W2_rot <- W2_k %*% R

    # Per-synergy distance
    per_synergy <- numeric(k)
    for (i in seq_len(k)) {
      n1 <- sqrt(sum(W1_k[, i]^2))
      n2 <- sqrt(sum(W2_rot[, i]^2))
      if (n1 > 0 && n2 > 0) {
        cos_sim <- sum(W1_k[, i] * W2_rot[, i]) / (n1 * n2)
        per_synergy[i] <- 1 - max(0, min(1, cos_sim))
      } else {
        per_synergy[i] <- 1
      }
    }

    # Global: Frobenius distance normalized
    residual <- sqrt(sum((W1_k - W2_rot)^2))
    max_possible <- sqrt(sum(W1_k^2) + sum(W2_k^2))
    global_idx <- if (max_possible > 0) residual / max_possible else 0

    list(
      global_change_index = max(0, min(1, global_idx)),
      per_synergy_change = per_synergy,
      alignment = seq_len(k)  # Procrustes uses rotation, not permutation
    )
  }
}


#' Compute Neural Adaptation Index Across Timepoints
#'
#' Compares corticomuscular coherence (CMC) and directional coupling
#' between two timepoints to quantify neural adaptation during rehabilitation.
#'
#' @param cmc_t0 CMC result at baseline (MSKNeuromechCMC object or coherence matrix).
#' @param cmc_t1 CMC result at follow-up.
#' @param directional_t0 Directional coupling at baseline
#'   (MSKNeuromechDirectional object or NULL).
#' @param directional_t1 Directional coupling at follow-up (or NULL).
#' @return A list with: cmc_change, directional_change, adaptation_index,
#'   interpretation ("improving"/"stable"/"declining").
#' @export
#' @examples
#' \dontrun{
#' nai <- mskNeuralAdaptationIndex(cmc_t0, cmc_t1, dir_t0, dir_t1)
#' }
mskNeuralAdaptationIndex <- function(cmc_t0, cmc_t1,
                                      directional_t0 = NULL,
                                      directional_t1 = NULL) {
  # Extract CMC matrices
  cmc_mat0 <- if (inherits(cmc_t0, "MSKNeuromechCMC")) cmc_t0$cmc_matrix
               else as.matrix(cmc_t0)
  cmc_mat1 <- if (inherits(cmc_t1, "MSKNeuromechCMC")) cmc_t1$cmc_matrix
               else as.matrix(cmc_t1)

  # CMC change: mean absolute difference in coherence
  # Align dimensions
  n_row <- min(nrow(cmc_mat0), nrow(cmc_mat1))
  n_col <- min(ncol(cmc_mat0), ncol(cmc_mat1))
  cmc_sub0 <- cmc_mat0[seq_len(n_row), seq_len(n_col), drop = FALSE]
  cmc_sub1 <- cmc_mat1[seq_len(n_row), seq_len(n_col), drop = FALSE]

  cmc_change <- mean(abs(cmc_sub1 - cmc_sub0))

  # Signed direction: positive = increasing coherence (improving)
  cmc_direction <- mean(cmc_sub1 - cmc_sub0)

  # Directional coupling change
  directional_change <- 0
  directional_direction <- 0

  if (!is.null(directional_t0) && !is.null(directional_t1)) {
    # Extract dominance ratios
    dom0 <- if (inherits(directional_t0, "MSKNeuromechDirectional")) {
      directional_t0$dominance_ratio
    } else {
      directional_t0
    }
    dom1 <- if (inherits(directional_t1, "MSKNeuromechDirectional")) {
      directional_t1$dominance_ratio
    } else {
      directional_t1
    }

    # Use common muscles
    common <- intersect(names(dom0), names(dom1))
    if (length(common) > 0) {
      d0 <- dom0[common]
      d1 <- dom1[common]
      # Replace Inf with large value for computation
      d0[!is.finite(d0)] <- 10
      d1[!is.finite(d1)] <- 10
      directional_change <- mean(abs(d1 - d0))
      directional_direction <- mean(d1 - d0)  # positive = more descending
    }
  }

  # Adaptation index: weighted combination
  # Higher CMC and more descending dominance = improving
  w_cmc <- 0.6
  w_dir <- 0.4

  if (!is.null(directional_t0) && !is.null(directional_t1)) {
    adaptation_index <- w_cmc * cmc_direction + w_dir * directional_direction
  } else {
    adaptation_index <- cmc_direction
  }

  # Interpretation
  interpretation <- if (adaptation_index > 0.05) {
    "improving"
  } else if (adaptation_index < -0.05) {
    "declining"
  } else {
    "stable"
  }

  list(
    cmc_change = cmc_change,
    directional_change = directional_change,
    adaptation_index = adaptation_index,
    interpretation = interpretation
  )
}


#' Compute Coordination Quality Score
#'
#' Compares a subject's EMG coordination pattern against a reference
#' (healthy baseline or normative data) to produce a 0-1 quality score.
#'
#' @param emg EMG data: matrix (time x channels), SummarizedExperiment, or vector.
#' @param reference_emg Reference EMG matrix (or NULL for within-subject reference).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param method Character, comparison method: "synergy_distance" (default),
#'   "correlation_profile", or "network_similarity".
#' @return A list with: quality_score (0-1, 1=perfect match to reference),
#'   component_scores, muscle_contributions.
#' @export
#' @examples
#' \dontrun{
#' cqs <- mskCoordinationQualityScore(emg, reference_emg, method = "synergy_distance")
#' }
mskCoordinationQualityScore <- function(emg, reference_emg = NULL, hg = NULL,
                                         method = c("synergy_distance",
                                                     "correlation_profile",
                                                     "network_similarity")) {
  method <- match.arg(method)
  hg <- .ensureHypergraph(hg)

  # Extract EMG
  emg_data <- .extractSignalMatrix(emg, "EMG")
  emg_mat <- emg_data$signal_mat
  sr <- emg_data$sr %||% 1000
  muscle_names <- emg_data$ch_names

  # Reference
  if (is.null(reference_emg)) {
    # Within-subject reference: use first half as reference, second half as test
    n <- nrow(emg_mat)
    half <- floor(n / 2)
    ref_mat <- emg_mat[seq_len(half), , drop = FALSE]
    test_mat <- emg_mat[(half + 1):n, , drop = FALSE]
  } else {
    ref_ext <- .extractSignalMatrix(reference_emg, "EMG_ref")
    ref_mat <- ref_ext$signal_mat
    test_mat <- emg_mat
  }

  n_muscles <- ncol(test_mat)

  if (method == "synergy_distance") {
    # Extract synergies from both
    n_syn <- min(ncol(test_mat), 4L)
    if (n_syn < 2) {
      # Single channel: use RMS correlation
      rms_test <- .computeRMS(test_mat)
      rms_ref <- .computeRMS(ref_mat)
      if (sd(rms_test) == 0 || sd(rms_ref) == 0) {
        quality_score <- 1
      } else {
        quality_score <- max(0, cor(rms_test, rms_ref))
      }
      return(list(
        quality_score = quality_score,
        component_scores = quality_score,
        muscle_contributions = setNames(rep(quality_score, n_muscles), muscle_names)
      ))
    }

    syn_test <- tryCatch(
      neuromechMuscleSynergy(test_mat, hg = hg, method = "nmf",
                              n_synergies = n_syn, sr = sr),
      error = function(e) NULL
    )
    syn_ref <- tryCatch(
      neuromechMuscleSynergy(ref_mat, hg = hg, method = "nmf",
                              n_synergies = n_syn, sr = sr),
      error = function(e) NULL
    )

    if (is.null(syn_test) || is.null(syn_ref)) {
      return(list(quality_score = NA_real_, component_scores = NA_real_,
                  muscle_contributions = setNames(rep(NA_real_, n_muscles),
                                                   muscle_names)))
    }

    sci <- mskSynergyChangeIndex(syn_ref, syn_test, method = "cosine")
    quality_score <- 1 - sci$global_change_index
    component_scores <- 1 - sci$per_synergy_change

    # Per-muscle contribution: based on synergy weight similarity
    W_ref <- syn_ref$W
    W_test <- syn_test$W[, sci$alignment[seq_len(ncol(W_ref))], drop = FALSE]
    muscle_contrib <- numeric(n_muscles)
    for (m in seq_len(n_muscles)) {
      n1 <- sqrt(sum(W_ref[m, ]^2))
      n2 <- sqrt(sum(W_test[m, ]^2))
      if (n1 > 0 && n2 > 0) {
        muscle_contrib[m] <- sum(W_ref[m, ] * W_test[m, ]) / (n1 * n2)
      } else {
        muscle_contrib[m] <- 0
      }
    }
    names(muscle_contrib) <- muscle_names

    list(
      quality_score = max(0, min(1, quality_score)),
      component_scores = component_scores,
      muscle_contributions = pmax(0, pmin(1, muscle_contrib))
    )

  } else if (method == "correlation_profile") {
    # Intermuscular correlation matrix comparison via Mantel test
    cor_test <- cor(test_mat)
    cor_ref <- cor(ref_mat)

    mantel <- .mantelTest(cor_test, cor_ref, n_perm = 199L)
    m_cor <- if (is.na(mantel$correlation)) 0 else mantel$correlation
    quality_score <- max(0, min(1, (m_cor + 1) / 2))

    # Per-muscle contribution: profile similarity
    muscle_contrib <- numeric(n_muscles)
    for (m in seq_len(n_muscles)) {
      r <- tryCatch(cor(cor_test[m, ], cor_ref[m, ]), error = function(e) 0)
      if (is.na(r)) r <- 0
      muscle_contrib[m] <- max(0, (r + 1) / 2)
    }
    names(muscle_contrib) <- muscle_names

    list(
      quality_score = quality_score,
      component_scores = m_cor,
      muscle_contributions = muscle_contrib
    )

  } else {
    # network_similarity: compare coherence-based adjacency
    coh_test <- .minimalCoherence(test_mat, sr)
    coh_ref <- .minimalCoherence(ref_mat, sr)

    # Frobenius distance normalized
    diff_norm <- sqrt(sum((coh_test - coh_ref)^2))
    max_norm <- sqrt(sum(coh_test^2) + sum(coh_ref^2))
    quality_score <- if (max_norm > 0) 1 - diff_norm / max_norm else 1

    # Per-muscle contribution
    muscle_contrib <- numeric(n_muscles)
    for (m in seq_len(n_muscles)) {
      d <- sqrt(sum((coh_test[m, ] - coh_ref[m, ])^2))
      mx <- sqrt(sum(coh_test[m, ]^2) + sum(coh_ref[m, ]^2))
      muscle_contrib[m] <- if (mx > 0) 1 - d / mx else 1
    }
    names(muscle_contrib) <- muscle_names

    list(
      quality_score = max(0, min(1, quality_score)),
      component_scores = quality_score,
      muscle_contributions = pmax(0, pmin(1, muscle_contrib))
    )
  }
}
