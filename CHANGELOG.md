# Changelog

All notable changes to this project's source code will be documented in this file. Items under `Unreleased` are upcoming features that will be out in the next version.

## Contributors

Please follow the recommendations outlined at [keepachangelog.com](https://keepachangelog.com). Please use the existing headings and styling as a guide, and add a link for the version diff at the bottom of the file. Also, please update the `Unreleased` link to compare it to the latest release version.

This changelog follows the project's lineage: **Comfortable Mexican Sofa → Comfortable Media Surfer → Comfy Middle Seat**. Version **3.2.0** is the first release published as `comfy_middle_seat`. The entries for **3.0.0–3.1.7** below are inherited from `comfortable_media_surfer` and retain their upstream links. For earlier history, see the [Comfortable Mexican Sofa releases](https://github.com/comfy/comfortable-mexican-sofa/releases).

## Comfy Middle Seat

## [Unreleased]

## [v4.0.1] - 2026-09-18

### Changed

- Remove unsaved-changes navigation warnings. Local draft recovery remains available for Pages and Translations.

## [v4.0.0] - 2026-09-18

### Added

- Search pages by title, path, or content, and find files and images in the editor.
- Restore or discard locally saved drafts for Pages and Translations.
- Preview Page and Translation revisions before restoring them.
- Add `comfy-middle-seat-upgrade` to convert legacy initializers with a backup.

### Changed

- Complete the rename from Comfortable Media Surfer to Comfy Middle Seat.
- Load page branches on demand and speed up page reordering.
- Preserve unsaved content when switching layouts; warn before discarding incompatible fields.
- Improve revision comparisons and prevent deletion of the root page.

**Upgrading:** Rename `config/initializers/comfortable_media_surfer.rb` to `comfy_middle_seat.rb` and replace `ComfortableMediaSurfer` Ruby references with `ComfyMiddleSeat`. Preview initializer conversion with `bundle exec comfy-middle-seat-upgrade --dry-run`. No database migration is required.

## [v3.2.1] - 2026-09-17

### Fixed

- Fix CI eager loading after the gem rename by excluding the explicitly required `comfy_middle_seat` entrypoint and version directory from Zeitwerk autoloading. Add a regression test that also checks eager loading outside CI.

### Changed

- At the time of this release, update the admin footer branding and repository link to Comfy Middle Seat while retaining the then-current `ComfortableMediaSurfer::VERSION` compatibility constant.
- Check that `COVERALLS_REPO_TOKEN` is configured before running the coverage job, with a clear error when it is missing.
- Document asset compilation and explicit test database setup, along with commands for running the main and browser/system test suites.
- Update README badges and release documentation, preserving the distinction between Seat releases and inherited Surfer history.

## [v3.2.0] - 2026-09-17

**First Comfy Middle Seat release.** Forked from [Comfortable Media Surfer](https://github.com/shakacode/comfortable-media-surfer), itself a revival of [Comfortable Mexican Sofa](https://github.com/comfy/comfortable-mexican-sofa). The new name keeps the C.M.S. initials and pays homage to the original.

### Changed

- Publish the gem as `comfy_middle_seat` and rename the gemspec to `comfy_middle_seat.gemspec`.
- At the time of v3.2.0, preserve the `ComfortableMediaSurfer` Ruby namespace and configuration while retaining the existing routes and database tables. The v4.0.0 namespace rename supersedes the Ruby compatibility behavior; the database compatibility remains unchanged.
- Move the version definition to `lib/comfy_middle_seat/version.rb` for release tooling, retaining a compatibility loader at the old path.
- Run the main test suite in six isolated processes by default, with merged coverage and a separate `test:serial` task for Coveralls.
- Update CI coverage to Rails 7.2, 8.0, and 8.1, with a separate browser/system test job.

### Added

- Add `lib/comfy_middle_seat.rb` so Bundler loads the existing implementation automatically under the new gem name.
- Add controls to publish and unpublish child pages from the admin interface.

### Fixed

- Strengthen site isolation for admin parameters, cross-site associations, asset lookup, reordering, categories, and fragment ownership.
- Fix file modal cleanup and reinitialization, and expose jQuery for Bootstrap integration.
- Remove the unsupported `:escape` option before JSON parsing while preserving other parser options.

### Historical v3.2.0 upgrade behavior

For v3.2.0, users replaced `comfortable_media_surfer` with `comfy_middle_seat` in the Gemfile while keeping the former Ruby namespace and initializer name. That release-specific compatibility guidance is preserved for history but is superseded by v4.0.0: current upgrades must rename the initializer to `config/initializers/comfy_middle_seat.rb` and replace `ComfortableMediaSurfer` Ruby references with `ComfyMiddleSeat`. Neither stage changes the database schema.

## Comfortable Media Surfer — inherited releases

The releases below belong to `comfortable_media_surfer`, not `comfy_middle_seat`. Their original notes and upstream comparison links are preserved.

## [v3.1.7] - 2026-02-20

### Fixed

- Fix wrong number of arguments for `to_s` in date tags from [PR 58](https://github.com/shakacode/comfortable-media-surfer/pull/58)

### Changed

- Update rubocop requirement from ~> 1.81.1 to ~> 1.84.0

## [v3.1.6] - 2026-02-19

### Added

- Claude code workflow

### Fixed

- problem creating root/home page from [P5 45](https://github.com/shakacode/comfortable-media-surfer/pull/45)

## [v3.1.5] - 2026-01-08

### Added

- Rails 8.1 compatibility

### Fixed

- Strip possible spaces around exclude page slugs, from [PR 42](https://github.com/shakacode/comfortable-media-surfer/pull/42)

### Changed

- gem updates for propshaft, brakeman, rubocop, haml-rails

## [v3.1.4] - 2025-07-14

### Fixed

- removed obsolete JQuery reference

### Changed

- updated gem versions
- update README for migration from Occams

## [v3.1.3] - 2025-05-29

### Fixed

- Fixed file descriptor leak during seeds import
- Fixed ‘Deep nesting of tags’ error for pages containing more than MAX_DEPTH tags
- Fixed importing pages with the same slug but different parents

## [v3.1.2] - 2025-05-26

### Fixed

- Fixed Expand/Collapse error in Admin/Pages.
- Include sassc-rails to gemspec, since it is deprecated after rails 7.0.8
- Update documentation to reflect recent changes

### Added

- added migration for Markdown snippets

## [v3.1.1] - 2025-02-08

### Fixed

- Fixed scss: use scss imports, not css ones that cannot be resolved by the browser

### Added

- Added rake task to compile assets, corresponding post install message
- Added import Rails from UJS
- Added missing jQuery import

### Removed

- Removed yarn, as not needed

## [v3.1.0] - 2024-12-31 (gem yanked, pending resolution of [Issue 8](https://github.com/shakacode/comfortable-media-surfer/issues/8)

### Added

- Added compatibility and support for Rails 8
- Added compatibility and support for propshaft (sprockets is still supported) - installing the gem now requires NodeJS to be installed. In addition, the `comfy:compile_assets` task needs to be run after installing the gem.

### Removed

- Removed sassc sprockets
- Rails 6.x compatibility dropped, since it is not being maintained as of October 2024

### Changed

- Updated README links to point to the Surfer wiki

## [v3.0.0] - 2024-11-30

First release of `comfortable_media_surfer`. This new gem is a revival of [ComfortableMexicanSofa](https://github.com/comfy/comfortable-mexican-sofa) which had been dormant for nearly 5 years.

### Fixed

- Fixed all broken tests to now pass on Rails 6.x and 7.x
- Code syntax per Rubocop linting

### Added

- Rails 7 compatibility, including many config and code changes. See the [PR](https://github.com/shakacode/comfortable-media-surfer/pull/1/files) for full details
- Added github actions workflows for CI build and test coverage
- Added CMS tags for navigation: children, siblings, breadcrumbs, with tests
- Added CMS tag for embedded audio, with tests
- Added CMS tag for image, with tests
- Added ability to write CMS snippets in Markdown, with tests

### Removed

- Rails 5 compatibility dropped, as it is EOL

### Changed

- Rebranded **ComfortableMexicanSofa** as **ComfortableMediaSurfer** in order to publish new gem (database table names and schema have not changed).

[Unreleased]: https://github.com/avonderluft/comfy-middle-seat/compare/v4.0.1...master
[v4.0.1]: https://github.com/avonderluft/comfy-middle-seat/compare/v4.0.0...v4.0.1
[v4.0.0]: https://github.com/avonderluft/comfy-middle-seat/compare/v3.2.1...v4.0.0
[v3.2.1]: https://github.com/avonderluft/comfy-middle-seat/compare/v3.2.0...v3.2.1
[v3.2.0]: https://github.com/avonderluft/comfy-middle-seat/compare/eeb5d590f47b5d6bb70191fb81c781540753fa97...v3.2.0
[v3.1.7]: https://github.com/shakacode/comfortable-media-surfer/compare/v3.1.6...v3.1.7
[v3.1.6]: https://github.com/shakacode/comfortable-media-surfer/compare/v3.1.5...v3.1.6
[v3.1.5]: https://github.com/shakacode/comfortable-media-surfer/compare/v3.1.4...v3.1.5
[v3.1.4]: https://github.com/shakacode/comfortable-media-surfer/compare/v3.1.3...v3.1.4
[v3.1.3]: https://github.com/shakacode/comfortable-media-surfer/compare/v3.1.2...v3.1.3
[v3.1.2]: https://github.com/shakacode/comfortable-media-surfer/compare/v3.1.1...v3.1.2
[v3.1.1]: https://github.com/shakacode/comfortable-media-surfer/compare/v3.1.0...v3.1.1
[v3.1.0]: https://github.com/shakacode/comfortable-media-surfer/compare/v3.0.0...v3.1.0
[v3.0.0]: https://github.com/shakacode/comfortable-media-surfer/compare/v2.0.19...v3.0.0
