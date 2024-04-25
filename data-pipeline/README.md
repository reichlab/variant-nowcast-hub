# (WIP) COVID Variant Pipeline

**Setup**

Follow the directions below to set this project up on your local machine.

1. Clone this repository and change into the project directory.
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