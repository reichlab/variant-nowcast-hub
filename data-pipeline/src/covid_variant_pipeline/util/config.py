from dataclasses import InitVar, asdict, dataclass
from datetime import datetime
from importlib import resources
from pprint import pprint

from cloudpathlib import AnyPath


@dataclass
class Config:
    data_path_root: InitVar[AnyPath]
    sequence_released_date: InitVar[datetime]
    reference_tree_as_of_date: InitVar[datetime]
    sequence_released_since_date: str = None
    reference_tree_date: str = None
    now = datetime.now()
    run_time = now.strftime("%Y%m%dT%H%M%S")
    module_path: AnyPath = AnyPath(resources.files("covid_variant_pipeline"))
    executable_path: AnyPath = module_path / "bin"
    ncbi_base_url: str = "https://api.ncbi.nlm.nih.gov/datasets/v2alpha/virus/genome/download"
    ncbi_sequence_file: AnyPath = None
    ncbi_sequence_metadata_file: AnyPath = None
    nextclade_base_url: str = "https://nextstrain.org/nextclade/sars-cov-2"
    nextclade_package_name: str = "ncbi.zip"
    reference_tree_file: AnyPath = None
    root_sequence_file: AnyPath = None
    assignment_no_metadata_file: AnyPath = None
    assignment_file: AnyPath = None

    def __post_init__(self, data_path_root, sequence_released_date, reference_tree_as_of_date):
        self.data_path = data_path_root / self.run_time
        self.sequence_released_since_date = sequence_released_date.strftime("%Y-%m-%d")
        self.reference_tree_date = reference_tree_as_of_date.strftime("%Y-%m-%d")
        self.ncbi_sequence_file = self.data_path / "ncbi_dataset/data/genomic.fna"
        self.ncbi_sequence_metadata_file = self.data_path / f"{self.sequence_released_since_date}-metadata.tsv"
        self.reference_tree_file = self.data_path / f"{self.reference_tree_date}_tree.json"
        self.root_sequence_file = self.data_path / f"{self.reference_tree_date}_root_sequence.fasta"
        self.assignment_no_metadata_file = (
            self.data_path / f"{self.sequence_released_since_date}_clade_assignments_no_metadata.csv"
        )
        self.assignment_file = self.data_path / f"{self.sequence_released_since_date}_clade_assignments.csv"

    def __repr__(self):
        return str(pprint(asdict(self)))
