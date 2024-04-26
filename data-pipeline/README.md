# (WIP) COVID Variant Pipeline

## Background

The goal of this Python module is to codify some of the experimentation we're doing to generate data for the upcoming COVID-19 Variant Nowcast hub: https://reichlab.atlassian.net/wiki/spaces/RLD/pages/22020097/Variant+data

This is _not_ production code. The purpose of the code is to help us see if the following approach is a viable way to point-in-time clade assignments for SARS-CoV-2 Genbank sequence data (to use for model scoring):

1. Get genome sequences from genbank
2. Get a reference tree (using S3 versioning to access tree data at specific points in time)
3. Use the above two items as input to the nextclade cli, which will assign clades to the sequences

We're working with small amounts of data so we can iterate quickly.


## Setup

If you'd like to try it out, this section has the setup instructions.

**Prerequisites**

The setup instructions below use [PDM](https://pdm-project.org/) to install Python, manage a Python virtual environment, and manage dependencies. However, PDM is only absolutely necessary for managing dependencies (because the lockfile is in PDM format), so other tools for Python installs and environments will work as well.

To install PDM: https://pdm-project.org/en/latest/#installation

**Setup**

Follow the directions below to set this project up on your local machine.

1. Clone this repository and change into the project's data-pipeline directory:

    ```bash
    cd variant-nowcast-hub/data-pipeline
    ```

2. Make sure you have a version of Python installed that meets the `requires-python` constraint in [pyproject.toml](pyproject.toml).

    **Note:** if you don't have Python installed, PDM can install it for you: `pdm python install 3.12.2`
3. Install the project dependencies (this will also create a virtual environment):

    ```bash
    pdm install
    ```

To sync project dependencies after pulling upstream code changes:

```bash
pdm sync
```

## Running the code

Set up the project as described above and make sure the virtual environment is activated.

1. From the repo's root, navigate to the directory that contains the `assign_clades.py` script::

```bash
cd data-pipeline/src/covid_variant_pipeline
```

2. Run the script:

```bash
python assign_clades.py
```