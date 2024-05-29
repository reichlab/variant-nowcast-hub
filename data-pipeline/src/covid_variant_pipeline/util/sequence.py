import json
import time

import polars as pl
import requests
import structlog
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

logger = structlog.get_logger()


def get_covid_genome_data(
    released_since_date: str,
    base_url: str = "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/virus/genome/download",
    filename: str = "ncbi.zip",
):
    """Download genome data package from NCBI."""

    headers = {
        "Accept": "application/zip",
        "Accept-Encoding": "br, deflate, gzip, zstd",
    }

    session = requests.Session()
    # attach a urllib3 retry adapter to the requests session
    # https://urllib3.readthedocs.io/en/latest/reference/urllib3.util.html#urllib3.util.retry.Retry
    retries = Retry(
        total=5,
        allowed_methods=frozenset(["GET", "POST"]),
        backoff_factor=1,
        status_forcelist=[401, 403, 404, 429, 500, 502, 503, 504],
    )
    session.mount("https://", HTTPAdapter(max_retries=retries))
    session.headers.update(headers)

    # TODO: this might be a better as an item in the forthcoming config file
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
    response = session.post(base_url, data=json.dumps(request_body), stream=True, timeout=(10, 300))

    if not response.ok:
        # If the session retries the max number of times, the app will throw an error before we get here.
        # So if we're here, it's because the post request failed on an HTTP status not on the above status_forcelist.
        logger.error(
            "Failed to download genome package",
            status_code=response.status_code,
            response_text=response.text,
            request=response.request.url,
            request_body=request_body,
        )
        # Exit the pipeline without displaying a traceback
        raise SystemExit(f"Unsuccessful call to NCBI API: {response.status_code}: {response.reason}")

    # TODO: Am still seeing intermittent errors: ChunkedEncodingError(ProtocolError('Response ended prematurely')
    with open(filename, "wb") as f:
        for chunk in response.iter_content(chunk_size=262144):
            if chunk:
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
