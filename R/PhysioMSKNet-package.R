#' PhysioMSKNet: Musculoskeletal Network Analysis for Physiological Data
#'
#' PhysioMSKNet applies network science to the human musculoskeletal system.
#' The system is represented as a hypergraph in which bones are vertices and
#' muscles are hyperedges connecting the bones they attach to (Murphy et al.
#' 2018, \doi{10.1371/journal.pbio.2002811}). From that representation the
#' package builds projected graphs, computes network metrics, detects
#' communities, runs a damped-oscillator perturbation model for impact scoring,
#' bridges the topology to EMG / IMU / motion-capture signals, and turns the
#' results into clinical and rehabilitation summaries.
#'
#' @section Getting the data and building a hypergraph:
#' \code{\link{loadIncidenceMatrix}}, \code{\link{loadMuscleMetadata}} and
#' \code{\link{loadMSKData}} return the bundled Murphy et al. dataset;
#' \code{\link{loadValidationData}} returns the per-figure validation tables.
#' \code{\link{MSKHypergraph}} constructs the hypergraph (from the bundled data
#' or your own incidence matrix), and \code{\link{projectBoneGraph}} /
#' \code{\link{projectMuscleGraph}} produce the one-mode projections.
#'
#' @section Degree and network metrics:
#' \code{\link{vertexDegree}}, \code{\link{hyperedgeDegree}} and
#' \code{\link{degreeDistribution}} describe the hypergraph degrees;
#' \code{\link{mskNetworkMetrics}}, \code{\link{mskBetweenness}},
#' \code{\link{mskCloseness}}, \code{\link{mskShortestPaths}} and
#' \code{\link{mskModularity}} operate on the projected graph.
#'
#' @section Community detection:
#' \code{\link{mskCommunityDetect}} (Louvain with a resolution parameter),
#' \code{\link{mskConsensusPartition}} (consensus over repeated runs) and
#' \code{\link{mskZRand}} (z-scored Rand index between partitions).
#'
#' @section Simulation and perturbation impact:
#' \code{\link{mskSimulate}} sets up the damped harmonic-oscillator model;
#' \code{\link{mskImpactScore}} / \code{\link{mskImpactScoreAll}} compute
#' perturbation impact; \code{\link{mskNullHypergraph}} /
#' \code{\link{mskNullEnsemble}} generate degree-preserving null models and
#' \code{\link{mskImpactDeviation}} scores impact against them.
#'
#' @section Hill-type muscle model:
#' \code{\link{forceLengthActive}}, \code{\link{forceLengthPassive}},
#' \code{\link{forceVelocity}}, \code{\link{tendonForceLength}} and
#' \code{\link{hillMuscleForce}} are the contractile-element curves;
#' \code{\link{emgToExcitation}}, \code{\link{excitationToActivation}},
#' \code{\link{emgDrivenParams}}, \code{\link{emgDrivenForce}},
#' \code{\link{emgDrivenJointMoment}} and \code{\link{calibrateEMGDrivenModel}}
#' form the EMG-driven forward pipeline.
#'
#' @section Bridges to measured signals:
#' Map other modalities onto the network with \code{\link{emgToMSKMapping}},
#' \code{\link{imuToMSKMapping}} and \code{\link{mocapToMSKMapping}}, then run
#' the matched analyses, e.g. \code{\link{imuNetworkKinematics}},
#' \code{\link{imuImpactPrediction}}, \code{\link{imuCommunityDynamics}} and the
#' \code{mocap*} / \code{emg*} equivalents.
#'
#' @section Clinical and rehabilitation layer:
#' \code{\link{mskClinicalPredictor}}, \code{\link{mskInjuryRiskProfile}},
#' \code{\link{mskDetectCompensation}}, \code{\link{mskRecoveryTrajectoryFit}}
#' and \code{\link{mskRehabProtocol}} summarise network features for outcome
#' prediction and rehabilitation planning.
#'
#' @section Reproduction and visualization:
#' \code{\link{mskReproducePaper}} re-runs the headline analyses against the
#' bundled validation data; \code{\link{plotMSKNetwork}},
#' \code{\link{plotDegreeDistribution}}, \code{\link{plotCommunityStructure}},
#' \code{\link{plotImpactVsDegree}}, \code{\link{plotImpactVsRecovery}} and
#' \code{\link{plotHomunculus}} draw the standard figures.
#'
#' @section Where to go next:
#' Start from the \code{vignette("PhysioMSKNet")} walkthrough. PhysioMSKNet is
#' part of the PhysioExperiment ecosystem: it pairs with \pkg{PhysioEMG},
#' \pkg{PhysioMoCap} and \pkg{PhysioOpenSim} for signal input and with
#' \pkg{PhysioAnnotationHub} for anatomical annotation.
#'
#' @references Murphy AC, Muldoon SF, Baker D, Lastowka A, Bennett B, Yang M,
#'   Bhatt P, Bassett DS (2018). "Structure, function, and control of the human
#'   musculoskeletal network." PLOS Biology 16(1): e2002811.
#'   \doi{10.1371/journal.pbio.2002811}
#'
#' @examples
#' # Build the default musculoskeletal hypergraph and inspect it
#' hg <- MSKHypergraph()
#' hg
#' # One-mode projection onto the bone space
#' A <- projectBoneGraph(hg)
#' dim(A)
#' @keywords internal
"_PACKAGE"
