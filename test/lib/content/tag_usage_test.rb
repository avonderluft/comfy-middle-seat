# frozen_string_literal: true

require_relative '../../test_helper'

class ContentTagUsageTest < ActiveSupport::TestCase
  SCANNER = ComfyMiddleSeat::Content::TagUsage

  setup do
    @site = comfy_cms_sites(:default)
    @layout = comfy_cms_layouts(:default)
    @snippet = comfy_cms_snippets(:default)
    @page = comfy_cms_pages(:default)
    @translation = comfy_cms_translations(:default)
    @fragment = comfy_cms_fragments(:default)
    @translated_fragment = comfy_cms_fragments(:translation)

    Comfy::Cms::Layout.update_all(content: '')
    Comfy::Cms::Snippet.update_all(content: '')
    Comfy::Cms::Fragment.update_all(content: nil)
  end

  def test_empty_inventory_and_source_count
    @fragment.update_column(:content, '')
    @translated_fragment.update_column(:content, 'plain text')

    assert_equal({
                   scope: 'all_sites',
                   sites: [site_details(@site)],
                   source_count: Comfy::Cms::Layout.count + Comfy::Cms::Snippet.count + 2,
                   complete: true,
                   entries: [],
                   warnings: []
                 }, SCANNER.new.call)
  end

  def test_aliases_parameters_and_sorted_entries
    @layout.update_column(:content, <<~CONTENT)
      {{cms:render_template 'Views/Show', locals: {items: [one, two]} }}
      {{cms:partial shared/Card, title: "A title", count: 2}}
      {{cms:helper link_to, 'Label', '/path', class: button}}
      {{cms:render_partial shared/Card}}
      {{cms:template 'Views/Show'}}
      {{cms:partial zebra}}
      {{cms:helper alpha}}
    CONTENT

    report = SCANNER.new.call
    assert report[:complete]
    assert_empty report[:warnings]
    assert_equal([
      ['helper', 'alpha'], ['helper', 'link_to'],
      ['partial', 'shared/Card'], ['partial', 'zebra'], ['template', 'Views/Show']
    ], report[:entries].map { |entry| [entry[:kind], entry[:name]] })
    report[:entries].each do |entry|
      assert_equal 'allowed_by_default', entry[:status]
      assert_equal [source(@layout, 'layout')], entry[:sources]
    end
  end

  def test_names_are_preserved_exactly
    @layout.update_column(:content, <<~'CONTENT')
      {{cms:partial ' Shared/Card '}}
      {{cms:partial Shared/Card}}
      {{cms:partial shared/card}}
      {{cms:partial './shared/card'}}
      {{cms:partial '123'}}
      {{cms:template “Smart/Quotes”}}
      {{cms:helper 'name#{raise "must not execute"}'}}
    CONTENT

    report = SCANNER.new.call
    assert report[:complete]
    assert_equal [
      ' Shared/Card ', './shared/card', '123', 'Shared/Card', 'Smart/Quotes',
      "name\#{raise \"must not execute\"}", 'shared/card'
    ].sort, report[:entries].map { |entry| entry[:name] }.sort
  end

  def test_same_name_is_distinct_for_each_kind
    @layout.update_column(:content, '{{cms:partial shared}}{{cms:helper shared}}{{cms:template shared}}')

    assert_equal(%w[helper partial template], SCANNER.new.call[:entries].map { |entry| entry[:kind] })
  end

  def test_comments_exclude_tags_and_invalid_parameters
    @layout.update_column(:content, <<~CONTENT)
      {{cms:comment "Ignore {{cms:partial short_note}} and {{cms:endcomment}}"}}
      {{cms:comment ‘Ignore {{cms:helper smart_note}}’}}
      {{cms:comment}}
        {{cms:partial hidden, invalid: [}}
        {{cms:helper}}
        {{cms:comment}}{{cms:template nested}}{{cms:endcomment}}
        {{cms:comment "Literal {{cms:endcomment}}"}}
        {{cms:unterminated
      {{cms:endcomment}}
      {{cms:partial visible}}
    CONTENT

    ComfyMiddleSeat::Content::ParamsParser.expects(:new).with('visible').returns(stub(params: ['visible'])).once

    report = SCANNER.new.call
    assert report[:complete]
    assert_empty report[:warnings]
    assert_equal(['visible'], report[:entries].map { |entry| entry[:name] })
  end

  def test_malformed_comments_warn_once_per_source_and_continue_other_sources
    malformed = [
      '{{cms:comment}}unclosed {{cms:partial hidden}}',
      '{{cms:endcomment}}',
      '{{cms:comment unquoted}}',
      '{{cms:comment "unterminated}}',
      '{{cms:comment "note" extra}}',
      '{{cms:comment}}hidden{{cms:endcomment extra}}',
      '{{cms:comment'
    ]
    @snippet.update_column(:content, '{{cms:helper still_scanned}}')
    malformed.each do |content|
      @layout.update_column(:content, "{{cms:partial before_error}}#{content}")
      report = SCANNER.new.call

      assert_equal false, report[:complete], content
      assert_equal ['still_scanned'], report[:entries].map { |entry| entry[:name] }, content
      assert_equal 1, report[:warnings].size, content
      warning = report[:warnings].first
      assert_equal source(@layout, 'layout'), warning[:source]
      assert_match 'Cannot tokenize source:', warning[:message]
      assert_match %r{comment}i, warning[:message]
    end
  end

  def test_parameter_errors_warn_per_token_and_continue_in_the_same_source
    @layout.update_column(:content, <<~CONTENT)
      {{cms:partial before}}
      {{cms:helper bad, [unclosed}}
      {{cms:template broken, value: %}}
      {{cms:helper after}}
    CONTENT
    @snippet.update_column(:content, '{{cms:template other_source}}')

    report = SCANNER.new.call
    assert_equal false, report[:complete]
    assert_equal(%w[after before other_source], report[:entries].map { |entry| entry[:name] })
    assert_equal 2, report[:warnings].size
    report[:warnings].each do |warning|
      assert_equal source(@layout, 'layout'), warning[:source]
      assert_match 'Cannot parse {{cms:', warning[:message]
    end
    assert_match 'Unclosed array param:', report[:warnings][0][:message]
    assert_match 'Unexpected char:', report[:warnings][1][:message]
  end

  def test_missing_blank_and_non_string_names_are_not_entries
    invalid_params = ['', '""', '"   "', '123', '[name]', 'name: value']
    tags = %w[partial render_partial helper template render_template]
    @layout.update_column(:content, tags.product(invalid_params).map { |tag, params| "{{cms:#{tag} #{params}}}" }.join)
    @snippet.update_column(:content, '{{cms:partial valid}}')

    report = SCANNER.new.call
    assert_equal false, report[:complete]
    assert_equal(['valid'], report[:entries].map { |entry| entry[:name] })
    assert_equal tags.size * invalid_params.size, report[:warnings].size
    report[:warnings].each do |warning|
      assert_equal source(@layout, 'layout'), warning[:source]
      assert_match 'Missing, blank or non-string name', warning[:message]
    end
  end

  def test_irrelevant_tokens_do_not_invoke_the_parameter_parser
    @layout.update_column(:content, <<~CONTENT)
      {{cms:unknown %}}{{cms:text [}}{{cms:snippet %}}
      {{cms:commentary %}}{{cms:endcomment_extra %}}
      {{cms:end}}{{cms:markdown}}{{cms:render_helper %}}
      plain text and {{not_cms:partial ignored}}
    CONTENT
    ComfyMiddleSeat::Content::ParamsParser.expects(:new).never

    report = SCANNER.new.call
    assert report[:complete]
    assert_empty report[:entries]
    assert_empty report[:warnings]
  end

  def test_all_raw_stores_including_unused_and_unpublished_content
    unused_layout = comfy_cms_layouts(:child)
    @page.update_column(:is_published, false)
    @translation.update_column(:is_published, false)
    @layout.update_column(:content, '{{cms:partial layout_path}}')
    unused_layout.update_column(:content, '{{cms:partial unused_layout}}')
    @snippet.update_columns(content: '{{cms:helper unused_snippet}}', markdown: true)
    @fragment.update_columns(content: '{{cms:template page_path}}', tag: 'wysiwyg')
    @translated_fragment.update_columns(content: '{{cms:template translated_path}}', tag: 'markdown')
    extra = @page.fragments.create!(identifier: 'not_in_layout', content: '{{cms:partial unused_fragment}}')

    report = SCANNER.new.call
    assert report[:complete]
    assert_equal 6, report[:entries].size
    assert_equal [source(@layout, 'layout')], entry(report, 'layout_path')[:sources]
    assert_equal [source(unused_layout, 'layout')], entry(report, 'unused_layout')[:sources]
    assert_equal [source(@snippet, 'snippet')], entry(report, 'unused_snippet')[:sources]
    assert_equal [source(@page, 'page', @fragment.identifier)], entry(report, 'page_path')[:sources]
    assert_equal [source(@translation, 'translation', @translated_fragment.identifier)], entry(report, 'translated_path')[:sources]
    assert_equal [source(@page, 'page', extra.identifier)], entry(report, 'unused_fragment')[:sources]
    assert_equal Comfy::Cms::Layout.count + Comfy::Cms::Snippet.count + 3, report[:source_count]
  end

  def test_sources_deduplicate_occurrences_but_keep_distinct_fields_and_owners
    content = '{{cms:partial shared}}{{cms:render_partial shared}}{{cms:partial shared, key: value}}'
    @layout.update_column(:content, content)
    @snippet.update_column(:content, content)
    @fragment.update_column(:content, content)
    @translated_fragment.update_column(:content, content)
    @page.fragments.create!(identifier: 'second', content: content)
    child = comfy_cms_pages(:child)
    child.fragments.create!(identifier: 'content', content: content)

    report = SCANNER.new.call
    assert_equal 1, report[:entries].size
    expected = [
      source(@layout, 'layout'), source(@snippet, 'snippet'),
      source(@page, 'page'), source(@page, 'page', 'second'),
      source(child, 'page'), source(@translation, 'translation')
    ]
    assert_equal expected.size, report[:entries].first[:sources].size
    expected.each { |item| assert_includes report[:entries].first[:sources], item }
  end

  def test_structured_fragment_content_is_ignored_for_pages_and_translations
    values = [nil, false, true, 123, ['{{cms:partial array}}'], { 'tag' => '{{cms:helper hash}}' }]
    [@page, @translation].each do |owner|
      values.each_with_index do |value, index|
        owner.fragments.create!(identifier: "structured_#{index}", content: value)
      end
    end
    @fragment.update_column(:content, '{{cms:partial string_content}}')

    report = SCANNER.new.call
    assert report[:complete]
    assert_empty report[:warnings]
    assert_equal(['string_content'], report[:entries].map { |entry| entry[:name] })
    assert_equal Comfy::Cms::Layout.count + Comfy::Cms::Snippet.count + 1, report[:source_count]
  end

  def test_fragments_owned_by_other_record_types_are_ignored
    Comfy::Cms::Fragment.create!(record: @snippet, identifier: 'foreign', content: '{{cms:partial ignored}}')

    assert_empty SCANNER.new.call[:entries]
  end

  def test_multiple_sites_and_relation_filter_include_only_selected_owners
    other_site, other_layout, other_snippet, other_page, other_translation = create_other_site
    @layout.update_column(:content, '{{cms:partial first_site}}')
    other_layout.update_column(:content, '{{cms:partial second_layout}}')
    other_snippet.update_column(:content, '{{cms:helper second_snippet}}')
    other_page.fragments.create!(identifier: 'body', content: '{{cms:template second_page}}')
    other_translation.fragments.create!(identifier: 'translated_body', content: '{{cms:template second_translation}}')

    report = SCANNER.new.call
    assert_equal [@site, other_site].sort_by(&:id).map { |site| site_details(site) }, report[:sites]
    assert_equal 5, report[:entries].size
    assert_equal [source(other_translation, 'translation', 'translated_body')], entry(report, 'second_translation')[:sources]

    selected = SCANNER.new(sites: Comfy::Cms::Site.where(id: other_site.id), scope: 'selected_sites').call
    assert_equal 'selected_sites', selected[:scope]
    assert_equal [site_details(other_site)], selected[:sites]
    assert_equal %w[second_layout second_page second_snippet second_translation], selected[:entries].map { |item| item[:name] }.sort
    assert_equal 4, selected[:source_count]
    selected[:entries].each do |item|
      assert(item[:sources].all? { |origin| origin[:site_id] == other_site.id })
    end

    @layout.update_column(:content, '{{cms:comment}}unclosed')
    assert SCANNER.new(sites: [other_site], scope: 'selected_sites').call[:complete]
    assert_equal false, SCANNER.new.call[:complete]
  end

  def test_site_arrays_are_deduplicated_and_custom_selections_default_to_filtered_scope
    @layout.update_column(:content, '{{cms:helper test}}')
    report = SCANNER.new(sites: [@site, @site]).call

    assert_equal 'selected_sites', report[:scope]
    assert_equal [site_details(@site)], report[:sites]
    assert_equal [source(@layout, 'layout')], report[:entries].first[:sources]
    assert_equal Comfy::Cms::Layout.count + Comfy::Cms::Snippet.count, report[:source_count]
  end

  def test_empty_site_selections_do_not_fall_back_to_all_sites
    @layout.update_column(:content, '{{cms:helper ignored}}')
    [[], Comfy::Cms::Site.none].each do |sites|
      assert_equal({
                     scope: 'selected_sites', sites: [], source_count: 0,
                     complete: true, entries: [], warnings: []
                   }, SCANNER.new(sites: sites, scope: 'selected_sites').call)
    end
  end

  def test_nil_and_non_array_allowlists_use_defaults_and_helper_blacklist
    names = ComfyMiddleSeat::Content::Tags::Helper::BLACKLIST + %w[ordinary send call Eval]
    @layout.update_column(:content, %w[partial helper template].product(names).map { |kind, name| "{{cms:#{kind} #{name}}}" }.join)

    [nil, false, true, 'ordinary', { 'ordinary' => true }].each do |allowed|
      configure_allowlists(allowed)
      report = SCANNER.new.call
      assert report[:complete]
      report[:entries].each do |item|
        blacklisted = item[:kind] == 'helper' && ComfyMiddleSeat::Content::Tags::Helper::BLACKLIST.include?(item[:name])
        assert_equal blacklisted ? 'blocked' : 'allowed_by_default', item[:status], "#{allowed.inspect}: #{item.inspect}"
      end
    end
  end

  def test_empty_arrays_block_all_kinds_without_making_inventory_incomplete
    configure_allowlists([])
    @layout.update_column(:content, '{{cms:partial path}}{{cms:helper method}}{{cms:template path}}')

    report = SCANNER.new.call
    assert report[:complete]
    assert_empty report[:warnings]
    assert_equal ['blocked'], report[:entries].map { |item| item[:status] }.uniq
  end

  def test_allowlists_are_independent_and_can_explicitly_allow_blacklisted_helpers
    ComfyMiddleSeat.config.allowed_partials = ['shared']
    ComfyMiddleSeat.config.allowed_helpers = ['eval']
    ComfyMiddleSeat.config.allowed_templates = []
    @layout.update_column(:content, <<~CONTENT)
      {{cms:partial shared}}{{cms:render_partial other}}
      {{cms:helper eval}}{{cms:helper shared}}
      {{cms:template shared}}{{cms:render_template other}}
    CONTENT

    assert_equal([
      %w[helper eval explicitly_allowed], %w[helper shared blocked],
      %w[partial other blocked], %w[partial shared explicitly_allowed],
      %w[template other blocked], %w[template shared blocked]
    ], SCANNER.new.call[:entries].map { |item| item.values_at(:kind, :name, :status) })
  end

  def test_symbol_allowlists_only_allow_helpers_without_mutating_frozen_or_mutable_arrays
    @layout.update_column(:content, <<~CONTENT)
      {{cms:helper symbol_name}}
      {{cms:partial symbol_name}}{{cms:render_partial symbol_alias}}
      {{cms:template symbol_name}}{{cms:render_template symbol_alias}}
    CONTENT

    [false, true].each do |frozen|
      allowed = %i[symbol_name symbol_alias]
      allowed.freeze if frozen
      configure_allowlists(allowed)

      report = SCANNER.new.call
      assert report[:complete]
      assert_empty report[:warnings]
      assert_equal([
        %w[helper symbol_name explicitly_allowed],
        %w[partial symbol_alias blocked], %w[partial symbol_name blocked],
        %w[template symbol_alias blocked], %w[template symbol_name blocked]
      ], report[:entries].map { |item| item.values_at(:kind, :name, :status) })
      %w[partial helper template].each do |kind|
        assert_same allowed, ComfyMiddleSeat.config.public_send("allowed_#{kind}s")
      end
      assert_equal %i[symbol_name symbol_alias], allowed
      assert_equal frozen, allowed.frozen?
    end
  end

  def test_allowlists_match_renderer_membership_without_mutation_even_when_frozen
    allowed = [:symbol_name, 123, 'Exact/Path', ' spaced ', 'wild/*', nil].freeze
    configure_allowlists(allowed)
    names = ['symbol_name', '123', 'Exact/Path', 'exact/path', ' spaced ', 'spaced', 'wild/path', 'wild/*']
    @layout.update_column(:content, %w[partial helper template].product(names).map { |kind, name| "{{cms:#{kind} '#{name}'}}" }.join)

    report = SCANNER.new.call
    assert report[:complete]
    report[:entries].each do |item|
      allowed_names = ['Exact/Path', ' spaced ', 'wild/*']
      allowed_names += %w[symbol_name 123] if item[:kind] == 'helper'
      assert_equal allowed_names.include?(item[:name]) ? 'explicitly_allowed' : 'blocked', item[:status]
    end
    %w[partial helper template].each do |kind|
      assert_same allowed, ComfyMiddleSeat.config.public_send("allowed_#{kind}s")
    end
    assert_equal [:symbol_name, 123, 'Exact/Path', ' spaced ', 'wild/*', nil], allowed
  end

  def test_each_call_reads_current_content_and_permissions_and_resets_warnings
    scanner = SCANNER.new
    @layout.update_column(:content, '{{cms:helper first}}{{cms:partial}}')
    first = scanner.call
    assert_equal false, first[:complete]

    @layout.update_column(:content, '{{cms:template second}}')
    ComfyMiddleSeat.config.allowed_templates = []
    second = scanner.call
    assert second[:complete]
    assert_empty second[:warnings]
    assert_equal(['second'], second[:entries].map { |item| item[:name] })
    assert_equal 'blocked', second[:entries].first[:status]
    assert_equal first[:source_count], second[:source_count]
    assert_equal(['first'], first[:entries].map { |item| item[:name] })
    assert_equal 1, first[:warnings].size
  end

  def test_warning_sources_identify_fragment_owners_and_fields
    @fragment.update_column(:content, '{{cms:helper}}')
    @translated_fragment.update_column(:content, '{{cms:comment}}unclosed')
    @snippet.update_column(:content, '{{cms:template valid}}')

    report = SCANNER.new.call
    assert_equal false, report[:complete]
    assert_equal([source(@page, 'page'), source(@translation, 'translation')], report[:warnings].map { |warning| warning[:source] })
    assert_equal(['valid'], report[:entries].map { |item| item[:name] })
  end

  def test_scanning_is_read_only_without_rendering_tag_instantiation_caches_or_erb_execution
    ComfyMiddleSeat.config.allow_erb = true
    @layout.update_columns(
      content: '<% raise "must not execute" %>{{cms:partial raw_layout}}{{cms:helper eval, "raise"}}',
      css: '{{cms:partial css_ignored}}', js: '{{cms:partial js_ignored}}'
    )
    @snippet.update_column(:content, '{{cms:template raw_snippet}}{{cms:snippet default}}')
    @fragment.update_column(:content, '{{cms:helper raw_page}}')
    @translated_fragment.update_column(:content, '{{cms:helper raw_translation}}')
    @page.update_column(:content_cache, '{{cms:partial page_cache_ignored}}')
    @translation.update_column(:content_cache, '{{cms:partial translation_cache_ignored}}')
    before = raw_snapshot

    ComfyMiddleSeat::Content::Renderer.any_instance.expects(:nodes).never
    ComfyMiddleSeat::Content::Renderer.any_instance.expects(:render).never
    ComfyMiddleSeat::Content::Renderer.expects(:tags).never
    ComfyMiddleSeat::Content::Tag.expects(:new).never
    [ComfyMiddleSeat::Content::Tags::Partial, ComfyMiddleSeat::Content::Tags::Template,
     ComfyMiddleSeat::Content::Tags::Helper, ComfyMiddleSeat::Content::Tags::Snippet].each do |klass|
      klass.expects(:new).never
    end
    [Comfy::Cms::Page, Comfy::Cms::Translation].each do |klass|
      klass.any_instance.expects(:content_cache).never
      klass.any_instance.expects(:render).never
    end
    Comfy::Cms::Layout.any_instance.expects(:content_tokens).never
    Rails.cache.expects(:fetch).never
    Rails.cache.expects(:read).never
    Rails.cache.expects(:write).never
    ERB.expects(:new).never

    report = nil
    queries = capture_queries { report = SCANNER.new.call }
    assert report[:complete]
    assert_equal %w[eval raw_layout raw_page raw_snippet raw_translation], report[:entries].map { |item| item[:name] }.sort
    assert_empty queries.grep(%r{\A\s*(INSERT|UPDATE|DELETE|REPLACE|CREATE|ALTER|DROP)}i)
    assert_equal before, raw_snapshot
  end

  def test_owner_and_fragment_queries_do_not_grow_per_record
    @fragment.update_column(:content, '{{cms:partial shared}}')
    @translated_fragment.update_column(:content, '{{cms:partial shared}}')
    initial_queries = capture_queries { SCANNER.new.call }

    5.times do |index|
      page = @site.pages.create!(layout: @layout, label: "Page #{index}", slug: "query-#{index}")
      translation = page.translations.create!(layout: @layout, label: "Translation #{index}", locale: 'fr')
      [page, translation].each do |owner|
        3.times { |field| owner.fragments.create!(identifier: "field_#{field}", content: '{{cms:partial shared}}') }
      end
    end

    report = nil
    expanded_queries = capture_queries { report = SCANNER.new.call }
    assert_equal initial_queries.size, expanded_queries.size
    assert_equal 32, report[:entries].first[:sources].size
  end

  def test_content_owners_and_fragments_are_scanned_across_batch_boundaries
    count = SCANNER::BATCH_SIZE + 1
    content = '{{cms:partial batched}}'
    [Comfy::Cms::Layout, Comfy::Cms::Snippet].each do |klass|
      klass.insert_all!(Array.new(count) do |index|
        { site_id: @site.id, label: "Batch #{index}", identifier: "batch_#{index}", content: content }
      end)
    end
    Comfy::Cms::Page.insert_all!(Array.new(count) do |index|
      { site_id: @site.id, layout_id: @layout.id, label: "Batch #{index}", full_path: "/batch-#{index}", is_published: false }
    end)
    pages = Comfy::Cms::Page.where(site_id: @site.id).where.not(id: [@page.id, comfy_cms_pages(:child).id]).pluck(:id)
    Comfy::Cms::Translation.insert_all!(pages.map do |id|
      { page_id: id, layout_id: @layout.id, label: "Batch #{id}", locale: 'fr', is_published: false }
    end)
    translations = Comfy::Cms::Translation.where(page_id: pages).pluck(:id)
    { Comfy::Cms::Page => pages, Comfy::Cms::Translation => translations }.each do |klass, ids|
      Comfy::Cms::Fragment.insert_all!(ids.map do |id|
        { record_type: klass.polymorphic_name, record_id: id, identifier: 'body', content: content }
      end)
    end
    # One owner also exceeds the fragment batch size independently of owner batching.
    Comfy::Cms::Fragment.insert_all!(Array.new(count) do |index|
      { record_type: Comfy::Cms::Page.polymorphic_name, record_id: @page.id, identifier: "batch_#{index}", content: content }
    end)

    report = nil
    queries = capture_queries { report = SCANNER.new.call }
    assert report[:complete]
    assert_equal 1, report[:entries].size
    assert_equal count * 5, report[:entries].first[:sources].size
    assert_equal Comfy::Cms::Layout.count + Comfy::Cms::Snippet.count + (count * 3), report[:source_count]
    assert_operator queries.size, :<, 60
    assert(queries.grep(%r{SELECT .*comfy_cms_fragments}i).all? { |sql| sql.match?(%r{LIMIT}i) })
  end

private

  def entry(report, name)
    report[:entries].find { |item| item[:name] == name }
  end

  def site_details(site)
    { id: site.id, identifier: site.identifier, label: site.label }
  end

  def source(record, type, field = 'content')
    {
      site_id: type == 'translation' ? record.page.site_id : record.site_id,
      type: type, id: record.id, label: record.label, field: field,
      page_id: type == 'translation' ? record.page_id : nil
    }
  end

  def configure_allowlists(value)
    ComfyMiddleSeat.config.allowed_partials = value
    ComfyMiddleSeat.config.allowed_helpers = value
    ComfyMiddleSeat.config.allowed_templates = value
  end

  def create_other_site
    site = Comfy::Cms::Site.create!(identifier: 'other', hostname: 'other.example.com', label: 'Other Site')
    layout = site.layouts.create!(identifier: 'other', label: 'Other Layout')
    snippet = site.snippets.create!(identifier: 'other', label: 'Other Snippet')
    page = site.pages.create!(layout: layout, label: 'Other Page', is_published: false)
    translation = page.translations.create!(layout: layout, label: 'Other Translation', locale: 'fr', is_published: false)
    [site, layout, snippet, page, translation]
  end

  def raw_snapshot
    [Comfy::Cms::Site, Comfy::Cms::Layout, Comfy::Cms::Snippet, Comfy::Cms::Page,
     Comfy::Cms::Translation, Comfy::Cms::Fragment, Comfy::Cms::Revision].to_h do |klass|
      [klass.name, klass.order(:id).pluck(*klass.column_names)]
    end
  end

  def capture_queries(&block)
    queries = []
    subscriber = ->(_name, _start, _finish, _id, payload) do
      queries << payload[:sql] unless payload[:name] == 'SCHEMA'
    end
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record', &block)
    end
    queries
  end
end
