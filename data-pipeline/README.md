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

Before setting up the project:

- Your machine will need to have an installed version of Python that meets the `requires-python` constraint in [pyproject.toml](pyproject.toml)
- That version of Python should be set as your current Python interpreter (if you don't already have a preferred Python workflow, [pyenv](https://github.com/pyenv/pyenv) is good tool for managing Python versions on your local machine).

In addition, if you're planning to make code changes that require adding or removing project dependencies, you'll need `pip-tools` installed on your machine. ([`pipx`](https://github.com/pypa/pipx) is a handy way to install python packages in a way that makes them available all the time, regardless of whatever virtual environment is currently activated.)


**Setup**

Follow the directions below to set this project up on your local machine.

1. Clone this repository and change into the project's data-pipeline directory:

    ```bash
    cd variant-nowcast-hub/data-pipeline
    ```

2. Create a Python virtual environment:

    ```bash
    python -m venv .venv
    ```

    **Note:** the resulting virtual environment will use whatever Python interpreter was active when you ran the command

3. Activate the virtual environment:

    ```bash
    source .venv/bin/activate
    ```

    **Note:** the command above is for Unix-based systems. If you're using Windows, the command is:

    ```bash
    .venv\Scripts\activate
    ```

4. Install the project dependencies. The following commands can also be used to update dependencies after pulling upstream code changes:

    ```bash
    # if you're planning to run the scripts without making code changes
    pip install -r requirements/requirements.txt && pip install -e .

    # if you're planning to make and submit code changes
    pip install -r requirements/dev-requirements.txt && pip install -e .
    ```

### Running the test suite

If you've installed the dev requirements and want to run the unit tests:

```bash
pytest -k unit
```

To run the full test suite, including an integration test that runs the pipeline end-to-end:

```bash
pytest
```

### Adding new dependencies

This project uses [`pip-tools`](https://github.com/jazzband/pip-tools) to generate requirements files from `pyproject.toml`.
To install `pip-tools`, run the following after activating your virtual environment:

3. Activate the virtual environment:

    ```bash
    source .venv/bin/activate
    ```

    **Note:** the command above is for Unix-based systems. If you're using Windows, the command is:

    ```bash
    .venv\Scripts\activate
    ```

4. Install the project dependencies. The following commands can also be used to update dependencies after pulling upstream code changes:

    ```bash
    # if you're planning to run the scripts without making code changes
    pip install -r requirements/dev-requirements.txt && pip install -e .

    # if you're planning to make and submit code changes
    pip install -r requirements/dev-requirements.txt && pip install -e .
    ```

### Adding new dependencies

This project uses [`pip-tools`](https://github.com/jazzband/pip-tools) to generate requirements files from `pyproject.toml`.

To add a new dependency:

1. Add dependency to the `dependencies` section `pyproject.toml` (if it's a dev dependency,
add it to the `dev` section of `[project.optional-dependencies]`).

2. Regenerate the `requirements.txt` file (if you've only added a dev dependency, you can skip this step)
    ```bash
    pip-compile -o requirements/requirements.txt pyproject.toml
    ```

3. Regenerate the `requirements-dev.txt` file (even if you haven't added a dev dependency):
    ```bash
    pip-compile --extra dev -o requirements/dev-requirements.txt pyproject.toml
    ```

## Running the code

Set up the project as described above and make sure the virtual environment is activated.

1. From anywhere in the repo's `data-pipeline` directory:

    ```bash
    assign_clades
    ```
