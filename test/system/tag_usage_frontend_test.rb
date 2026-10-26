# frozen_string_literal: true

require_relative '../test_helper'

class TagUsageFrontendTest < ApplicationSystemTestCase
  setup do
    @site = comfy_cms_sites(:default)
    @snippet = comfy_cms_snippets(:default)
    @snippet.update_column(:content, '{{cms:partial shared/card}}{{cms:render_partial shared/card}}')
  end

  def test_navigation_source_disclosure_and_candidate_configuration
    visit_p comfy_admin_cms_site_snippets_path(@site)
    click_link 'Tag usage'

    assert_selector 'h2', text: 'Tag usage'
    within '#tag-usage-partial' do
      assert_selector 'code', text: 'shared/card', count: 1
      assert_selector 'td', text: 'Allowed by default'
      assert_no_link href: edit_comfy_admin_cms_site_snippet_path(@site, @snippet)
      find('summary', text: 'Used in (1)').click
      assert_link href: edit_comfy_admin_cms_site_snippet_path(@site, @snippet)
    end
    config = find_field('Candidate configuration', readonly: true)
    assert_includes config.value, '"shared/card"'
    assert_includes config.value, 'NOT a complete application-wide allowlist'
  end

  def test_incomplete_scan_keeps_warning_and_valid_results_visible
    @snippet.update_column(:content, '{{cms:partial shared/card}}{{cms:helper}}')
    visit_p comfy_admin_cms_site_tag_usage_path(@site)

    assert_selector '.tag-usage-incomplete', text: 'Report incomplete.'
    assert_selector '#tag-usage-partial code', text: 'shared/card'
    within '#tag-usage-warnings' do
      assert_link href: edit_comfy_admin_cms_site_snippet_path(@site, @snippet)
      assert_text 'Missing, blank or non-string name'
    end
    assert_includes find_field('Candidate configuration', readonly: true).value, 'INCOMPLETE SCAN'
    assert_no_selector '.tag-usage-incomplete[data-cms-flash]'
  end
end
