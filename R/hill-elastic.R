# Elastic-tendon equilibrium for the Hill model ---------------------------
# The rigid-tendon model (hill-model.R) sets fiber length = MTU length - tendon
# slack. A real tendon is compliant: under load it stretches, so the fiber
# operates at a different length. This file adds a tendon force-length curve and
# solves the quasi-static muscle-tendon force equilibrium for the fiber length,
# then an EMG-driven pipeline that uses it. Reference: Zajac (1989); Thelen
# (2003) J Biomech Eng 125:70; Millard et al. (2013) J Biomech Eng 135:021005.

#' Tendon force-length curve
#'
#' Normalised tendon force as a function of normalised tendon length
#' (`tendon length / tendon slack length`): zero below slack, rising steeply to
#' one maximum-isometric-force at the reference strain.
#' @param norm_tendon_length Tendon length divided by tendon slack length.
#' @param e0t Tendon strain at maximum isometric force (default 0.04).
#' @param kt Exponential stiffness shape (default 3).
#' @return Normalised tendon force (>= 0).
#' @export
tendonForceLength <- function(norm_tendon_length, e0t = 0.04, kt = 3) {
  strain <- norm_tendon_length - 1
  ft <- (exp(kt * strain / e0t) - 1) / (exp(kt) - 1)
  pmax(ft, 0)
}

#' Equilibrium fiber length with a compliant tendon
#'
#' Solves the quasi-static (isometric) muscle-tendon force balance for the fiber
#' length: the fiber active+passive force along the tendon equals the tendon
#' force, with `tendon length = MTU length - fiber length * cos(pennation)`.
#'
#' @param activation Activation in `[0, 1]`.
#' @param mtu_length Muscle-tendon-unit length (m).
#' @param optimal_fiber_length Optimal fiber length (m).
#' @param tendon_slack_length Tendon slack length (m).
#' @param max_isometric_force Peak isometric force (N).
#' @param pennation Pennation angle (rad).
#' @param e0t Tendon reference strain (default 0.04).
#' @return A list with `fiber_length`, `tendon_length`, `norm_fiber_length`,
#'   `norm_tendon_length`, and `force` (N).
#' @examples
#' equilibriumFiberLength(0.5, mtu_length = 0.30,
#'                        optimal_fiber_length = 0.10,
#'                        tendon_slack_length = 0.20)
#' @export
equilibriumFiberLength <- function(activation, mtu_length,
                                   optimal_fiber_length, tendon_slack_length,
                                   max_isometric_force = 1000, pennation = 0,
                                   e0t = 0.04) {
  cosp <- cos(pennation)
  f_muscle <- function(lf) {
    l <- lf / optimal_fiber_length
    max_isometric_force *
      (activation * forceLengthActive(l) + forceLengthPassive(l)) * cosp
  }
  f_tendon <- function(lf) {
    lt <- mtu_length - lf * cosp
    max_isometric_force * tendonForceLength(lt / tendon_slack_length, e0t = e0t)
  }
  g <- function(lf) f_muscle(lf) - f_tendon(lf)
  lo <- 1e-4 * optimal_fiber_length
  hi <- (mtu_length / cosp) - 1e-6
  if (hi <= lo || g(lo) * g(hi) > 0) {
    # no interior root (e.g. MTU shorter than slack): fall back to rigid tendon
    lf <- max((mtu_length - tendon_slack_length) / cosp, lo)
  } else {
    lf <- stats::uniroot(g, c(lo, hi), tol = 1e-10)$root
  }
  lt <- mtu_length - lf * cosp
  list(fiber_length = lf, tendon_length = lt,
       norm_fiber_length = lf / optimal_fiber_length,
       norm_tendon_length = lt / tendon_slack_length,
       force = f_tendon(lf))
}

#' EMG-driven force with a compliant tendon
#'
#' Forward pipeline as [emgDrivenForce()] but with tendon compliance: at each
#' time the muscle-tendon force equilibrium is solved for the fiber length
#' (quasi-static), so tendon stretch is accounted for. Requires the MTU length
#' trajectory (e.g. from [muscleTendonKinematics()]).
#'
#' @param emg EMG envelope.
#' @param mtu_length MTU length (m); scalar or same length as `emg`.
#' @param sr Sampling rate (Hz).
#' @param optimal_fiber_length,tendon_slack_length Muscle geometry (m).
#' @param params Parameter list from [emgDrivenParams()].
#' @return Muscle-tendon force time series (N).
#' @examples
#' sr <- 500; t <- seq(0, 1, by = 1 / sr)
#' emg <- pmax(sin(2 * pi * 2 * t), 0)
#' f <- emgDrivenForceElastic(emg, mtu_length = 0.30, sr = sr,
#'                            optimal_fiber_length = 0.10,
#'                            tendon_slack_length = 0.19)
#' max(f)
#' @export
emgDrivenForceElastic <- function(emg, mtu_length, sr,
                                  optimal_fiber_length, tendon_slack_length,
                                  params = emgDrivenParams()) {
  u <- emgToExcitation(emg, params$max_emg, params$emg_nonlin)
  a <- excitationToActivation(u, 1 / sr, params$tau_act, params$tau_deact)
  n <- length(a)
  ml <- if (length(mtu_length) == 1L) rep(mtu_length, n) else mtu_length[seq_len(n)]
  force <- numeric(n)
  for (i in seq_len(n)) {
    eq <- equilibriumFiberLength(a[i], ml[i], optimal_fiber_length,
                                 tendon_slack_length,
                                 params$max_isometric_force, params$pennation)
    force[i] <- eq$force
  }
  force
}
