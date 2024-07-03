import datetime

import click
from click.testing import CliRunner
from covid_variant_pipeline.assign_clades import main


# test below runs the entire pipeline
def test_main(tmp_path):
    today = datetime.date.today()
    test_date = today - datetime.timedelta(days=5)

    runner = CliRunner()
    with runner.isolated_filesystem(temp_dir=tmp_path):
        result = runner.invoke(
            main,
            [
                "--sequence-released-since-date",
                str(test_date),
                "--reference-tree-date",
                str(test_date),
                "--data-dir",
                tmp_path,
            ],
            catch_exceptions=True,
            color=True,
            standalone_mode=False
        )
        assert result.exit_code == 0


def test_main_bad_date(tmp_path):
    today = datetime.date.today()
    test_date = today - datetime.timedelta(days=5)

    runner = CliRunner()
    with runner.isolated_filesystem(temp_dir=tmp_path):
        result = runner.invoke(
            main,
            [
                "--sequence-released-since-date",
                str(test_date),
                "--reference-tree-date",
                "5/1/2024",
                "--data-dir",
                tmp_path,
            ],
            standalone_mode=False
        )
        assert isinstance(result.exception, click.exceptions.BadParameter)
