[![Rails CI](https://github.com/avonderluft/comfy-middle-seat/actions/workflows/rubyonrails.yml/badge.svg)](https://github.com/avonderluft/comfy-middle-seat/actions/workflows/rubyonrails.yml) [![Test Coverage](https://img.shields.io/coverallsCoverage/github/avonderluft/comfy-middle-seat?branch=master&cacheSeconds=300)](https://coveralls.io/github/avonderluft/comfy-middle-seat?branch=master) [![Gem Version](https://img.shields.io/gem/v/comfy_middle_seat.svg?style=flat)](https://rubygems.org/gems/comfy_middle_seat) [![Gem Downloads](https://img.shields.io/gem/dt/comfy_middle_seat.svg?style=flat)](https://rubygems.org/gems/comfy_middle_seat) [![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/avonderluft/comfy-middle-seat?label=last%20release&color=seagreen)](https://github.com/avonderluft/comfy-middle-seat/releases)

# Comfy Middle Seat

*A self-hosted, embeddable CMS engine for Rails 7.2+, 8.x*

Add editor-managed pages, reusable layouts, rich text, Markdown, files, translations, search, and revision history to an existing Rails application—without moving your content into a separate service.

Comfy Middle Seat is actively maintained and continues the lineage of Comfortable Mexican Sofa and Comfortable Media Surfer. It keeps the memorable C.M.S. initials, with a new place to sit.  It all depend on who is sitting to your right and left.

[Quick Start](#quick-start) · [Features](#features) · [Documentation](#documentation) · [Upgrading](#upgrading) · [Contributing](#contributing)

## Why Comfy Middle Seat?

Choose Comfy Middle Seat when you want content editing inside your Rails application rather than a separate hosted CMS.

- Keep application code and CMS-rendered pages together.
- Own and host your content, database, and files.
- Use familiar Rails controllers, views, helpers, authentication, and authorization.
- Add CMS-managed pages without creating a separate frontend application.
- Extend or override the admin area using normal Rails conventions.

Comfy Middle Seat is best suited to Rails applications that render their own websites. It is not intended to be a hosted SaaS CMS or a JavaScript-first visual page builder.

## Features

### For content editors

- Hierarchical pages with fast, on-demand tree navigation.
- Rich text, Markdown, plain text, images, files, dates, numbers, checkboxes, and reusable snippets.
- Search across page titles, paths, and content.
- Searchable image and file selection inside the editor.
- Local draft recovery for Pages and Translations.
- Revision history with comparison, preview, and restore workflows.
- Page translations and multilingual publishing.
- Multi-site publishing from one installation.
- Controls to publish or unpublish child pages together.

### For Rails developers

- Drop-in Rails engine with configurable admin and public routes.
- Flexible layouts built with simple `{{ cms:... }}` content tags.
- Active Storage integration for files and images.
- CMS seed files for version-controlled starter content.
- Configurable authentication and authorization.
- Extendable admin views, controllers, helpers, and partials.
- Stable `comfy_cms_*` database tables for upgrades from Sofa and Surfer.
- CI coverage across current Ruby and Rails releases.

## Quick Start

Add the gem to your Rails application's `Gemfile`:

```ruby
gem "comfy_middle_seat", "~> 4.0"
```

Install the gem and generate the CMS:

```sh
bundle install
bin/rails active_storage:install
bin/rails generate comfy:cms
bin/rails db:migrate
bin/rails comfy:compile_assets
```

The generator adds the CMS routes and creates `config/initializers/comfy_middle_seat.rb`.

Make sure the public content route remains after your application's other routes so it does not capture them first:

```ruby
comfy_route :cms_admin, path: "/admin"
comfy_route :cms, path: "/"
```

Start Rails and open [http://localhost:3000/admin](http://localhost:3000/admin). The generated development credentials are `user` and `pass`.

> **Security:** Replace the default admin credentials or configure application authentication before exposing the admin area to a network.

### Basic configuration

Use the `ComfyMiddleSeat` namespace in `config/initializers/comfy_middle_seat.rb`:

```ruby
ComfyMiddleSeat.configure do |config|
  config.cms_title = "My CMS"
  config.admin_base_controller = "ApplicationController"
end

ComfyMiddleSeat::AccessControl::AdminAuthentication.username = "admin-user"
ComfyMiddleSeat::AccessControl::AdminAuthentication.password = "change-me"
```

The initializer documents additional options for authentication, authorization, revisions, locales, seeds, helpers, partials, and application integration.

## How content works

A Site defines a hostname, path, and language. Layouts define page structure and the fields editors can manage. For example:

```html
<div id="page">
  {{ cms:snippet header }}
  <div id="main">
    <div id="content">
      {{ cms:breadcrumbs }}
      {{ cms:siblings exclude: "search,comments" }}
      <hr/>
      {{ cms:markdown content }}
    </div>
  </div>
</div>
```

When an editor creates a Page using this Layout, the admin automatically presents fields for `title` and `content`. Content tags can also provide Markdown, files, images, dates, numbers, checkboxes, snippets, partials, helpers, navigation, and other reusable content.

## Compatibility and requirements

| Component | Support |
| --- | --- |
| Ruby | 3.2 or newer; CI tests 3.3, 3.4, and 4.0 |
| Rails | CI tests 7.2, 8.0, and 8.1 |
| Node.js | 18 or newer for asset compilation |
| File storage | Active Storage |
| Image processing | ImageMagick |

Pagination is provided by [Kaminari](https://github.com/amatsuda/kaminari). The admin uses Bootstrap, CodeMirror, and Redactor.

## Documentation

The [Comfortable Media Surfer Wiki](https://github.com/shakacode/comfortable-media-surfer/wiki) remains a reference for inherited CMS features while first-party Comfy Middle Seat documentation is expanded.

Useful starting points:

- [Content Tags](https://github.com/shakacode/comfortable-media-surfer/wiki/Content-Tags)
- [Multiple Sites](https://github.com/shakacode/comfortable-media-surfer/wiki/Sites)
- [CMS Seeds](https://github.com/shakacode/comfortable-media-surfer/wiki/CMS-Seeds)
- [Revision History](https://github.com/shakacode/comfortable-media-surfer/wiki/Revisions)
- [Extending the Admin Area](https://github.com/shakacode/comfortable-media-surfer/wiki/HowTo:-Reusing-Admin-Area)
- [Changelog](CHANGELOG.md)

When adapting upstream examples, use the `comfy_middle_seat` gem, `config/initializers/comfy_middle_seat.rb`, and the `ComfyMiddleSeat` Ruby namespace.

## Upgrading

### From Comfortable Media Surfer

1. Replace `comfortable_media_surfer` with `comfy_middle_seat` in the `Gemfile`. Do not include both gems.
2. Run `bundle install`.
3. Preview and run the standalone initializer converter from the Rails application root:

   ```sh
   bundle exec comfy-middle-seat-upgrade --dry-run
   bundle exec comfy-middle-seat-upgrade
   ```

4. Replace any remaining Ruby references from `ComfortableMediaSurfer` to `ComfyMiddleSeat`.

The converter renames `config/initializers/comfortable_media_surfer.rb` to `config/initializers/comfy_middle_seat.rb`, updates namespace references, and preserves the original as a `.bak` file. It refuses to overwrite an existing initializer or backup.

The existing `comfy_cms_*` tables, schema, and stored records are used as-is. No CMS database migration is required for this upgrade.

### From Comfortable Mexican Sofa

Upgrade the application to Rails 7.2 or newer, replace the old gem with `comfy_middle_seat`, run `bundle install`, generate or convert `config/initializers/comfy_middle_seat.rb`, and update application integrations to use `ComfyMiddleSeat`.

Sofa and Comfy Middle Seat use the same `comfy_cms_*` database table names, so the CMS tables do not need to be renamed.

### From Occams

Upgrade the application to Rails 7.2 or newer and replace Occams with `comfy_middle_seat`. Occams used different table names and namespace values, so its data requires conversion:

```sql
ALTER TABLE occams_cms_categories RENAME TO comfy_cms_categories;
ALTER TABLE occams_cms_categorizations RENAME TO comfy_cms_categorizations;
ALTER TABLE occams_cms_files RENAME TO comfy_cms_files;
ALTER TABLE occams_cms_fragments RENAME TO comfy_cms_fragments;
ALTER TABLE occams_cms_layouts RENAME TO comfy_cms_layouts;
ALTER TABLE occams_cms_pages RENAME TO comfy_cms_pages;
ALTER TABLE occams_cms_revisions RENAME TO comfy_cms_revisions;
ALTER TABLE occams_cms_sites RENAME TO comfy_cms_sites;
ALTER TABLE occams_cms_snippets RENAME TO comfy_cms_snippets;
ALTER TABLE occams_cms_translations RENAME TO comfy_cms_translations;
UPDATE comfy_cms_categories SET categorized_type = 'Comfy::Cms::Page' WHERE categorized_type = 'Occams::Cms::Page';
UPDATE comfy_cms_categorizations SET categorized_type = 'Comfy::Cms::Page' WHERE categorized_type = 'Occams::Cms::Page';
UPDATE comfy_cms_fragments SET record_type = 'Comfy::Cms::Page' WHERE record_type = 'Occams::Cms::Page';
UPDATE comfy_cms_fragments SET record_type = 'Comfy::Cms::Layout' WHERE record_type = 'Occams::Cms::Layout';
UPDATE comfy_cms_fragments SET record_type = 'Comfy::Cms::Snippet' WHERE record_type = 'Occams::Cms::Snippet';
UPDATE comfy_cms_revisions SET record_type = 'Comfy::Cms::Page' WHERE record_type = 'Occams::Cms::Page';
UPDATE comfy_cms_revisions SET record_type = 'Comfy::Cms::Layout' WHERE record_type = 'Occams::Cms::Layout';
UPDATE comfy_cms_revisions SET record_type = 'Comfy::Cms::Snippet' WHERE record_type = 'Occams::Cms::Snippet';
UPDATE active_storage_attachments SET record_type = 'Comfy::Cms::File' WHERE record_type = 'Occams::Cms::File';
```

Back up the database and test this conversion outside production first.

## Project history

- [Comfortable Mexican Sofa](https://github.com/comfy/comfortable-mexican-sofa), created by Oleg Khabarov, established the original Rails CMS.
- [oCcaMS](https://github.com/avonderluft/occams) explored a revival after Sofa became inactive.
- [Comfortable Media Surfer](https://github.com/shakacode/comfortable-media-surfer), sponsored by ShakaCode, brought the project forward for current Rails versions.
- [Comfy Middle Seat](https://github.com/avonderluft/comfy-middle-seat) continues that work under its own namespace, release line, and maintenance direction.

See the [Changelog](CHANGELOG.md), [Sofa releases](https://github.com/comfy/comfortable-mexican-sofa/releases), and [Surfer releases](https://github.com/shakacode/comfortable-media-surfer/releases) for the complete inherited history.

## Add-ons

For blog functionality, see [ComfyBlog](https://github.com/comfy/comfy-blog).

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and pull-request guidance.

The main checks are:

```sh
bundle exec rake test
bundle exec rails test:system
bundle exec rubocop
```

Bug reports and focused feature proposals can be opened through [GitHub Issues](https://github.com/avonderluft/comfy-middle-seat/issues).

## Acknowledgements

- [Oleg Khabarov](https://github.com/GBH) and the contributors to [Comfortable Mexican Sofa](https://github.com/comfy/comfortable-mexican-sofa), the original Comfy CMS.
- [Andrew vonderLuft](https://github.com/avonderluft) for reviving Sofa with the [oCcaMS](https://github.com/avonderluft/occams) project, and carrying it forward.
- [ShakaCode](https://github.com/shakacode) for sponsoring the revived project as [Comfortable Media Surfer](https://github.com/shakacode/comfortable-media-surfer).
- [Roman Almeida](https://github.com/nasmorn) for contributing the OEM license for [Redactor Text Editor](https://imperavi.com/redactor/).

---

Copyright 2010-2019 Oleg Khabarov, 2024-2026 ShakaCode LLC, 2026 Andrew vonderLuft.

Released under the [MIT License](LICENSE).
