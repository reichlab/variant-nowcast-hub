# Variant Nowcast Hub Scripts

The `src/` directory contains scripts that support this hub's operations. The scripts are designed to be run by scheduled
GitHub workflows on a Linux-based runner (_i.e._, they have not been tested in a Windows environment).

The sections below contain information about the scripts and how to run them manually.

## Generating list of clades to model

`get_clades_to_model.py` generates a list of clades to model for the hub's upcoming round (the first Wednesday following
the run date). The script writes the clade list and accompanying metadata to `auxiliary-data/modeled-clades/[round_id].txt`.

To run the script manually:

1. Make sure that `uv` is installed on your machine:

    ```bash
    brew install uv
    ```

    (see [`uv` documentation](https://docs.astral.sh/uv/getting-started/installation/#installing-uv) for a full list of installation options)

2. From the root of the repo, run the following command:

    ```bash
    uv run src/get_clades_to_model.py
    ```

## Adding a new modeling round to the hub

`make_round_config.R` reads in the most recent clade list (see above) and uses it to generate a new modeling round, which is
then appended to the hub's existing `hub-config/tasks.json` file.

To run the script manually (RStudio users):

1. Make sure that `renv` is installed on your machine.
2. Open `src/make_round_config.R` in RStudio _OR_ open the `src/variant-nowcast-hub.Rproj` project in RStudio.
3. If prompted by `renv` that some of the packages in `renv.lock` are not installed:

    ```r
    renv::restore()
    ```
4. Run the make_round_config script:

    ```r
    source("make_round_config.R")
    ```


To run the script manually (without RStudio):

1. Make sure that `renv` is installed on your machine.
2. Open an R session and set the working directory to the repo's `src` directory.
3. Make sure that the required packages are installed:

    ```r
    renv::restore()
    ```
4. Run the make_round_config script:

    ```r
     source("make_round_config.R")
    ```


