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

## Getting Help

- **renv documentation**: https://rstudio.github.io/renv/
- **Issue tracker**: https://github.com/reichlab/variant-nowcast-hub/issues
- **R package management**: https://r-pkgs.org/dependencies.html

For questions specific to this hub, open an issue or ask in the Reich Lab Slack.

---

**Last updated**: November 12, 2025
**Maintainers**: variant-nowcast-hub administrators
**Related**: Issue #291
