# Kinematic Stress-based Impact Prediction

Computes kinematic stress per bone from MoCap data and propagates it
through the MSK incidence matrix to estimate muscle vulnerability.

## Usage

``` r
mocapImpactPrediction(
  pe_mocap,
  hg = NULL,
  mapping = NULL,
  stress_metric = c("acceleration", "jerk", "range"),
  use_proxy = TRUE
)
```

## Arguments

- pe_mocap:

  A numeric matrix (frames x segments) with MoCap data.

- hg:

  An MSKHypergraph object (NULL loads default).

- mapping:

  Optional data.frame from
  [`mocapToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapToMSKMapping.md).

- stress_metric:

  Character, kinematic stress metric: "acceleration", "jerk", or
  "range".

- use_proxy:

  Logical, if TRUE uses degree-based proxy instead of full simulation
  for impact deviation (default: TRUE).

## Value

A list with:

- vulnerability:

  Named numeric vector of muscle vulnerability scores

- bone_stress:

  Named numeric vector of bone stress values

- muscle_stress_exposure:

  Named numeric vector of muscle stress exposure

- ranking:

  Data frame ranking muscles by vulnerability

## Examples

``` r
set.seed(6)
seg <- matrix(cumsum(rnorm(300 * 3)), 300, 3)
colnames(seg) <- c("humerus", "radius", "femur")
attr(seg, "sr") <- 120
mocapImpactPrediction(seg)
#> $vulnerability
#>                             Trapezius                      Latissimus Dorsi 
#>                             0.0000000                            17.8236991 
#>           Serratus Posterior Superior           Serratus Posterior Inferior 
#>                             0.0000000                             0.0000000 
#>                      Levator Scapulae                        Rhomboid Minor 
#>                             0.0000000                             0.0000000 
#>                        Rhomboid Major                     Serratus Anterior 
#>                             0.0000000                             0.0000000 
#>                               Deltoid                         Supraspinatus 
#>                             0.3240673                             2.1758801 
#>                         Infraspinatus                           Teres Minor 
#>                             2.1758801                             2.1758801 
#>                           Teres Major                         Subscapularis 
#>                             2.1758801                             2.1758801 
#>                            Subclavius                      Pectoralis Major 
#>                             0.0000000                             7.8239095 
#>                      Pectoralis Minor                      Coracobrachialis 
#>                             0.0000000                             2.1758801 
#>                        Biceps Brachii                            Brachialis 
#>                             0.6178707                             2.1758801 
#>                       Triceps Brachii                              Anconeus 
#>                             0.3240673                             2.1758801 
#>                        Pronator Teres                 Flexor Carpi Radialis 
#>                             0.2938034                             0.0000000 
#>                       Palmaris Longus                  Flexor Carpi Ulnaris 
#>                             0.0000000                             0.0000000 
#>        Flexor Digitorum Superficialis            Flexor Digitorum Profundus 
#>                             3.6935285                             0.0000000 
#>                Flexor Pollicis Longus                    Pronator Quadratus 
#>                             0.8394383                             1.9726800 
#>                       Brachioradialis        Extensor Carpi Radialis Longus 
#>                             1.7653447                             2.1758801 
#>        Extensor Carpi Radialis Brevis                    Extensor Digitorum 
#>                             0.0000000                             0.0000000 
#>                Extensor Digiti Minimi                Extensor Carpi Ulnaris 
#>                             0.0000000                             0.0000000 
#>                             Supinator              Abductor Pollicis Longus 
#>                             5.3843015                             1.4270451 
#>              Extensor Pollicis Brevis              Extensor Pollicis Longus 
#>                             0.2938034                             0.0000000 
#>                      Extensor Indicis              Abductor Pollicis Brevis 
#>                             0.0000000                             0.0000000 
#>                Flexor Pollicis Brevis                     Opponens Pollicis 
#>                             0.0000000                             0.0000000 
#>                     Adductor Pollicis                       Palmaris Brevis 
#>                             0.0000000                             0.0000000 
#>                Abductor Digiti Minimi           Flexor Digiti Minimi Brevis 
#>                             0.0000000                             0.0000000 
#>                Opponens Digiti Minimi                   Palmar Interossei 1 
#>                             0.0000000                             0.0000000 
#>                   Palmar Interossei 2                  Palmar Interossei  3 
#>                             0.0000000                             0.0000000 
#>                   Dorsal Interossei 1                   Dorsal Interossei 2 
#>                             0.0000000                             0.0000000 
#>                   Dorsal Interossei 3                   Dorsal Interossei 4 
#>                             0.0000000                             0.0000000 
#>                           Lumbrical 1                           Lumbrical 2 
#>                             0.0000000                             0.0000000 
#>                           Lumbrical 3                           Lumbrical 4 
#>                             0.0000000                             0.0000000 
#>                      Splenius Capitis                     Splenius Cervicis 
#>                             0.0000000                             0.0000000 
#>                 Iliocostalis Lumborum                 Iliocostalis Thoracis 
#>                             0.0000000                             0.0000000 
#>                 Iliocostalis Cervicis                  Longissimus Thoracis 
#>                             0.0000000                             0.0000000 
#>                  Longissimus Cervicis                   Longissimus Capitis 
#>                             0.0000000                             0.0000000 
#>                     Spinalis Thoracis                     Spinalis Cervicis 
#>                             0.0000000                             0.0000000 
#>                      Spinalis Capitis                 Semispinalis Thoracis 
#>                             0.0000000                             0.0000000 
#>                 Semispinalis Cervicis                  Semispinalis Capitis 
#>                             0.0000000                             0.0000000 
#>                            Multifidus                       Interspinalis 1 
#>                             0.0000000                             0.0000000 
#>                       Interspinalis 2                       Interspinalis 3 
#>                             0.0000000                             0.0000000 
#>                       Interspinalis 4                       Interspinalis 5 
#>                             0.0000000                             0.0000000 
#>                       Interspinalis 6                       Interspinalis 7 
#>                             0.0000000                             0.0000000 
#>                       Interspinalis 8                       Interspinalis 9 
#>                             0.0000000                             0.0000000 
#>                      Interspinalis 10                      Interspinalis 11 
#>                             0.0000000                             0.0000000 
#>                      Interspinalis 12                           Rotatores 1 
#>                             0.0000000                             0.0000000 
#>                           Rotatores 2                           Rotatores 3 
#>                             0.0000000                             0.0000000 
#>                           Rotatores 4                           Rotatores 5 
#>                             0.0000000                             0.0000000 
#>                           Rotatores 6                           Rotatores 7 
#>                             0.0000000                             0.0000000 
#>                           Rotatores 8                           Rotatores 9 
#>                             0.0000000                             0.0000000 
#>                          Rotatores 10                          Rotatores 11 
#>                             0.0000000                             0.0000000 
#>                     Intertransverse 1                     Intertransverse 2 
#>                             0.0000000                             0.0000000 
#>                     Intertransverse 3                     Intertransverse 4 
#>                             0.0000000                             0.0000000 
#>                     Intertransverse 5                     Intertransverse 6 
#>                             0.0000000                             0.0000000 
#>                     Intertransverse 7                     Intertransverse 8 
#>                             0.0000000                             0.0000000 
#>                     Intertransverse 9                    Intertransverse 10 
#>                             0.0000000                             0.0000000 
#>                    Intertransverse 11                    Intertransverse 12 
#>                             0.0000000                             0.0000000 
#>                    Intertransverse 13                    Intertransverse 14 
#>                             0.0000000                             0.0000000 
#>             Obliquus Capitis Inferior             Obliquus Capitis Superior 
#>                             0.0000000                             0.0000000 
#>        Rectus Capitis Posterior Major        Rectus Capitis Posterior Minor 
#>                             0.0000000                             0.0000000 
#>                          Longus Colli                        Longus Capitis 
#>                             0.0000000                             0.0000000 
#>               Rectus Capitis Anterior              Rectus Capitis Lateralis 
#>                             0.0000000                             0.0000000 
#>                      Anterior Scalene                       Scalene Minimus 
#>                             0.0000000                             0.0000000 
#>                        Middle Scalene                     Posterior Scalene 
#>                             0.0000000                             0.0000000 
#>                   Sternocleidomastoid                              Platysma 
#>                             0.0000000                             0.0000000 
#>                           Sternohyoid                              Omohyoid 
#>                             0.0000000                             0.0000000 
#>                         Sternothyroid                            Thryohyoid 
#>                             0.0000000                             0.0000000 
#>                            Stylohyoid                             Digastric 
#>                             0.0000000                             0.0000000 
#>                             Mylohyoid                            Geniohyoid 
#>                             0.0000000                             0.0000000 
#>                           Occipitalis                             Frontalis 
#>                             0.0000000                             0.0000000 
#>                     Orbicularis Oculi                 Corrugator Supercilii 
#>                             0.0000000                             0.0000000 
#>                      Orbicularis Oris Levator Labii Superioris Alaeque Nasi 
#>                             0.0000000                             0.0000000 
#>              Levator Labii Superioris                     Zygomaticus Minor 
#>                             0.0000000                             0.0000000 
#>                     Zygomaticus Major                   Levator Anguli Oris 
#>                             0.0000000                             0.0000000 
#>                            Buccinator                 Depressor Anguli Oris 
#>                             0.0000000                             0.0000000 
#>                              Masseter                      Medial Pterygoid 
#>                             0.0000000                             0.0000000 
#>                     Lateral Pterygoid          Levator Palpebrae Superioris 
#>                             0.0000000                             0.0000000 
#>                        Lateral Rectus                         Medial Rectus 
#>                             0.0000000                             0.0000000 
#>                       Superior Rectus                       Inferior Rectus 
#>                             0.0000000                             0.0000000 
#>                      Superior Oblique                      Inferior Oblique 
#>                             0.0000000                             0.0000000 
#>                    Tensor Fascia Lata                       Gluteus Maximus 
#>                             0.0000000                             2.6259592 
#>                        Gluteus Medius                       Gluteus Minimus 
#>                             0.8609702                             2.0232800 
#>                            Piriformis                     Superior Gemellus 
#>                             2.0232800                             2.0232800 
#>                     Inferior Gemellus                    Obturator Internus 
#>                             2.0232800                             0.8609702 
#>                     Quadratus Femoris                        Semitendinosus 
#>                             2.0232800                             0.0000000 
#>                       Semimembranosus                        Biceps Femoris 
#>                             0.0000000                             0.3013396 
#>                       Adductor Longus                       Adductor Brevis 
#>                             2.0232800                             2.0232800 
#>                       Adductor Magnus                              Gracilis 
#>                             0.8609702                             0.0000000 
#>                    Obturator Externus                             Sartorius 
#>                             2.0232800                             0.0000000 
#>                        Rectus Femoris                      Vastus Lateralis 
#>                             0.0000000                             0.8609702 
#>                    Vastus Intermedius                       Vastus Medialis 
#>                             0.8609702                             0.8609702 
#>                     Articularis Genus                           Psoas Major 
#>                             2.0232800                             3.7882690 
#>                               Iliacus                             Pectineus 
#>                             2.0232800                             2.0232800 
#>                         Gastrocnemius                                Soleus 
#>                             2.0232800                             0.0000000 
#>                             Plantaris                             Popliteus 
#>                             2.0232800                             0.8609702 
#>               Flexor Digitorum Longus                    Tibialis Posterior 
#>                             0.0000000                             0.0000000 
#>                Flexor Hallucis Longus                       Peroneus Longus 
#>                             0.0000000                             0.0000000 
#>                       Peroneus Brevis                     Tibialis Anterior 
#>                             0.0000000                             0.0000000 
#>              Extensor Hallucis Longus             Extensor Digitorum Longus 
#>                             0.0000000                             0.0000000 
#>                      Peroneus Tertius                     Abductor Hallucis 
#>                             0.0000000                             0.0000000 
#>               Flexor Digitorum Brevis                Abductor Digiti Minimi 
#>                             0.0000000                             0.0000000 
#>       Abductor Ossis Metatarsi Quinti                     Quadratus Plantae 
#>                             0.0000000                             0.0000000 
#>                           Lumbrical 1                           Lumbrical 2 
#>                             0.0000000                             0.0000000 
#>                           Lumbrical 3                           Lumbrical 4 
#>                             0.0000000                             0.0000000 
#>                Flexor Hallucis Brevis                     Adductor Hallucis 
#>                             0.0000000                             0.0000000 
#>           Flexor Digiti Minimi Brevis                  Plantar Interossei 1 
#>                             0.0000000                             0.0000000 
#>                  Plantar Interossei 2                  Plantar Interossei 3 
#>                             0.0000000                             0.0000000 
#>                   Dorsal Interossei 1                   Dorsal Interossei 2 
#>                             0.0000000                             0.0000000 
#>                   Dorsal Interossei 3                   Dorsal Interossei 4 
#>                             0.0000000                             0.0000000 
#>              Extensor Hallucis Brevis             Extensor Digitorum Brevis 
#>                             0.0000000                             0.0000000 
#>                          Cricothryoid              Posterior cricoarytenoid 
#>                             0.0000000                             0.0000000 
#>                Lateral cricoarytenoid                 Transversus arytenoid 
#>                             0.0000000                             0.0000000 
#>                               Vocalis                        Thyroarytenoid 
#>                             0.0000000                             0.0000000 
#>                     Oblique arytenoid                         Aryepiglottic 
#>                             0.0000000                             0.0000000 
#>                       Thyroepiglottic                External intercostal 1 
#>                             0.0000000                             0.0000000 
#>                External intercostal 2                External intercostal 3 
#>                             0.0000000                             0.0000000 
#>                External intercostal 4                External intercostal 5 
#>                             0.0000000                             0.0000000 
#>                External intercostal 6                External intercostal 7 
#>                             0.0000000                             0.0000000 
#>                External intercostal 8                External intercostal 9 
#>                             0.0000000                             0.0000000 
#>               External intercostal 10               External intercostal 11 
#>                             0.0000000                             0.0000000 
#>                Internal intercostal 1                Internal intercostal 2 
#>                             0.0000000                             0.0000000 
#>                Internal intercostal 3                Internal intercostal 4 
#>                             0.0000000                             0.0000000 
#>                Internal intercostal 5                Internal intercostal 6 
#>                             0.0000000                             0.0000000 
#>                Internal intercostal 7                Internal intercostal 8 
#>                             0.0000000                             0.0000000 
#>                Internal intercostal 9               Internal intercostal 10 
#>                             0.0000000                             0.0000000 
#>               Internal intercostal 11               Innermost intercostal 1 
#>                             0.0000000                             0.0000000 
#>               Innermost intercostal 2               Innermost intercostal 3 
#>                             0.0000000                             0.0000000 
#>               Innermost intercostal 4               Innermost intercostal 5 
#>                             0.0000000                             0.0000000 
#>               Innermost intercostal 6               Innermost intercostal 7 
#>                             0.0000000                             0.0000000 
#>               Innermost intercostal 8               Innermost intercostal 9 
#>                             0.0000000                             0.0000000 
#>              Innermost intercostal 10              Innermost intercostal 11 
#>                             0.0000000                             0.0000000 
#>                         Subcostalis 1                         Subcostalis 2 
#>                             0.0000000                             0.0000000 
#>                         Subcostalis 3                         Subcostalis 4 
#>                             0.0000000                             0.0000000 
#>                         Subcostalis 6                             Diaphragm 
#>                             0.0000000                             0.0000000 
#>                      External oblique                      Internal oblique 
#>                             0.0000000                             0.0000000 
#>                 Transversus abdominis                      Rectus abdominis 
#>                             0.0000000                             0.0000000 
#>                           Pyramidalis                    Quadratus lumborum 
#>                             0.0000000                             0.0000000 
#> 
#> $bone_stress
#>  Humerus   Radius    Femur 
#> 4.533092 4.109758 4.215175 
#> 
#> $muscle_stress_exposure
#>                             Trapezius                      Latissimus Dorsi 
#>                              0.000000                              4.533092 
#>           Serratus Posterior Superior           Serratus Posterior Inferior 
#>                              0.000000                              0.000000 
#>                      Levator Scapulae                        Rhomboid Minor 
#>                              0.000000                              0.000000 
#>                        Rhomboid Major                     Serratus Anterior 
#>                              0.000000                              0.000000 
#>                               Deltoid                         Supraspinatus 
#>                              4.533092                              4.533092 
#>                         Infraspinatus                           Teres Minor 
#>                              4.533092                              4.533092 
#>                           Teres Major                         Subscapularis 
#>                              4.533092                              4.533092 
#>                            Subclavius                      Pectoralis Major 
#>                              0.000000                              4.533092 
#>                      Pectoralis Minor                      Coracobrachialis 
#>                              0.000000                              4.533092 
#>                        Biceps Brachii                            Brachialis 
#>                              8.642850                              4.533092 
#>                       Triceps Brachii                              Anconeus 
#>                              4.533092                              4.533092 
#>                        Pronator Teres                 Flexor Carpi Radialis 
#>                              4.109758                              0.000000 
#>                       Palmaris Longus                  Flexor Carpi Ulnaris 
#>                              0.000000                              0.000000 
#>        Flexor Digitorum Superficialis            Flexor Digitorum Profundus 
#>                              4.109758                              0.000000 
#>                Flexor Pollicis Longus                    Pronator Quadratus 
#>                              4.109758                              4.109758 
#>                       Brachioradialis        Extensor Carpi Radialis Longus 
#>                              8.642850                              4.533092 
#>        Extensor Carpi Radialis Brevis                    Extensor Digitorum 
#>                              0.000000                              0.000000 
#>                Extensor Digiti Minimi                Extensor Carpi Ulnaris 
#>                              0.000000                              0.000000 
#>                             Supinator              Abductor Pollicis Longus 
#>                              8.642850                              4.109758 
#>              Extensor Pollicis Brevis              Extensor Pollicis Longus 
#>                              4.109758                              0.000000 
#>                      Extensor Indicis              Abductor Pollicis Brevis 
#>                              0.000000                              0.000000 
#>                Flexor Pollicis Brevis                     Opponens Pollicis 
#>                              0.000000                              0.000000 
#>                     Adductor Pollicis                       Palmaris Brevis 
#>                              0.000000                              0.000000 
#>                Abductor Digiti Minimi           Flexor Digiti Minimi Brevis 
#>                              0.000000                              0.000000 
#>                Opponens Digiti Minimi                   Palmar Interossei 1 
#>                              0.000000                              0.000000 
#>                   Palmar Interossei 2                  Palmar Interossei  3 
#>                              0.000000                              0.000000 
#>                   Dorsal Interossei 1                   Dorsal Interossei 2 
#>                              0.000000                              0.000000 
#>                   Dorsal Interossei 3                   Dorsal Interossei 4 
#>                              0.000000                              0.000000 
#>                           Lumbrical 1                           Lumbrical 2 
#>                              0.000000                              0.000000 
#>                           Lumbrical 3                           Lumbrical 4 
#>                              0.000000                              0.000000 
#>                      Splenius Capitis                     Splenius Cervicis 
#>                              0.000000                              0.000000 
#>                 Iliocostalis Lumborum                 Iliocostalis Thoracis 
#>                              0.000000                              0.000000 
#>                 Iliocostalis Cervicis                  Longissimus Thoracis 
#>                              0.000000                              0.000000 
#>                  Longissimus Cervicis                   Longissimus Capitis 
#>                              0.000000                              0.000000 
#>                     Spinalis Thoracis                     Spinalis Cervicis 
#>                              0.000000                              0.000000 
#>                      Spinalis Capitis                 Semispinalis Thoracis 
#>                              0.000000                              0.000000 
#>                 Semispinalis Cervicis                  Semispinalis Capitis 
#>                              0.000000                              0.000000 
#>                            Multifidus                       Interspinalis 1 
#>                              0.000000                              0.000000 
#>                       Interspinalis 2                       Interspinalis 3 
#>                              0.000000                              0.000000 
#>                       Interspinalis 4                       Interspinalis 5 
#>                              0.000000                              0.000000 
#>                       Interspinalis 6                       Interspinalis 7 
#>                              0.000000                              0.000000 
#>                       Interspinalis 8                       Interspinalis 9 
#>                              0.000000                              0.000000 
#>                      Interspinalis 10                      Interspinalis 11 
#>                              0.000000                              0.000000 
#>                      Interspinalis 12                           Rotatores 1 
#>                              0.000000                              0.000000 
#>                           Rotatores 2                           Rotatores 3 
#>                              0.000000                              0.000000 
#>                           Rotatores 4                           Rotatores 5 
#>                              0.000000                              0.000000 
#>                           Rotatores 6                           Rotatores 7 
#>                              0.000000                              0.000000 
#>                           Rotatores 8                           Rotatores 9 
#>                              0.000000                              0.000000 
#>                          Rotatores 10                          Rotatores 11 
#>                              0.000000                              0.000000 
#>                     Intertransverse 1                     Intertransverse 2 
#>                              0.000000                              0.000000 
#>                     Intertransverse 3                     Intertransverse 4 
#>                              0.000000                              0.000000 
#>                     Intertransverse 5                     Intertransverse 6 
#>                              0.000000                              0.000000 
#>                     Intertransverse 7                     Intertransverse 8 
#>                              0.000000                              0.000000 
#>                     Intertransverse 9                    Intertransverse 10 
#>                              0.000000                              0.000000 
#>                    Intertransverse 11                    Intertransverse 12 
#>                              0.000000                              0.000000 
#>                    Intertransverse 13                    Intertransverse 14 
#>                              0.000000                              0.000000 
#>             Obliquus Capitis Inferior             Obliquus Capitis Superior 
#>                              0.000000                              0.000000 
#>        Rectus Capitis Posterior Major        Rectus Capitis Posterior Minor 
#>                              0.000000                              0.000000 
#>                          Longus Colli                        Longus Capitis 
#>                              0.000000                              0.000000 
#>               Rectus Capitis Anterior              Rectus Capitis Lateralis 
#>                              0.000000                              0.000000 
#>                      Anterior Scalene                       Scalene Minimus 
#>                              0.000000                              0.000000 
#>                        Middle Scalene                     Posterior Scalene 
#>                              0.000000                              0.000000 
#>                   Sternocleidomastoid                              Platysma 
#>                              0.000000                              0.000000 
#>                           Sternohyoid                              Omohyoid 
#>                              0.000000                              0.000000 
#>                         Sternothyroid                            Thryohyoid 
#>                              0.000000                              0.000000 
#>                            Stylohyoid                             Digastric 
#>                              0.000000                              0.000000 
#>                             Mylohyoid                            Geniohyoid 
#>                              0.000000                              0.000000 
#>                           Occipitalis                             Frontalis 
#>                              0.000000                              0.000000 
#>                     Orbicularis Oculi                 Corrugator Supercilii 
#>                              0.000000                              0.000000 
#>                      Orbicularis Oris Levator Labii Superioris Alaeque Nasi 
#>                              0.000000                              0.000000 
#>              Levator Labii Superioris                     Zygomaticus Minor 
#>                              0.000000                              0.000000 
#>                     Zygomaticus Major                   Levator Anguli Oris 
#>                              0.000000                              0.000000 
#>                            Buccinator                 Depressor Anguli Oris 
#>                              0.000000                              0.000000 
#>                              Masseter                      Medial Pterygoid 
#>                              0.000000                              0.000000 
#>                     Lateral Pterygoid          Levator Palpebrae Superioris 
#>                              0.000000                              0.000000 
#>                        Lateral Rectus                         Medial Rectus 
#>                              0.000000                              0.000000 
#>                       Superior Rectus                       Inferior Rectus 
#>                              0.000000                              0.000000 
#>                      Superior Oblique                      Inferior Oblique 
#>                              0.000000                              0.000000 
#>                    Tensor Fascia Lata                       Gluteus Maximus 
#>                              0.000000                              4.215175 
#>                        Gluteus Medius                       Gluteus Minimus 
#>                              4.215175                              4.215175 
#>                            Piriformis                     Superior Gemellus 
#>                              4.215175                              4.215175 
#>                     Inferior Gemellus                    Obturator Internus 
#>                              4.215175                              4.215175 
#>                     Quadratus Femoris                        Semitendinosus 
#>                              4.215175                              0.000000 
#>                       Semimembranosus                        Biceps Femoris 
#>                              0.000000                              4.215175 
#>                       Adductor Longus                       Adductor Brevis 
#>                              4.215175                              4.215175 
#>                       Adductor Magnus                              Gracilis 
#>                              4.215175                              0.000000 
#>                    Obturator Externus                             Sartorius 
#>                              4.215175                              0.000000 
#>                        Rectus Femoris                      Vastus Lateralis 
#>                              0.000000                              4.215175 
#>                    Vastus Intermedius                       Vastus Medialis 
#>                              4.215175                              4.215175 
#>                     Articularis Genus                           Psoas Major 
#>                              4.215175                              4.215175 
#>                               Iliacus                             Pectineus 
#>                              4.215175                              4.215175 
#>                         Gastrocnemius                                Soleus 
#>                              4.215175                              0.000000 
#>                             Plantaris                             Popliteus 
#>                              4.215175                              4.215175 
#>               Flexor Digitorum Longus                    Tibialis Posterior 
#>                              0.000000                              0.000000 
#>                Flexor Hallucis Longus                       Peroneus Longus 
#>                              0.000000                              0.000000 
#>                       Peroneus Brevis                     Tibialis Anterior 
#>                              0.000000                              0.000000 
#>              Extensor Hallucis Longus             Extensor Digitorum Longus 
#>                              0.000000                              0.000000 
#>                      Peroneus Tertius                     Abductor Hallucis 
#>                              0.000000                              0.000000 
#>               Flexor Digitorum Brevis                Abductor Digiti Minimi 
#>                              0.000000                              0.000000 
#>       Abductor Ossis Metatarsi Quinti                     Quadratus Plantae 
#>                              0.000000                              0.000000 
#>                           Lumbrical 1                           Lumbrical 2 
#>                              0.000000                              0.000000 
#>                           Lumbrical 3                           Lumbrical 4 
#>                              0.000000                              0.000000 
#>                Flexor Hallucis Brevis                     Adductor Hallucis 
#>                              0.000000                              0.000000 
#>           Flexor Digiti Minimi Brevis                  Plantar Interossei 1 
#>                              0.000000                              0.000000 
#>                  Plantar Interossei 2                  Plantar Interossei 3 
#>                              0.000000                              0.000000 
#>                   Dorsal Interossei 1                   Dorsal Interossei 2 
#>                              0.000000                              0.000000 
#>                   Dorsal Interossei 3                   Dorsal Interossei 4 
#>                              0.000000                              0.000000 
#>              Extensor Hallucis Brevis             Extensor Digitorum Brevis 
#>                              0.000000                              0.000000 
#>                          Cricothryoid              Posterior cricoarytenoid 
#>                              0.000000                              0.000000 
#>                Lateral cricoarytenoid                 Transversus arytenoid 
#>                              0.000000                              0.000000 
#>                               Vocalis                        Thyroarytenoid 
#>                              0.000000                              0.000000 
#>                     Oblique arytenoid                         Aryepiglottic 
#>                              0.000000                              0.000000 
#>                       Thyroepiglottic                External intercostal 1 
#>                              0.000000                              0.000000 
#>                External intercostal 2                External intercostal 3 
#>                              0.000000                              0.000000 
#>                External intercostal 4                External intercostal 5 
#>                              0.000000                              0.000000 
#>                External intercostal 6                External intercostal 7 
#>                              0.000000                              0.000000 
#>                External intercostal 8                External intercostal 9 
#>                              0.000000                              0.000000 
#>               External intercostal 10               External intercostal 11 
#>                              0.000000                              0.000000 
#>                Internal intercostal 1                Internal intercostal 2 
#>                              0.000000                              0.000000 
#>                Internal intercostal 3                Internal intercostal 4 
#>                              0.000000                              0.000000 
#>                Internal intercostal 5                Internal intercostal 6 
#>                              0.000000                              0.000000 
#>                Internal intercostal 7                Internal intercostal 8 
#>                              0.000000                              0.000000 
#>                Internal intercostal 9               Internal intercostal 10 
#>                              0.000000                              0.000000 
#>               Internal intercostal 11               Innermost intercostal 1 
#>                              0.000000                              0.000000 
#>               Innermost intercostal 2               Innermost intercostal 3 
#>                              0.000000                              0.000000 
#>               Innermost intercostal 4               Innermost intercostal 5 
#>                              0.000000                              0.000000 
#>               Innermost intercostal 6               Innermost intercostal 7 
#>                              0.000000                              0.000000 
#>               Innermost intercostal 8               Innermost intercostal 9 
#>                              0.000000                              0.000000 
#>              Innermost intercostal 10              Innermost intercostal 11 
#>                              0.000000                              0.000000 
#>                         Subcostalis 1                         Subcostalis 2 
#>                              0.000000                              0.000000 
#>                         Subcostalis 3                         Subcostalis 4 
#>                              0.000000                              0.000000 
#>                         Subcostalis 6                             Diaphragm 
#>                              0.000000                              0.000000 
#>                      External oblique                      Internal oblique 
#>                              0.000000                              0.000000 
#>                 Transversus abdominis                      Rectus abdominis 
#>                              0.000000                              0.000000 
#>                           Pyramidalis                    Quadratus lumborum 
#>                              0.000000                              0.000000 
#> 
#> $ranking
#>                                    muscle vulnerability stress_exposure
#> 1                        Latissimus Dorsi       17.8237          4.5331
#> 2                        Pectoralis Major        7.8239          4.5331
#> 3                               Supinator        5.3843          8.6429
#> 4                             Psoas Major        3.7883          4.2152
#> 5          Flexor Digitorum Superficialis        3.6935          4.1098
#> 6                         Gluteus Maximus        2.6260          4.2152
#> 7                           Supraspinatus        2.1759          4.5331
#> 8                           Infraspinatus        2.1759          4.5331
#> 9                             Teres Minor        2.1759          4.5331
#> 10                            Teres Major        2.1759          4.5331
#> 11                          Subscapularis        2.1759          4.5331
#> 12                       Coracobrachialis        2.1759          4.5331
#> 13                             Brachialis        2.1759          4.5331
#> 14                               Anconeus        2.1759          4.5331
#> 15         Extensor Carpi Radialis Longus        2.1759          4.5331
#> 16                        Gluteus Minimus        2.0233          4.2152
#> 17                             Piriformis        2.0233          4.2152
#> 18                      Superior Gemellus        2.0233          4.2152
#> 19                      Inferior Gemellus        2.0233          4.2152
#> 20                      Quadratus Femoris        2.0233          4.2152
#> 21                        Adductor Longus        2.0233          4.2152
#> 22                        Adductor Brevis        2.0233          4.2152
#> 23                     Obturator Externus        2.0233          4.2152
#> 24                      Articularis Genus        2.0233          4.2152
#> 25                                Iliacus        2.0233          4.2152
#> 26                              Pectineus        2.0233          4.2152
#> 27                          Gastrocnemius        2.0233          4.2152
#> 28                              Plantaris        2.0233          4.2152
#> 29                     Pronator Quadratus        1.9727          4.1098
#> 30                        Brachioradialis        1.7653          8.6429
#> 31               Abductor Pollicis Longus        1.4270          4.1098
#> 32                         Gluteus Medius        0.8610          4.2152
#> 33                     Obturator Internus        0.8610          4.2152
#> 34                        Adductor Magnus        0.8610          4.2152
#> 35                       Vastus Lateralis        0.8610          4.2152
#> 36                     Vastus Intermedius        0.8610          4.2152
#> 37                        Vastus Medialis        0.8610          4.2152
#> 38                              Popliteus        0.8610          4.2152
#> 39                 Flexor Pollicis Longus        0.8394          4.1098
#> 40                         Biceps Brachii        0.6179          8.6429
#> 41                                Deltoid        0.3241          4.5331
#> 42                        Triceps Brachii        0.3241          4.5331
#> 43                         Biceps Femoris        0.3013          4.2152
#> 44                         Pronator Teres        0.2938          4.1098
#> 45               Extensor Pollicis Brevis        0.2938          4.1098
#> 46                              Trapezius        0.0000          0.0000
#> 47            Serratus Posterior Superior        0.0000          0.0000
#> 48            Serratus Posterior Inferior        0.0000          0.0000
#> 49                       Levator Scapulae        0.0000          0.0000
#> 50                         Rhomboid Minor        0.0000          0.0000
#> 51                         Rhomboid Major        0.0000          0.0000
#> 52                      Serratus Anterior        0.0000          0.0000
#> 53                             Subclavius        0.0000          0.0000
#> 54                       Pectoralis Minor        0.0000          0.0000
#> 55                  Flexor Carpi Radialis        0.0000          0.0000
#> 56                        Palmaris Longus        0.0000          0.0000
#> 57                   Flexor Carpi Ulnaris        0.0000          0.0000
#> 58             Flexor Digitorum Profundus        0.0000          0.0000
#> 59         Extensor Carpi Radialis Brevis        0.0000          0.0000
#> 60                     Extensor Digitorum        0.0000          0.0000
#> 61                 Extensor Digiti Minimi        0.0000          0.0000
#> 62                 Extensor Carpi Ulnaris        0.0000          0.0000
#> 63               Extensor Pollicis Longus        0.0000          0.0000
#> 64                       Extensor Indicis        0.0000          0.0000
#> 65               Abductor Pollicis Brevis        0.0000          0.0000
#> 66                 Flexor Pollicis Brevis        0.0000          0.0000
#> 67                      Opponens Pollicis        0.0000          0.0000
#> 68                      Adductor Pollicis        0.0000          0.0000
#> 69                        Palmaris Brevis        0.0000          0.0000
#> 70                 Abductor Digiti Minimi        0.0000          0.0000
#> 71            Flexor Digiti Minimi Brevis        0.0000          0.0000
#> 72                 Opponens Digiti Minimi        0.0000          0.0000
#> 73                    Palmar Interossei 1        0.0000          0.0000
#> 74                    Palmar Interossei 2        0.0000          0.0000
#> 75                   Palmar Interossei  3        0.0000          0.0000
#> 76                    Dorsal Interossei 1        0.0000          0.0000
#> 77                    Dorsal Interossei 2        0.0000          0.0000
#> 78                    Dorsal Interossei 3        0.0000          0.0000
#> 79                    Dorsal Interossei 4        0.0000          0.0000
#> 80                            Lumbrical 1        0.0000          0.0000
#> 81                            Lumbrical 2        0.0000          0.0000
#> 82                            Lumbrical 3        0.0000          0.0000
#> 83                            Lumbrical 4        0.0000          0.0000
#> 84                       Splenius Capitis        0.0000          0.0000
#> 85                      Splenius Cervicis        0.0000          0.0000
#> 86                  Iliocostalis Lumborum        0.0000          0.0000
#> 87                  Iliocostalis Thoracis        0.0000          0.0000
#> 88                  Iliocostalis Cervicis        0.0000          0.0000
#> 89                   Longissimus Thoracis        0.0000          0.0000
#> 90                   Longissimus Cervicis        0.0000          0.0000
#> 91                    Longissimus Capitis        0.0000          0.0000
#> 92                      Spinalis Thoracis        0.0000          0.0000
#> 93                      Spinalis Cervicis        0.0000          0.0000
#> 94                       Spinalis Capitis        0.0000          0.0000
#> 95                  Semispinalis Thoracis        0.0000          0.0000
#> 96                  Semispinalis Cervicis        0.0000          0.0000
#> 97                   Semispinalis Capitis        0.0000          0.0000
#> 98                             Multifidus        0.0000          0.0000
#> 99                        Interspinalis 1        0.0000          0.0000
#> 100                       Interspinalis 2        0.0000          0.0000
#> 101                       Interspinalis 3        0.0000          0.0000
#> 102                       Interspinalis 4        0.0000          0.0000
#> 103                       Interspinalis 5        0.0000          0.0000
#> 104                       Interspinalis 6        0.0000          0.0000
#> 105                       Interspinalis 7        0.0000          0.0000
#> 106                       Interspinalis 8        0.0000          0.0000
#> 107                       Interspinalis 9        0.0000          0.0000
#> 108                      Interspinalis 10        0.0000          0.0000
#> 109                      Interspinalis 11        0.0000          0.0000
#> 110                      Interspinalis 12        0.0000          0.0000
#> 111                           Rotatores 1        0.0000          0.0000
#> 112                           Rotatores 2        0.0000          0.0000
#> 113                           Rotatores 3        0.0000          0.0000
#> 114                           Rotatores 4        0.0000          0.0000
#> 115                           Rotatores 5        0.0000          0.0000
#> 116                           Rotatores 6        0.0000          0.0000
#> 117                           Rotatores 7        0.0000          0.0000
#> 118                           Rotatores 8        0.0000          0.0000
#> 119                           Rotatores 9        0.0000          0.0000
#> 120                          Rotatores 10        0.0000          0.0000
#> 121                          Rotatores 11        0.0000          0.0000
#> 122                     Intertransverse 1        0.0000          0.0000
#> 123                     Intertransverse 2        0.0000          0.0000
#> 124                     Intertransverse 3        0.0000          0.0000
#> 125                     Intertransverse 4        0.0000          0.0000
#> 126                     Intertransverse 5        0.0000          0.0000
#> 127                     Intertransverse 6        0.0000          0.0000
#> 128                     Intertransverse 7        0.0000          0.0000
#> 129                     Intertransverse 8        0.0000          0.0000
#> 130                     Intertransverse 9        0.0000          0.0000
#> 131                    Intertransverse 10        0.0000          0.0000
#> 132                    Intertransverse 11        0.0000          0.0000
#> 133                    Intertransverse 12        0.0000          0.0000
#> 134                    Intertransverse 13        0.0000          0.0000
#> 135                    Intertransverse 14        0.0000          0.0000
#> 136             Obliquus Capitis Inferior        0.0000          0.0000
#> 137             Obliquus Capitis Superior        0.0000          0.0000
#> 138        Rectus Capitis Posterior Major        0.0000          0.0000
#> 139        Rectus Capitis Posterior Minor        0.0000          0.0000
#> 140                          Longus Colli        0.0000          0.0000
#> 141                        Longus Capitis        0.0000          0.0000
#> 142               Rectus Capitis Anterior        0.0000          0.0000
#> 143              Rectus Capitis Lateralis        0.0000          0.0000
#> 144                      Anterior Scalene        0.0000          0.0000
#> 145                       Scalene Minimus        0.0000          0.0000
#> 146                        Middle Scalene        0.0000          0.0000
#> 147                     Posterior Scalene        0.0000          0.0000
#> 148                   Sternocleidomastoid        0.0000          0.0000
#> 149                              Platysma        0.0000          0.0000
#> 150                           Sternohyoid        0.0000          0.0000
#> 151                              Omohyoid        0.0000          0.0000
#> 152                         Sternothyroid        0.0000          0.0000
#> 153                            Thryohyoid        0.0000          0.0000
#> 154                            Stylohyoid        0.0000          0.0000
#> 155                             Digastric        0.0000          0.0000
#> 156                             Mylohyoid        0.0000          0.0000
#> 157                            Geniohyoid        0.0000          0.0000
#> 158                           Occipitalis        0.0000          0.0000
#> 159                             Frontalis        0.0000          0.0000
#> 160                     Orbicularis Oculi        0.0000          0.0000
#> 161                 Corrugator Supercilii        0.0000          0.0000
#> 162                      Orbicularis Oris        0.0000          0.0000
#> 163 Levator Labii Superioris Alaeque Nasi        0.0000          0.0000
#> 164              Levator Labii Superioris        0.0000          0.0000
#> 165                     Zygomaticus Minor        0.0000          0.0000
#> 166                     Zygomaticus Major        0.0000          0.0000
#> 167                   Levator Anguli Oris        0.0000          0.0000
#> 168                            Buccinator        0.0000          0.0000
#> 169                 Depressor Anguli Oris        0.0000          0.0000
#> 170                              Masseter        0.0000          0.0000
#> 171                      Medial Pterygoid        0.0000          0.0000
#> 172                     Lateral Pterygoid        0.0000          0.0000
#> 173          Levator Palpebrae Superioris        0.0000          0.0000
#> 174                        Lateral Rectus        0.0000          0.0000
#> 175                         Medial Rectus        0.0000          0.0000
#> 176                       Superior Rectus        0.0000          0.0000
#> 177                       Inferior Rectus        0.0000          0.0000
#> 178                      Superior Oblique        0.0000          0.0000
#> 179                      Inferior Oblique        0.0000          0.0000
#> 180                    Tensor Fascia Lata        0.0000          0.0000
#> 181                        Semitendinosus        0.0000          0.0000
#> 182                       Semimembranosus        0.0000          0.0000
#> 183                              Gracilis        0.0000          0.0000
#> 184                             Sartorius        0.0000          0.0000
#> 185                        Rectus Femoris        0.0000          0.0000
#> 186                                Soleus        0.0000          0.0000
#> 187               Flexor Digitorum Longus        0.0000          0.0000
#> 188                    Tibialis Posterior        0.0000          0.0000
#> 189                Flexor Hallucis Longus        0.0000          0.0000
#> 190                       Peroneus Longus        0.0000          0.0000
#> 191                       Peroneus Brevis        0.0000          0.0000
#> 192                     Tibialis Anterior        0.0000          0.0000
#> 193              Extensor Hallucis Longus        0.0000          0.0000
#> 194             Extensor Digitorum Longus        0.0000          0.0000
#> 195                      Peroneus Tertius        0.0000          0.0000
#> 196                     Abductor Hallucis        0.0000          0.0000
#> 197               Flexor Digitorum Brevis        0.0000          0.0000
#> 198                Abductor Digiti Minimi        0.0000          0.0000
#> 199       Abductor Ossis Metatarsi Quinti        0.0000          0.0000
#> 200                     Quadratus Plantae        0.0000          0.0000
#> 201                           Lumbrical 1        0.0000          0.0000
#> 202                           Lumbrical 2        0.0000          0.0000
#> 203                           Lumbrical 3        0.0000          0.0000
#> 204                           Lumbrical 4        0.0000          0.0000
#> 205                Flexor Hallucis Brevis        0.0000          0.0000
#> 206                     Adductor Hallucis        0.0000          0.0000
#> 207           Flexor Digiti Minimi Brevis        0.0000          0.0000
#> 208                  Plantar Interossei 1        0.0000          0.0000
#> 209                  Plantar Interossei 2        0.0000          0.0000
#> 210                  Plantar Interossei 3        0.0000          0.0000
#> 211                   Dorsal Interossei 1        0.0000          0.0000
#> 212                   Dorsal Interossei 2        0.0000          0.0000
#> 213                   Dorsal Interossei 3        0.0000          0.0000
#> 214                   Dorsal Interossei 4        0.0000          0.0000
#> 215              Extensor Hallucis Brevis        0.0000          0.0000
#> 216             Extensor Digitorum Brevis        0.0000          0.0000
#> 217                          Cricothryoid        0.0000          0.0000
#> 218              Posterior cricoarytenoid        0.0000          0.0000
#> 219                Lateral cricoarytenoid        0.0000          0.0000
#> 220                 Transversus arytenoid        0.0000          0.0000
#> 221                               Vocalis        0.0000          0.0000
#> 222                        Thyroarytenoid        0.0000          0.0000
#> 223                     Oblique arytenoid        0.0000          0.0000
#> 224                         Aryepiglottic        0.0000          0.0000
#> 225                       Thyroepiglottic        0.0000          0.0000
#> 226                External intercostal 1        0.0000          0.0000
#> 227                External intercostal 2        0.0000          0.0000
#> 228                External intercostal 3        0.0000          0.0000
#> 229                External intercostal 4        0.0000          0.0000
#> 230                External intercostal 5        0.0000          0.0000
#> 231                External intercostal 6        0.0000          0.0000
#> 232                External intercostal 7        0.0000          0.0000
#> 233                External intercostal 8        0.0000          0.0000
#> 234                External intercostal 9        0.0000          0.0000
#> 235               External intercostal 10        0.0000          0.0000
#> 236               External intercostal 11        0.0000          0.0000
#> 237                Internal intercostal 1        0.0000          0.0000
#> 238                Internal intercostal 2        0.0000          0.0000
#> 239                Internal intercostal 3        0.0000          0.0000
#> 240                Internal intercostal 4        0.0000          0.0000
#> 241                Internal intercostal 5        0.0000          0.0000
#> 242                Internal intercostal 6        0.0000          0.0000
#> 243                Internal intercostal 7        0.0000          0.0000
#> 244                Internal intercostal 8        0.0000          0.0000
#> 245                Internal intercostal 9        0.0000          0.0000
#> 246               Internal intercostal 10        0.0000          0.0000
#> 247               Internal intercostal 11        0.0000          0.0000
#> 248               Innermost intercostal 1        0.0000          0.0000
#> 249               Innermost intercostal 2        0.0000          0.0000
#> 250               Innermost intercostal 3        0.0000          0.0000
#> 251               Innermost intercostal 4        0.0000          0.0000
#> 252               Innermost intercostal 5        0.0000          0.0000
#> 253               Innermost intercostal 6        0.0000          0.0000
#> 254               Innermost intercostal 7        0.0000          0.0000
#> 255               Innermost intercostal 8        0.0000          0.0000
#> 256               Innermost intercostal 9        0.0000          0.0000
#> 257              Innermost intercostal 10        0.0000          0.0000
#> 258              Innermost intercostal 11        0.0000          0.0000
#> 259                         Subcostalis 1        0.0000          0.0000
#> 260                         Subcostalis 2        0.0000          0.0000
#> 261                         Subcostalis 3        0.0000          0.0000
#> 262                         Subcostalis 4        0.0000          0.0000
#> 263                         Subcostalis 6        0.0000          0.0000
#> 264                             Diaphragm        0.0000          0.0000
#> 265                      External oblique        0.0000          0.0000
#> 266                      Internal oblique        0.0000          0.0000
#> 267                 Transversus abdominis        0.0000          0.0000
#> 268                      Rectus abdominis        0.0000          0.0000
#> 269                           Pyramidalis        0.0000          0.0000
#> 270                    Quadratus lumborum        0.0000          0.0000
#>     impact_deviation
#> 1             3.9319
#> 2             1.7260
#> 3             0.6230
#> 4             0.8987
#> 5             0.8987
#> 6             0.6230
#> 7            -0.4800
#> 8            -0.4800
#> 9            -0.4800
#> 10           -0.4800
#> 11           -0.4800
#> 12           -0.4800
#> 13           -0.4800
#> 14           -0.4800
#> 15           -0.4800
#> 16           -0.4800
#> 17           -0.4800
#> 18           -0.4800
#> 19           -0.4800
#> 20           -0.4800
#> 21           -0.4800
#> 22           -0.4800
#> 23           -0.4800
#> 24           -0.4800
#> 25           -0.4800
#> 26           -0.4800
#> 27           -0.4800
#> 28           -0.4800
#> 29           -0.4800
#> 30           -0.2043
#> 31            0.3472
#> 32           -0.2043
#> 33           -0.2043
#> 34           -0.2043
#> 35           -0.2043
#> 36           -0.2043
#> 37           -0.2043
#> 38           -0.2043
#> 39           -0.2043
#> 40            0.0715
#> 41            0.0715
#> 42            0.0715
#> 43            0.0715
#> 44            0.0715
#> 45            0.0715
#> 46            5.8621
#> 47            0.8987
#> 48            1.1745
#> 49            0.3472
#> 50            0.0715
#> 51            0.3472
#> 52            1.4502
#> 53           -0.4800
#> 54            0.0715
#> 55            0.0715
#> 56            0.0715
#> 57            0.3472
#> 58            0.6230
#> 59            0.0715
#> 60            1.7260
#> 61            0.0715
#> 62            0.0715
#> 63            0.0715
#> 64            0.3472
#> 65           -0.2043
#> 66           -0.2043
#> 67           -0.2043
#> 68            0.8987
#> 69           -0.4800
#> 70           -0.4800
#> 71           -0.2043
#> 72           -0.2043
#> 73           -0.2043
#> 74           -0.2043
#> 75           -0.2043
#> 76            0.0715
#> 77            0.0715
#> 78            0.0715
#> 79            0.0715
#> 80           -0.4800
#> 81           -0.4800
#> 82           -0.4800
#> 83           -0.4800
#> 84            2.0017
#> 85            0.6230
#> 86            3.3804
#> 87            2.2774
#> 88            1.4502
#> 89            7.2408
#> 90            1.7260
#> 91            1.4502
#> 92            3.3804
#> 93            0.3472
#> 94            1.1745
#> 95            2.5532
#> 96            2.2774
#> 97            2.0017
#> 98            5.5864
#> 99           -0.4800
#> 100          -0.4800
#> 101          -0.4800
#> 102          -0.4800
#> 103          -0.4800
#> 104          -0.4800
#> 105          -0.4800
#> 106          -0.4800
#> 107          -0.4800
#> 108          -0.4800
#> 109          -0.4800
#> 110          -0.4800
#> 111          -0.4800
#> 112          -0.4800
#> 113          -0.4800
#> 114          -0.4800
#> 115          -0.4800
#> 116          -0.4800
#> 117          -0.4800
#> 118          -0.4800
#> 119          -0.4800
#> 120          -0.4800
#> 121          -0.4800
#> 122          -0.4800
#> 123          -0.4800
#> 124          -0.4800
#> 125          -0.4800
#> 126          -0.4800
#> 127          -0.4800
#> 128          -0.4800
#> 129          -0.4800
#> 130          -0.4800
#> 131          -0.4800
#> 132          -0.4800
#> 133          -0.4800
#> 134          -0.4800
#> 135          -0.4800
#> 136          -0.4800
#> 137          -0.4800
#> 138          -0.4800
#> 139          -0.4800
#> 140           0.8987
#> 141           0.3472
#> 142          -0.4800
#> 143          -0.4800
#> 144           0.3472
#> 145          -0.2043
#> 146           1.1745
#> 147          -0.2043
#> 148          -0.2043
#> 149          -0.4800
#> 150          -0.2043
#> 151          -0.2043
#> 152          -0.4800
#> 153          -0.4800
#> 154          -0.4800
#> 155          -0.2043
#> 156          -0.4800
#> 157          -0.4800
#> 158          -0.2043
#> 159          -0.4800
#> 160           0.0715
#> 161          -0.4800
#> 162          -0.2043
#> 163          -0.2043
#> 164          -0.4800
#> 165          -0.4800
#> 166          -0.4800
#> 167          -0.4800
#> 168           0.0715
#> 169          -0.4800
#> 170          -0.2043
#> 171           0.0715
#> 172          -0.4800
#> 173          -0.2043
#> 174          -0.2043
#> 175          -0.2043
#> 176          -0.2043
#> 177          -0.2043
#> 178          -0.4800
#> 179          -0.4800
#> 180          -0.4800
#> 181          -0.2043
#> 182          -0.4800
#> 183          -0.2043
#> 184          -0.2043
#> 185          -0.2043
#> 186          -0.2043
#> 187           0.6230
#> 188           2.2774
#> 189           0.0715
#> 190           0.6230
#> 191          -0.4800
#> 192           0.8987
#> 193           0.3472
#> 194           2.2774
#> 195          -0.4800
#> 196           0.0715
#> 197           0.6230
#> 198          -0.2043
#> 199          -0.4800
#> 200          -0.4800
#> 201          -0.2043
#> 202          -0.2043
#> 203          -0.2043
#> 204          -0.2043
#> 205          -0.2043
#> 206           0.0715
#> 207          -0.4800
#> 208          -0.4800
#> 209          -0.4800
#> 210          -0.4800
#> 211          -0.2043
#> 212          -0.2043
#> 213          -0.2043
#> 214          -0.2043
#> 215          -0.4800
#> 216           0.8987
#> 217          -0.4800
#> 218          -0.4800
#> 219          -0.4800
#> 220          -0.7557
#> 221          -0.4800
#> 222          -0.4800
#> 223          -0.7557
#> 224          -0.4800
#> 225          -0.4800
#> 226          -0.4800
#> 227          -0.4800
#> 228          -0.4800
#> 229          -0.4800
#> 230          -0.4800
#> 231          -0.4800
#> 232          -0.4800
#> 233          -0.4800
#> 234          -0.4800
#> 235          -0.4800
#> 236          -0.4800
#> 237          -0.4800
#> 238          -0.4800
#> 239          -0.4800
#> 240          -0.4800
#> 241          -0.4800
#> 242          -0.4800
#> 243          -0.4800
#> 244          -0.4800
#> 245          -0.4800
#> 246          -0.4800
#> 247          -0.4800
#> 248          -0.4800
#> 249          -0.4800
#> 250          -0.4800
#> 251          -0.4800
#> 252          -0.4800
#> 253          -0.4800
#> 254          -0.4800
#> 255          -0.4800
#> 256          -0.4800
#> 257          -0.4800
#> 258          -0.4800
#> 259          -0.4800
#> 260          -0.4800
#> 261          -0.4800
#> 262          -0.4800
#> 263          -0.4800
#> 264           1.7260
#> 265           2.0017
#> 266           0.8987
#> 267           1.7260
#> 268           0.3472
#> 269          -0.4800
#> 270           0.8987
#> 
```
