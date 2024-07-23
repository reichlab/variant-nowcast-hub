from itertools import product
import pandas as pd
import numpy as np

df = pd.DataFrame.from_records(
    list(
        product(
            ["2024-01-26"],
            [
                "2024-01-05",
                "2024-01-12",
                "2024-01-19",
                "2024-01-26",
                "2024-02-03",
                "2024-02-10",
            ],
            np.arange(50).astype("str"),
            np.arange(30).astype("str"),
            ["sample"],
            np.arange(500),
        )
    )
)
df["value"] = np.random.standard_normal(df.shape[0])

df.columns = [
    "nowcast_date",
    "target_date",
    "location",
    "variant",
    "output_type",
    "output_type_id",
    "value",
]
df.to_parquet("example3.parquet")

df = pd.DataFrame.from_records(
    list(
        product(
            [
                "2024-01-05",
                "2024-01-12",
                "2024-01-19",
                "2024-01-26",
                "2024-02-03",
                "2024-02-10",
            ],
            np.arange(50).astype("str"),
            np.arange(30).astype("str"),
            ["sample"],
            np.arange(500),
        )
    )
)
df["value"] = np.random.standard_normal(df.shape[0])

df.columns = [
    "target_date",
    "location",
    "variant",
    "output_type",
    "output_type_id",
    "value",
]
df.to_parquet("example3a.parquet")


df.to_csv("example2.csv")
