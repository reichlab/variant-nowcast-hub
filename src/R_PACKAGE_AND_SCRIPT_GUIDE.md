# Adding R Scripts and Managing Packages in `src/`

**Purpose**: Guide for variant-nowcast-hub administrators on adding R scripts and managing R package dependencies using `renv`.

**Related Issue**: #291

---

## Overview

The `src/` directory uses `renv` for R package management, ensuring reproducible environments across different machines and contributors. All R scripts in `src/` share the same package library defined in `src/renv.lock`.

**Key files**:
- `src/.Rprofile` - Activates renv when R starts in this directory
- `src/renv.lock` - Lockfile specifying exact package versions
- `src/renv/` - renv infrastructure (auto-managed)
- `src/variant-nowcast-hub.Rproj` - RStudio project file

---

## Part 1: Adding a New R Script to `src/`

### Step 1: Create the Script

Create your R script in the `src/` directory:

```r
# src/my_new_script.R

#' Brief description of what this script does
#'
#' More detailed description if needed. Explain:
#' - What inputs it expects
#' - What outputs it generates
#' - When/how it should be run

# Load required packages
require(dplyr)
require(arrow)
require(hubData)

# Set working directory using here package
here::i_am("src/my_new_script.R")

# Your script logic here
# ...
```

### Step 2: Follow Coding Conventions

**Package loading**:
```r
# Use require() for all package dependencies
require(dplyr)
require(arrow)

# For packages with specific functions, you can also use ::
hubData::connect_hub(...)
```

**Working directory**:
```r
# Always set the working directory with here::i_am()
here::i_am("src/my_new_script.R")

# Then use relative paths
path_to_data <- "../model-output"
```

**Documentation**:
- Add roxygen-style comments (`#'`) at the top explaining the script's purpose
- Comment complex logic inline
- Include usage examples if the script takes arguments

### Step 3: Test the Script

Before committing, test your script works correctly:

```r
# In RStudio:
# 1. Open src/variant-nowcast-hub.Rproj
# 2. Run: source("my_new_script.R")

# Or from command line:
cd src/
Rscript my_new_script.R
```

### Step 4: Add Script to GitHub Actions (if applicable)

If your script should run automatically in a workflow, add it to `.github/workflows/`:

```yaml
# Example: .github/workflows/my-workflow.yaml
- name: Run my new script
  run: |
    cd src/
    Rscript my_new_script.R
```

---

## Part 2: Adding a New Package to `renv.lock`

When your script needs a package that isn't already in `renv.lock`, follow these steps:

### Step 1: Open the Project in RStudio

**Recommended approach** (uses RStudio):
1. Navigate to `src/` directory
2. Double-click `variant-nowcast-hub.Rproj` to open in RStudio
3. renv will automatically activate (you'll see a message in the console)

**Alternative** (command line):
```bash
cd src/
R
```

### Step 2: Install the Package

In the R console:

```r
# Install the new package (and its dependencies)
install.packages("scoringRules")

# Or for GitHub packages:
remotes::install_github("username/package")

# Or for specific versions:
install.packages("scoringRules", version = "1.1.0")
```

This installs the package into the renv-managed library (not your system library).

### Step 3: Update Your Script

Add `require()` for the new package:

```r
# src/my_script.R
require(dplyr)
require(scoringRules)  # <- newly added

# Use the package
score <- scoringRules::crps_sample(...)
```

### Step 4: Snapshot the New Package

Tell renv to update the lockfile with the new package:

```r
# In R console (with src/ as working directory)
renv::snapshot()
```

renv will:
1. Scan your R scripts for `library()` and `require()` calls
2. Identify packages that aren't in `renv.lock`
3. Ask for confirmation to add them

**Example output**:
```
The following package(s) will be updated in the lockfile:

# CRAN -----------------------------------------------------------------------
- scoringRules   [* -> 1.1.0]

Do you want to proceed? [Y/n]:
```

Type `Y` and press Enter.

### Step 5: Verify the Update

Check that `renv.lock` was updated:

```bash
git diff src/renv.lock
```

You should see the new package added with version and dependencies.

### Step 6: Test the Environment

Verify the package works in a clean environment:

```r
# Remove the package from the library
renv::remove("scoringRules")

# Restore from the lockfile (simulates a fresh install)
renv::restore()

# Test your script
source("my_script.R")
```

### Step 7: Commit the Changes

```bash
git add src/renv.lock
git add src/my_script.R
git commit -m "Add scoringRules package for scoring functionality

- Added scoringRules to renv.lock
- Updated my_script.R to use scoringRules::crps_sample()
"
git push
```

---

## Part 3: Updating Packages in `renv.lock`

There are two scenarios for updating packages:

### Scenario A: Update a Single Package

**When**: You need a newer version of a specific package (e.g., bug fix, new feature)

```r
# In R console (src/ as working directory)

# Update the package
install.packages("dplyr")  # Gets latest version

# Or update to a specific version
install.packages("dplyr", version = "1.1.4")

# Snapshot the change
renv::snapshot()
```

**Verify**:
```bash
git diff src/renv.lock | grep -A 5 "dplyr"
```

### Scenario B: Update All Packages

**When**: Regular maintenance, or after R version upgrade

⚠️ **Caution**: This can introduce breaking changes. Test thoroughly.

```r
# In R console (src/ as working directory)

# Update all packages to latest versions
renv::update()

# Review the changes
# renv will show you what will be updated

# Accept or reject individual updates
# Then snapshot
renv::snapshot()
```

### Scenario C: Update After R Version Upgrade

**When**: You've upgraded R (e.g., 4.4.1 → 4.5.0)

```r
# In R console (src/ as working directory)

# Rebuild packages for new R version
renv::rebuild()

# Update the R version in lockfile
renv::snapshot()
```

**Verify** the R version in `renv.lock`:
```json
{
  "R": {
    "Version": "4.5.0",  // <- should match your R version
    ...
  }
}
```

### Testing After Updates

After updating packages, always test critical scripts:

```bash
# Test key workflows
cd src/
Rscript ensemble_model.R
Rscript score_nowcasts_script.R
Rscript make_round_config.R
```

Or run the GitHub Actions workflows locally if available.

---

## Common Scenarios and Troubleshooting

### Problem: "Package not found" when running script

**Cause**: Package is used in script but not in `renv.lock`

**Solution**:
```r
# Install missing package
install.packages("missing_package")

# Update lockfile
renv::snapshot()
```

### Problem: "Package version conflict"

**Cause**: Two packages require different versions of a dependency

**Solution**:
```r
# Let renv resolve conflicts
renv::snapshot()

# If that fails, check which packages have conflicts
renv::dependencies()

# Manually specify compatible versions if needed
install.packages("conflicting_package", version = "X.Y.Z")
renv::snapshot()
```

### Problem: "renv not activated"

**Cause**: Working directory is not `src/` or `.Rprofile` not sourced

**Solution**:
```r
# Check current directory
getwd()  # Should show: .../variant-nowcast-hub/src

# If not in src/, change directory
setwd("src/")

# Manually activate renv
source("renv/activate.R")
```

### Problem: GitHub Actions fails after adding package

**Cause**: `renv.lock` not committed, or package unavailable on CRAN/GitHub

**Solution**:
```bash
# Ensure renv.lock is committed
git add src/renv.lock
git commit -m "Update renv.lock with new package"
git push

# If package is from GitHub, ensure workflow has:
# remotes::install_github("username/package")
```

### Problem: "Unable to restore from renv.lock"

**Cause**: Package version no longer available, or repository changed

**Solution**:
```r
# Try updating to a newer version
install.packages("problematic_package")
renv::snapshot()

# Or check package source in renv.lock
# and update Repository/Source fields if needed
```

---

## Best Practices

### 1. Always Use `renv::snapshot()` After Installing Packages

❌ **Don't**:
```r
install.packages("newpackage")
# Commit script but forget to update renv.lock
```

✅ **Do**:
```r
install.packages("newpackage")
renv::snapshot()  # Updates renv.lock
# Commit both script and renv.lock
```

### 2. Test in Clean Environment

Before committing, verify others can reproduce your environment:

```r
# Remove all packages
renv::clean()

# Restore from lockfile (fresh install)
renv::restore()

# Test your script works
source("my_script.R")
```

### 3. Document Why You're Adding Packages

In your commit message, explain:
- What the package is for
- Why it's needed
- What alternatives you considered (if any)

```bash
git commit -m "Add scoringRules package for CRPS evaluation

We need to calculate CRPS (Continuous Ranked Probability Score) for
probabilistic model evaluation. The scoringRules package provides
optimized implementations for this.

Considered alternatives:
- Implementing CRPS manually (too complex, error-prone)
- Using forecast package (doesn't support sample-based CRPS)

Ref: #289
"
```

### 4. Pin Important Package Versions

For critical infrastructure packages, document version requirements:

```r
# In script comments:
# Requires dplyr >= 1.1.0 for .by argument
# Requires arrow >= 10.0.0 for parquet v2 support
```

### 5. Keep `renv.lock` Minimal

Only install packages you actually use:
- Don't install "nice-to-have" packages
- Remove unused packages periodically

```r
# Check which packages are actually used
renv::dependencies()

# Remove unused packages
renv::clean()
renv::snapshot()
```

---

## Quick Reference

### Common renv Commands

```r
# Install packages (adds to library)
install.packages("package_name")

# Update lockfile with new/updated packages
renv::snapshot()

# Install packages from lockfile (first-time setup)
renv::restore()

# Update a specific package
install.packages("package_name")
renv::snapshot()

# Update all packages (careful!)
renv::update()

# Remove unused packages from library
renv::clean()

# Check package status
renv::status()

# List dependencies in your scripts
renv::dependencies()

# Rebuild packages (after R upgrade)
renv::rebuild()
```

### Workflow Summary

**Adding new package**:
1. `install.packages("package")`
2. `renv::snapshot()`
3. Test script works
4. Commit `renv.lock` + script

**Adding new script**:
1. Create script in `src/`
2. Add `require()` calls
3. Add `here::i_am("src/script.R")`
4. Test with `source("script.R")`
5. Install any new packages (see above)
6. Commit script (+ `renv.lock` if packages added)

**Updating packages**:
1. `install.packages("package")` (or `renv::update()`)
2. `renv::snapshot()`
3. Test critical scripts
4. Commit `renv.lock`

---

## Example: Complete Workflow

Let's walk through adding a new scoring script that needs the `scoringRules` package:

```bash
# Step 1: Create the script
cd src/
touch calculate_crps.R
```

```r
# Step 2: Write the script (calculate_crps.R)
#' Calculate CRPS for variant nowcast submissions
#'
#' This script computes Continuous Ranked Probability Scores (CRPS)
#' for sample-based model submissions against observed clade proportions.

require(dplyr)
require(arrow)
require(hubData)
require(scoringRules)  # <-- new package needed

here::i_am("src/calculate_crps.R")

# Load submissions
hub_con <- hubData::connect_hub(...)
submissions <- hub_con %>% collect_hub()

# Calculate CRPS
scores <- submissions %>%
  group_by(model_id, location, target_date, clade) %>%
  summarise(
    crps = scoringRules::crps_sample(
      y = observed_prop,
      dat = value
    )
  )

# Save results
arrow::write_parquet(scores, "../auxiliary-data/scores/crps_scores.parquet")
```

```r
# Step 3: Open RStudio project
# In RStudio: File > Open Project > src/variant-nowcast-hub.Rproj

# Step 4: Install the new package
install.packages("scoringRules")
# > Installing package into 'src/renv/library/...'
# > package 'scoringRules' successfully unpacked

# Step 5: Update lockfile
renv::snapshot()
# > The following package(s) will be updated in the lockfile:
# > - scoringRules   [* -> 1.1.0]
# > Do you want to proceed? [Y/n]: Y
# > * Lockfile written to 'src/renv.lock'.

# Step 6: Test the script
source("calculate_crps.R")
# Should run without errors
```

```bash
# Step 7: Verify changes
git diff src/renv.lock
# Should show scoringRules added

# Step 8: Commit
git add src/calculate_crps.R src/renv.lock
git commit -m "Add CRPS scoring script

- New script to calculate CRPS for model evaluation
- Added scoringRules package to renv.lock
- Scores saved to auxiliary-data/scores/

Ref: #291
"
git push
```

Done! 🎉

---

## Part 4: Working with GitHub Actions

GitHub Actions automate the variant-nowcast-hub's weekly workflows, including round creation, validation, ensemble generation, and scoring. All workflows are defined in `.github/workflows/`.

### Overview of Hub Workflows

The hub uses **8 main workflows**:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `create-modeling-round.yaml` | Monday 3am UTC | Generate clade list & new round config |
| `validate-submission.yaml` | PR to `model-output/` | Validate model submissions |
| `create-ensemble.yaml` | Thursday 1am UTC | Generate ensemble forecast |
| `run-post-submission-jobs.yaml` | Thursday 12:20-1:20am UTC | Generate target data & unscored locations |
| `test-python-scripts.yaml` | PR to `src/*.py` | Run Python tests |
| `validate-config.yaml` | PR to `hub-config/` | Validate hub configuration |
| `cache-hubval-deps.yaml` | Daily | Cache R dependencies for validation |
| `hubverse-aws-upload.yaml` | Push to main | Upload hub data to S3 |

### Workflow Anatomy: Key Components

All workflows share common patterns. Here's an annotated example from `create-modeling-round.yaml`:

```yaml
name: Create new modeling round

# When the workflow runs
on:
  schedule:
    - cron: "0 03 * * 1"  # Every Monday at 3 AM UTC
  workflow_dispatch:       # Allow manual triggering

# Permissions needed
permissions:
    contents: write
    pull-requests: write

jobs:
  create-clade-modeling-round:
    runs-on: ubuntu-latest
    steps:
      # Step 1: Check out repository code
      - name: Checkout 🛎️
        uses: actions/checkout@v5
        with:
            sparse-checkout: |      # Only check out what's needed
              auxiliary-data/
              hub-config/
              src/

      # Step 2: Set up Python with uv
      - name: Install uv 🐍
        uses: astral-sh/setup-uv@557e51de59eb14aaaba2ed9621916900a91d50c6
        with:
          version: "0.5.30"

      # Step 3: Set up R
      - name: Set up R 📊
        uses: r-lib/actions/setup-r@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
        with:
          r-version: 4.4.1
          extra-repositories: 'https://hubverse-org.r-universe.dev'

      # Step 4: Restore R packages from renv.lock
      - name: Set up renv 📦
        uses: r-lib/actions/setup-renv@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
        with:
          working-directory: src

      # Step 5: Run scripts
      - name: Create clade list and update tasks.json 🦠
        run: |
          uv run --with-requirements requirements.txt get_clades_to_model.py
          Rscript make_round_config.R
        working-directory: src

      # Step 6: Create a PR with results
      - name: Create PR for new modeling round 🚀
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git checkout -b new_round_"$(date +'%Y-%m-%d_%H-%M-%S')"
          git add auxiliary-data/modeled-clades/ hub-config/
          git commit -m "Add new round $(date +'%Y-%m-%d')"
          git push -u origin HEAD
          gh pr create --base main --title "Add new round" --body "..."
```

### Common Workflow Patterns

#### Pattern 1: Sparse Checkout

To speed up workflows, check out only required directories:

```yaml
- name: Checkout 🛎️
  uses: actions/checkout@v5
  with:
      sparse-checkout: |
        auxiliary-data/
        hub-config/
        src/
```

**Use when**: The repository is large (e.g., lots of model-output files).

#### Pattern 2: Setting up Python with `uv`

All Python scripts use `uv` for dependency management:

```yaml
- name: Install uv 🐍
  uses: astral-sh/setup-uv@557e51de59eb14aaaba2ed9621916900a91d50c6
  with:
    version: "0.5.30"

- name: Run Python script 🐍
  run: |
    uv run --with-requirements requirements.txt my_script.py --arg=value
  working-directory: src
```

**Key points**:
- Always specify `--with-requirements requirements.txt` to install dependencies
- Set `working-directory: src` to run scripts from the correct location
- Use inline script metadata (PEP 723) in Python scripts for dependencies

#### Pattern 3: Setting up R with `renv`

R workflows use `renv` to restore packages from `src/renv.lock`:

```yaml
- name: Set up R 📊
  uses: r-lib/actions/setup-r@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
  with:
    r-version: 4.4.1
    install-r: true
    use-public-rspm: true
    extra-repositories: 'https://hubverse-org.r-universe.dev'

- name: Set up renv 📦
  env:
    GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}
  uses: r-lib/actions/setup-renv@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
  with:
    working-directory: src
```

**Key points**:
- `setup-renv` automatically runs `renv::restore()` using `src/renv.lock`
- `extra-repositories` provides Hubverse packages from r-universe
- `GITHUB_PAT` needed to access private packages (if any)

#### Pattern 4: Creating Pull Requests

Two approaches for creating PRs:

**Approach A: Inline bash commands**

```yaml
- name: Create PR 🚀
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git checkout -b my_branch_$(date +'%Y-%m-%d_%H-%M-%S')
    git add path/to/files/
    git commit -m "My commit message"
    git push -u origin HEAD
    gh pr create \
      --base main \
      --title "My PR Title" \
      --body "My PR description"
```

**Approach B: Reusable action** (`.github/actions/create-pr/action.yml`)

```yaml
- name: Create PR 🚀
  uses: ./.github/actions/create-pr
  with:
    pr-prefix: "my-feature-$(date +'%Y-%m-%d')"
    file-path: path/to/files/
    commit-message: "My commit message"
    pr-body: "My PR description"
```

The reusable action includes safety checks (skips if no changes) and standardized naming.

#### Pattern 5: Matrix Strategies

For running jobs across multiple dates/parameters:

```yaml
jobs:
  get-dates:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-dates.outputs.MATRIX_DATES }}
    steps:
      - name: Set dates 🕰️
        id: set-dates
        run: |
          # Generate matrix JSON using shared function
          source ${GITHUB_WORKSPACE}/.github/shared/shared-functions.sh
          matrix_dates=$(generate_weekly_dates "2024-12-04" 13)
          echo "matrix_dates=$matrix_dates" >> $GITHUB_OUTPUT

  process-data:
    needs: get-dates
    strategy:
      matrix: ${{ fromJson(needs.get-dates.outputs.matrix) }}
    steps:
      - name: Process for date ${{ matrix.nowcast-date }}
        run: |
          python my_script.py --date=${{ matrix.nowcast-date }}
```

**Example**: `run-post-submission-jobs.yaml` generates target data for 14 rounds in parallel.

#### Pattern 6: Uploading/Downloading Artifacts

Share data between jobs:

```yaml
# Job 1: Create data
- name: Upload data 📤
  uses: actions/upload-artifact@v4
  with:
    name: my-data-${{ matrix.date }}
    path: path/to/data/*.parquet

# Job 2: Use data
- name: Download data 📥
  uses: actions/download-artifact@v5
  with:
    pattern: my-data-*
    merge-multiple: true
    path: ${{ github.workspace }}/data/
```

**Use case**: Parallel matrix jobs (create-target-data) upload parquets, then a final job (target-data-pr) downloads and commits them.

### Adding a New Workflow

Follow these steps to create a new workflow:

#### Step 1: Create the Workflow File

```bash
touch .github/workflows/my-new-workflow.yaml
```

#### Step 2: Define the Workflow

```yaml
name: My New Workflow

on:
  schedule:
    - cron: "0 12 * * 3"  # Every Wednesday at noon UTC
  workflow_dispatch:       # Allow manual runs

permissions:
  contents: read
  pull-requests: write

jobs:
  my-job:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout 🛎️
        uses: actions/checkout@v5
        with:
            sparse-checkout: |
              src/
              model-output/

      # Add setup steps (Python/R)
      # Add your script execution
      # Add PR creation (if needed)
```

#### Step 3: Add Script Execution

**For Python scripts**:

```yaml
- name: Install uv 🐍
  uses: astral-sh/setup-uv@557e51de59eb14aaaba2ed9621916900a91d50c6
  with:
    version: "0.5.30"

- name: Run my Python script 🐍
  run: |
    uv run --with-requirements requirements.txt my_script.py
  working-directory: src
```

**For R scripts**:

```yaml
- name: Set up R 📊
  uses: r-lib/actions/setup-r@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
  with:
    r-version: 4.4.1
    install-r: true
    use-public-rspm: true
    extra-repositories: 'https://hubverse-org.r-universe.dev'

- name: Set up renv 📦
  uses: r-lib/actions/setup-renv@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
  with:
    working-directory: src

- name: Run my R script 📊
  run: |
    Rscript my_script.R
  working-directory: src
```

#### Step 4: Test the Workflow

```bash
# Commit and push
git add .github/workflows/my-new-workflow.yaml
git commit -m "Add workflow for my new feature"
git push

# Manually trigger the workflow
gh workflow run my-new-workflow.yaml

# Watch the workflow run
gh run watch
```

Or use the GitHub web interface: **Actions tab → Select workflow → Run workflow**.

#### Step 5: Debug if Needed

View logs:

```bash
# List recent runs
gh run list --workflow=my-new-workflow.yaml

# View logs for a specific run
gh run view <run-id> --log
```

Or in the GitHub UI: **Actions → Select run → View logs**.

### Updating an Existing Workflow

When modifying workflows, consider:

#### Scenario A: Change Schedule

```yaml
# Before
on:
  schedule:
    - cron: "0 03 * * 1"  # Monday 3am UTC

# After
on:
  schedule:
    - cron: "0 02 * * 1"  # Monday 2am UTC (1 hour earlier)
```

**Test**: Use `workflow_dispatch` to test manually before waiting for the scheduled run.

#### Scenario B: Add a New Step

Insert steps in logical order:

```yaml
- name: Set up renv 📦
  uses: r-lib/actions/setup-renv@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
  with:
    working-directory: src

# NEW STEP: Validate renv status
- name: Check renv status 🔍
  run: |
    Rscript -e "renv::status()"
  working-directory: src

- name: Run my R script 📊
  run: |
    Rscript my_script.R
  working-directory: src
```

#### Scenario C: Update R or Python Version

```yaml
# Update R version
- name: Set up R 📊
  uses: r-lib/actions/setup-r@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
  with:
    r-version: 4.5.0  # <-- Updated from 4.4.1

# Update uv version
- name: Install uv 🐍
  uses: astral-sh/setup-uv@557e51de59eb14aaaba2ed9621916900a91d50c6
  with:
    version: "0.6.0"  # <-- Updated from 0.5.30
```

**Important**: If updating R version, rebuild `renv.lock`:

```r
# In R console (src/ directory)
renv::rebuild()
renv::snapshot()
```

#### Scenario D: Pin Action Versions

For reproducibility, pin action versions using commit SHAs:

```yaml
# Instead of:
uses: actions/checkout@v5

# Use:
uses: actions/checkout@abc123def456...  # Full SHA

# Find SHAs at:
# https://github.com/actions/checkout/releases
```

**Already pinned in hub workflows**:
- `r-lib/actions/setup-r@bd49c52ffe281809afa6f0fecbf37483c5dd0b93` (v2.11.3)
- `astral-sh/setup-uv@557e51de59eb14aaaba2ed9621916900a91d50c6` (v6.6.1)

### Using Shared Functions and Actions

The hub provides reusable components:

#### Shared Functions (`.github/shared/shared-functions.sh`)

```bash
# Get most recent Wednesday (for nowcast_date)
get_latest_wednesday() {
    if [ -n "$1" ]; then
        echo "$1"
    else
        if [ $(date +%u) -eq 3 ]; then
            date +%Y-%m-%d
        else
            date -d'last wednesday' +%Y-%m-%d
        fi
    fi
}

# Generate weekly dates for matrix strategy
generate_weekly_dates() {
    local start_date=$1
    local weeks=$2
    seq 0 7 $(echo "7 * $weeks" | bc) \
    | xargs -I {} date -d "$start_date -{} days" +%Y-%m-%d \
    | jq -R \
    | jq -sc '. | map({"nowcast-date": .}) | {"include": .}'
}
```

**Usage in workflow**:

```yaml
- name: Set dates 🕰️
  run: |
    source ${GITHUB_WORKSPACE}/.github/shared/shared-functions.sh
    nowcast_date=$(get_latest_wednesday "${{ inputs.nowcast_date }}")
    matrix_dates=$(generate_weekly_dates "$nowcast_date" 13)
    echo "nowcast_date=$nowcast_date" >> $GITHUB_OUTPUT
    echo "matrix_dates=$matrix_dates" >> $GITHUB_OUTPUT
```

#### Reusable Action (`.github/actions/create-pr/action.yml`)

```yaml
# In your workflow:
- name: Create PR 🚀
  uses: ./.github/actions/create-pr
  with:
    pr-prefix: "my-feature-2024-12-04"
    file-path: auxiliary-data/scores/
    commit-message: "Add scores for round 2024-12-04"
    pr-body: "Generated via workflow_name.yaml"
```

The action handles:
- Branch creation with timestamp
- Git config for bot user
- Checking for changes (skips if none)
- PR creation with standardized format

### Workflow Triggers

#### Cron Schedules

```yaml
on:
  schedule:
    - cron: "0 03 * * 1"  # Every Monday at 3 AM UTC
```

**Cron format**: `minute hour day month weekday`

**Hub examples**:
- `"0 03 * * 1"` - Monday 3am UTC (create-modeling-round)
- `"0 01 * * 4"` - Thursday 1am UTC (create-ensemble)
- `"20 00 * 4-10 4"` - Thursday 12:20am UTC, Apr-Oct (run-post-submission-jobs)
- `"10 0 * * *"` - Daily at 12:10am UTC (cache-hubval-deps)

**⚠️ Important**: GitHub Actions cron uses UTC time. Convert from ET:
- ET to UTC: Add 4-5 hours (depending on DST)
- Example: 8pm ET Wednesday = 12am-1am UTC Thursday

#### Path-Based Triggers

```yaml
on:
  pull_request:
    branches: main
    paths:
      - 'model-output/**'      # Trigger on model submissions
      - 'model-metadata/*'     # Trigger on metadata changes
      - '!**README**'          # EXCEPT README files
```

**Use case**: `validate-submission.yaml` only runs when model-output or metadata changes.

#### Manual Triggers

```yaml
on:
  workflow_dispatch:
    inputs:
      nowcast_date:
        description: "Nowcast date (YYYY-MM-DD)"
        required: false
```

**Usage**:
```bash
gh workflow run my-workflow.yaml --field nowcast_date=2024-12-04
```

Or use the **Actions** tab in GitHub UI.

### Common Workflow Patterns in the Hub

#### Pattern: Scheduled Job with Manual Override

```yaml
on:
  schedule:
    - cron: "0 03 * * 1"
  workflow_dispatch:
    inputs:
      nowcast_date:
        description: "Override nowcast date"
        required: false
```

**Why**: Scheduled runs happen automatically, but admins can manually trigger for testing or re-runs.

#### Pattern: Conditional Job Execution

```yaml
jobs:
  my-job:
    if: ${{ github.repository_owner == 'reichlab' }}
    runs-on: ubuntu-latest
```

**Why**: Prevents workflows from running in forks (e.g., cache-building jobs).

#### Pattern: Job Dependencies

```yaml
jobs:
  get-dates:
    runs-on: ubuntu-latest
    outputs:
      nowcast_date: ${{ steps.set-dates.outputs.NOWCAST_DATE }}
    steps: [...]

  create-target-data:
    needs: get-dates
    runs-on: ubuntu-latest
    env:
      NOWCAST_DATE: ${{ needs.get-dates.outputs.nowcast_date }}
    steps: [...]

  create-pr:
    needs: [get-dates, create-target-data]
    runs-on: ubuntu-latest
    steps: [...]
```

**Why**: Jobs run in sequence when outputs/artifacts are needed downstream.

### Troubleshooting Workflows

#### Problem: Workflow doesn't trigger on schedule

**Possible causes**:
- Cron expression incorrect (use https://crontab.guru/ to verify)
- Repository inactive (GitHub disables scheduled workflows after 60 days of no commits)
- Branch is not default branch (scheduled workflows only run on default branch)

**Solution**:
```bash
# Check if workflow is disabled
gh workflow list

# Enable it
gh workflow enable my-workflow.yaml

# Test with manual trigger
gh workflow run my-workflow.yaml
```

#### Problem: `renv::restore()` fails in workflow

**Cause**: Package version in `renv.lock` no longer available, or R version mismatch

**Solution**:
```r
# Locally (in src/ directory):
# Update packages to latest compatible versions
renv::update()
renv::snapshot()

# Ensure R version in renv.lock matches workflow:
renv::snapshot()  # Updates R version field
```

Then commit updated `renv.lock` and re-run workflow.

#### Problem: Python script fails with "ModuleNotFoundError"

**Cause**: Missing dependency in `src/requirements.txt` or inline metadata

**Solution**:
```bash
# Ensure all dependencies are in requirements.txt
cd src/
grep "import" my_script.py  # Check imports
pip install missing_package  # Test locally
echo "missing_package==1.2.3" >> requirements.txt

# Or add to inline script metadata:
# /// script
# dependencies = [
#   "missing_package==1.2.3",
# ]
# ///
```

Commit and re-run workflow.

#### Problem: Workflow creates empty PR

**Cause**: No changes to commit (e.g., script didn't modify any files)

**Solution**: The `create-pr` action checks for this:

```yaml
# Already built into .github/actions/create-pr/action.yml:
if git diff --staged --quiet; then
  echo "No changes to commit"
  exit 0
fi
```

Check script logs to debug why no files were modified.

#### Problem: Sparse checkout missing files

**Cause**: Required files/directories not included in `sparse-checkout`

**Solution**: Add missing paths:

```yaml
- name: Checkout 🛎️
  uses: actions/checkout@v5
  with:
      sparse-checkout: |
        auxiliary-data/
        hub-config/
        src/
        target-data/  # <-- Add if needed
```

### Best Practices for Workflows

#### 1. Use Sparse Checkout for Large Repos

❌ **Don't**:
```yaml
- uses: actions/checkout@v5  # Checks out entire repo (slow)
```

✅ **Do**:
```yaml
- uses: actions/checkout@v5
  with:
      sparse-checkout: |
        src/
        hub-config/
```

**Why**: Speeds up checkout (variant-nowcast-hub has 1000+ model-output files).

#### 2. Pin Action Versions with SHAs

❌ **Don't**:
```yaml
uses: actions/checkout@v5  # Tag can change
```

✅ **Do**:
```yaml
uses: actions/checkout@abc123...  # SHA is immutable
```

**Why**: Ensures reproducibility and prevents supply chain attacks.

#### 3. Use Environment Variables for Shared Values

❌ **Don't**:
```yaml
- run: python script.py --date=2024-12-04
- run: echo "Processing 2024-12-04"
- run: git commit -m "Add data for 2024-12-04"
```

✅ **Do**:
```yaml
env:
  NOWCAST_DATE: 2024-12-04
steps:
  - run: python script.py --date=$NOWCAST_DATE
  - run: echo "Processing $NOWCAST_DATE"
  - run: git commit -m "Add data for $NOWCAST_DATE"
```

#### 4. Document Complex Workflows

Add comments explaining non-obvious logic:

```yaml
# nowcast_date = round_id of the round that just closed for submissions,
#    defaults to the most recent Wednesday if not explicitly set (YYYY-MM-DD)
# submission_close_date = an alias for nowcast_date
# matrix_dates = an array of 14 round_ids in YYYY-MM-DD format, starting with
#    nowcast_date and going back 13 weeks
- name: Set dates 🕰️
  run: |
    source ${GITHUB_WORKSPACE}/.github/shared/shared-functions.sh
    nowcast_date=$(get_latest_wednesday "${{ inputs.nowcast_date }}")
    [...]
```

#### 5. Test Workflows Locally When Possible

Use [act](https://github.com/nektos/act) to run workflows locally:

```bash
# Install act
brew install act

# Run a workflow locally
act -j my-job-name

# Or test a specific workflow file
act -W .github/workflows/my-workflow.yaml
```

**Limitations**: Some features (e.g., GitHub API access) won't work locally.

#### 6. Use Reusable Actions for Common Tasks

Instead of duplicating PR creation logic, use the shared action:

```yaml
# Reusable across workflows
- uses: ./.github/actions/create-pr
  with:
    pr-prefix: "my-feature"
    file-path: data/
    commit-message: "Update data"
    pr-body: "Generated by workflow"
```

#### 7. Set Appropriate Permissions

Use least-privilege principle:

```yaml
# Read-only by default
permissions:
  contents: read

# Only grant write when needed
permissions:
  contents: write
  pull-requests: write
```

### Workflow Development Checklist

When adding or modifying a workflow:

- [ ] Workflow has a descriptive `name:`
- [ ] Includes `workflow_dispatch:` for manual testing
- [ ] Uses sparse checkout if repo is large
- [ ] Pins action versions with commit SHAs
- [ ] Sets appropriate `permissions:`
- [ ] Uses `working-directory:` consistently
- [ ] Python scripts use `uv run --with-requirements requirements.txt`
- [ ] R scripts use `setup-renv` to restore packages
- [ ] PRs created by bot user (`github-actions[bot]`)
- [ ] Branch names include timestamps to avoid conflicts
- [ ] Commit messages are descriptive
- [ ] Comments explain complex logic
- [ ] Tested with manual trigger before scheduling
- [ ] Documented in this guide (if introducing new patterns)

### Example: Complete Custom Workflow

Let's create a workflow to calculate weekly summary statistics:

```yaml
# .github/workflows/calculate-summary-stats.yaml
name: Calculate weekly summary statistics

on:
  schedule:
    - cron: "0 06 * * 5"  # Every Friday at 6 AM UTC
  workflow_dispatch:
    inputs:
      nowcast_date:
        description: "Nowcast date to summarize (YYYY-MM-DD)"
        required: false

permissions:
  contents: write
  pull-requests: write

jobs:
  calculate-stats:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout 🛎️
        uses: actions/checkout@v5
        with:
            sparse-checkout: |
              model-output/
              auxiliary-data/
              src/

      - name: Set up R 📊
        uses: r-lib/actions/setup-r@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
        with:
          r-version: 4.4.1
          install-r: true
          use-public-rspm: true
          extra-repositories: 'https://hubverse-org.r-universe.dev'

      - name: Set up renv 📦
        uses: r-lib/actions/setup-renv@bd49c52ffe281809afa6f0fecbf37483c5dd0b93
        with:
          working-directory: src

      - name: Calculate summary statistics 📈
        env:
          NOWCAST_DATE: ${{ inputs.nowcast_date }}
        run: |
          if [ -z "$NOWCAST_DATE" ]; then
            source ${GITHUB_WORKSPACE}/.github/shared/shared-functions.sh
            NOWCAST_DATE=$(get_latest_wednesday)
          fi
          echo "Calculating stats for $NOWCAST_DATE"
          Rscript calculate_summary_stats.R --nowcast-date=$NOWCAST_DATE
        working-directory: src

      - name: Create PR with summary statistics 🚀
        uses: ./.github/actions/create-pr
        with:
          pr-prefix: "summary-stats-$(date +'%Y-%m-%d')"
          file-path: auxiliary-data/summary-stats/
          commit-message: "Add summary statistics for latest round"
          pr-body: "Weekly summary statistics generated by calculate-summary-stats workflow"
```

**Corresponding R script** (`src/calculate_summary_stats.R`):

```r
#' Calculate summary statistics for model submissions
#'
#' Aggregates model submissions by location and clade, computing
#' mean, median, and quantiles across all models.

require(dplyr)
require(arrow)
require(hubData)
require(here)

here::i_am("src/calculate_summary_stats.R")

# Parse command line args
args <- commandArgs(trailingOnly = TRUE)
nowcast_date <- args[grep("--nowcast-date", args)]
nowcast_date <- sub("--nowcast-date=", "", nowcast_date)

# Connect to hub and load data
hub_con <- connect_hub(
  hub_path = here::here(),
  file_format = "parquet"
)

submissions <- hub_con %>%
  filter(nowcast_date == !!nowcast_date) %>%
  collect_hub()

# Calculate summary stats
summary_stats <- submissions %>%
  group_by(location, target_date, clade) %>%
  summarise(
    mean_value = mean(value),
    median_value = median(value),
    q25 = quantile(value, 0.25),
    q75 = quantile(value, 0.75),
    n_models = n_distinct(model_id),
    .groups = "drop"
  )

# Save results
output_dir <- here::here("auxiliary-data", "summary-stats")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

arrow::write_parquet(
  summary_stats,
  file.path(output_dir, paste0(nowcast_date, "-summary-stats.parquet"))
)

cat("✓ Summary statistics saved to", output_dir, "\n")
```

**To deploy**:

```bash
# Add the R script and install any new packages
cd src/
# Open R, install packages, update renv.lock (see Part 2)

# Add workflow file
git add .github/workflows/calculate-summary-stats.yaml
git add src/calculate_summary_stats.R
git add src/renv.lock  # If packages were added

git commit -m "Add workflow to calculate weekly summary statistics

- New R script: calculate_summary_stats.R
- Scheduled to run every Friday at 6am UTC
- Creates PR with aggregated model statistics
"

git push

# Test it manually
gh workflow run calculate-summary-stats.yaml
gh run watch
```

---

## Getting Help

- **renv documentation**: https://rstudio.github.io/renv/
- **GitHub Actions docs**: https://docs.github.com/en/actions
- **Issue tracker**: https://github.com/reichlab/variant-nowcast-hub/issues
- **R package management**: https://r-pkgs.org/dependencies.html

For questions specific to this hub, open an issue or ask in the Reich Lab Slack.

---

**Last updated**: December 3, 2025
**Maintainers**: variant-nowcast-hub administrators
**Related**: Issue #291
