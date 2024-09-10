# Generating list of clades to model (WIP)

Follow the steps below to generate a list of clades to model for a specific round_id. The output will be 
a list of clades that is written to `auxiliary-data/modeled-clades/[round_id].txt`.

1. Make sure that `uv` is installed on your machine:

    ```bash
    brew install uv
    ```

    (see [`uv` documentation](https://docs.astral.sh/uv/getting-started/installation/#installing-uv) for a full list of installation options)

2. From the root of the repo, run the following command:

    ```bash
    uv run src/get_clades_to_model.py
    ```

**TODO:** per the related [GitHub issue](https://github.com/reichlab/variant-nowcast-hub/issues/26), we want to generate a PR with the newly generated list of clades.