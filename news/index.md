# Changelog

## PhysioMSKNet 0.2.0

- Forward EMG-driven Hill-type muscle model (`R/hill-model.R`): turns an
  EMG envelope into physical muscle force and joint torque (N.m),
  replacing the amplitude proxy.
  - [`excitationToActivation()`](https://x-biosignal.github.io/PhysioMSKNet/reference/excitationToActivation.md)
    — first-order activation dynamics (Thelen 2003).
  - [`forceLengthActive()`](https://x-biosignal.github.io/PhysioMSKNet/reference/forceLengthActive.md),
    [`forceLengthPassive()`](https://x-biosignal.github.io/PhysioMSKNet/reference/forceLengthPassive.md),
    [`forceVelocity()`](https://x-biosignal.github.io/PhysioMSKNet/reference/forceVelocity.md),
    [`hillMuscleForce()`](https://x-biosignal.github.io/PhysioMSKNet/reference/hillMuscleForce.md)
    — the Hill contractile + passive elements.
  - [`emgToExcitation()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToExcitation.md),
    [`emgDrivenForce()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgDrivenForce.md),
    [`emgDrivenJointMoment()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgDrivenJointMoment.md)
    — the forward EMG-to-moment pipeline over normalised fiber
    kinematics from
    [`muscleTendonKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/muscleTendonKinematics.md).
  - [`calibrateEMGDrivenModel()`](https://x-biosignal.github.io/PhysioMSKNet/reference/calibrateEMGDrivenModel.md)
    — CEINMS-style calibration to measured joint moments.

## PhysioMSKNet 0.1.0

Initial release as a standalone package in the x-biosignal ecosystem.
PhysioMSKNet brings network-science analysis of the human
musculoskeletal system to R, implementing the hypergraph model of Murphy
et al. (2018, PLOS Biology) and bridging it to multi-modal physiological
signals (EMG, MoCap, IMU, EEG, OpenSim) for rehabilitation-oriented
analysis.

### New Features

- Hypergraph data model in which bones are vertices and muscles are
  hyperedges:
  - [`MSKHypergraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/MSKHypergraph.md)
    constructs the model from a sparse incidence matrix, with a bundled
    173-bone x 270-muscle anatomical dataset loadable via
    [`loadMSKData()`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadMSKData.md),
    [`loadIncidenceMatrix()`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadIncidenceMatrix.md),
    [`loadMuscleMetadata()`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadMuscleMetadata.md),
    and
    [`loadValidationData()`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadValidationData.md).
  - One-mode projections
    [`projectBoneGraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/projectBoneGraph.md)
    and
    [`projectMuscleGraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/projectMuscleGraph.md),
    plus
    [`hyperedgeDegree()`](https://x-biosignal.github.io/PhysioMSKNet/reference/hyperedgeDegree.md),
    [`vertexDegree()`](https://x-biosignal.github.io/PhysioMSKNet/reference/vertexDegree.md),
    and
    [`degreeDistribution()`](https://x-biosignal.github.io/PhysioMSKNet/reference/degreeDistribution.md).
- Damped harmonic-oscillator physical simulation and perturbation-based
  impact scoring:
  - [`mskSimulate()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskSimulate.md)
    sets up a spring-mass system (spring constant 1/(deg-1) per muscle);
    [`mskImpactScore()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactScore.md)
    and
    [`mskImpactScoreAll()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactScoreAll.md)
    perturb muscles via velocity-Verlet integration in a 4th spatial
    dimension to quantify network-wide displacement.
  - [`mskNullHypergraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNullHypergraph.md)
    /
    [`mskNullEnsemble()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNullEnsemble.md)
    generate degree-preserving randomized null models, and
    [`mskImpactDeviation()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactDeviation.md)
    scores each muscle against its degree-matched null distribution.
- Community detection and graph metrics:
  - [`mskCommunityDetect()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCommunityDetect.md)
    and
    [`mskConsensusPartition()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskConsensusPartition.md)
    run Louvain community detection (with a pure-R fallback when
    `igraph` is absent), with
    [`mskModularity()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskModularity.md),
    [`mskZRand()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskZRand.md),
    and
    [`mskConsensusPartition()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskConsensusPartition.md)
    consensus over repeated runs.
  - Centrality and distance metrics via
    [`mskNetworkMetrics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNetworkMetrics.md),
    [`mskBetweenness()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskBetweenness.md)
    (Brandes),
    [`mskCloseness()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCloseness.md),
    and
    [`mskShortestPaths()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskShortestPaths.md).
- Statistical validation against the reference paper:
  - [`mskRobustRegression()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRobustRegression.md)
    (weighted / [`MASS::rlm`](https://rdrr.io/pkg/MASS/man/rlm.html)
    robust fitting),
    [`mskImpactRecoveryModel()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactRecoveryModel.md),
    and
    [`mskHomuncCorrelation()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskHomuncCorrelation.md)
    reproduce the impact-vs-recovery and community-vs-homunculus
    results, and
    [`mskReproducePaper()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskReproducePaper.md)
    runs the full validation pipeline end to end.
- Base-graphics visualization:
  [`plotMSKNetwork()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotMSKNetwork.md),
  [`plotDegreeDistribution()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotDegreeDistribution.md),
  [`plotCommunityStructure()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotCommunityStructure.md),
  [`plotImpactVsDegree()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotImpactVsDegree.md),
  [`plotImpactVsRecovery()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotImpactVsRecovery.md),
  and
  [`plotHomunculus()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotHomunculus.md).

### Multi-Modal Bridges

- EMG bridge:
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md)
  matches EMG channels to muscles, and
  [`emgStructuralCoherence()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgStructuralCoherence.md),
  [`emgCommunityCompare()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgCommunityCompare.md),
  and
  [`emgMSKEnrichment()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgMSKEnrichment.md)
  compare functional coherence and activation against network structure
  (with a Mantel test and Welch-coherence fallback).
- MoCap and IMU bridges:
  [`mocapToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapToMSKMapping.md)
  /
  [`imuToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuToMSKMapping.md)
  resolve segment and sensor names to bones, and
  [`mocapNetworkKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapNetworkKinematics.md),
  [`mocapImpactPrediction()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapImpactPrediction.md),
  [`mocapCommunityDynamics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapCommunityDynamics.md),
  [`imuNetworkKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuNetworkKinematics.md),
  [`imuImpactPrediction()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuImpactPrediction.md),
  and
  [`imuCommunityDynamics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuCommunityDynamics.md)
  propagate kinematic stress and movement synchrony through the network.
- OpenSim bridge:
  [`opensimToMSKHypergraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/opensimToMSKHypergraph.md)
  builds a hypergraph directly from an `.osim` model (parsing PathPoint
  attachments), with
  [`opensimNetworkAnalysis()`](https://x-biosignal.github.io/PhysioMSKNet/reference/opensimNetworkAnalysis.md),
  [`opensimCompareModels()`](https://x-biosignal.github.io/PhysioMSKNet/reference/opensimCompareModels.md),
  and
  [`opensimForceToImpact()`](https://x-biosignal.github.io/PhysioMSKNet/reference/opensimForceToImpact.md)
  for force-weighted impact analysis.
- Neuromechanics bridge: corticomuscular and directional coupling
  ([`neuromechCorticomuscularCoupling()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechCorticomuscularCoupling.md),
  [`neuromechDirectionalCoupling()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechDirectionalCoupling.md)
  via Granger causality / transfer entropy), electromechanical delay
  ([`neuromechElectromechanicalDelay()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechElectromechanicalDelay.md)),
  joint-torque estimation from moment arms
  ([`neuromechJointTorque()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechJointTorque.md)),
  NMF/PCA muscle-synergy decomposition
  ([`neuromechMuscleSynergy()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechMuscleSynergy.md)),
  motor-drive topography, integrated vulnerability, and a
  [`neuromechSummary()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechSummary.md)
  orchestrator.
- Knowledge-graph bridge (via PhysioAnnotationHub):
  [`mskAnnotate()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskAnnotate.md),
  [`mskEnrichKG()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskEnrichKG.md)
  (hypergeometric enrichment),
  [`mskPathwayQuery()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskPathwayQuery.md),
  [`mskCommunityProfile()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCommunityProfile.md),
  [`mskClinicalEvidence()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskClinicalEvidence.md),
  and
  [`mskKGSummary()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskKGSummary.md).

### Rehabilitation Analysis

- Clinical prediction from network topology:
  [`mskClinicalPredictor()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskClinicalPredictor.md),
  [`mskRecoveryTimeline()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRecoveryTimeline.md),
  [`mskInjuryRiskProfile()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskInjuryRiskProfile.md),
  [`mskRehabProtocol()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRehabProtocol.md),
  and the
  [`mskOutcomeSummary()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskOutcomeSummary.md)
  orchestrator.
- Compensation detection:
  [`mskDetectCompensation()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskDetectCompensation.md),
  [`mskCompensationRiskScore()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCompensationRiskScore.md),
  [`mskCompensationEvolution()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCompensationEvolution.md),
  [`mskCompensationNetwork()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCompensationNetwork.md),
  and
  [`mskCompensationSummary()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCompensationSummary.md)
  identify and track compensatory activation in muscles neighboring an
  injury.
- Longitudinal tracking:
  [`mskLongitudinalTracker()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskLongitudinalTracker.md)
  with ICC-based
  [`mskMinimalDetectableChange()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskMinimalDetectableChange.md),
  parametric
  [`mskRecoveryTrajectoryFit()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRecoveryTrajectoryFit.md)
  (exponential / sigmoid / linear),
  [`mskDetectResponderStatus()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskDetectResponderStatus.md),
  [`mskDetectRecoveryPlateau()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskDetectRecoveryPlateau.md),
  [`mskSynergyChangeIndex()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskSynergyChangeIndex.md),
  [`mskNeuralAdaptationIndex()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNeuralAdaptationIndex.md),
  and
  [`mskCoordinationQualityScore()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCoordinationQualityScore.md).
- Functional outcome prediction:
  [`mskPredictFunctionalOutcome()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskPredictFunctionalOutcome.md)
  (ROM, strength, composite score),
  [`mskFunctionalMilestones()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskFunctionalMilestones.md),
  [`mskOutcomeConfidenceInterval()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskOutcomeConfidenceInterval.md),
  [`mskReassess()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskReassess.md),
  [`mskAdaptProtocol()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskAdaptProtocol.md),
  and
  [`mskOutcomeReport()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskOutcomeReport.md).

### Notes

- Clinical and outcome functions are research-exploration tools, not
  diagnostic devices; recovery models were validated on aggregate muscle
  groups and patient-factor adjustments are heuristic.
- `igraph`, `MASS`, `readxl`, and the sibling PhysioEMG / PhysioMoCap /
  PhysioOpenSim / PhysioCrossModal / PhysioAnnotationHub packages are
  optional (Suggests); pure-R and minimal fallbacks are used when
  absent.
