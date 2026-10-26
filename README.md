[![Rails CI](https://github.com/avonderluft/comfy-middle-seat/actions/workflows/rubyonrails.yml/badge.svg)](https://github.com/avonderluft/comfy-middle-seat/actions/workflows/rubyonrails.yml) [![Test Coverage](https://img.shields.io/coverallsCoverage/github/avonderluft/comfy-middle-seat?branch=master&cacheSeconds=300)](https://coveralls.io/github/avonderluft/comfy-middle-seat?branch=master) [![Gem Version](https://img.shields.io/gem/v/comfy_middle_seat.svg?style=flat)](https://rubygems.org/gems/comfy_middle_seat) [![Gem Downloads](https://img.shields.io/gem/dt/comfy_middle_seat.svg?style=flat)](https://rubygems.org/gems/comfy_middle_seat) [![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/avonderluft/comfy-middle-seat?label=last%20release&color=seagreen)](https://github.com/avonderluft/comfy-middle-seat/releases)

# Comfy Middle Seat

*A self-hosted, embeddable CMS engine for Rails 7.2+, 8.x*

Add editor-managed pages, reusable layouts, rich text, Markdown, files, translations, search, and revision history to an existing Rails application—without moving your content into a separate service.

Comfy Middle Seat is actively maintained and continues the lineage of Comfortable Mexican Sofa and Comfortable Media Surfer. It keeps the memorable C.M.S. initials, with a new place to sit.  It all depends on who is sitting to your right and left.

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
- Publish individual pages or whole branches, with ancestor-aware visibility.

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

### Descriptive tag aliases

These names are interchangeable; existing tags remain supported:

| Existing tag | Alias |
| --- | --- |
| `asset` | `layout_asset` |
| `partial` | `render_partial` |
| `template` | `render_template` |

```liquid
{{ cms:layout_asset main, type: css, as: tag }}
{{ cms:render_partial "layouts/embed_video", id: MYpbvXgpIzc }}
{{ cms:render_template "marketing/landing" }}
```

Aliases preserve all parameters, defaults, and existing allowlist behavior. No new allowlist requirement or content migration is introduced. Asset tags still require `type: css` or `type: js`; omitting the type does not default to CSS. Their URLs follow the configured Rails routes, not an independent manual override of `public_cms_path`. HTML attributes are preserved, though formatting may differ. Check for conflicts if your application already registers custom tags with these alias names.

### Tag usage audit

Open **Tag usage** in the admin navigation to list unique partials, helpers, and templates for the selected site. Expand **Used in** for source edit links. The report shows current permissions and candidate allowlists for review; it does not change permissions.

For an application-wide inventory, use the Rake task:

```sh
bin/rails comfy:cms:tag_usage
bin/rails comfy:cms:tag_usage SITE=default
bin/rails comfy:cms:tag_usage FORMAT=json
bin/rails comfy:cms:tag_usage FORMAT=config
```

`SITE` is a site identifier, not its numeric ID; omit it to scan all sites. `FORMAT` defaults to `text`. JSON includes source locations, scope, permissions, and warnings. Configuration output is a copyable initializer block. Both options can be combined.

The scanner reads saved layouts, snippets, page fragments, and translation fragments, including unpublished content. Aliases share one entry; counts refer to distinct source fields, not runtime executions. CMS comments are excluded. No helpers, views, ERB, or pages are executed, and caches are not read or updated.

**Review before applying candidate allowlists.** Discovered names—including currently blocked names—are not automatically safe. Allowlists are application-wide, so a single-site report is not sufficient for a multi-site installation. Replacing an allowlist blocks omitted names, including previously approved ones.

Warnings identify malformed comments or parameters. They go to stderr, and an incomplete scan exits nonzero while still emitting the partial report. JSON includes the warnings too; generated configuration marks incomplete scans. Unknown sites and unsupported formats also exit nonzero.

This is a source inventory, not runtime dependency analysis. It does not scan revisions, unsaved drafts, unimported seed files, layout CSS/JavaScript, application views, or dynamically generated tags. Restoring revisions or importing content can introduce new names; scan again afterward. Concurrent content edits are not a database snapshot, so rescan before changing permissions.

### Editor shortcuts

In HTML and Markdown code editors, type a shortcut and press **Tab** to insert a CMS tag. The parameter placeholder is selected so you can replace it immediately. For example, `;md` inserts `{{ cms:markdown content }}` with `content` selected.

Type **`;;` then Tab**, or press **Ctrl+Space**, for a searchable shortcut list. Search by shortcut or tag name: `c` prioritizes comment, children, and other `c` shortcuts; `p fl` finds `page_file_link`. Exact and prefix matches appear before fuzzy matches.

Use the arrow keys and **Enter** or **Tab** to choose. The tag replaces the entire trigger and search text. **Escape** closes the list without changing your text. Full names such as `;markdown` also work for direct expansion. One **Undo** reverses the expansion without removing what you typed.

| Shortcut | Inserts | Selected placeholder |
| --- | --- | --- |
| `;md` | `markdown` | `content` |
| `;tx` | `text` | `field` |
| `;ta` | `textarea` | `content` |
| `;wys` | `wysiwyg` | `content` |
| `;da` | `date` | `field` |
| `;dt` | `datetime` | `field` |
| `;num` | `number` | `field` |
| `;cb` | `checkbox` | `field` |
| `;fi` | `file`, as a link | `attachment` |
| `;fs` | `files`, as links | `attachments` |
| `;im` | `image` | `image label` |
| `;au` | `audio` | `path/to/audio` |
| `;fl` | `file_link`, as a link | `file_id` |
| `;pfl` | `page_file_link`, as a link | `attachment` |
| `;sn` | `snippet` | `identifier` |
| `;as`, `;css` | CSS `asset` tag | `layout_identifier` |
| `;js` | JavaScript `asset` tag | `layout_identifier` |
| `;hlp` | `helper` | `method_name` |
| `;par` | `partial` | `path/to/partial` |
| `;tpl` | `template` | `path/to/template` |
| `;cr` | `breadcrumbs` | — |
| `;ch` | `children` | — |
| `;si` | `siblings` | — |
| `;com` | Complete multiline comment block | `Comment here` |
| `;nt` | `comment "Note"` (also `;note`) | `Note` |
| `;ec` | `endcomment` | — |
| `;end` | `end` | — |

Placeholders are examples: replace them with your field names, identifiers, paths, or IDs. `;asset` inserts the CSS version; `;comment` inserts a full comment block. The descriptive aliases (`;layout_asset`, `;render_partial`, `;render_template`) also work for expansion and search, inserting the existing tag spellings.

Shortcuts work at the start of a line, after whitespace, or after `>`, outside an existing CMS tag. Unrecognized shortcuts retain normal Tab behavior. CSS, JavaScript, ordinary text fields, and visual editors are unchanged. Saved content uses the standard `{{ cms:... }}` syntax.

### CMS comments

Use a quoted note for a short comment:

```html
{{cms:comment "Replace this banner in December"}}
```

Use a block to hide a section, including any CMS tags inside it:

```html
{{cms:comment}}
Internal note: this section is not ready.
{{cms:markdown old_content}}
{{cms:snippet seasonal_banner}}
{{cms:endcomment}}
```

Comments produce no rendered output and do not create editor fields. Unlike HTML comments, enclosed CMS tags are not processed. Source text and existing field values remain stored; removing a comment restores normal processing.

Blocks may be nested and must end with `{{cms:endcomment}}`, not `{{cms:end}}`. Short notes accept single or double quotes, with backslash-escaped quotes. Unclosed blocks and malformed comment tags raise a clear syntax error. Comments work in layouts, snippets, and rendered fragment content, including Markdown. They are not a place for secrets: original source remains available to editors and may be exposed by APIs that include raw content.

### Image resizing

Resize images from the media library or page attachments without changing the originals:

```liquid
{{ cms:image "Homepage banner", resize_to_limit: "1600x600" }}
{{ cms:file card_photo, as: image, resize_to_fill: "600x400" }}
{{ cms:image "Product photo", resize_and_pad: "500x500" }}
```

The same options work with `file`, `files`, `image`, `file_link`, and `page_file_link`:

| Option | Result |
| --- | --- |
| `resize_to_limit` | Fit within the dimensions; never enlarge. |
| `resize_to_fit` | Fit within the dimensions; allow enlargement. |
| `resize_to_fill` | Fill the exact dimensions with a centered crop. |
| `resize_and_pad` | Fit the whole image into the exact dimensions with padding. |

Specify one operation and positive dimensions as `"WIDTHxHEIGHT"`. Invalid values, conflicting operations, and dimensions above the configured limit raise an error. Padding uses the processor's defaults; its color/transparency can differ between processors and image formats. Sizing options are ignored for missing attachments and files that Active Storage cannot transform, such as PDFs and SVGs under its default configuration. Missing attachments render nothing; non-transformable files retain their original URLs.

The default maximum requested width or height is 4096 pixels. Change it in `config/initializers/comfy_middle_seat.rb`:

```ruby
ComfyMiddleSeat.configure do |config|
  config.max_image_dimension = 6000
end
```

This limits requested tag dimensions, not upload sizes or all intermediate processing memory. Admin thumbnails use fixed sizes.

The CMS respects your application's Active Storage processor. Use ImageMagick with `:mini_magick`, or install libvips and add `ruby-vips` to your application's Gemfile, then configure:

```ruby
# config/application.rb, inside your application class
config.active_storage.variant_processor = :vips
```

Restart after changing processors. No processor switch is required to use the new options; the gem retains its existing MiniMagick dependency for compatibility.

#### Existing image tags

- `resize: "400x300"` translates to `resize_to_fit`; `resize: "400x300>"` translates to `resize_to_limit`. Both work with either processor.
- Supported legacy combinations of `resize`, `gravity`, and `crop` retain their operation order under MiniMagick. Resize accepts `WxH` with an optional `>`, `<`, `!`, or `^` suffix; crop requires `WxH+X+Y` (signed offsets). Offset-free crops are rejected because ImageMagick treats them as tiling, not a single crop. Gravity accepts the standard compass positions and `center`.
- Other legacy geometry, including percentages and one-dimensional sizes, raises an actionable error. Replace it with an explicit two-dimensional operation. The size limit applies to legacy dimensions too.
- Complex legacy expressions are not silently approximated on Vips. Convert them before switching processors; do not mix legacy and modern options in a tag.

After upgrading, clear rendered page and translation caches once so image links use the new transformations:

```ruby
Comfy::Cms::Page.update_all(content_cache: nil)
Comfy::Cms::Translation.update_all(content_cache: nil)
```

No database migration or re-upload is needed. New variants are generated on demand and may increase storage use temporarily; originals and old variants are not deleted. Purge any external page/CDN HTML caches separately. Clear rendered caches again after changing the sizing policy. Active Storage's variant keys do not include the processor: switching processors reuses existing variants with the same options, even after clearing page caches. To regenerate those images with the new processor, invalidate the affected derived variants separately, preserving the original uploads, and clear any cached derivative files on your CDN.

### Publishing pages

A page is publicly visible only when it and all its ancestors are published. Unpublishing a parent hides its branch without changing descendants’ individual publication settings. Republishing the parent restores only descendants whose full ancestor chain is published; drafts stay unpublished. Translations must also satisfy their own publication settings.

The Page index toggle changes only that page. The **Child pages** menu’s **Publish descendants** and **Unpublish descendants** actions change all descendants, not the current page or its ancestors. The admin marks published pages hidden by an unpublished ancestor.

Development mode continues to show unpublished pages for preview. Check public visibility in test, staging, or production mode.

## Compatibility and requirements

| Component | Support |
| --- | --- |
| Ruby | 3.2 or newer; CI tests 3.3, 3.4, and 4.0 |
| Rails | CI tests 7.2, 8.0, and 8.1 |
| Node.js | 18 or newer for asset compilation |
| File storage | Active Storage |
| Image processing | ImageMagick or libvips (via Active Storage) |

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

### Ancestor-aware publishing (unreleased)

Review branches with unpublished ancestors: their descendants will no longer be publicly accessible. No database migration is required. After deploying, clear existing rendered content once from the Rails console so cached navigation follows the new rule:

```ruby
Comfy::Cms::Page.update_all(content_cache: nil)
Comfy::Cms::Translation.update_all(content_cache: nil)
```

Content is regenerated on demand. Subsequent publication and parent changes refresh the affected site’s caches automatically.

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
