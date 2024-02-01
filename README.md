
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
> (2023). The Fremont Frontier: Living at the Margins of Maize Farming.
> *American Antiquity*.

**Preprint**: [manuscript.pdf](/manuscript/manuscript.pdf)  
**Supplement**: [analysis.html](https://kbvernon.github.io/western-fremont/R/analysis.html)  

## Contents  

📂 [_extensions](/_extensions) has Quarto extension for compiling manuscript  
📂 [data](/data) required for reproducing analysis and figures  
&emsp;&emsp;&RightTee; 💾 [villages.csv](data/villages.csv)  
&emsp;&emsp;&RightTee; 🌎 western-fremont.gpkg is a GeoPackage database with all necessary data  
&emsp;&emsp;&RightTee; 📈 elevation-everything.csv is the coefficient table for the elevation model  
&emsp;&emsp;&RightTee; 📈 western-fremont-model.Rds is the final model  
📂 [figures](/figures) contains all figures included in the paper  
📂 [manuscript](/manuscript) contains the pre-print  
&emsp;&emsp;&RightTee; 📄 [manuscript.qmd](/manuscript/manuscript.qmd)  
&emsp;&emsp;&RightTee; 📄 [manuscript.pdf](/manuscript/manuscript.pdf)  
📂 [R](/R) code for preparing data and conducting analysis, including  
&emsp;&emsp;&RightTee; 📄 [analysis.qmd](/R/analysis.qmd) is the primary analysis,  
&emsp;&emsp;&RightTee; 📄 [cost-distance.R](/R/cost-distance.R),  
&emsp;&emsp;&RightTee; 📄 [data-wrangling.R](/R/data-wrangling.R),  
&emsp;&emsp;&RightTee; 📄 [paleocar.R](/R/paleocar.R),  
&emsp;&emsp;&RightTee; 📄 [prism.R](/R/prism.R),  
&emsp;&emsp;&RightTee; 📄 [regression-table.R](/R/regression-table.R), and  
&emsp;&emsp;&RightTee; various scripts with helper functions  

## 🌎 How to Rebuild GeoPackage Database  

All scripts for conducting analysis and generating figures assume that
the data can be found in a GeoPackage database called
`data/western-fremont.gpkg`. Unfortunately, a GeoPackage is not amenable
to git integration, so we have to store it somewhere else, in this case
Zenodo. Assuming you're in the `western-fremont` project folder, the following
is sufficient to get a local copy of the database:  

```
download.file(
  url = "https://zenodo.org/record/<record-id-here>/western-fremont.gpkg?download=1", 
  destfile = "./data/western-fremont.gpkg", 
  mode = "wb"
)
```

## License  

**Text and figures:** [CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/)

**Code:** [MIT](LICENSE.md)

**Data:** [CC-0](http://creativecommons.org/publicdomain/zero/1.0/)
attribution requested in reuse.
