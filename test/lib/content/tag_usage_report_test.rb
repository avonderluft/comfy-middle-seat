# frozen_string_literal: true

require_relative '../../test_helper'
require 'ripper'

class ContentTagUsageReportTest < ActiveSupport::TestCase
  setup do
    @source = { site_id: 1, type: 'layout', id: 10, label: 'Main', field: 'content', page_id: nil }
    @report = {
      scope: 'all_sites',
      sites: [{ id: 1, identifier: 'main', label: 'Main' }, { id: 2, identifier: 'other', label: 'Other' }],
      source_count: 7,
      complete: true,
      entries: [
        entry('template', 'pages/show', 'explicitly_allowed'),
        entry('partial', 'shared/zebra', 'blocked'),
        entry('helper', 'link_to', 'allowed_by_default'),
        entry('partial', 'shared/alpha', 'explicitly_allowed', [@source, @source.merge(id: 11)])
      ],
      warnings: []
    }
    @formatter = ComfyMiddleSeat::Content::TagUsageReport.new(@report)
  end

  def test_text_groups_and_sorts_names_with_statuses_and_source_counts
    assert_equal <<~TEXT, @formatter.text
      Tag usage — all sites
      Sites: "main", "other"
      Sources scanned: 7
      Scan complete.
      Counts are saved source fields, not runtime executions.

      Partials
        "shared/alpha" — Explicitly allowed — 2 source(s)
        "shared/zebra" — Blocked — 1 source(s)

      Helpers
        "link_to" — Allowed by default — 1 source(s)

      Templates
        "pages/show" — Explicitly allowed — 1 source(s)
    TEXT
  end

  def test_empty_inventory_still_reports_every_kind
    @report.merge!(sites: [], source_count: 0, entries: [])

    text = @formatter.text
    assert_includes text, "Sources scanned: 0\nScan complete."
    %w[Partials Helpers Templates].each do |heading|
      assert_includes text, "#{heading}\n  No matching tags found."
    end
    assert_equal [], @formatter.warnings
  end

  def test_json_preserves_the_entire_report_including_source_metadata_and_warnings
    @report[:complete] = false
    @report[:warnings] = [{ source: @source, message: "Cannot parse \"name\"\nnext line" }]
    @report[:entries] << entry('helper', "literal\#{name}", 'blocked')

    json = @formatter.json
    assert_equal JSON.parse(JSON.generate(@report)), JSON.parse(json)
    assert_includes json, "\n  \"scope\": \"all_sites\",\n"
    refute_includes json, 'Tag usage —'
    refute_includes json, 'Warning ('
  end

  def test_config_is_a_sorted_deduplicated_candidate_including_blocked_names
    @report[:entries] << entry('partial', 'shared/alpha', 'explicitly_allowed')

    assert_equal <<~RUBY, @formatter.config
      # Candidate allowlists only. Review every name before applying.
      # Discovery is not security approval; blocked names are included.
      # Replacing allowlists blocks omitted names, including existing approved uses.
      # Scope: all sites. Sites: "main", "other"
      ComfyMiddleSeat.configure do |config|
        config.allowed_partials = [
          "shared/alpha",
          "shared/zebra",
        ]
        config.allowed_helpers = [
          "link_to",
        ]
        config.allowed_templates = [
          "pages/show",
        ]
      end
    RUBY
  end

  def test_empty_config_assigns_empty_arrays_for_all_kinds
    @report[:entries] = []

    config = @formatter.config
    %w[partials helpers templates].each do |kind|
      assert_includes config, "  config.allowed_#{kind} = []\n"
    end
    refute_includes config, 'Site-filtered report'
    refute_includes config, 'INCOMPLETE SCAN'
    refute_nil Ripper.sexp(config)
  end

  def test_config_escapes_ruby_interpolation_newlines_quotes_and_backslashes
    name = "double\" single' backslash\\\n\#{raise \"must not execute\"} \#@instance \#$global"
    @report[:entries] = %w[partial helper template].map { |kind| entry(kind, name, 'blocked') }
    expected_literal = <<~'RUBY'.strip
      "double\" single' backslash\\\n\#{raise \"must not execute\"} \#@instance \#$global",
    RUBY

    config = @formatter.config
    assert_equal(3, config.lines.count { |line| line.strip == expected_literal })
    refute_includes config, "backslash\\\n"
    refute_nil Ripper.sexp(config)
  end

  def test_site_identifiers_and_text_names_cannot_inject_extra_lines
    @report[:sites].first[:identifier] = "main\"\nComfyMiddleSeat.configure {}"
    @report[:entries] = [entry('helper', "name\"\nnext", 'blocked')]

    assert_includes @formatter.text, '"name\"\nnext" — Blocked — 1 source(s)'
    [@formatter.text, @formatter.config].each do |output|
      assert_includes output, 'Sites: "main\"\nComfyMiddleSeat.configure {}", "other"'
      refute_includes output, "\nComfyMiddleSeat.configure {}"
    end
    refute_nil Ripper.sexp(@formatter.config)
  end

  def test_selected_scope_warns_that_config_is_not_application_wide
    @report[:scope] = 'selected_sites'
    @report[:sites] = [@report[:sites].first]

    assert_includes @formatter.text, "Tag usage — selected sites\nSites: \"main\"\n"
    assert_includes @formatter.config, '# Scope: selected sites. Sites: "main"'
    assert_includes @formatter.config, '# Site-filtered report: NOT a complete application-wide allowlist.'
    refute_includes @formatter.config, 'INCOMPLETE SCAN'
  end

  def test_incomplete_scan_warns_for_both_scopes_without_suppressing_candidates
    @report[:complete] = false

    %w[all_sites selected_sites].each do |scope|
      @report[:scope] = scope
      assert_includes @formatter.text, 'Scan incomplete; review warnings.'
      refute_includes @formatter.text, 'Scan complete.'
      assert_includes @formatter.config, '# INCOMPLETE SCAN: resolve warnings before using these lists.'
      assert_includes @formatter.config, '"shared/zebra",'
    end
  end

  def test_warnings_identify_sources_and_escape_fields_and_messages
    @report[:warnings] = [
      { source: @source, message: 'Cannot tokenize source' },
      { source: @source.merge(site_id: 2, type: 'translation', id: 20, field: "body\"\nnext"),
        message: "Cannot parse \"tag\"\nnext line" }
    ]

    assert_equal [
      'Warning (site 1, layout 10, field "content"): "Cannot tokenize source"',
      'Warning (site 2, translation 20, field "body\"\nnext"): "Cannot parse \"tag\"\nnext line"'
    ], @formatter.warnings
  end

  def test_formatting_does_not_execute_configuration_or_mutate_the_report
    before = Marshal.load(Marshal.dump(@report))
    ComfyMiddleSeat.expects(:configure).never
    ComfyMiddleSeat.expects(:config).never
    ComfyMiddleSeat::Content::TagUsage.expects(:new).never

    %i[text json config warnings].each do |format|
      assert_equal @formatter.public_send(format), @formatter.public_send(format)
    end
    assert_equal before, @report
  end

private

  def entry(kind, name, status, sources = [@source])
    { kind: kind, name: name, status: status, sources: sources }
  end
end
