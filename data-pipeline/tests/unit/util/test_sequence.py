from collections import Counter

import polars as pl
import pytest
from covid_variant_pipeline.util.sequence import parse_sequence_assignments


@pytest.fixture
def df_assignments():
    return pl.DataFrame(
        {
            "seqName": [
                "PP782799.1 Severe acute respiratory syndrome coronavirus 2 isolate SARS-CoV-2/human/USA/NY-PV74597/2022",
                "ABCDEFG Severe caffeine deprivation virus",
                "12345678 ",
            ],
            "clade": ["BA.5.2.1", "XX.99.88.77", "howdy"],
        }
    )


def test_parse_sequence_assignments(df_assignments):
    result = parse_sequence_assignments(df_assignments)

    # resulting dataframe should have an additional column called "seq"
    assert Counter(result.columns) == Counter(["seqName", "clade", "seq"])

    # check resulting sequence numbers
    assert Counter(result["seq"].to_list()) == Counter(["PP782799.1", "ABCDEFG", "12345678"])


def test_parse_sequence_duplicates(df_assignments):
    df_duplicates = pl.concat([df_assignments, df_assignments])

    with pytest.raises(ValueError):
        parse_sequence_assignments(df_duplicates)
