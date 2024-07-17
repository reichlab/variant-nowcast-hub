##########################################################################################
# MacOS M-series chip users:
# To accommodate the Nextclade CLI binary, add this option to the build command:
# --platform=linux/amd64
##########################################################################################

# Pulling the nextclade image to grab the CLI binary is kind of overkill, but it's
# an easy way to control the version we're using.
# TODO: fix up the reference tree/root sequence so we can use a newer version
FROM nextstrain/nextclade:3.3.1

FROM python:3.12-slim-bookworm
COPY --from=0 /usr/bin/nextclade /opt/src/covid_variant_pipeline/bin/

# create a user to run the pipeline
ARG USERNAME=pipeline-user
ARG USER_UID=2222
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME
RUN chown -R pipeline-user:pipeline-user /opt/

ENV PYTHONPATH "${PYTHONPATH}:/opt/"

# Install the dataformat CLI tool
WORKDIR /opt/src/covid_variant_pipeline/bin/
ADD https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/dataformat ./dataformat
RUN chmod +x ./dataformat
ENV PATH "${PATH}:/opt/src/covid_variant_pipeline/bin/"

# Install Python dependencies
WORKDIR /opt/
RUN pip install --upgrade pip
RUN pip install uv

COPY pyproject.toml .
COPY requirements/ ./requirements/
# if sufficiently motivated, we could be clever enough to keep the image size down by
# only installing the dev requirements and test scripts during CI/CD builds
RUN uv pip install --system -r ./requirements/requirements-dev.txt --no-cache-dir
RUN uv pip install --system -e .

# Override polars install to use Polars version compatible with legacy CPUs
# TODO: consider removing the Polars dependency altogether?
RUN pip uninstall polars -y
RUN uv pip install --system polars-lts-cpu --no-cache-dir

USER $USERNAME

COPY src/covid_variant_pipeline/ ./src/covid_variant_pipeline/
COPY tests/ ./tests/

ENTRYPOINT ["assign_clades"]
