# CladeTime Upstream Fix: Change Log

**Date**: November 3, 2025
**Objective**: Add fallback to variant-nowcast-hub archives for historical metadata in CladeTime

## Changes Discussed and Implemented

### Session Start
- **Goal**: Implement Option 1 - Upstream fix in CladeTime repo
- **Location**: `/Users/trobacker/GitHub/cladetime/`
- **Target File**: `src/cladetime/util/reference.py`

---

## Change Log

### [Planning] - Initial Investigation
**Discussion**: Reviewing the CladeTime repository structure and identifying where to add the fallback mechanism.

**Files to modify**:
- `src/cladetime/util/reference.py` - Main implementation
- Tests (TBD)
- Documentation (TBD)

### [Implementation] - Adding Hub Fallback to reference.py

**File**: `/Users/trobacker/GitHub/cladetime/src/cladetime/util/reference.py`

**Current Behavior**:
- `_get_s3_object_url()` (lines 63-94) queries S3 for versioned objects
- Raises `ValueError` if no version found before the specified date (line 89)
- This fails for `metadata_version.json` files deleted in Nextstrain's Oct 2025 cleanup

**Proposed Changes**:
1. Add new function `_get_metadata_from_nowcast_hub(date)` to fetch from Hub archives
2. Modify `_get_s3_object_url()` to catch ValueError for metadata_version.json
3. Fall back to Hub archives when Nextstrain S3 doesn't have the file
4. Return metadata in format compatible with existing CladeTime code

**Implementation Plan**:
- Add import for `requests` (for HTTP requests to GitHub)
- Add import for `json` (for parsing Hub's JSON files)
- Add new helper function before `_get_s3_object_url()`
- Modify `_get_ncov_metadata()` in sequence.py to support Hub fallback
- Update call sites in tree.py and cladetime.py to pass dates

---

### [COMPLETED] - Implementation Details

**Files Modified:**

#### 1. `/Users/trobacker/GitHub/cladetime/src/cladetime/util/reference.py`

**Added imports** (lines 3-6):
```python
import json
import re
import subprocess
from datetime import datetime, timedelta, timezone  # Added timedelta
```

**Added imports** (line 12):
```python
import requests  # For HTTP requests to GitHub
```

**Added new function** `_get_metadata_from_hub()` (lines 66-123):
- Fetches metadata from variant-nowcast-hub GitHub archives
- Tries exact date match first at `auxiliary-data/modeled-clades/{date}.json`
- Falls back to nearest prior archive within 30 days
- Returns the `meta.ncov` section containing Nextclade metadata
- Raises ValueError if no archive found within 30 days before date

**Function signature:**
```python
def _get_metadata_from_hub(date: datetime) -> dict:
    """
    Retrieve ncov metadata from variant-nowcast-hub archives when
    Nextstrain S3 does not have historical metadata_version.json files.
    """
```

#### 2. `/Users/trobacker/GitHub/cladetime/src/cladetime/sequence.py`

**Updated import** (line 23):
```python
from cladetime.util.reference import _get_date, _get_metadata_from_hub
```

**Modified function** `_get_ncov_metadata()` (lines 129-182):
- Added optional parameter `as_of_date: datetime | None = None`
- **Added empty URL check** (lines 154-166): Detects empty/invalid URLs and goes directly to fallback
- When URL fetch fails (`not response.ok`), tries Hub fallback if date provided
- Logs warnings and info messages for fallback attempts
- Returns empty dict `{}` if both S3 and Hub fail

**Updated function signature:**
```python
def _get_ncov_metadata(
    url_ncov_metadata: str,
    session: Session | None = None,
    as_of_date: datetime | None = None,  # NEW
) -> dict:
```

**Fallback logic** (lines 162-172):
```python
# Try fallback to variant-nowcast-hub archives if date is provided
if as_of_date:
    try:
        logger.info("Attempting fallback to variant-nowcast-hub archives", ...)
        metadata = _get_metadata_from_hub(as_of_date)
        logger.info("Successfully retrieved metadata from Hub fallback")
        return metadata
    except Exception as e:
        logger.error("Hub fallback also failed", error=str(e))
        return {}
```

#### 3. `/Users/trobacker/GitHub/cladetime/src/cladetime/tree.py`

**Wrapped `_get_s3_object_url()` call** (lines 52-64):
```python
try:
    self.url_ncov_metadata = _get_s3_object_url(
        self._config.nextstrain_ncov_bucket,
        self._config.nextstrain_ncov_metadata_key,
        self.as_of
    )[1]
except ValueError as e:
    # S3 doesn't have historical metadata - will use Hub fallback when fetching
    logger.warn(
        "Nextstrain S3 metadata not available, will use Hub fallback",
        date=self.as_of.strftime("%Y-%m-%d"),
        error=str(e),
    )
    # Set to empty string so fallback will be triggered
    self.url_ncov_metadata = ""
```

**Updated `ncov_metadata` property** (lines 78-90):
```python
# Pass as_of date for Hub fallback support
metadata = sequence._get_ncov_metadata(self.url_ncov_metadata, as_of_date=self.as_of)
```

**Updated `_get_tree_url()` method** (line 160):
```python
# Pass as_of date for Hub fallback support
ncov_metadata = _get_ncov_metadata(url_ncov_metadata, as_of_date=self.as_of)
```

#### 4. `/Users/trobacker/GitHub/cladetime/src/cladetime/cladetime.py`

**Wrapped `_get_s3_object_url()` call** (lines 80-92):
```python
try:
    self.url_ncov_metadata = _get_s3_object_url(
        self._config.nextstrain_ncov_bucket,
        self._config.nextstrain_ncov_metadata_key,
        self.sequence_as_of
    )[1]
except ValueError as e:
    # S3 doesn't have historical metadata - will use Hub fallback when fetching
    logger.warn(
        "Nextstrain S3 metadata not available, will use Hub fallback",
        date=self.sequence_as_of.strftime("%Y-%m-%d"),
        error=str(e),
    )
    # Set to empty string so fallback will be triggered
    self.url_ncov_metadata = ""
```

**Updated `ncov_metadata` property** (lines 186-200):
```python
# Pass sequence_as_of date for Hub fallback support
metadata = sequence._get_ncov_metadata(self.url_ncov_metadata, as_of_date=self.sequence_as_of)
```

---

### Implementation Summary

The fallback mechanism works in two stages:

**Stage 1**: When CladeTime initializes and calls `_get_s3_object_url()` to get metadata_version.json URL:
- If S3 has the file: Store URL normally
- If S3 raises ValueError (file not found): Catch exception, log warning, set `url_ncov_metadata = ""`

**Stage 2**: When `ncov_metadata` property is accessed and calls `_get_ncov_metadata()`:
- Try to fetch from the URL (S3)
- If fetch fails (response not OK) AND date was provided: Fall back to Hub archives
- If Hub succeeds: Return Hub metadata
- If Hub also fails: Return empty dict

This approach is:
- ✅ Backwards compatible (date parameter is optional)
- ✅ Clean and maintainable
- ✅ Benefits all CladeTime users
- ✅ Well-documented with logging

---

### Next Steps for CladeTime Repository

1. ✅ **Implementation complete** - All code changes merged
2. **Add unit tests** for the new fallback functionality
3. **Update CladeTime documentation** to mention Hub fallback
4. **Create release** with new version number
5. **Publish to PyPI**

---

## Impact on variant-nowcast-hub

### What Changed in CladeTime

The CladeTime package (v2.x) now includes automatic fallback to variant-nowcast-hub archives when Nextstrain S3 metadata is unavailable for historical dates. This resolves the issue where `get_target_data.py` workflow failures occurred due to Nextstrain's October 2025 cleanup of historical `metadata_version.json` files.

**Key changes:**
- New function `_get_metadata_from_hub()` in `cladetime/util/reference.py` fetches metadata from Hub's `auxiliary-data/modeled-clades/` archives
- `_get_ncov_metadata()` in `cladetime/sequence.py` now accepts optional `as_of_date` parameter and falls back to Hub when S3 fails
- Tree and CladeTime classes properly handle S3 failures and pass dates to enable fallback
- Fallback searches for exact match first, then nearest prior archive within 30 days

### What Needs to Happen in variant-nowcast-hub

**After CladeTime release:**

1. **Update CladeTime dependency version** in `src/requirements.txt`:
   ```
   cladetime>=2.x.x  # Replace with actual version number
   ```

2. **No code changes required** - The fallback is automatic and transparent to existing code

3. **Test the fix** by re-running failed workflows:
   - Manually trigger `run-post-submission-jobs.yaml` for past `nowcast-date` values that previously failed (2025-08-06 onwards)
   - Verify target data is generated successfully without errors
   - Confirm metadata versions match expected values from Hub archives

4. **Monitor for warnings** in GitHub Actions logs:
   - Look for "Nextstrain S3 metadata not available, will use Hub fallback" warnings
   - These indicate the fallback is engaging correctly (expected for dates after 2025-07-01)

5. **Documentation updates** (optional):
   - Update README or admin docs to mention CladeTime's Hub fallback feature
   - Note that Hub archives must be available for historical rounds

### Backwards Compatibility

- The changes are **fully backwards compatible**
- No modifications needed to `get_target_data.py`, `get_clades_to_model.py`, or other scripts
- Older CladeTime versions will continue to work for dates where Nextstrain S3 still has metadata
- Newer dates requiring fallback will only work with CladeTime v2.x or later

### Archive Requirements

For the fallback to work, variant-nowcast-hub must maintain:
- `auxiliary-data/modeled-clades/YYYY-MM-DD.json` files for all modeling rounds
- Each file must include `meta.ncov` section with Nextclade metadata:
  - `nextclade_dataset_name_full`
  - `nextclade_dataset_version`
  - `nextclade_version_num`
  - `created_at` (tree_as_of timestamp)

These files are already being generated by `get_clades_to_model.py` and should not be deleted.

---

_Last updated: November 3, 2025_
