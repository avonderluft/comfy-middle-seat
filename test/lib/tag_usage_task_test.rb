# frozen_string_literal: true

require_relative '../test_helper'
require 'rake'

class TagUsageTaskTest < ActiveSupport::TestCase
  setup do
    @original_rake_application = Rake.application
    @original_env = %w[SITE FORMAT].to_h { |key| [key, ENV.fetch(key, nil)] }
    %w[SITE FORMAT].each { |key| ENV.delete(key) }
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load File.expand_path('../../lib/tasks/cms_tag_usage.rake', __dir__)
    @task = Rake::Task['comfy:cms:tag_usage']
    @sites = mock('all sites relation')
    @report = {
      scope: 'all_sites',
      sites: [{ id: 1, identifier: 'main', label: 'Main' }, { id: 2, identifier: 'other', label: 'Other' }],
      source_count: 3,
      complete: true,
      entries: [],
      warnings: []
    }
  end

  teardown do
    Rake.application = @original_rake_application
    @original_env.each { |key, value| ENV[key] = value }
  end

  def test_defaults_to_text_and_all_sites_after_loading_environment
    environment_loaded = false
    Rake::Task[:environment].enhance { environment_loaded = true }
    Comfy::Cms::Site.expects(:all).with do
      environment_loaded
    end.returns(@sites)
    expect_scan

    stdout, stderr = invoke_task

    assert_includes stdout, "Tag usage — all sites\nSites: \"main\", \"other\"\n"
    assert_includes stdout, "Sources scanned: 3\nScan complete."
    assert_empty stderr
  end

  def test_loading_the_task_twice_emits_only_one_json_report
    load File.expand_path('../../lib/tasks/cms_tag_usage.rake', __dir__)
    ENV['FORMAT'] = 'json'
    Comfy::Cms::Site.expects(:all).once.returns(@sites)
    expect_scan

    stdout, stderr = invoke_task

    assert_equal 1, @task.actions.size
    assert_equal JSON.parse(JSON.generate(@report)), JSON.parse(stdout)
    assert_empty stderr
  end

  def test_explicit_text_format
    ENV['FORMAT'] = 'text'
    Comfy::Cms::Site.expects(:all).returns(@sites)
    expect_scan

    stdout, stderr = invoke_task

    assert_includes stdout, 'Counts are saved source fields, not runtime executions.'
    assert_empty stderr
  end

  def test_json_is_clean_machine_readable_report
    ENV['FORMAT'] = 'json'
    Comfy::Cms::Site.expects(:all).returns(@sites)
    expect_scan

    stdout, stderr = invoke_task

    assert_equal JSON.parse(JSON.generate(@report)), JSON.parse(stdout)
    assert_empty stderr
  end

  def test_config_outputs_candidates_including_blocked_names_and_review_warning
    ENV['FORMAT'] = 'config'
    @report[:entries] = [{ kind: 'helper', name: 'send', status: 'blocked', sources: [] }]
    Comfy::Cms::Site.expects(:all).returns(@sites)
    expect_scan
    ComfyMiddleSeat.expects(:configure).never

    stdout, stderr = invoke_task

    assert_includes stdout, '# Discovery is not security approval; blocked names are included.'
    assert_includes stdout, "  config.allowed_helpers = [\n    \"send\",\n  ]"
    assert_includes stdout, 'config.allowed_partials = []'
    assert_includes stdout, 'config.allowed_templates = []'
    assert_empty stderr
  end

  def test_site_filter_passes_only_the_selected_relation_and_scope_to_scanner
    ENV['SITE'] = 'other'
    ENV['FORMAT'] = 'json'
    selected_sites = mock('selected sites relation')
    Comfy::Cms::Site.expects(:all).returns(@sites)
    @sites.expects(:where).with(identifier: 'other').returns(selected_sites)
    selected_sites.expects(:exists?).returns(true)
    @report[:scope] = 'selected_sites'
    @report[:sites] = [@report[:sites].last]
    expect_scan(sites: selected_sites, scope: 'selected_sites')

    stdout, stderr = invoke_task

    json = JSON.parse(stdout)
    assert_equal 'selected_sites', json.fetch('scope')
    assert_equal(['other'], json.fetch('sites').map { |site| site.fetch('identifier') })
    assert_empty stderr
  end

  def test_site_filtered_config_warns_that_candidates_are_not_application_wide
    ENV['SITE'] = 'main'
    ENV['FORMAT'] = 'config'
    selected_sites = mock('selected sites relation')
    Comfy::Cms::Site.expects(:all).returns(@sites)
    @sites.expects(:where).with(identifier: 'main').returns(selected_sites)
    selected_sites.expects(:exists?).returns(true)
    @report[:scope] = 'selected_sites'
    @report[:sites] = [@report[:sites].first]
    expect_scan(sites: selected_sites, scope: 'selected_sites')

    stdout, stderr = invoke_task

    assert_includes stdout, '# Scope: selected sites. Sites: "main"'
    assert_includes stdout, '# Site-filtered report: NOT a complete application-wide allowlist.'
    assert_empty stderr
  end

  def test_unknown_site_fails_without_scanning_or_falling_back_to_all_sites
    assert_rejected_site('missing')
  end

  def test_blank_site_fails_instead_of_defaulting_to_all_sites
    ['', '   '].each { |identifier| assert_rejected_site(identifier) }
  end

  def test_invalid_or_blank_format_fails_before_querying_sites_or_scanning
    Comfy::Cms::Site.expects(:all).never
    ComfyMiddleSeat::Content::TagUsage.expects(:new).never

    ['', 'yaml', 'JSON', 'config;puts 1'].each do |format|
      ENV['FORMAT'] = format
      stdout, stderr = invoke_failing_task

      assert_empty stdout
      assert_equal "FORMAT must be text, json or config.\n", stderr
    end
  end

  def test_incomplete_json_prints_report_to_stdout_and_warnings_to_stderr_before_failing
    ENV['FORMAT'] = 'json'
    incomplete_report
    Comfy::Cms::Site.expects(:all).returns(@sites)
    expect_scan

    stdout, stderr = invoke_failing_task

    assert_equal JSON.parse(JSON.generate(@report)), JSON.parse(stdout)
    refute JSON.parse(stdout).fetch('complete')
    refute_includes stdout, 'Warning ('
    assert_equal <<~'WARNINGS', stderr
      Warning (site 1, layout 10, field "content"): "Cannot tokenize source\nreview content"
      Warning (site 2, page 20, field "body"): "Missing name"
      Tag usage scan incomplete; resolve warnings and scan again.
    WARNINGS
  end

  def test_incomplete_text_and_config_also_emit_output_warnings_and_nonzero_exit
    incomplete_report
    Comfy::Cms::Site.expects(:all).twice.returns(@sites)
    expect_scan(times: 2)

    { 'text' => 'Scan incomplete; review warnings.',
      'config' => '# INCOMPLETE SCAN: resolve warnings before using these lists.' }.each do |format, notice|
      ENV['FORMAT'] = format
      stdout, stderr = invoke_failing_task

      assert_includes stdout, notice
      refute_includes stdout, 'Warning ('
      assert_includes stderr, 'Warning (site 1, layout 10, field "content"):'
      assert_includes stderr, 'Warning (site 2, page 20, field "body"): "Missing name"'
      assert_includes stderr, 'Tag usage scan incomplete; resolve warnings and scan again.'
    end
  end

private

  def expect_scan(sites: @sites, scope: 'all_sites', times: 1)
    scanner = mock('tag usage scanner')
    ComfyMiddleSeat::Content::TagUsage.expects(:new).with(sites: sites, scope: scope).times(times).returns(scanner)
    scanner.expects(:call).times(times).returns(@report)
  end

  def invoke_task
    @task.reenable
    capture_io { @task.invoke }
  end

  def invoke_failing_task
    @task.reenable
    capture_io do
      error = assert_raises(SystemExit) { @task.invoke }
      refute error.success?
      refute_equal 0, error.status
    end
  end

  def assert_rejected_site(identifier)
    ENV['SITE'] = identifier
    selected_sites = mock('empty sites relation')
    Comfy::Cms::Site.expects(:all).returns(@sites)
    @sites.expects(:where).with(identifier: identifier).returns(selected_sites)
    selected_sites.expects(:exists?).returns(false)
    ComfyMiddleSeat::Content::TagUsage.expects(:new).never

    stdout, stderr = invoke_failing_task

    assert_empty stdout
    assert_equal "Unknown site identifier: #{identifier.inspect}\n", stderr
  end

  def incomplete_report
    @report[:complete] = false
    @report[:warnings] = [
      { source: { site_id: 1, type: 'layout', id: 10, field: 'content' }, message: "Cannot tokenize source\nreview content" },
      { source: { site_id: 2, type: 'page', id: 20, field: 'body' }, message: 'Missing name' }
    ]
  end
end
