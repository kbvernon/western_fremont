# western_fremont

<!-- badges: start -->

<!-- badges: end -->

This repository contains the data and code for our paper:

> Kenneth B. Vernon
> [![](https://orcid.org/sites/default/files/images/orcid_16x16.png)](https://orcid.org/0000-0003-0098-5092),
> Weston McCool
> [![](https://orcid.org/sites/default/files/images/orcid_16x16.png)](https://orcid.org/0000-0003-3190-470X),
> Peter M. Yaworsky
> [![](https://orcid.org/sites/default/files/images/orcid_16x16.png)](https://orcid.org/0000-0002-4620-9569),
> Jerry D. Spangler
> [![](https://orcid.org/sites/default/files/images/orcid_16x16.png)](https://orcid.org/0000-0002-0316-310X),
> Simon Brewer
> [![](https://orcid.org/sites/default/files/images/orcid_16x16.png)](https://orcid.org/0000-0002-6810-1911),
> and Brian F. Codding
> [![](https://orcid.org/sites/default/files/images/orcid_16x16.png)](https://orcid.org/0000-0001-7977-8568)
> (2024). The Fremont Frontier: Living at the Margins of Maize Farming.
> *American Antiquity*.

**Preprint**: [manuscript.pdf](/manuscript/manuscript.pdf)\
**Supplement**:
[analysis.html](https://kbvernon.github.io/western-fremont/R/analysis.html)

## Contents

📂 [\_extensions](/_extensions) has Quarto extension for compiling manuscript\
📂 [data](/data) required for reproducing analysis and figures\
  ⊢ 💾 [villages.csv](data/villages.csv)\
  ⊢ 🌎 western-fremont.gpkg is a GeoPackage database with all necessary data\
  ⊢ 📈 elevation-everything.csv is the coefficient table for the elevation
model\
  ⊢ 📈 western-fremont-model.Rds is the final model\
📂 [figures](/figures) contains all figures included in the paper\
📂 [manuscript](/manuscript) contains the pre-print\
  ⊢ 📄 [manuscript.qmd](/manuscript/manuscript.qmd)\
  ⊢ 📄 [manuscript.pdf](/manuscript/manuscript.pdf)\
📂 [R](/R) code for preparing data and conducting analysis, including\
  ⊢ 📄 [analysis.qmd](/R/analysis.qmd) is the primary analysis,\
  ⊢ 📄 [cost-distance.R](/R/cost-distance.R),\
  ⊢ 📄 [data-wrangling.R](/R/data-wrangling.R),\
  ⊢ 📄 [paleocar.R](/R/paleocar.R),\
  ⊢ 📄 [prism.R](/R/prism.R),\
  ⊢ 📄 [regression-table.R](/R/regression-table.R), and\
  ⊢ various scripts with helper functions

## 🌎 How to Rebuild GeoPackage Database

All scripts for conducting analysis and generating figures assume that the data
can be found in a GeoPackage database called `data/western-fremont.gpkg`.
Unfortunately, a GeoPackage is not amenable to git integration, so we have to
store it somewhere else, in this case Zenodo. Assuming you're in the
`western_fremont` project folder, the following should be sufficient to get a
local copy of the database:

``` r
library(here)

here("R", "rebuild-geopackage-database.R") |> source()
```

Maybe, anyway, I haven't actually tested this... 😰🤞

## 📈 Replicate analysis

Once you have the GeoPackage built, the code to replicate the analysis and
generate the figures is this:

``` r
library(quarto)

# needs to be run in this order
here("R", "fig-elevation-tradeoffs.R") |> source()
here("R", "fig-overview-maps.R") |> source()
here("R", "analysis.qmd") |> quarto_render()

# if you have a hankerin' to compile the manuscript (I mean, why stop now?)
# you can do that like so:
here("manuscript", "manuscript.qmd") |> quarto_render()
```

## License

**Text and figures:** [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/)

**Code:** [MIT](LICENSE.md)

**Data:** [CC-0](http://creativecommons.org/publicdomain/zero/1.0/) attribution
requested in reuse.
