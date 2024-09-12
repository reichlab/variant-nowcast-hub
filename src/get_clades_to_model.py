"""Stub file for testing github action."""


def main():
    clade_list = ["A", "B", "C"]
    clade_file = "src/2024-09-01.txt"
    with open(clade_file, "w") as f:
        for clade in clade_list:
            f.write(f"{clade}\n")
        f.write("other\n")


if __name__ == "__main__":
    main()
