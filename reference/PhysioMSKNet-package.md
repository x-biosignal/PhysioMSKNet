# PhysioMSKNet: Musculoskeletal Network Analysis for Physiological Data

PhysioMSKNet applies network science to the human musculoskeletal
system. The system is represented as a hypergraph in which bones are
vertices and muscles are hyperedges connecting the bones they attach to
(Murphy et al. 2018,
[doi:10.1371/journal.pbio.2002811](https://doi.org/10.1371/journal.pbio.2002811)
). From that representation the package builds projected graphs,
computes network metrics, detects communities, runs a damped-oscillator
perturbation model for impact scoring, bridges the topology to EMG / IMU
/ motion-capture signals, and turns the results into clinical and
rehabilitation summaries.

## Getting the data and building a hypergraph

[`loadIncidenceMatrix`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadIncidenceMatrix.md),
[`loadMuscleMetadata`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadMuscleMetadata.md)
and
[`loadMSKData`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadMSKData.md)
return the bundled Murphy et al. dataset;
[`loadValidationData`](https://x-biosignal.github.io/PhysioMSKNet/reference/loadValidationData.md)
returns the per-figure validation tables.
[`MSKHypergraph`](https://x-biosignal.github.io/PhysioMSKNet/reference/MSKHypergraph.md)
constructs the hypergraph (from the bundled data or your own incidence
matrix), and
[`projectBoneGraph`](https://x-biosignal.github.io/PhysioMSKNet/reference/projectBoneGraph.md)
/
[`projectMuscleGraph`](https://x-biosignal.github.io/PhysioMSKNet/reference/projectMuscleGraph.md)
produce the one-mode projections.

## Degree and network metrics

[`vertexDegree`](https://x-biosignal.github.io/PhysioMSKNet/reference/vertexDegree.md),
[`hyperedgeDegree`](https://x-biosignal.github.io/PhysioMSKNet/reference/hyperedgeDegree.md)
and
[`degreeDistribution`](https://x-biosignal.github.io/PhysioMSKNet/reference/degreeDistribution.md)
describe the hypergraph degrees;
[`mskNetworkMetrics`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNetworkMetrics.md),
[`mskBetweenness`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskBetweenness.md),
[`mskCloseness`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCloseness.md),
[`mskShortestPaths`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskShortestPaths.md)
and
[`mskModularity`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskModularity.md)
operate on the projected graph.

## Community detection

[`mskCommunityDetect`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskCommunityDetect.md)
(Louvain with a resolution parameter),
[`mskConsensusPartition`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskConsensusPartition.md)
(consensus over repeated runs) and
[`mskZRand`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskZRand.md)
(z-scored Rand index between partitions).

## Simulation and perturbation impact

[`mskSimulate`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskSimulate.md)
sets up the damped harmonic-oscillator model;
[`mskImpactScore`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactScore.md)
/
[`mskImpactScoreAll`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactScoreAll.md)
compute perturbation impact;
[`mskNullHypergraph`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNullHypergraph.md)
/
[`mskNullEnsemble`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskNullEnsemble.md)
generate degree-preserving null models and
[`mskImpactDeviation`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskImpactDeviation.md)
scores impact against them.

## Hill-type muscle model

[`forceLengthActive`](https://x-biosignal.github.io/PhysioMSKNet/reference/forceLengthActive.md),
[`forceLengthPassive`](https://x-biosignal.github.io/PhysioMSKNet/reference/forceLengthPassive.md),
[`forceVelocity`](https://x-biosignal.github.io/PhysioMSKNet/reference/forceVelocity.md),
[`tendonForceLength`](https://x-biosignal.github.io/PhysioMSKNet/reference/tendonForceLength.md)
and
[`hillMuscleForce`](https://x-biosignal.github.io/PhysioMSKNet/reference/hillMuscleForce.md)
are the contractile-element curves;
[`emgToExcitation`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToExcitation.md),
[`excitationToActivation`](https://x-biosignal.github.io/PhysioMSKNet/reference/excitationToActivation.md),
[`emgDrivenParams`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgDrivenParams.md),
[`emgDrivenForce`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgDrivenForce.md),
[`emgDrivenJointMoment`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgDrivenJointMoment.md)
and
[`calibrateEMGDrivenModel`](https://x-biosignal.github.io/PhysioMSKNet/reference/calibrateEMGDrivenModel.md)
form the EMG-driven forward pipeline.

## Bridges to measured signals

Map other modalities onto the network with
[`emgToMSKMapping`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md),
[`imuToMSKMapping`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuToMSKMapping.md)
and
[`mocapToMSKMapping`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapToMSKMapping.md),
then run the matched analyses, e.g.
[`imuNetworkKinematics`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuNetworkKinematics.md),
[`imuImpactPrediction`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuImpactPrediction.md),
[`imuCommunityDynamics`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuCommunityDynamics.md)
and the `mocap*` / `emg*` equivalents.

## Clinical and rehabilitation layer

[`mskClinicalPredictor`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskClinicalPredictor.md),
[`mskInjuryRiskProfile`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskInjuryRiskProfile.md),
[`mskDetectCompensation`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskDetectCompensation.md),
[`mskRecoveryTrajectoryFit`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRecoveryTrajectoryFit.md)
and
[`mskRehabProtocol`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRehabProtocol.md)
summarise network features for outcome prediction and rehabilitation
planning.

## Reproduction and visualization

[`mskReproducePaper`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskReproducePaper.md)
re-runs the headline analyses against the bundled validation data;
[`plotMSKNetwork`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotMSKNetwork.md),
[`plotDegreeDistribution`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotDegreeDistribution.md),
[`plotCommunityStructure`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotCommunityStructure.md),
[`plotImpactVsDegree`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotImpactVsDegree.md),
[`plotImpactVsRecovery`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotImpactVsRecovery.md)
and
[`plotHomunculus`](https://x-biosignal.github.io/PhysioMSKNet/reference/plotHomunculus.md)
draw the standard figures.

## Where to go next

Start from the
[`vignette("PhysioMSKNet")`](https://x-biosignal.github.io/PhysioMSKNet/articles/PhysioMSKNet.md)
walkthrough. PhysioMSKNet is part of the PhysioExperiment ecosystem: it
pairs with PhysioEMG, PhysioMoCap and PhysioOpenSim for signal input and
with PhysioAnnotationHub for anatomical annotation.

## References

Murphy AC, Muldoon SF, Baker D, Lastowka A, Bennett B, Yang M, Bhatt P,
Bassett DS (2018). "Structure, function, and control of the human
musculoskeletal network." PLOS Biology 16(1): e2002811.
[doi:10.1371/journal.pbio.2002811](https://doi.org/10.1371/journal.pbio.2002811)

## See also

Useful links:

- <https://github.com/x-biosignal/PhysioMSKNet>

- <https://x-biosignal.r-universe.dev/PhysioMSKNet>

- <https://x-biosignal.github.io/PhysioMSKNet>

- Report bugs at <https://github.com/x-biosignal/PhysioMSKNet/issues>

## Author

**Maintainer**: Yusuke Matsui <mail.to.matsui@gmail.com>

## Examples

``` r
# Build the default musculoskeletal hypergraph and inspect it
hg <- MSKHypergraph()
hg
#> MSKHypergraph
#>   Bones (vertices): 173 
#>   Muscles (hyperedges): 270 
#>   Connections: 1010 
#>   Sparsity: 0.9784 
#>   Muscle degree range: 1-30 
#>   Bone degree range: 1-23 
# One-mode projection onto the bone space
A <- projectBoneGraph(hg)
dim(A)
#> [1] 173 173
```
