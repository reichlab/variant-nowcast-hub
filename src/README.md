# For Hub Admins: Variant Nowcast Hub Scripts and Workflows

> [!IMPORTANT]
> **The `src/` directory contains scripts used by hub administrators** and automated jobs.
> Hub participants and modelers: turn back now. There is nothing for you here but misery.

## Table of contents

  - [Scripts](#scripts)
  - [GitHub workflows](#workflows)

## Scripts

Details of the scripts in this folder can be found below. All of them assume that your working directory is the `src/`
directory. To ensure stability:

- R scripts manage their dependencies with [the renv R package](https://rstudio.github.io/renv/).
  The `variant-hub-admin.Rproj` file allows you to open the `src/` folder as an independent R project from
  the root of this hub.
- Python scripts are run via `uv` commands that create transient virtual environments based on the dependencies in
  [`requirements.txt`](requirements.txt).

The scripts are designed to be run by scheduled GitHub workflows on a Linux-based runner
(_i.e._, they have not been tested in a Windows environment).

The sections below contain information about the scripts and how to run them manually.

### Generating list of clades to model

`get_clades_to_model.py` generates a list of clades to model for the hub's upcoming round (the first Wednesday following
the run date). The script writes the clade list and accompanying metadata to `auxiliary-data/modeled-clades/[round_id].json`.

To run the script manually:

1. Make sure that `uv` is installed on your machine:

    ```bash
    brew install uv
    ```

    (see [`uv` documentation](https://docs.astral.sh/uv/getting-started/installation/#installing-uv)
    for a full list of installation options)

2. From the root of the repo, run the following command:

    ```bash
    uv run --with-requirements src/requirements.txt src/get_clades_to_model.py
    ```

### Adding a new modeling round to the hub

`make_round_config.R` reads in the most recent clade list (see above) and uses it to generate a new modeling round,
which is then appended to the hub's existing `hub-config/tasks.json` file.

To run the script manually (RStudio users):

1. Open `src/make_round_config.R` in RStudio _OR_ open the `src/variant-nowcast-hub.Rproj` project in RStudio.
2. If prompted by `renv` that some of the packages in `renv.lock` are not installed:

    ```r
    renv::restore()
    ```

3. Run the make_round_config script:

    ```r
    source("make_round_config.R")
    ```

To run the script manually (without RStudio):

1. Open an R session and set the working directory to the repo's `src` directory.
2. If prompted by `renv` that some packages in `renv.lock` are not installed:

    ```r
    renv::restore()
    ```

3. Run the make_round_config script:

    ```r
     source("make_round_config.R")
    ```

### Post round-submission scripts

After a modeling round closes for submissions (Wednesdays at 8 PM US Eastern),
the [`run-post-submission-jobs.yaml` GitHub workflow](https://github.com/reichlab/variant-nowcast-hub/blob/main/.github/workflows/run-post-submission-jobs.yaml) runs two of the scripts in this directory.

#### get_location_date_counts.py

For each location used by this hub, `get_location_date_counts.py` generates a daily count of
Sars-Cov-2 genome sequences collected.
The output includes counts for each of the 31 days prior to the latest round's nowcast date (_i.e._, the round_id)
This script writes its output to `auxiliary-data/unscored-location-dates/[round_id].csv`.

To run the script manually:

1. Make sure that `uv` is installed on your machine:

    ```bash
    brew install uv
    ```

    (see [`uv` documentation](https://docs.astral.sh/uv/getting-started/installation/#installing-uv)
    for a full list of installation options)

2. From the root of the repo, run the following command:

    ```bash
    uv run --with-requirements src/requirements.txt src/get_location_date_counts.py
    ```

#### get_target_data.py

`get_target_data.py` generates a sets of oracle output and timeseries target
data. This script is actually a small command line interface (CLI), with
options as follows:

```sh
➜ uv run --with-requirements src/requirements.txt python src/get_target_data.py --help
Usage: get_target_data.py [OPTIONS]

Options:
  --nowcast-date [%Y-%m-%d]       The modeling round nowcast date (i.e.,
                                  round_id) (YYYY-MM-DD). [required]
  --sequence-as-of [%Y-%m-%d]     Get counts based on the last available
                                  Nextstrain sequence metadata on or prior to
                                  this UTC date (YYYY-MM-DD). Default is the
                                  nowcast date + 90 days.
  --tree-as-of [%Y-%m-%d]         Use this UTC date to retrieve the reference
                                  tree used for clade assignment (YYYY-MM-DD).
                                  Defaults to created_at in the rounds
                                  modeled-clades file.
  --collection-min-date [%Y-%m-%d]
                                  Assign clades to sequences collected on or
                                  after this UTC date (YYYY-MM-DD). Default is
                                  the nowcast date minus 90 days.
  --collection-max-date [%Y-%m-%d]
                                  Assign clades to sequences collected on or
                                  before this UTC date (YYYY-MM-DD), Default
                                  is the nowcast date plus 10 days.
  --target-data-dir TEXT          Path object to the directory where the
```

To run the script manually:

1. Make sure that `uv` is installed on your machine:

    ```bash
    brew install uv
    ```

    (see [`uv` documentation](https://docs.astral.sh/uv/getting-started/installation/#installing-uv)
    for a full list of installation options)

2. From the root of the repo, run the following command:

    ```bash
    uv run --with-requirements src/requirements.txt src/get_target_data.py --nowcast-date=2024-10-09
    ```

## Workflows

Many of the scripts in `variant-nowcast-hub/src` are run via scheduled
[GitHub workflows](https://docs.github.com/en/actions/about-github-actions/understanding-github-actions#workflows),
usually when a new round is ready to open or when a round closes for submissions.

Per GitHub standards, the workflow definitions are `.yaml` files stored in this repo's
[`.github/workflows/`](https://github.com/reichlab/variant-nowcast-hub/tree/main/.github/workflows) directory. The
information below maps workflows to scripts in `src/` and describes how to re-run them if needed.[^1]

### create-modeling-round.yaml

The [`create-modeling-round.yaml` workflow](https://github.com/reichlab/variant-nowcast-hub/blob/main/.github/workflows/create-modeling-round.yaml)
generates the data required to open a new modeling round and opens a corresponding PR.

- Scheduled to run on Mondays at 3 AM UTC
- Runs the following scripts:

    - [`get_clades_to_model.py`](https://github.com/reichlab/variant-nowcast-hub/blob/main/src/get_clades_to_model.py)
    - [`make_round_config.R`](https://github.com/reichlab/variant-nowcast-hub/blob/main/src/make_round_config.R)
- Re-running:

    - The round_id used by this workflow is calculated as the Wednesday following the run date.
    - Therefore, it can be safely re-run on the Monday or Tuesday of the current round.

### run-post-submission-jobs.yaml

The [`run-post-submission-jobs.yaml` workflow](https://github.com/reichlab/variant-nowcast-hub/blob/main/.github/workflows/run-post-submission-jobs.yaml)
runs after submissions close for a round. It generates updated target-data and unscored-location-dates
files for the specified round and opens a corresponding PR.

- Scheduled to run on Thursdays at 12:20 or 1:20 AM UTC (depending on the month; best we could do to accommodate DST)
- Runs the following scripts:

    - [`get_location_date_counts.py`](https://github.com/reichlab/variant-nowcast-hub/blob/main/src/get_location_date_counts.py)
    - [`get_target_data.py`](https://github.com/reichlab/variant-nowcast-hub/blob/main/src/get_target_data.py)
- Re-running:

    - This workflow can be re-run manually for any past round_id.
    - If a round_id is not specified, it will use the latest round as determined by the date
      of the most recent Wednesday.

> [!NOTE]
> More information about the target data process can be found in the [target-data README](../target-data/README.md).

[^1]: Not all workflows are listed here. Many of them are generic Hubverse actions and are documented in
[`hubverse-actions`](https://github.com/hubverse-org/hubverse-actions).
