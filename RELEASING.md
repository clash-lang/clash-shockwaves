

# GIT setup
Development happens on the `main` branch, which has no assigned version.

Major releases branch off from here (i.e. `1.0`). Minor releases are released
on these branches.

# Releasing

## Major version
- Check that all changes have actually been merged to main,
  and that all pipelines succeed.
- Create a major version branch from `main`, called `<X>.<Y>`.

## Minor version
- Make sure all changes are on the major version branch.
  Either merge branches that branch off of the same point as the major release branch
  into the release branch (after also merging to `main`), or cherry-pick (squashed!)
  merges from `main`.

## Both

- Create a release branch (`release/<X>.<Y>.<Z>`).
- Update the version number in VERSION.
- Aggregate the changelog (in a **single separate** commit)
- Create a changelog update branch `changelog/<X>.<Y>.<Z>` on `main`,
  cherry-pick the previous commit, and create a PR.
- Create a PR from the release branch to the major release branch,
  and get it merged.
- Create a release on the major release branch.
  Include the changelog, checking that there are no relative links that break.
  Attach a new tag `v<X>.<Y>.<Z>`. This will trigger the release pipelines.
- Verify the release pipelines did not fail. If further corrections are required,
  they can be executed manually, and will try to upload artifacts to the release
  matching the version in the `VERSION` file.

# Bugfixes to older versions

## Backporting fixes
- Cherry-pick bugfix commits into the version branch.

## Version-specific bugs
- Update version branch through a branch+PR.

## Both
Go through standard release procedure.
