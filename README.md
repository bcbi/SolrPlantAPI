# SolrPlantAPI

Web-accessible (REST) service for Identification and resolution of plant taxonomic names

## Prerequisites

* Julia 1.0
* Python
  * NLTK `pip install nltk`
  * NLTK resources 
    ```
    import nltk
    nltk.download('punkt')
    nltk.download('conll2000')
    ```
  * TEXTBLOB `pip install blob`


### Installing/Running locally

* Clone this repository
* Install Julia dependencies (within Julia REPL)
```
  julia install_julia_pkgs
```
* Run `julia chemgrab_api.jl`


### Sample queries to BCBI's server 

* `http://bcbi.brown.edu/solrplant_api/?plantname=Arabidopsis%20thaliana`

### WebAccess

You may also access this tool though our [website](http://bcbi.brown.edu/solrplant)
