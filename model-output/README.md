# Model outputs folder

This folder contains a set of subdirectories, one for each model, that contains submitted model output files for that model. The structure of these directories and their contents follows [the model output guidelines in our documentation](https://hubverse.io/en/latest/user-guide/model-output.html). Documentation for hub submissions specifically is provided below. 

# Data submission instructions

All model output files should be submitted directly to a team's subdirectory
within the the [model-output/](./)
folder. Data in this directory should be added to the repository through
a pull request so that automatic data validation checks are run.

These instructions provide detail about the [data
format](#Data-formatting) as well as [validation](#Forecast-validation) that
you can do prior to this pull request. In addition, we describe
[metadata](https://github.com/Infectious-Disease-Modeling-Hubs/hubTemplate/blob/master/model-metadata/README.md)
that each model should provide in the model-metadata folder.

*Table of Contents*

-   [Model output details](#Model-output-details)
-   [Submission file format](#Submission-file-format)
-   [Data formatting](#Data-formatting)
-   [Model output validation](#Model-output-validation)
-   [Weekly ensemble build](#Weekly-ensemble-build)
-   [Policy on late submissions](#policy-on-late-or-updated-submissions)


## Model output details
This hub follows [hubverse](https://hubverse.io/) data standards. Submissions must include either mean outputs, or sample-based model outputs. If sample-based model outputs are submitted and means are not, modelers should assume that these samples may be used to compute a mean prediction which may be scored. 

We use the term “model task” below to refer to a prediction for a specific clade, location and target date. For example, if mean model outputs are submitted, there will be one value between 0 and 1 for each model task. The submitted values for all clades must sum to 1 (within +/- 0.001) for a given location and target date.
As we will describe in further detail below, the target for prediction is the proportion of circulating viral genomes for a given location and target date amongst infected individuals that are sequenced for SARS-CoV-2.

To submit probabilistic predictions, a [sample format](https://hubverse.io/en/latest/user-guide/sample-output-type.html) is used to encode samples from the predictive distribution for each model task. The hub requires exactly 100 samples for each model task. One key advantage to submitting sample-based output is that dependence can be encoded across horizons (corresponding to trajectories of variant prevalence over time), or even across locations (see details in [Hubverse sample model-output specifications](https://hubverse.io/en/latest/user-guide/sample-output-type.html#compound-modeling-tasks)). For this hub, we require that samples be submitted in such a way as to imply that they are structured into trajectories across clades and horizons. (See following section for how variants are classified into clade categories.) In particular, a common sample ID will be used in multiple rows of the submission file with different combinations of clade and target date. This means that 

1. at each location and target date a common sample ID (in the `ouput_type_id` column) ensures that the clade proportions sum to 1, and
2. for each location and clade, common sample IDs across `target_date` values allows us to draw trajectories by clade.

This specification corresponds to a hubverse-style "compound modeling task" that includes the following fields: `nowcast_date`, `location`. Samples then capture dependence across the complementary set of task ids: `target_date`, `clade`.

We note that sample IDs present in the `output_type_id` column of submissions are not necessarily inherent properties of how the samples are generated, as they can be changed post-hoc by a modeler. For example, some models may make nowcasts independently by target date but the samples could be tied together either randomly or via some other correlation structure or secondary model to assign sample IDs that are consistent across target dates. As another example, some models may make forecasts that have joint dependence structure across locations as well as target dates. Sample IDs can be shared across locations as well, but this is not required for the submission to pass validation.

To be included in the hub ensemble model, samples must be submitted and the mean forecast for the hub ensemble will be obtained as a summary of sample predictions.

## Submission file format

Submissions must be submitted as `.parquet` files and must follow a specific tabular data format. Every submission file must contain the following columns

 - `nowcast_date`: the date of the Wednesday submission deadline, in `YYYY-MM-DD` format.
 - `target_date`: the date that a specific nowcast prediction is made for, in `YYYY-MM-DD` format.
 - `location`: the two-letter abbreviation for a US state, including DC and PR for Washington DC and Puerto Rico.
 - `clade`: the label for a Nextstrain clade (or "other"), as defined on a per-round basis in [these files](https://github.com/reichlab/variant-nowcast-hub/tree/main/auxiliary-data/modeled-clades).
 - `output_type`: the type of output represented by this row, one of either `mean` or `sample`.
 - `output_type_id`: either `NA` for `mean` rows or, for `sample` rows, an alphanumeric sample ID value that links together rows from the same predictive sample from the model.
 - `value`: the predicted proportion (between 0 and 1 inclusive) for the combination of `target_date`, `location` and `clade`.
 
Here are a few example rows, showing `mean` values for ten unique modeling tasks (a modeling task is a unique combination of `location`, `target_date` and `clade`):

| `nowcast_date` | `target_date` | `location` | `clade`   | `output_type` | `output_type_id` | `value` |
|----------------|---------------|------------|-------------|---------------|------------------|---------|
| 2024-09-25     | 2024-09-23    | MA         | 24A         | mean          | NA               | 0.1     |
| 2024-09-25     | 2024-09-23    | MA         | 24B         | mean          | NA               | 0.2     |
| 2024-09-25     | 2024-09-23    | MA         | 24C         | mean          | NA               | 0.05    |
| 2024-09-25     | 2024-09-23    | MA         | recombinant | mean          | NA               | 0.6     |
| 2024-09-25     | 2024-09-23    | MA         | other       | mean          | NA               | 0.05    |
| 2024-09-25     | 2024-09-24    | MA         | 24A         | mean          | NA               | 0.12    |
| 2024-09-25     | 2024-09-24    | MA         | 24B         | mean          | NA               | 0.18    |
| 2024-09-25     | 2024-09-24    | MA         | 24C         | mean          | NA               | 0.02    |
| 2024-09-25     | 2024-09-24    | MA         | recombinant | mean          | NA               | 0.6     |
| 2024-09-25     | 2024-09-24    | MA         | other       | mean          | NA               | 0.08    |

Here are a few example rows, showing two predictive samples for ten unique modeling tasks. The samples that share the same value in the `output_type_id` column are assumed to be drawn from the same predictive sample from the model:

| `nowcast_date` | `target_date` | `location` | `clade`   | `output_type` | `output_type_id` | `value` |
|----------------|---------------|------------|-------------|---------------|------------------|---------|
| 2024-09-25     | 2024-09-23    | MA         | 24A         | sample        | MA00             | 0.1     |
| 2024-09-25     | 2024-09-23    | MA         | 24B         | sample        | MA00             | 0.2     |
| 2024-09-25     | 2024-09-23    | MA         | 24C         | sample        | MA00             | 0.05    |
| 2024-09-25     | 2024-09-23    | MA         | recombinant | sample        | MA00             | 0.6     |
| 2024-09-25     | 2024-09-23    | MA         | other       | sample        | MA00             | 0.05    |
| 2024-09-25     | 2024-09-24    | MA         | 24A         | sample        | MA00             | 0.12    |
| 2024-09-25     | 2024-09-24    | MA         | 24B         | sample        | MA00             | 0.18    |
| 2024-09-25     | 2024-09-24    | MA         | 24C         | sample        | MA00             | 0.02    |
| 2024-09-25     | 2024-09-24    | MA         | recombinant | sample        | MA00             | 0.6     |
| 2024-09-25     | 2024-09-24    | MA         | other       | sample        | MA00             | 0.08    |
| 2024-09-25     | 2024-09-23    | MA         | 24A         | sample        | MA01             | 0.1     |
| 2024-09-25     | 2024-09-23    | MA         | 24B         | sample        | MA01             | 0.2     |
| 2024-09-25     | 2024-09-23    | MA         | 24C         | sample        | MA01             | 0.05    |
| 2024-09-25     | 2024-09-23    | MA         | recombinant | sample        | MA01             | 0.6     |
| 2024-09-25     | 2024-09-23    | MA         | other       | sample        | MA01             | 0.05    |
| 2024-09-25     | 2024-09-24    | MA         | 24A         | sample        | MA01             | 0.12    |
| 2024-09-25     | 2024-09-24    | MA         | 24B         | sample        | MA01             | 0.18    |
| 2024-09-25     | 2024-09-24    | MA         | 24C         | sample        | MA01             | 0.02    |
| 2024-09-25     | 2024-09-24    | MA         | recombinant | sample        | MA01             | 0.6     |
| 2024-09-25     | 2024-09-24    | MA         | other       | sample        | MA01             | 0.08    |



## Data formatting 

The automatic checks in place for forecast files submitted to this
repository validates both the filename and file contents to ensure the
file can be used in the visualization and ensemble forecasting.

### Subdirectory

Each model that submits forecasts for this project will have a unique subdirectory within the [model-output/](model-output/) directory in this GitHub repository where forecasts will be submitted. Each subdirectory must be named

    team-model

where

-   `team` is the `team_abbr` field from the model metadata file and
-   `model` is the `model_abbr` field from the model matadata file.

Both team and model should be less than 15 characters and not include
hyphens or other special characters, with the exception of "\_".

The combination of `team` and `model` should be unique from any other model in the project.


### Metadata

The metadata file will be saved within the model-metdata directory in the Hub's GitHub repository, and should have the following naming convention:


      team-model.yml

Details on the content and formatting of metadata files are provided in the [model-metadata README](https://github.com/Infectious-Disease-Modeling-Hubs/hubTemplate/blob/master/model-metadata/README.md).




### Submission files

Each submission file should have the following
format

    YYYY-MM-DD-team-model.csv

where

-   `YYYY` is the 4 digit year,
-   `MM` is the 2 digit month,
-   `DD` is the 2 digit day,
-   `team` is the `team_abbr`, and
-   `model` is the `model_abbr`.

The date YYYY-MM-DD is the [`nowcast_date`](#nowcast_date). This should be the Wednesday submission deadline for each round.

The `team` and `model` in this file must match the `team` and `model` in
the directory this file is in. 


## Forecast validation 

To ensure proper data formatting, pull requests for new data in
`model-output/` will be automatically run. Optionally, you may also run these validations locally.

### Pull request forecast validation

When a pull request is submitted, the data are validated through [Github
Actions](https://docs.github.com/en/actions) which runs the tests
present in [the hubValidations
package](https://github.com/Infectious-Disease-Modeling-Hubs/hubValidations). The
intent for these tests are to validate the requirements above. Please
[let us know]( https://github.com/reichlab/variant-nowcast-hub/issues/new) if you are facing issues while running the tests.


## Weekly ensemble build 

Every Wednesday evening, we will generate an ensemble using valid submissions in the current week by the deadline. Some or all participant forecasts may be combined into an ensemble forecast to be published in real-time along with the participant forecasts. In addition, some or all forecasts may be displayed alongside the output of a baseline model for comparison.


## Policy on late or updated submissions 

In order to ensure that forecasting is done in real-time, all forecasts are required to be submitted to this repository by Wednesday at 8pm ET each week. We do not accept late forecasts.
