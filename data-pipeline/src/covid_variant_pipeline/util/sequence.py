"""Functions for retrieving and parsing SARS-CoV-2 virus genome data."""

import json
import time

import polars as pl
import structlog
from covid_variant_pipeline.util.session import check_response, get_session

logger = structlog.get_logger()


def get_covid_genome_data(
    released_since_date: str,
    base_url: str,
    filename: str
):
    """Download genome data package from NCBI."""
    headers = {
        "Accept": "application/zip",
    }
    session = get_session()
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
    response = session.post(base_url, data=json.dumps(request_body), timeout=(300, 300))
    check_response(response)

    # Originally tried saving the NCBI package via a stream call and iter_content (to prevent potential
    # memory issues that can arise when download large files). However, ran into an intermittent error:
    # ChunkedEncodingError(ProtocolError('Response ended prematurely').
    # We may need to revisit this at some point, depending on how much data we place to request via the
    # API and what kind of machine the pipeline will run on.
    with open(filename, "wb") as f:
        f.write(response.content)

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
