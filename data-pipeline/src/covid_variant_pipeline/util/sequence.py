import json
import time
from datetime import datetime, timedelta

import polars as pl
import requests
import structlog

logger = structlog.get_logger()


def get_covid_genome_data(
    base_url: str = "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/virus/genome/download",
    released_since_date: str = None,
    filename: str = "ncbi.zip",
) -> dict:
    """Download genome data package from NCBI."""

    if not released_since_date:
        released_since_date = (datetime.now() - timedelta(weeks=2)).strftime(("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z")

    headers = {
        "Accept": "application/zip",
        "Accept-Encoding": "br, deflate, gzip, zstd",
    }

    # TODO: add session retries
    session = requests.Session()
    session.headers.update(headers)

    request_body = {
        "released_since": released_since_date,
        "taxon": "SARS-CoV-2",
        "refseq_only": False,
        "annotated_only": False,
        "host": "Homo sapiens",
        "complete_only": False,
        "table_fields": ["unspecified"],
        "include_sequence": ["GENOME"],
        "aux_report": ["DATASET_REPORT"],
        "format": "tsv",
        "use_psg": False,
    }

    logger.info("NCBI API call starting", released_since_date=released_since_date)

    start = time.perf_counter()
    response = session.post(base_url, data=json.dumps(request_body), stream=True)

    if not response.ok:
        logger.error(
            "Failed to download genome package",
            status_code=response.status_code,
            request=response.request.url,
            request_body=request_body,
        )

    with open(filename, "wb") as f:
        # we can tweak the chunk_size after getting a better idea of where this will run
        for chunk in response.iter_content(chunk_size=524288):
            f.write(chunk)

    end = time.perf_counter()
    elapsed = end - start

    logger.info("NCBI API call completed", elapsed=elapsed)


def parse_sequence_assignments(df_assignments: pl.DataFrame) -> pl.DataFrame:
    """Parse out the sequence number from the seqName column returned by the clade assignment tool."""

    # polars apparently can't split out the sequence number from that big name column
    # without resorting an apply, so here we're dropping into pandas to do that
    # (might be a premature optimization, since this manoever requires both pandas and pyarrow)
    seq = pl.from_pandas(df_assignments.to_pandas()["seqName"].str.split(" ").str[0].rename("seq"))

    # we're expecting one row per sequence
    if seq.n_unique() != df_assignments.shape[0]:
        raise ValueError("Clade assignment data contains duplicate sequence. Stopping assignment process.")

    # add the parsed sequence number as a new column
    df_assignments = df_assignments.insert_column(1, seq)

    return df_assignments
