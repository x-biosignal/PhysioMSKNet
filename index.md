# PhysioMSKNet

**Musculoskeletal Network Analysis for Physiological Data**

PhysioMSKNet applies network science to the human musculoskeletal
system. It implements hypergraph representations of muscle-bone
connections, perturbation-based impact scoring, community detection,
cross-modal mapping (EMG, IMU, MoCap), clinical outcome prediction, and
neuromechanical coupling analysis. The theoretical foundation follows
Murphy et al. (2018)
[doi:10.1371/journal.pbio.2002811](https://doi.org/10.1371/journal.pbio.2002811).

The package exports 88 functions organized into 10 functional
categories, providing a comprehensive toolkit for translational
musculoskeletal research spanning biomechanics, rehabilitation, and
neuroscience.

## Features

### Hypergraph Representation

The `MSKHypergraph` class models the musculoskeletal system as a
hypergraph where bones are vertices and muscles are hyperedges
connecting their origin and insertion sites. This representation
preserves the many-to-many topology lost in standard graph projections.

| Function | Description |
|----|----|
| [`MSKHypergraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/MSKHypergraph.md) | Construct a hypergraph from an incidence matrix |
| [`vertexDegree()`](https://x-biosignal.github.io/PhysioMSKNet/reference/vertexDegree.md) | Number of muscles attached to each bone |
| [`hyperedgeDegree()`](https://x-biosignal.github.io/PhysioMSKNet/reference/hyperedgeDegree.md) | Number of bones spanned by each muscle |
| [`projectMuscleGraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/projectMuscleGraph.md) | Project to muscle co-activation graph |
| [`projectBoneGraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/projectBoneGraph.md) | Project to bone adjacency graph |
| [`mskNullHypergraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNullHypergraph.md) | Generate a degree-preserving null model |
| [`mskNullEnsemble()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNullEnsemble.md) | Generate an ensemble of null models |
| [`loadIncidenceMatrix()`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadIncidenceMatrix.md) | Load incidence matrix from file |
| [`loadMSKData()`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadMSKData.md) | Load bundled MSK dataset |
| [`loadMuscleMetadata()`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadMuscleMetadata.md) | Load bundled muscle metadata |
| [`loadValidationData()`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadValidationData.md) | Load validation dataset |

### Network Metrics

| Function | Description |
|----|----|
| [`mskNetworkMetrics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNetworkMetrics.md) | Compute all metrics in one call |
| [`mskBetweenness()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskBetweenness.md) | Betweenness centrality |
| [`mskCloseness()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCloseness.md) | Closeness centrality |
| [`degreeDistribution()`](https://x-biosignal.github.io/PhysioMSKNet/reference/degreeDistribution.md) | Degree distribution analysis |
| [`mskModularity()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskModularity.md) | Network modularity score |
| [`mskShortestPaths()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskShortestPaths.md) | Shortest path computation |

### Physical Simulation

| Function | Description |
|----|----|
| [`mskSimulate()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskSimulate.md) | Damped harmonic oscillator simulation |
| [`mskReproducePaper()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskReproducePaper.md) | Reproduce Murphy et al. (2018) results |

### Perturbation-Based Impact Analysis

| Function | Description |
|----|----|
| [`mskImpactScore()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactScore.md) | Perturbation impact for a single vertex |
| [`mskImpactScoreAll()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactScoreAll.md) | Impact scores for all vertices |
| [`mskImpactDeviation()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactDeviation.md) | Deviation from null model expectation |
| [`mskImpactRecoveryModel()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactRecoveryModel.md) | Recovery dynamics after perturbation |

### Community Detection

| Function | Description |
|----|----|
| [`mskCommunityDetect()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCommunityDetect.md) | Detect musculoskeletal communities |
| [`mskConsensusPartition()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskConsensusPartition.md) | Consensus partition from multiple runs |
| [`mskCommunityProfile()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCommunityProfile.md) | Detailed profile of each community |
| [`mskZRand()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskZRand.md) | z-score of the Rand index for partition comparison |

### Cross-Modal Mapping

Bridge musculoskeletal network topology to physiological signals from
EMG, IMU, and motion capture.

**EMG Integration:**

| Function | Description |
|----|----|
| [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md) | Map EMG channels to MSK network nodes |
| [`emgCommunityCompare()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgCommunityCompare.md) | Compare EMG synergies to MSK communities |
| [`emgMSKEnrichment()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgMSKEnrichment.md) | Test enrichment of EMG patterns in MSK modules |
| [`emgStructuralCoherence()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgStructuralCoherence.md) | Coherence between EMG and structural topology |

**IMU Integration:**

| Function | Description |
|----|----|
| [`imuToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuToMSKMapping.md) | Map IMU sensors to MSK network nodes |
| [`imuCommunityDynamics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuCommunityDynamics.md) | Time-varying community structure from IMU |
| [`imuImpactPrediction()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuImpactPrediction.md) | Predict impact scores from IMU signals |
| [`imuNetworkKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuNetworkKinematics.md) | Network-informed kinematic analysis |

**MoCap Integration:**

| Function | Description |
|----|----|
| [`mocapToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapToMSKMapping.md) | Map motion capture markers to MSK network |
| [`mocapCommunityDynamics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapCommunityDynamics.md) | Time-varying community structure from MoCap |
| [`mocapImpactPrediction()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapImpactPrediction.md) | Predict impact scores from MoCap data |
| [`mocapNetworkKinematics()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapNetworkKinematics.md) | Network-informed kinematic analysis |

### Clinical Prediction

| Function | Description |
|----|----|
| [`mskClinicalPredictor()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskClinicalPredictor.md) | Build predictive model from network features |
| [`mskPredictFunctionalOutcome()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskPredictFunctionalOutcome.md) | Predict functional outcome scores |
| [`mskDetectResponderStatus()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskDetectResponderStatus.md) | Classify responders vs. non-responders |
| [`mskDetectCompensation()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskDetectCompensation.md) | Detect compensatory movement patterns |
| [`mskDetectRecoveryPlateau()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskDetectRecoveryPlateau.md) | Identify recovery plateaus |
| [`mskClinicalEvidence()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskClinicalEvidence.md) | Generate clinical evidence summary |
| [`mskInjuryRiskProfile()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskInjuryRiskProfile.md) | Compute injury risk from network topology |
| [`mskFunctionalMilestones()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskFunctionalMilestones.md) | Track functional milestones |

### Compensation Analysis

| Function | Description |
|----|----|
| [`mskCompensationNetwork()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCompensationNetwork.md) | Build compensation network from deviations |
| [`mskCompensationSummary()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCompensationSummary.md) | Summarize compensation patterns |
| [`mskCompensationEvolution()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCompensationEvolution.md) | Track compensation changes over time |
| [`mskCompensationRiskScore()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCompensationRiskScore.md) | Quantify compensation-related risk |

### Recovery and Rehabilitation

| Function | Description |
|----|----|
| [`mskOutcomeReport()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskOutcomeReport.md) | Generate outcome report |
| [`mskOutcomeSummary()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskOutcomeSummary.md) | Concise outcome summary |
| [`mskOutcomeConfidenceInterval()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskOutcomeConfidenceInterval.md) | Confidence intervals for outcome metrics |
| [`mskRecoveryTrajectoryFit()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRecoveryTrajectoryFit.md) | Fit recovery trajectory models |
| [`mskRecoveryTimeline()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRecoveryTimeline.md) | Projected recovery timeline |
| [`mskLongitudinalTracker()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskLongitudinalTracker.md) | Track network metrics over time |
| [`mskMinimalDetectableChange()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskMinimalDetectableChange.md) | Compute MDC for network metrics |
| [`mskRehabProtocol()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRehabProtocol.md) | Generate network-informed rehab protocol |
| [`mskAdaptProtocol()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskAdaptProtocol.md) | Adapt protocol based on progress data |
| [`mskReassess()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskReassess.md) | Reassess patient status |
| [`mskCoordinationQualityScore()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCoordinationQualityScore.md) | Coordination quality from network metrics |

### Neuromechanics Bridge

| Function | Description |
|----|----|
| [`neuromechSummary()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechSummary.md) | Integrated neuromechanical summary |
| [`neuromechMuscleSynergy()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechMuscleSynergy.md) | Muscle synergy extraction |
| [`neuromechDirectionalCoupling()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechDirectionalCoupling.md) | Directional coupling between signals |
| [`neuromechCorticomuscularCoupling()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechCorticomuscularCoupling.md) | Corticomuscular coherence |
| [`neuromechJointTorque()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechJointTorque.md) | Joint torque estimation |
| [`neuromechMotorDriveTopography()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechMotorDriveTopography.md) | Spatial motor drive mapping |
| [`neuromechElectromechanicalDelay()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechElectromechanicalDelay.md) | EMD estimation |
| [`neuromechIntegratedVulnerability()`](https://x-biosignal.github.io/PhysioMSKNet/reference/neuromechIntegratedVulnerability.md) | Multi-factor vulnerability index |
| [`mskNeuralAdaptationIndex()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNeuralAdaptationIndex.md) | Neural adaptation quantification |
| [`mskSynergyChangeIndex()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskSynergyChangeIndex.md) | Synergy change over time |

### Annotation and Knowledge Graph

| Function | Description |
|----|----|
| [`mskAnnotate()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskAnnotate.md) | Annotate network nodes with anatomical metadata |
| [`mskEnrichKG()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskEnrichKG.md) | Knowledge graph enrichment analysis |
| [`mskKGSummary()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskKGSummary.md) | Knowledge graph summary for a network |
| [`mskPathwayQuery()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskPathwayQuery.md) | Query anatomical pathways |
| [`mskHomuncCorrelation()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskHomuncCorrelation.md) | Correlation with somatotopic organization |

### OpenSim Integration

| Function | Description |
|----|----|
| [`opensimToMSKHypergraph()`](https://x-biosignal.github.io/PhysioMSKNet/reference/opensimToMSKHypergraph.md) | Convert OpenSim model to MSK hypergraph |
| [`opensimNetworkAnalysis()`](https://x-biosignal.github.io/PhysioMSKNet/reference/opensimNetworkAnalysis.md) | Full network analysis from an OpenSim model |
| [`opensimForceToImpact()`](https://x-biosignal.github.io/PhysioMSKNet/reference/opensimForceToImpact.md) | Map OpenSim muscle forces to impact scores |
| [`opensimCompareModels()`](https://x-biosignal.github.io/PhysioMSKNet/reference/opensimCompareModels.md) | Compare network topology across models |

### Visualization

| Function | Description |
|----|----|
| [`plotMSKNetwork()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotMSKNetwork.md) | Network graph visualization |
| [`plotDegreeDistribution()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotDegreeDistribution.md) | Degree distribution plot |
| [`plotHomunculus()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotHomunculus.md) | Body map with network overlay |
| [`plotCommunityStructure()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotCommunityStructure.md) | Community detection results |
| [`plotImpactVsDegree()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotImpactVsDegree.md) | Impact score vs. degree scatter |
| [`plotImpactVsRecovery()`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotImpactVsRecovery.md) | Impact vs. recovery time |

### Statistics

| Function | Description |
|----|----|
| [`mskRobustRegression()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRobustRegression.md) | Robust regression for network predictors |

## Installation

### From R-universe

``` r

install.packages("PhysioMSKNet",
                  repos = c("https://x-biosignal.r-universe.dev",
                            "https://cloud.r-project.org"))
```

### From GitHub

``` r

# install.packages("remotes")
remotes::install_github("x-biosignal/PhysioMSKNet")
```

## Quick Start

``` r

library(PhysioMSKNet)

# --- Build a hypergraph from bundled data ---
inc <- loadIncidenceMatrix()
hg <- MSKHypergraph(inc)
print(hg)

# --- Compute network metrics ---
metrics <- mskNetworkMetrics(hg)
metrics$degree
metrics$betweenness
metrics$modularity

# --- Perturbation-based impact analysis ---
impact <- mskImpactScoreAll(hg)
head(sort(impact, decreasing = TRUE))

# --- Detect communities ---
comm <- mskCommunityDetect(hg)
profile <- mskCommunityProfile(hg, comm)

# --- Visualize ---
plotMSKNetwork(hg, community = comm)
plotImpactVsDegree(hg, impact)
plotHomunculus(hg, values = impact)

# --- Cross-modal: map EMG to MSK network ---
emg_map <- emgToMSKMapping(
  emg_channels = c("TA", "SOL", "GM", "GL", "RF", "VL", "VM", "BF"),
  hypergraph = hg
)
emgCommunityCompare(emg_map, comm)

# --- Clinical prediction ---
predictor <- mskClinicalPredictor(
  features = metrics,
  outcome = patient_scores,
  method = "lasso"
)
mskPredictFunctionalOutcome(predictor, new_features)

# --- Neuromechanics ---
synergies <- neuromechMuscleSynergy(emg_data, n_synergies = 4)
neuromechSummary(hg, emg_data, imu_data)
```

## Dependencies

- **R** (\>= 4.2)
- **Matrix** (sparse matrix operations)

### Optional (Suggests)

| Package              | Purpose                                        |
|----------------------|------------------------------------------------|
| igraph               | Graph algorithms for advanced network analysis |
| MASS                 | Robust statistical methods                     |
| ggplot2              | Enhanced visualization                         |
| readxl               | Excel data import                              |
| xml2                 | OpenSim XML parsing                            |
| PhysioAnnotationHub  | Anatomical annotation and knowledge graph      |
| PhysioCrossModal     | Cross-modal signal integration                 |
| PhysioEMG            | EMG signal processing                          |
| PhysioMoCap          | Motion capture data handling                   |
| PhysioOpenSim        | Native OpenSim model access                    |
| SummarizedExperiment | Bioconductor data containers                   |

## Theoretical Background

The musculoskeletal network model is based on:

> Murphy AC, Muldoon SF, Baker D, Lastowka A, Bennett B, Yang M, Bhatt
> P, Bassett DS (2018). “Structure, function, and control of the human
> musculoskeletal network.” *PLOS Biology*, 16(1): e2002811.
> [doi:10.1371/journal.pbio.2002811](https://doi.org/10.1371/journal.pbio.2002811)

The human musculoskeletal system is modeled as a hypergraph where
**bones are vertices** and **muscles are hyperedges** connecting their
attachment sites. This representation enables network-theoretic analysis
of structural vulnerability, functional modularity, and injury impact
propagation.

## Ecosystem

PhysioMSKNet is part of the [PhysioExperiment
ecosystem](https://github.com/x-biosignal/PhysioExperiment), a suite of
R packages for multi-modal physiological signal analysis.

Related packages:

| Package | Role |
|----|----|
| [PhysioExperiment](https://github.com/x-biosignal/PhysioExperiment) | Core data model and signal processing |
| [PhysioOpenSim](https://github.com/x-biosignal/PhysioExperiment) | Native OpenSim C++ integration |
| [PhysioAnnotationHub](https://github.com/x-biosignal/PhysioExperiment) | Anatomical knowledge graph |
| [PhysioMoCap](https://github.com/x-biosignal/PhysioExperiment) | Motion capture I/O and analysis |
| [PhysioEMG](https://github.com/x-biosignal/PhysioExperiment) | EMG signal processing |

## Author

Yusuke Matsui

## License

MIT

## Governance & support

Part of the [Physio ecosystem](https://x-biosignal.r-universe.dev).
Community and policy documents live in the umbrella repository:

- [Code of
  Conduct](https://github.com/x-biosignal/PhysioExperiment/blob/main/CODE_OF_CONDUCT.md)
- [Contributing](https://github.com/x-biosignal/PhysioExperiment/blob/main/CONTRIBUTING.md)
- [Governance](https://github.com/x-biosignal/PhysioExperiment/blob/main/GOVERNANCE.md)
- [Support](https://github.com/x-biosignal/PhysioExperiment/blob/main/SUPPORT.md)
- [Security
  policy](https://github.com/x-biosignal/PhysioExperiment/blob/main/SECURITY.md)
- [Deprecation & lifecycle
  policy](https://github.com/x-biosignal/PhysioExperiment/blob/main/DEPRECATION.md)
