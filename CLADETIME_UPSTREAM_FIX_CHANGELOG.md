# CladeTime 0.4.0: Impact on variant-nowcast-hub

**Last Updated**: December 9, 2025
**CladeTime Version**: 0.4.0

## Summary

CladeTime 0.4.0 resolves workflow failures caused by Nextstrain's October 2025 deletion of historical `metadata_version.json` files from S3. The package now automatically falls back to variant-nowcast-hub's own archives (`auxiliary-data/modeled-clades/`) when Nextstrain data is unavailable.

**Good news**: This update is **fully compatible** with variant-nowcast-hub workflows. No code changes are required.

## The Problem

Starting in October 2025, Nextstrain implemented a 90-day retention policy for S3 versioned objects, permanently deleting historical metadata files. This caused CladeTime to fail when VNH workflows tried to access metadata for past modeling rounds.

## The Solution

CladeTime 0.4.0 includes automatic fallback to variant-nowcast-hub's GitHub archives:

1. **Primary source**: Tries Nextstrain S3 first (fast path, works for recent dates)
2. **Fallback**: If S3 doesn't have the file, fetches from `auxiliary-data/modeled-clades/{date}.json` on GitHub
3. **Search strategy**: Tries exact date match first, then searches for nearest prior archive within 30 days

## Breaking Changes in CladeTime 0.4.0

While CladeTime 0.4.0 includes breaking changes, **they do NOT affect variant-nowcast-hub**:

- **Minimum `sequence_as_of` date**: Now 2025-09-29 (was 2023-05-01)
- **Minimum `tree_as_of` date**: Now 2024-10-09 (via Hub fallback)
- **New error handling**: Raises `CladeTimeDataUnavailableError` for unavailable dates instead of silently defaulting

## What Changed in This PR

✅ **Updated CladeTime dependency** in `src/requirements.txt`:
```
cladetime>=0.4.0,<0.5.0
```
(Previously: `cladetime>=0.3.0,<0.4.0`)

✅ **No code changes required** - The fallback is automatic and transparent

## Testing

**Verified December 9, 2025:**
- ✅ Successfully ran `get_clades_to_model.py` with CladeTime 0.4.0
- ✅ Generated valid clade list JSON matching expected format
- ✅ Confirmed date validation works correctly
- ✅ Verified current date is within availability window

## Next Steps

**After CladeTime 0.4.0 is released to PyPI:**

1. **Merge this PR** to update VNH's CladeTime dependency

2. **Re-run failed workflows** to verify the fix:
   - Manually trigger `run-post-submission-jobs.yaml` for dates that previously failed (2025-10-15 onwards, reaching the 90 day threshold)
   - Verify target data generation succeeds
   - Check that metadata versions match Hub archive values

3. **Monitor logs** for fallback warnings:
   - Look for: "Nextstrain S3 metadata not available, will use Hub fallback"
   - These warnings are expected and indicate the fallback is working correctly

4. **Maintain Hub archives** (critical):
   - Continue generating `auxiliary-data/modeled-clades/` files via `get_clades_to_model.py`
   - **Never delete these files** - they are now essential for:
     - Historical workflow reproducibility
     - CladeTime's fallback mechanism
     - Target data generation for past rounds

## Archive Requirements

For the fallback to work, variant-nowcast-hub must maintain `auxiliary-data/modeled-clades/YYYY-MM-DD.json` files with:
- `meta.ncov.nextclade_dataset_name_full`
- `meta.ncov.nextclade_dataset_version`
- `meta.ncov.nextclade_version_num`
- `meta.ncov.created_at`

These files are already being generated automatically by `get_clades_to_model.py` and cover all dates needed by workflows (back to September 2024).

## Coverage

**Timeline:**
- Hub opened: October 9, 2024
- Modeled-clades archives: 2024-09-11 onwards (60+ weeks)
- Workflow requirement: Current round + 13 weeks back (~14 weeks)
- Nextstrain S3 retention: 90 days

**Result**: Hub archives fully cover all dates needed by workflows.

---

_For detailed implementation information, see [CladeTime PR #181](https://github.com/reichlab/cladetime/pull/181)_
