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
RUN uv pip install --system -r ./requirements/requirements.txt --no-cache-dir
RUN uv pip install --system -e .

# Override polars install to use Polars version compatible with legacy CPUs
# TODO: consider removing the Polars dependency altogether?
RUN pip uninstall polars -y
RUN uv pip install --system polars-lts-cpu --no-cache-dir

USER $USERNAME

WORKDIR /opt/src/covid_variant_pipeline/
COPY src/covid_variant_pipeline/ .

ENTRYPOINT ["assign_clades"]
