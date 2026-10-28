# Releasing Sprixe BIOS

A release is a tag `vX.Y.Z` on `main`. Pushing it runs [`release.yml`](../.github/workflows/release.yml):
the checks and build of [`build.yml`](../.github/workflows/build.yml), then a **draft** GitHub release
with the image built there. Nothing is published until a maintainer publishes that draft.

Versions follow [Semantic Versioning](https://semver.org/). A pre-release takes a suffix,
`v0.1.0-beta.1`, and its GitHub release is marked as a pre-release.

## The changelog: the [Unreleased] section

Every change a user can notice adds a line to `CHANGELOG.md` under `## [Unreleased]`, in the pull
request that makes it ([CONTRIBUTING.md](../CONTRIBUTING.md#changelog)). A release does not write
notes: it renames that section. The release workflow refuses a tag whose version has no dated
section, or an empty one.

## Steps

1. **Prove `main`.** Run the full regression (`bench/non-regression.sh`) and the game matrix on the
   image built from `main`, with your own ROM sets ([BENCH.md](BENCH.md)). The CI does not run MAME.
2. **Open a release pull request** that:
   - renames `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, and adds an empty `## [Unreleased]`
     above it;
   - adds or updates the link references at the bottom of `CHANGELOG.md` (there are none before
     the first release):
     `[Unreleased]: https://github.com/lid-labs/sprixe-bios/compare/vX.Y.Z...HEAD` and
     `[X.Y.Z]: https://github.com/lid-labs/sprixe-bios/compare/vPREVIOUS...vX.Y.Z` (for the first
     release, `.../releases/tag/vX.Y.Z`);
   - changes the version shown on the boot screen if it should (`src/c0/ecran.s`, `.Lversion`). This
     changes the image: update `build/expected-sha256.txt`, and the recorded fingerprint of the
     `boot-ecran` scene.
3. **Merge it, then tag the merge commit** on `main`:

   ```bash
   git checkout main && git pull
   git tag -a vX.Y.Z -m "Sprixe BIOS vX.Y.Z"
   git push origin vX.Y.Z
   ```

4. **Check the draft** in the repository's Releases: the notes, the two images
   (`sprixe-bios-X.Y.Z.rom`, `sprixe-bios-X.Y.Z-byteswapped.bin`) and `SHA256SUMS`. Then publish it.

The notes are the version's section of `CHANGELOG.md`, followed by a table of CRC32, 16-bit byte
sum and SHA-256 for each image (`build/release.py`). To preview them locally, before tagging, on an
image built from the release commit:

```bash
python3 -I build/release.py X.Y.Z sprixe-bios.sp1 dist
```

`dist/` is ignored by git. Entries must use inline links, `[text](url)`: link definitions are
stripped from the notes, since the ones at the bottom of the file would otherwise end up there.

## The first release, 0.1.0

`CHANGELOG.md` already holds a `## [0.1.0] - Unreleased` section summarising the whole BIOS. For
0.1.0, move the entries of `## [Unreleased]` into it, merged under the same `###` headings (one
`### Added`, one `### Fixed`…), date its heading, and leave an empty `## [Unreleased]` above.

## If the workflow fails

A run that fails before its last step creates no release. Fix the cause on `main` through a pull
request, then move the tag to the new commit (`git tag -d vX.Y.Z`, `git push origin :refs/tags/vX.Y.Z`,
tag again) — only while nothing has been published from it.

A draft that is wrong (its notes, for example) is deleted first (`gh release delete vX.Y.Z`): the
workflow refuses to create a second release for a tag that already has one. Then fix `main` and move
the tag as above.
