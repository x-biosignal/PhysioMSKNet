# PhysioMSKNet

<!-- badges: start -->
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![R-universe](https://x-biosignal.r-universe.dev/badges/PhysioMSKNet)](https://x-biosignal.r-universe.dev/PhysioMSKNet)
<!-- badges: end -->

**Musculoskeletal Network Analysis for Physiological Data**

PhysioMSKNet applies network science to the human musculoskeletal system.
It implements hypergraph representations of muscle-bone connections,
perturbation-based impact scoring, community detection, cross-modal mapping
(EMG, IMU, MoCap), clinical outcome prediction, and neuromechanical coupling
analysis. The theoretical foundation follows Murphy et al. (2018)
[doi:10.1371/journal.pbio.2002811](https://doi.org/10.1371/journal.pbio.2002811).

The package exports 88 functions organized into 10 functional categories,
providing a comprehensive toolkit for translational musculoskeletal research
spanning biomechanics, rehabilitation, and neuroscience.

## Features

### Hypergraph Representation

The `MSKHypergraph` class models the musculoskeletal system as a hypergraph
where bones are vertices and muscles are hyperedges connecting their origin and
insertion sites. This representation preserves the many-to-many topology lost
in standard graph projections.

| Function | Description |
|---|---|
| `MSKHypergraph()` | Construct a hypergraph from an incidence matrix |
| `vertexDegree()` | Number of muscles attached to each bone |
| `hyperedgeDegree()` | Number of bones spanned by each muscle |
| `projectMuscleGraph()` | Project to muscle co-activation graph |
| `projectBoneGraph()` | Project to bone adjacency graph |
| `mskNullHypergraph()` | Generate a degree-preserving null model |
| `mskNullEnsemble()` | Generate an ensemble of null models |
| `loadIncidenceMatrix()` | Load incidence matrix from file |
| `loadMSKData()` | Load bundled MSK dataset |
| `loadMuscleMetadata()` | Load bundled muscle metadata |
| `loadValidationData()` | Load validation dataset |

### Network Metrics

| Function | Description |
|---|---|
| `mskNetworkMetrics()` | Compute all metrics in one call |
| `mskBetweenness()` | Betweenness centrality |
| `mskCloseness()` | Closeness centrality |
| `degreeDistribution()` | Degree distribution analysis |
| `mskModularity()` | Network modularity score |
| `mskShortestPaths()` | Shortest path computation |

### Physical Simulation

| Function | Description |
|---|---|
| `mskSimulate()` | Damped harmonic oscillator simulation |
| `mskReproducePaper()` | Reproduce Murphy et al. (2018) results |

### Perturbation-Based Impact Analysis

| Function | Description |
|---|---|
| `mskImpactScore()` | Perturbation impact for a single vertex |
| `mskImpactScoreAll()` | Impact scores for all vertices |
| `mskImpactDeviation()` | Deviation from null model expectation |
| `mskImpactRecoveryModel()` | Recovery dynamics after perturbation |

### Community Detection

| Function | Description |
|---|---|
| `mskCommunityDetect()` | Detect musculoskeletal communities |
| `mskConsensusPartition()` | Consensus partition from multiple runs |
| `mskCommunityProfile()` | Detailed profile of each community |
| `mskZRand()` | z-score of the Rand index for partition comparison |

### Cross-Modal Mapping

Bridge musculoskeletal network topology to physiological signals from EMG,
IMU, and motion capture.

**EMG Integration:**

| Function | Description |
|---|---|
| `emgToMSKMapping()` | Map EMG channels to MSK network nodes |
| `emgCommunityCompare()` | Compare EMG synergies to MSK communities |
| `emgMSKEnrichment()` | Test enrichment of EMG patterns in MSK modules |
| `emgStructuralCoherence()` | Coherence between EMG and structural topology |

**IMU Integration:**

| Function | Description |
|---|---|
| `imuToMSKMapping()` | Map IMU sensors to MSK network nodes |
| `imuCommunityDynamics()` | Time-varying community structure from IMU |
| `imuImpactPrediction()` | Predict impact scores from IMU signals |
| `imuNetworkKinematics()` | Network-informed kinematic analysis |

**MoCap Integration:**

| Function | Description |
|---|---|
| `mocapToMSKMapping()` | Map motion capture markers to MSK network |
| `mocapCommunityDynamics()` | Time-varying community structure from MoCap |
| `mocapImpactPrediction()` | Predict impact scores from MoCap data |
| `mocapNetworkKinematics()` | Network-informed kinematic analysis |

### Clinical Prediction

| Function | Description |
|---|---|
| `mskClinicalPredictor()` | Build predictive model from network features |
| `mskPredictFunctionalOutcome()` | Predict functional outcome scores |
| `mskDetectResponderStatus()` | Classify responders vs. non-responders |
| `mskDetectCompensation()` | Detect compensatory movement patterns |
| `mskDetectRecoveryPlateau()` | Identify recovery plateaus |
| `mskClinicalEvidence()` | Generate clinical evidence summary |
| `mskInjuryRiskProfile()` | Compute injury risk from network topology |
| `mskFunctionalMilestones()` | Track functional milestones |

### Compensation Analysis

| Function | Description |
|---|---|
| `mskCompensationNetwork()` | Build compensation network from deviations |
| `mskCompensationSummary()` | Summarize compensation patterns |
| `mskCompensationEvolution()` | Track compensation changes over time |
| `mskCompensationRiskScore()` | Quantify compensation-related risk |

### Recovery and Rehabilitation

| Function | Description |
|---|---|
| `mskOutcomeReport()` | Generate outcome report |
| `mskOutcomeSummary()` | Concise outcome summary |
| `mskOutcomeConfidenceInterval()` | Confidence intervals for outcome metrics |
| `mskRecoveryTrajectoryFit()` | Fit recovery trajectory models |
| `mskRecoveryTimeline()` | Projected recovery timeline |
| `mskLongitudinalTracker()` | Track network metrics over time |
| `mskMinimalDetectableChange()` | Compute MDC for network metrics |
| `mskRehabProtocol()` | Generate network-informed rehab protocol |
| `mskAdaptProtocol()` | Adapt protocol based on progress data |
| `mskReassess()` | Reassess patient status |
| `mskCoordinationQualityScore()` | Coordination quality from network metrics |

### Neuromechanics Bridge

| Function | Description |
|---|---|
| `neuromechSummary()` | Integrated neuromechanical summary |
| `neuromechMuscleSynergy()` | Muscle synergy extraction |
| `neuromechDirectionalCoupling()` | Directional coupling between signals |
| `neuromechCorticomuscularCoupling()` | Corticomuscular coherence |
| `neuromechJointTorque()` | Joint torque estimation |
| `neuromechMotorDriveTopography()` | Spatial motor drive mapping |
| `neuromechElectromechanicalDelay()` | EMD estimation |
| `neuromechIntegratedVulnerability()` | Multi-factor vulnerability index |
| `mskNeuralAdaptationIndex()` | Neural adaptation quantification |
| `mskSynergyChangeIndex()` | Synergy change over time |

### Annotation and Knowledge Graph

| Function | Description |
|---|---|
| `mskAnnotate()` | Annotate network nodes with anatomical metadata |
| `mskEnrichKG()` | Knowledge graph enrichment analysis |
| `mskKGSummary()` | Knowledge graph summary for a network |
| `mskPathwayQuery()` | Query anatomical pathways |
| `mskHomuncCorrelation()` | Correlation with somatotopic organization |

### OpenSim Integration

| Function | Description |
|---|---|
| `opensimToMSKHypergraph()` | Convert OpenSim model to MSK hypergraph |
| `opensimNetworkAnalysis()` | Full network analysis from an OpenSim model |
| `opensimForceToImpact()` | Map OpenSim muscle forces to impact scores |
| `opensimCompareModels()` | Compare network topology across models |

### Visualization

| Function | Description |
|---|---|
| `plotMSKNetwork()` | Network graph visualization |
| `plotDegreeDistribution()` | Degree distribution plot |
| `plotHomunculus()` | Body map with network overlay |
| `plotCommunityStructure()` | Community detection results |
| `plotImpactVsDegree()` | Impact score vs. degree scatter |
| `plotImpactVsRecovery()` | Impact vs. recovery time |

### Statistics

| Function | Description |
|---|---|
| `mskRobustRegression()` | Robust regression for network predictors |

## Installation

### From R-universe

```r
install.packages("PhysioMSKNet",
                  repos = c("https://x-biosignal.r-universe.dev",
                            "https://cloud.r-project.org"))
```

### From GitHub

```r
# install.packages("remotes")
remotes::install_github("x-biosignal/PhysioMSKNet")
```

## Quick Start

```r
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

- **R** (>= 4.2)
- **Matrix** (sparse matrix operations)

### Optional (Suggests)

| Package | Purpose |
|---|---|
| igraph | Graph algorithms for advanced network analysis |
| MASS | Robust statistical methods |
| ggplot2 | Enhanced visualization |
| readxl | Excel data import |
| xml2 | OpenSim XML parsing |
| PhysioAnnotationHub | Anatomical annotation and knowledge graph |
| PhysioCrossModal | Cross-modal signal integration |
| PhysioEMG | EMG signal processing |
| PhysioMoCap | Motion capture data handling |
| PhysioOpenSim | Native OpenSim model access |
| SummarizedExperiment | Bioconductor data containers |

## Theoretical Background

The musculoskeletal network model is based on:

> Murphy AC, Muldoon SF, Baker D, Lastowka A, Bennett B, Yang M, Bhatt P,
> Bassett DS (2018). "Structure, function, and control of the human
> musculoskeletal network." *PLOS Biology*, 16(1): e2002811.
> [doi:10.1371/journal.pbio.2002811](https://doi.org/10.1371/journal.pbio.2002811)

The human musculoskeletal system is modeled as a hypergraph where **bones are
vertices** and **muscles are hyperedges** connecting their attachment sites.
This representation enables network-theoretic analysis of structural
vulnerability, functional modularity, and injury impact propagation.

## Ecosystem

PhysioMSKNet is part of the
[PhysioExperiment ecosystem](https://github.com/x-biosignal/PhysioExperiment),
a suite of R packages for multi-modal physiological signal analysis.

Related packages:

| Package | Role |
|---|---|
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

Part of the [Physio ecosystem](https://x-biosignal.r-universe.dev). Community and
policy documents live in the umbrella repository:

- [Code of Conduct](https://github.com/x-biosignal/PhysioExperiment/blob/main/CODE_OF_CONDUCT.md)
- [Contributing](https://github.com/x-biosignal/PhysioExperiment/blob/main/CONTRIBUTING.md)
- [Governance](https://github.com/x-biosignal/PhysioExperiment/blob/main/GOVERNANCE.md)
- [Support](https://github.com/x-biosignal/PhysioExperiment/blob/main/SUPPORT.md)
- [Security policy](https://github.com/x-biosignal/PhysioExperiment/blob/main/SECURITY.md)
- [Deprecation & lifecycle policy](https://github.com/x-biosignal/PhysioExperiment/blob/main/DEPRECATION.md)
