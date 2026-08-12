# Map Injured Muscles to Clinical Codes and Evidence

Generates a clinical evidence report for a set of injured muscles by
querying the knowledge graph for ICD-10 codes, ICF codes, innervation,
functional impact, and related muscles (synergists and antagonists).

## Usage

``` r
mskClinicalEvidence(injury_muscles, hub = NULL, hg = NULL)
```

## Arguments

- injury_muscles:

  Character or integer vector identifying injured muscles.

- hub:

  A PhysioAnnotationHub object (NULL loads default).

- hg:

  An MSKHypergraph object (NULL loads default).

## Value

An S3 object of class `"MSKClinicalEvidence"` with:

- muscles:

  Data frame of injury muscle annotations

- icd10_codes:

  Matching ICD-10 entries

- icf_codes:

  Matching ICF entries

- affected_nerves:

  Nerves innervating injured muscles

- affected_spinal_levels:

  Spinal segments involved

- functional_impact:

  Affected actions/movements

- synergists:

  Synergistic muscles from KG

- antagonists:

  Antagonistic muscles from KG

## Clinical Validity

ICD-10 and ICF code mappings are based on knowledge graph associations
and may not capture all valid codes for a clinical scenario. This tool
provides evidence aggregation for research; clinical coding should
follow local guidelines and be reviewed by qualified professionals.

## Examples

``` r
if (FALSE) { # \dontrun{
evidence <- mskClinicalEvidence(c("Biceps Brachii", "Deltoid"))
print(evidence)
} # }
```
