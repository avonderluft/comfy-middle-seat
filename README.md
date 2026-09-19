[![Rails CI](https://github.com/avonderluft/comfy-middle-seat/actions/workflows/rubyonrails.yml/badge.svg)](https://github.com/avonderluft/comfy-middle-seat/actions/workflows/rubyonrails.yml) [![Test Coverage](https://img.shields.io/coverallsCoverage/github/avonderluft/comfy-middle-seat?branch=master&cacheSeconds=300)](https://coveralls.io/github/avonderluft/comfy-middle-seat?branch=master) [![Gem Version](https://img.shields.io/gem/v/comfy_middle_seat.svg?style=flat)](https://rubygems.org/gems/comfy_middle_seat) [![Gem Downloads](https://img.shields.io/gem/dt/comfy_middle_seat.svg?style=flat)](https://rubygems.org/gems/comfy_middle_seat) [![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/avonderluft/comfy-middle-seat?label=last%20release&color=seagreen)](https://github.com/avonderluft/comfy-middle-seat/releases)

# Comfy Middle Seat

It all depends on who is sitting on your left and on your right.

Comfy Middle Seat is a Rails CMS (Content Management System) engine, published as the `comfy_middle_seat` gem. It is descended from Comfortable Media Surfer and pays homage to the original Comfortable Mexican Sofa—with the same C.M.S. initials with a new place to sit.

The current implementation uses the `ComfyMiddleSeat` Ruby namespace, `comfy_middle_seat` internal paths, and the initializer `config/initializers/comfy_middle_seat.rb`. Database storage remains compatible: the existing `comfy_cms_*` tables and schema are unchanged, so this namespace change requires no database migration.

## Project History

- **[Comfortable Mexican Sofa](https://github.com/comfy/comfortable-mexican-sofa)**, created by Oleg Khabarov, is the original Rails CMS on which this project is built.  Oleg deserves the lion's share of kudos.
- **[oCcaMS](https://github.com/avonderluft/occams)** was an attempted revival of Sofa. Andrew vonderLuft was a contributor to [RadiantCMS](https://github.com/radiant/radiant) back in the day, but that project became inactive. He found Sofa and liked it even better than Radiant, but sadly it too became inactive. Hence Occams.
- **[Comfortable Media Surfer](https://github.com/shakacode/comfortable-media-surfer)** revived Sofa under the sponsorship of ShakaCode, continuing its development for modern Rails applications.
- **[Comfy Middle Seat](https://github.com/avonderluft/comfy-middle-seat)** began as a fork of Comfortable Media Surfer and is now implemented under its own `ComfyMiddleSeat` namespace and `comfy_middle_seat` paths.

See the [CHANGELOG](CHANGELOG.md) for the inherited development history, and the original [Sofa releases](https://github.com/comfy/comfortable-mexican-sofa/releases) and [Surfer releases](https://github.com/shakacode/comfortable-media-surfer/releases) for earlier releases.

## Features

- Simple drop-in integration with Rails 7.2+ apps with minimal configuration
* The CMS keeps clear from the rest of your application
* Powerful page templating capability using [Content Tags](https://github.com/shakacode/comfortable-media-surfer/wiki/Docs:-Content-Tags)
* [Multiple Sites](https://github.com/shakacode/comfortable-media-surfer/wiki/Sites) from a single installation
* Multi-Language Support (i18n) (ca, cs, da, de, en, es, fi, fr, gr, hr, it, ja, nb, nl, pl, pt-BR, ru, sv, tr, uk, zh-CN, zh-TW) and page localization.
* [CMS Seeds](https://github.com/shakacode/comfortable-media-surfer/wiki/CMS-Seeds) for initial content population
* [Revision History](https://github.com/shakacode/comfortable-media-surfer/wiki/Revisions) to revert changes
* [Extendable Admin Area](https://github.com/shakacode/comfortable-media-surfer/wiki/HowTo:-Reusing-Admin-Area) built with [Bootstrap 4](http://getbootstrap.com) (responsive design). Using [CodeMirror](http://codemirror.net) for HTML and Markdown highlighing and [Redactor](http://imperavi.com/redactor) as the WYSIWYG editor.

## Dependencies

- File attachments are handled by [ActiveStorage](https://github.com/rails/rails/tree/master/activestorage). Make sure that you can run appropriate migrations by running: `rails active_storage:install`
- Image resizing is done with with [ImageMagick](http://www.imagemagick.org/script/download.php), so make sure it's installed.
- Pagination is handled by [kaminari](https://github.com/amatsuda/kaminari).

## Compatibility

On Ruby 3.2+, 4.x, Rails 7.2+, 8.x

## Installation

Add gem definition to your Gemfile:

```ruby
gem "comfy_middle_seat", "~> 3.2.0"
```

Then, for a new installation, run these commands from the Rails project's root:

```sh
bundle install
rails generate comfy:cms
rails db:migrate
rails comfy:compile_assets
```

`rails db:migrate` is part of a new installation. Applications upgrading from Comfortable Media Surfer already have the same tables and schema and do not need a database migration for the gem, namespace, or internal-path rename.

Now take a look inside your `config/routes.rb` file. You'll see where routes attach for the admin area and content serving. Make sure that content serving route appears as a very last item or it will make all other routes to be inaccessible.

```ruby
comfy_route :cms_admin, path: "/admin"
comfy_route :cms, path: "/"
```

The generator creates `config/initializers/comfy_middle_seat.rb`. Use `ComfyMiddleSeat` for configuration and other library API references:

```ruby
ComfyMiddleSeat.configure do |config|
  config.cms_title = "My CMS"
  config.admin_base_controller = "ApplicationController"
end

ComfyMiddleSeat::AccessControl::AdminAuthentication.username = "user"
ComfyMiddleSeat::AccessControl::AdminAuthentication.password = "change-me"
```

## Converting from Comfortable Media Surfer, Comfortable Mexican Sofa, or Occams

### From Surfer to Middle Seat

1. Replace `comfortable_media_surfer` in your Gemfile with `comfy_middle_seat` and run `bundle install`. Do not include both gems.
2. From the Rails application root, preview and run the standalone initializer upgrader. It does not boot Rails:

   ```sh
   bundle exec comfy-middle-seat-upgrade --dry-run
   bundle exec comfy-middle-seat-upgrade
   ```

   It renames `config/initializers/comfortable_media_surfer.rb` to `config/initializers/comfy_middle_seat.rb`, updates the project namespace references inside it, and preserves the original as `config/initializers/comfortable_media_surfer.rb.bak`. It refuses to overwrite an existing initializer or backup.
3. In any other application integrations, replace Ruby references to `ComfortableMediaSurfer` with `ComfyMiddleSeat`.

For example:

```ruby
# Before
ComfortableMediaSurfer.configure do |config|
  config.cms_title = "My CMS"
end

# After
ComfyMiddleSeat.configure do |config|
  config.cms_title = "My CMS"
end
```

Review the converted initializer and remove its `.bak` file when satisfied. The database tables, schema, and stored records remain unchanged; existing `comfy_cms_*` tables are used as-is, and **no database migration is required** for this upgrade.

### From Sofa to Middle Seat

The database structure is the same, so no database migration is required for the CMS tables. Your Sofa project must first be upgraded to Rails 7.2 or newer. Then update the Gemfile, run `bundle install`, use `config/initializers/comfy_middle_seat.rb`, and update CMS library references in application code to `ComfyMiddleSeat`:

```ruby
gem "comfy_middle_seat", "~> 3.2.0"
```

### From Occams to Middle Seat

The project must be on Rails 7.2 or newer. Unlike Surfer and Sofa, Occams used different table names, so converting an Occams database requires the following SQL. This is an Occams data conversion, not a migration caused by the current `ComfyMiddleSeat` namespace or internal-path change.

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

## Quick Start Guide

After finishing installation you should be able to navigate to http://localhost:3000/admin

The default username and password are `user` and `pass`. Change them before exposing the application. Admin credentials and other CMS settings are configured in `config/initializers/comfy_middle_seat.rb` through the `ComfyMiddleSeat` namespace.

Before creating pages and populating them with content we need to create a Site. Site defines a hostname, content path and its language.

After creating a Site, you need to make a Layout. Layout is the template of your pages; it defines some reusable content (like header and footer, for example) and places where the content goes. A very simple layout can look like this:

```html
<html>
  <body>
    <h1>{{ cms:text title }}</h1>
    {{ cms:wysiwyg content }}
  </body>
</html>
```

Once you have a layout, you may start creating pages and populating content. It's that easy.

## Documentation

The [Comfortable Media Surfer Wiki](https://github.com/shakacode/comfortable-media-surfer/wiki) remains an upstream reference for inherited CMS features, including [Content Tags](https://github.com/shakacode/comfortable-media-surfer/wiki/Docs:-Content-Tags). These historical upstream links are intentionally preserved. When adapting its examples, use the `comfy_middle_seat` gem, `config/initializers/comfy_middle_seat.rb`, and the `ComfyMiddleSeat` Ruby namespace; upstream examples that use `ComfortableMediaSurfer` show the former API and must be updated.

## Add-ons

If you want to add a Blog functionality to your app take a look at
[ComfyBlog](https://github.com/comfy/comfy-blog).

![Admin Area Preview](doc/preview.jpg)


#### Contributing

Comfy Middle Seat can run like any Rails application in development. It's as easy to work on as any other Rails app. For more detail, see [CONTRIBUTING](CONTRIBUTING.md).

#### Testing

- `bin/rails db:migrate RAILS_ENV=test`
- `rake db:test:prepare`
- `rake test`

#### Acknowledgements

- To [Oleg Khabarov](https://github.com/GBH) and the contributors to [Comfortable Mexican Sofa](https://github.com/comfy/comfortable-mexican-sofa), the original CMS.
- To [ShakaCode](https://github.com/shakacode) and the contributors to [Comfortable Media Surfer](https://github.com/shakacode/comfortable-media-surfer), whose revival this fork builds on.
- To [Roman Almeida](https://github.com/nasmorn) for contributing OEM License for [Redactor Text Editor](http://imperavi.com/redactor).

---

Copyright 2010-2019 Oleg Khabarov, 2024-2026 ShakaCode LLC, 2026 Andrew vonderLuft.<br/>Released under the [MIT license](LICENSE)
