import datetime

import pytest
from click.testing import CliRunner
from covid_variant_pipeline.assign_clades import main


# test below runs the entire pipeline
def test_main(tmp_path):
    today = datetime.date.today()
    test_date = today - datetime.timedelta(days=-5)

    runner = CliRunner()
    with runner.isolated_filesystem(temp_dir=tmp_path):
        result = runner.invoke(main, ["--as-of-date", str(test_date)])
        assert result.exit_code == 0


def test_main_bad_date(tmp_path):
    runner = CliRunner()
    with pytest.raises(Exception):
        with runner.isolated_filesystem(temp_dir=tmp_path):
            result = runner.invoke(main, ["--as-of-date", "5/1/2024"])
            assert result.exit_code == 0
