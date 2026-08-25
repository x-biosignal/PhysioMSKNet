# PhysioMSKNet 0.3.0

- Elastic-tendon extension to the Hill model (`R/hill-elastic.R`):
  - `tendonForceLength()` — tendon force-length curve.
  - `equilibriumFiberLength()` — solves the quasi-static muscle-tendon force
    equilibrium for the fiber length, accounting for tendon compliance.
  - `emgDrivenForceElastic()` — EMG-driven force with a compliant tendon.

# PhysioMSKNet 0.2.0

- Forward EMG-driven Hill-type muscle model (`R/hill-model.R`): turns an EMG
  envelope into physical muscle force and joint torque (N.m), replacing the
  amplitude proxy.
  - `excitationToActivation()` — first-order activation dynamics (Thelen 2003).
  - `forceLengthActive()`, `forceLengthPassive()`, `forceVelocity()`,
    `hillMuscleForce()` — the Hill contractile + passive elements.
  - `emgToExcitation()`, `emgDrivenForce()`, `emgDrivenJointMoment()` — the
    forward EMG-to-moment pipeline over normalised fiber kinematics from
    `muscleTendonKinematics()`.
  - `calibrateEMGDrivenModel()` — CEINMS-style calibration to measured joint
    moments.

# PhysioMSKNet 0.1.0

Initial release as a standalone package in the x-biosignal ecosystem.
PhysioMSKNet brings network-science analysis of the human musculoskeletal
system to R, implementing the hypergraph model of Murphy et al. (2018,
PLOS Biology) and bridging it to multi-modal physiological signals (EMG,
MoCap, IMU, EEG, OpenSim) for rehabilitation-oriented analysis.

## New Features

- Hypergraph data model in which bones are vertices and muscles are
  hyperedges:
  - `MSKHypergraph()` constructs the model from a sparse incidence matrix,
    with a bundled 173-bone x 270-muscle anatomical dataset loadable via
    `loadMSKData()`, `loadIncidenceMatrix()`, `loadMuscleMetadata()`, and
    `loadValidationData()`.
  - One-mode projections `projectBoneGraph()` and `projectMuscleGraph()`,
    plus `hyperedgeDegree()`, `vertexDegree()`, and `degreeDistribution()`.
- Damped harmonic-oscillator physical simulation and perturbation-based
  impact scoring:
  - `mskSimulate()` sets up a spring-mass system (spring constant
    1/(deg-1) per muscle); `mskImpactScore()` and `mskImpactScoreAll()`
    perturb muscles via velocity-Verlet integration in a 4th spatial
    dimension to quantify network-wide displacement.
  - `mskNullHypergraph()` / `mskNullEnsemble()` generate degree-preserving
    randomized null models, and `mskImpactDeviation()` scores each muscle
    against its degree-matched null distribution.
- Community detection and graph metrics:
  - `mskCommunityDetect()` and `mskConsensusPartition()` run Louvain
    community detection (with a pure-R fallback when `igraph` is absent),
    with `mskModularity()`, `mskZRand()`, and `mskConsensusPartition()`
    consensus over repeated runs.
  - Centrality and distance metrics via `mskNetworkMetrics()`,
    `mskBetweenness()` (Brandes), `mskCloseness()`, and
    `mskShortestPaths()`.
- Statistical validation against the reference paper:
  - `mskRobustRegression()` (weighted / `MASS::rlm` robust fitting),
    `mskImpactRecoveryModel()`, and `mskHomuncCorrelation()` reproduce the
    impact-vs-recovery and community-vs-homunculus results, and
    `mskReproducePaper()` runs the full validation pipeline end to end.
- Base-graphics visualization: `plotMSKNetwork()`,
  `plotDegreeDistribution()`, `plotCommunityStructure()`,
  `plotImpactVsDegree()`, `plotImpactVsRecovery()`, and `plotHomunculus()`.

## Multi-Modal Bridges

- EMG bridge: `emgToMSKMapping()` matches EMG channels to muscles, and
  `emgStructuralCoherence()`, `emgCommunityCompare()`, and
  `emgMSKEnrichment()` compare functional coherence and activation against
  network structure (with a Mantel test and Welch-coherence fallback).
- MoCap and IMU bridges: `mocapToMSKMapping()` / `imuToMSKMapping()` resolve
  segment and sensor names to bones, and `mocapNetworkKinematics()`,
  `mocapImpactPrediction()`, `mocapCommunityDynamics()`,
  `imuNetworkKinematics()`, `imuImpactPrediction()`, and
  `imuCommunityDynamics()` propagate kinematic stress and movement synchrony
  through the network.
- OpenSim bridge: `opensimToMSKHypergraph()` builds a hypergraph directly
  from an `.osim` model (parsing PathPoint attachments), with
  `opensimNetworkAnalysis()`, `opensimCompareModels()`, and
  `opensimForceToImpact()` for force-weighted impact analysis.
- Neuromechanics bridge: corticomuscular and directional coupling
  (`neuromechCorticomuscularCoupling()`, `neuromechDirectionalCoupling()`
  via Granger causality / transfer entropy), electromechanical delay
  (`neuromechElectromechanicalDelay()`), joint-torque estimation from moment
  arms (`neuromechJointTorque()`), NMF/PCA muscle-synergy decomposition
  (`neuromechMuscleSynergy()`), motor-drive topography, integrated
  vulnerability, and a `neuromechSummary()` orchestrator.
- Knowledge-graph bridge (via PhysioAnnotationHub): `mskAnnotate()`,
  `mskEnrichKG()` (hypergeometric enrichment), `mskPathwayQuery()`,
  `mskCommunityProfile()`, `mskClinicalEvidence()`, and `mskKGSummary()`.

## Rehabilitation Analysis

- Clinical prediction from network topology: `mskClinicalPredictor()`,
  `mskRecoveryTimeline()`, `mskInjuryRiskProfile()`, `mskRehabProtocol()`,
  and the `mskOutcomeSummary()` orchestrator.
- Compensation detection: `mskDetectCompensation()`,
  `mskCompensationRiskScore()`, `mskCompensationEvolution()`,
  `mskCompensationNetwork()`, and `mskCompensationSummary()` identify and
  track compensatory activation in muscles neighboring an injury.
- Longitudinal tracking: `mskLongitudinalTracker()` with ICC-based
  `mskMinimalDetectableChange()`, parametric `mskRecoveryTrajectoryFit()`
  (exponential / sigmoid / linear), `mskDetectResponderStatus()`,
  `mskDetectRecoveryPlateau()`, `mskSynergyChangeIndex()`,
  `mskNeuralAdaptationIndex()`, and `mskCoordinationQualityScore()`.
- Functional outcome prediction: `mskPredictFunctionalOutcome()` (ROM,
  strength, composite score), `mskFunctionalMilestones()`,
  `mskOutcomeConfidenceInterval()`, `mskReassess()`, `mskAdaptProtocol()`,
  and `mskOutcomeReport()`.

## Notes

- Clinical and outcome functions are research-exploration tools, not
  diagnostic devices; recovery models were validated on aggregate muscle
  groups and patient-factor adjustments are heuristic.
- `igraph`, `MASS`, `readxl`, and the sibling PhysioEMG / PhysioMoCap /
  PhysioOpenSim / PhysioCrossModal / PhysioAnnotationHub packages are
  optional (Suggests); pure-R and minimal fallbacks are used when absent.
