# frozen_string_literal: true

require_relative '../../../../test_helper'

class Comfy::Admin::Cms::TagUsageControllerTest < ActionDispatch::IntegrationTest
  class DeniedController < Comfy::Admin::Cms::TagUsageController
    def authorize
      @authorized_site = @site
      head :forbidden
    end
  end

  class UnauthenticatedController < Comfy::Admin::Cms::TagUsageController
    def authenticate
      head :unauthorized
    end
  end

  setup do
    @site = comfy_cms_sites(:default)
    @layout = comfy_cms_layouts(:default)
    @snippet = comfy_cms_snippets(:default)
    @page = comfy_cms_pages(:default)
    @translation = comfy_cms_translations(:default)
    @fragment = comfy_cms_fragments(:default)
    @translated_fragment = comfy_cms_fragments(:translation)
    @path = comfy_admin_cms_site_tag_usage_path(@site)

    Comfy::Cms::Layout.update_all(content: '')
    Comfy::Cms::Snippet.update_all(content: '')
    Comfy::Cms::Fragment.update_all(content: nil)
  end

  def test_site_scoped_route_and_navigation
    assert_equal "/admin/sites/#{@site.id}/tag_usage", @path
    assert_recognizes({ controller: 'comfy/admin/cms/tag_usage', action: 'index', site_id: @site.id.to_s }, @path)

    r :get, @path
    assert_response :success
    assert_select 'nav a.nav-link.active[href=?]', @path, text: 'Tag usage'
    assert_select 'nav li:has(a[href=?]) + li a[href=?]', comfy_admin_cms_site_files_path(@site), @path
    assert_select 'h3', text: 'Partials'
    assert_select 'h3', text: 'Helpers'
    assert_select 'h3', text: 'Templates'
  end

  def test_site_isolation_including_warnings_and_config
    other_site = Comfy::Cms::Site.create!(identifier: 'other', hostname: 'other.example.com')
    other_site.snippets.create!(identifier: 'other', content: '{{cms:partial foreign_name}}{{cms:helper}}')
    @layout.update_column(:content, '{{cms:partial local_name}}')

    r :get, @path
    assert_response :success
    report = assigns(:report)
    assert_equal 'selected_sites', report[:scope]
    assert_equal([@site.id], report[:sites].map { |site| site[:id] })
    assert_equal(['local_name'], report[:entries].map { |entry| entry[:name] })
    assert report[:complete]
    assert_no_match 'foreign_name', response.body
    assert_select '#tag-usage-config', text: %r{local_name}

    r :get, comfy_admin_cms_site_tag_usage_path(other_site)
    assert_equal([other_site.id], assigns(:report)[:sites].map { |site| site[:id] })
    assert_equal(['foreign_name'], assigns(:report)[:entries].map { |entry| entry[:name] })
    assert_no_match 'local_name', response.body
    assert_select '.tag-usage-incomplete', count: 1
  end

  def test_unknown_site_does_not_scan_session_or_fallback_site
    r :get, @path
    ComfyMiddleSeat::Content::TagUsage.expects(:new).never

    assert_raises ActiveRecord::RecordNotFound do
      r :get, comfy_admin_cms_site_tag_usage_path(site_id: 'missing')
    end
  end

  def test_site_locale_session_and_admin_locale_override
    @site.update_column(:locale, 'fr')
    r :get, @path
    assert_response :success
    assert_equal @site.id, request.session[:site_id]
    assert_select 'h2', text: I18n.t('comfy.admin.cms.tag_usage.title', locale: :fr)

    ComfyMiddleSeat.config.admin_locale = :en
    r :get, @path
    assert_select 'h2', text: 'Tag usage'
  ensure
    I18n.locale = :en
  end

  def test_default_authentication_prevents_scanning
    ComfyMiddleSeat::Content::TagUsage.expects(:new).never
    get @path
    assert_response :unauthorized
  end

  def test_custom_authentication_hook_prevents_scanning
    ComfyMiddleSeat::Content::TagUsage.expects(:new).never
    with_routing do |routes|
      routes.draw do
        get '/tag-usage/:site_id' => 'comfy/admin/cms/tag_usage_controller_test/unauthenticated#index'
      end
      r :get, "/tag-usage/#{@site.id}"
      assert_response :unauthorized
    end
  end

  def test_custom_authorization_hook_receives_site_and_prevents_scanning
    ComfyMiddleSeat::Content::TagUsage.expects(:new).never
    with_routing do |routes|
      routes.draw do
        get '/tag-usage/:site_id' => 'comfy/admin/cms/tag_usage_controller_test/denied#index'
      end
      r :get, "/tag-usage/#{@site.id}"
      assert_response :forbidden
      assert_equal @site, assigns(:authorized_site)
    end
  end

  def test_unique_sorted_names_source_counts_and_edit_links
    content = '{{cms:partial zebra}}{{cms:partial shared/card}}{{cms:render_partial shared/card}}'
    @layout.update_column(:content, content)
    @snippet.update_column(:content, '{{cms:partial shared/card}}')
    @page.update_column(:is_published, false)
    @translation.update_column(:is_published, false)
    @fragment.update_columns(identifier: 'page_body', content: '{{cms:partial shared/card}}')
    @translated_fragment.update_columns(identifier: 'translated_body', content: '{{cms:partial shared/card}}')

    r :get, @path
    assert_response :success
    assert_select '#tag-usage-partial tbody tr > td:first-child code' do |names|
      assert_equal ['shared/card', 'zebra'], names.map(&:text)
    end
    assert_select '#tag-usage-partial tbody tr:first-child details' do
      assert_select 'summary', text: %r{Used in\s+\(4\)}
      assert_select 'li', count: 4
      assert_select 'a[href=?]', edit_comfy_admin_cms_site_layout_path(@site, @layout)
      assert_select 'a[href=?]', edit_comfy_admin_cms_site_snippet_path(@site, @snippet)
      assert_select 'a[href=?]', edit_comfy_admin_cms_site_page_path(@site, @page)
      assert_select 'a[href=?]', edit_comfy_admin_cms_site_page_translation_path(@site, @page, @translation)
      assert_select 'code', text: 'page_body'
      assert_select 'code', text: 'translated_body'
    end
  end

  def test_current_statuses
    ComfyMiddleSeat.config.allowed_partials = ['approved']
    @layout.update_column(:content, '{{cms:partial approved}}{{cms:partial denied}}{{cms:helper ordinary}}{{cms:template view}}')

    r :get, @path
    assert_select '#tag-usage-partial tr:has(code:contains("approved")) td', text: 'Explicitly allowed'
    assert_select '#tag-usage-partial tr:has(code:contains("denied")) td', text: 'Blocked'
    assert_select '#tag-usage-helper td', text: 'Allowed by default'
    assert_select '#tag-usage-template td', text: 'Allowed by default'
  end

  def test_no_matches_is_not_an_incomplete_report
    r :get, @path
    assert_response :success
    assert_select 'section p', text: 'No matching tags found.', count: 3
    assert_select '.tag-usage-incomplete', count: 0
    assert_select '#tag-usage-warnings', count: 0
  end

  def test_warnings_without_matches_include_source_edit_links
    @translated_fragment.update_column(:content, '{{cms:helper}}')

    r :get, @path
    assert_response :success
    assert_select '.tag-usage-incomplete', text: I18n.t('comfy.admin.cms.tag_usage.incomplete')
    assert_select 'section p', text: 'No matching tags found.', count: 3
    assert_select '#tag-usage-warnings' do
      assert_select 'a[href=?]', edit_comfy_admin_cms_site_page_translation_path(@site, @page, @translation)
      assert_select 'code', text: 'content'
      assert_select 'pre', text: %r{Missing, blank or non-string name}
    end
  end

  def test_config_is_formatter_output_in_a_readonly_textarea
    @layout.update_column(:content, '{{cms:partial shared/card}}')

    r :get, @path
    expected = ComfyMiddleSeat::Content::TagUsageReport.new(assigns(:report)).config
    assert_select 'textarea#tag-usage-config[readonly]', count: 1 do |fields|
      assert_equal expected.strip, fields.first.text.strip
    end
    assert_select '#tag-usage-config-warning', text: I18n.t('comfy.admin.cms.tag_usage.review')
    assert_select 'form', count: 0
  end

  def test_names_labels_fields_warnings_and_config_are_escaped
    payload = '</textarea><script>alert(1)</script>'
    @site.update_column(:label, payload)
    @layout.update_columns(label: payload, content: "{{cms:partial '#{payload}'}}{{cms:helper bad, [#{payload}}}")
    @fragment.update_columns(identifier: payload, content: "{{cms:partial '#{payload}'}}")

    r :get, @path
    assert_response :success
    assert_select '#tag-usage-partial tbody tr > td:first-child code', text: payload
    assert_select '#tag-usage-partial details a', text: %r{#{Regexp.escape(payload)}}
    assert_select '#tag-usage-partial details code', text: payload
    assert_select '#tag-usage-warnings pre', text: %r{#{Regexp.escape(payload)}}
    assert_select 'textarea#tag-usage-config', text: %r{#{Regexp.escape(payload)}}
    assert_no_match '<script>alert(1)</script>', response.body
    assert_includes response.body, '&lt;script&gt;'
  end
end
