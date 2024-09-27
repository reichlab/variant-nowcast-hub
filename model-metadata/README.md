# Model metadata

This folder contains metadata files for the models submitting to the  *SARS-CoV-2 Variant Nowcast Hub*. The specification for these files has been adapted to be consistent with [model metadata guidelines in the hubverse documentation](https://hubdocs.readthedocs.io/en/latest/user-guide/model-metadata.html).

Each model is required to have metadata in 
[yaml format](https://docs.ansible.com/ansible/latest/reference_appendices/YAMLSyntax.html).

These instructions provide details about the [data
format](#Data-format) as well as [validation](#Data-validation) that
you can do prior to a pull request with a metadata file.

# Data format

## Required fields

This section describes each of the variables (keys) in the yaml document.
Please order the variables in this order.

### team_name
The name of your team that no more than 50 characters long.

### team_abbr
An abbreviation of your team name that is up to 16 characters long, consisting entirely of alphanumeric characters or underscores, with no other characters allowed.

### model_name
The name of your model that no more than 50 characters long.

### model_abbr
An abbreviation of your model name that is up to 16 characters long, consisting entirely of alphanumeric characters or underscores, with no other characters allowed.

### model_contributors

A list of all individuals involved in the submission of this model.
A name, affiliation, and email address is required for each contributor. Individuals may also include an optional orcid identifier.

The syntax of this field should be 
```
model_contributors: [
  {
    "name": "Modeler Name 1",
    "affiliation": "Institution Name 1",
    "email": "modeler1@example.com",
    "orcid": "1234-1234-1234-1234"
  },
  {
    "name": "Modeler Name 2",
    "affiliation": "Institution Name 2",
    "email": "modeler2@example.com",
    "orcid": "1234-1234-1234-1234"
  }
]
```

### license

One of the [accepted licenses](https://github.com/reichlab/variant-nowcast-hub/blob/main/hub-config/model-metadata-schema.json#L72).

We encourage teams to submit as a "cc-by-4.0" to allow the broadest possible uses including uses such as private vaccine production (which would be excluded by the "cc-by-nc-4.0" license). 

### team_funding 

A list of funding source(s) for the team or members of the team, including any specific acknowledgment that would be natural to include in a publication. For example, "National Institutes of General Medical Sciences (R01GM123456). The content is solely the responsibility of the authors and does not necessarily represent the official views of NIGMS." If no funding supported the modeling effort, then just an acknowledgment such as "No funding declared." should be included.

### methods

A summary of the methods used by this model (5000 character limit). Among other information, this should include details about the joint dependence structure of the model, and across what variables the model draws joint distributions, e.g., across horizons but not horizons and locations.

### methods_url

A link to a complete write-up of the model specification, with mathematical details. This could be a peer-reviewed article, preprint, or an unpublished PDF or webpage stored at a public url somewhere.

### data_sources

List or description of data inputs used by the model. For example:  NextStrain, GISAID for sequences outside of the U.S., wastewater variant proportions, etc...

### ensemble_of_models

A boolean value (`true` or `false`) that indicates whether a model is an ensemble of any separate component models.

### ensemble_of_hub_models

A boolean value (`true` or `false`) that indicates whether a model is an ensemble specifically of other models submited to this hub.

## Optional fields

### model_version
An identifier of the version of the model

### website_url

A url to a website that has additional data about your model. 
We encourage teams to submit the most user-friendly version of your 
model, e.g. a dashboard, or similar, that displays your model forecasts. 

### repo_url

A github (or similar) repository url containing code for the model. 

### citation

One or more citations to manuscripts or preprints with additional model details. For example, "Gibson GC , Reich NG , Sheldon D. Real-time mechanistic bayesian forecasts of COVID-19 mortality. medRxiv. 2020. https://doi.org/10.1101/2020.12.22.20248736".


# Data validation

Optionally, you may validate a model metadata file locally before submitting it to the hub in a pull request. Note that this is not required, since the validations will also run on the pull request. To run the validations locally, follow these steps:

1. Create a fork of the `*[insert hub name]*` repository and then clone the fork to your computer.
2. Create a draft of the model metadata file for your model and place it in the `model-metadata` folder of this clone.
3. Install the hubValidations package for R by running the following command from within an R session:
``` r
remotes::install_github("Infectious-Disease-Modeling-Hubs/hubValidations")
```
4. Validate your draft metadata file by running the following command in an R session:
``` r
hubValidations::validate_model_metadata(
    hub_path="<path to your clone of the hub repository>",
    file_path="<name of your metadata file>")
```

For example, if your working directory is the root of the hub repository, you can use a command similar to the following:
``` r
hubValidations::validate_model_metadata(hub_path=".", file_path="UMass-trends_ensemble.yml")
```

If all is well, you should see output similar to the following:
```
✔ model-metadata-schema.json: File exists at path hub-config/model-metadata-schema.json.
✔ UMass-trends_ensemble.yml: File exists at path model-metadata/UMass-trends_ensemble.yml.
✔ UMass-trends_ensemble.yml: Metadata file extension is "yml" or "yaml".
✔ UMass-trends_ensemble.yml: Metadata file directory name matches "model-metadata".
✔ UMass-trends_ensemble.yml: Metadata file contents are consistent with schema specifications.
✔ UMass-trends_ensemble.yml: Metadata file name matches the `model_id` specified within the metadata file.
```

If there are any errors, you will see a message describing the problem.
