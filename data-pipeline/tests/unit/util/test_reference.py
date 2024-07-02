from unittest import mock

import pytest
from covid_variant_pipeline.util.reference import get_reference_data
from requests import Response


@pytest.fixture
def get_nextclade_response():
    def _get_nextclade_response():
        return {
            "tree": "cladesandstuff",
            "meta": {"updated": "2021-09-01"},
            "root_sequence": {"nuc": "fastasequence"},
        }

    return _get_nextclade_response


@pytest.fixture
def get_nextclade_response_no_root():
    def _get_nextclade_response_no_root():
        return {
            "tree": "cladesandstuff",
            "meta": {"updated": "2021-09-01"},
        }

    return _get_nextclade_response_no_root


@mock.patch("requests.get")
def test_get_reference_data(mock_get, get_nextclade_response):
    mock_response = Response()
    mock_response.status_code = 200
    mock_response.json = get_nextclade_response
    mock_get.return_value = mock_response

    reference = get_reference_data("www.fakenextclade.com", "2021-09-01")

    assert reference["tree"] == "cladesandstuff"
    assert reference["meta"]["updated"] == "2021-09-01"
    assert "fastasequence" in reference["root_sequence"]


@mock.patch("requests.get")
def test_missing_root_sequence(mock_get, get_nextclade_response_no_root, capsys):
    mock_response = Response()
    mock_response.status_code = 200
    mock_response.json = get_nextclade_response_no_root
    mock_get.return_value = mock_response

    with pytest.raises(SystemExit):
        get_reference_data("www.fakenextclade.com", "2021-09-01")
    out, err = capsys.readouterr()
    assert "no root sequence" in out
    assert "2021-09-01" in out
