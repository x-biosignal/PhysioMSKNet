# Forward EMG-driven Hill-type muscle model -------------------------------
# The kinematics layer (muscleTendonKinematics) yields normalised fiber length
# and velocity. This file adds the FORCE layer: excitation-to-activation
# dynamics, the Hill contractile element (active force-length, force-velocity)
# with a passive element, EMG-to-force, joint moment, and CEINMS-style parameter
# calibration against measured joint moments. Together they turn an EMG envelope
# into physical muscle force and joint torque (N.m), not an amplitude proxy.
#
# References: Zajac (1989); Thelen (2003) J Biomech Eng 125:70; Buchanan et al.
# (2004) J Appl Biomech 20:367 (EMG-driven / CEINMS framework).

#' Active force-length multiplier
#'
#' Gaussian active force-length curve, peaking at the optimal fiber length
#' (normalised length 1).
#' @param norm_len Normalised fiber length (optimal = 1).
#' @param width Gaussian width parameter (default 0.45).
#' @return Multiplier in `[0, 1]`.
#' @export
forceLengthActive <- function(norm_len, width = 0.45) {
  exp(-((norm_len - 1)^2) / width)
}

#' Passive force-length multiplier
#'
#' Exponential passive element (Thelen 2003): zero below optimal length, rising
#' as the fiber is stretched beyond it.
#' @param norm_len Normalised fiber length.
#' @param k_pe Exponential shape (default 4).
#' @param e0 Passive strain at maximum isometric force (default 0.6).
#' @return Passive multiplier (>= 0).
#' @export
forceLengthPassive <- function(norm_len, k_pe = 4, e0 = 0.6) {
  fpe <- (exp(k_pe * (norm_len - 1) / e0) - 1) / (exp(k_pe) - 1)
  pmax(fpe, 0)
}

#' Force-velocity multiplier
#'
#' Normalised Hill force-velocity relation. Velocity is normalised fiber
#' velocity with negative = shortening (concentric), positive = lengthening
#' (eccentric).
#' @param norm_vel Normalised fiber velocity (concentric < 0).
#' @param af Hill shape parameter for shortening (default 0.25).
#' @param f_ecc Eccentric force asymptote (default 1.8).
#' @param k_ecc Eccentric saturation constant (default 0.15).
#' @return Multiplier (0 at max shortening, 1 at isometric, up to `f_ecc`).
#' @export
forceVelocity <- function(norm_vel, af = 0.25, f_ecc = 1.8, k_ecc = 0.15) {
  ifelse(norm_vel <= 0,
         (1 + norm_vel) / (1 - norm_vel / af),                 # concentric
         1 + (f_ecc - 1) * norm_vel / (norm_vel + k_ecc))      # eccentric
}

#' EMG envelope to neural excitation
#'
#' Rectifies and normalises an EMG envelope to `[0, 1]`, with an optional
#' A-shape (exponential) EMG-to-activation non-linearity.
#' @param emg EMG envelope (already rectified/smoothed, or raw — abs is taken).
#' @param max_emg Normalising maximum (default: the signal maximum).
#' @param nonlin Non-linearity coefficient `A` (0 = linear; typical -3..0 or
#'   positive for a convex map).
#' @return Excitation in `[0, 1]`.
#' @export
emgToExcitation <- function(emg, max_emg = NULL, nonlin = 0) {
  e <- abs(emg)
  if (is.null(max_emg)) max_emg <- max(e)
  if (!is.finite(max_emg) || max_emg <= 0) max_emg <- 1
  u <- pmin(pmax(e / max_emg, 0), 1)
  if (nonlin != 0) u <- (exp(nonlin * u) - 1) / (exp(nonlin) - 1)
  u
}

#' Excitation-to-activation dynamics
#'
#' First-order activation dynamics (Thelen 2003): activation lags excitation,
#' with faster activation than deactivation.
#' @param excitation Neural excitation in `[0, 1]`.
#' @param dt Time step in seconds.
#' @param tau_act Activation time constant (default 0.010 s).
#' @param tau_deact Deactivation time constant (default 0.040 s).
#' @param a0 Initial activation (default: `excitation[1]`).
#' @return Activation time series in `[0, 1]`.
#' @export
excitationToActivation <- function(excitation, dt, tau_act = 0.010,
                                   tau_deact = 0.040, a0 = NULL) {
  n <- length(excitation)
  a <- numeric(n)
  a[1] <- if (is.null(a0)) excitation[1] else a0
  for (i in seq_len(n)[-1]) {
    ai <- a[i - 1]; u <- excitation[i]
    tau <- if (u > ai) tau_act * (0.5 + 1.5 * ai) else tau_deact / (0.5 + 1.5 * ai)
    ai <- ai + dt * (u - ai) / tau
    a[i] <- min(max(ai, 0), 1)
  }
  a
}

#' Default EMG-driven muscle parameters
#'
#' @param max_isometric_force Peak isometric force `F_max` in N (default 1000).
#' @param pennation Pennation angle in radians (default 0).
#' @param tau_act,tau_deact Activation dynamics time constants (s).
#' @param emg_nonlin EMG-to-activation non-linearity coefficient.
#' @param max_emg Optional EMG normaliser.
#' @return A named list of parameters.
#' @export
emgDrivenParams <- function(max_isometric_force = 1000, pennation = 0,
                            tau_act = 0.010, tau_deact = 0.040,
                            emg_nonlin = 0, max_emg = NULL) {
  list(max_isometric_force = max_isometric_force, pennation = pennation,
       tau_act = tau_act, tau_deact = tau_deact,
       emg_nonlin = emg_nonlin, max_emg = max_emg)
}

#' Hill-type muscle force
#'
#' Total muscle-tendon force from activation and normalised fiber kinematics:
#' \eqn{F = F_{max}\,[a\,f_L(\tilde l)\,f_V(\tilde v) + f_{PE}(\tilde l)]\cos\alpha}.
#' @param activation Activation in `[0, 1]`.
#' @param norm_len Normalised fiber length.
#' @param norm_vel Normalised fiber velocity.
#' @param max_isometric_force Peak isometric force (N).
#' @param pennation Pennation angle (rad).
#' @return Muscle force in N.
#' @export
hillMuscleForce <- function(activation, norm_len, norm_vel,
                            max_isometric_force = 1000, pennation = 0) {
  fl <- forceLengthActive(norm_len)
  fpe <- forceLengthPassive(norm_len)
  fv <- forceVelocity(norm_vel)
  max_isometric_force * (activation * fl * fv + fpe) * cos(pennation)
}

#' EMG-driven muscle force
#'
#' Full forward pipeline: EMG envelope -> excitation -> activation dynamics ->
#' Hill contractile + passive force, given normalised fiber kinematics (e.g. from
#' [muscleTendonKinematics()]).
#' @param emg EMG envelope time series.
#' @param norm_len Normalised fiber length (scalar or same length as `emg`).
#' @param norm_vel Normalised fiber velocity (scalar or same length as `emg`).
#' @param sr Sampling rate (Hz).
#' @param params Parameter list from [emgDrivenParams()].
#' @return Muscle force time series (N).
#' @examples
#' sr <- 1000; t <- seq(0, 2, by = 1 / sr)
#' emg <- pmax(sin(2 * pi * 1 * t), 0) * abs(rnorm(length(t), 1, 0.1))
#' f <- emgDrivenForce(emg, norm_len = 1, norm_vel = 0, sr = sr,
#'                     params = emgDrivenParams(max_isometric_force = 800))
#' max(f)
#' @export
emgDrivenForce <- function(emg, norm_len, norm_vel, sr,
                           params = emgDrivenParams()) {
  u <- emgToExcitation(emg, params$max_emg, params$emg_nonlin)
  a <- excitationToActivation(u, 1 / sr, params$tau_act, params$tau_deact)
  n <- length(a)
  nl <- if (length(norm_len) == 1L) rep(norm_len, n) else norm_len[seq_len(n)]
  nv <- if (length(norm_vel) == 1L) rep(norm_vel, n) else norm_vel[seq_len(n)]
  hillMuscleForce(a, nl, nv, params$max_isometric_force, params$pennation)
}

#' EMG-driven joint moment
#'
#' Combines muscle forces with moment arms into a net joint moment (N.m).
#' @param forces A force time series (one muscle) or a time x muscle matrix.
#' @param moment_arm Moment arm(s) in m: a scalar/vector matching `forces`.
#' @return Net joint moment time series (N.m).
#' @export
emgDrivenJointMoment <- function(forces, moment_arm) {
  if (is.matrix(forces)) {
    if (length(moment_arm) != ncol(forces))
      stop("`moment_arm` must have one entry per muscle (column).", call. = FALSE)
    as.numeric(forces %*% moment_arm)
  } else {
    forces * moment_arm
  }
}

#' Calibrate an EMG-driven model to measured joint moments
#'
#' CEINMS-style calibration: adjusts a small set of parameters (force scale,
#' activation time constant, EMG non-linearity) to minimise the RMS error
#' between the model's predicted joint moment and a measured reference moment
#' (e.g. from inverse dynamics).
#' @param emg EMG envelope.
#' @param norm_len,norm_vel Normalised fiber kinematics.
#' @param moment_arm Moment arm (m).
#' @param reference_moment Measured joint moment to match (N.m).
#' @param sr Sampling rate (Hz).
#' @param params Starting parameters from [emgDrivenParams()].
#' @return A list with calibrated `params`, `rmse`, `r` (correlation of predicted
#'   vs reference moment), `par` (optimised values), and `convergence`.
#' @export
calibrateEMGDrivenModel <- function(emg, norm_len, norm_vel, moment_arm,
                                    reference_moment, sr,
                                    params = emgDrivenParams()) {
  base_force <- params$max_isometric_force
  predict_moment <- function(theta) {
    p <- params
    p$max_isometric_force <- base_force * theta[1]
    p$tau_act <- theta[2]
    p$emg_nonlin <- theta[3]
    emgDrivenJointMoment(emgDrivenForce(emg, norm_len, norm_vel, sr, p),
                         moment_arm)
  }
  obj <- function(theta) sqrt(mean((predict_moment(theta) - reference_moment)^2))
  opt <- stats::optim(c(1, params$tau_act, params$emg_nonlin), obj,
                      method = "L-BFGS-B",
                      lower = c(0.2, 0.005, 0), upper = c(5, 0.05, 6))
  p <- params
  p$max_isometric_force <- base_force * opt$par[1]
  p$tau_act <- opt$par[2]
  p$emg_nonlin <- opt$par[3]
  pred <- predict_moment(opt$par)
  list(params = p, rmse = opt$value,
       r = stats::cor(pred, reference_moment),
       par = opt$par, convergence = opt$convergence)
}
