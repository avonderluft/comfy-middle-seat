# frozen_string_literal: true

require_relative '../../../../../test_helper'

class Comfy::Admin::Cms::Revisions::PageControllerTest < ActionDispatch::IntegrationTest
  setup do
    @site     = comfy_cms_sites(:default)
    @page     = comfy_cms_pages(:default)
    @revision = comfy_cms_revisions(:page)
  end

  def test_get_index
    r :get, comfy_admin_cms_site_page_revisions_path(@site, @page)
    assert_response :redirect
    assert_redirected_to action: :show, id: @revision
  end

  def test_get_index_with_no_revisions
    Comfy::Cms::Revision.delete_all
    r :get, comfy_admin_cms_site_page_revisions_path(@site, @page)
    assert_response :redirect
    assert_redirected_to edit_comfy_admin_cms_site_page_path(@site, @page)
  end

  def test_get_show
    r :get, comfy_admin_cms_site_page_revision_path(@site, @page, @revision)
    assert_response :success
    assert assigns(:record)
    assert assigns(:revision)
    assert assigns(:record).is_a?(Comfy::Cms::Page)
    assert_template :show
  end

  def test_get_show_describes_selected_snapshot_and_current_content
    replaced_at = Time.zone.parse('2024-05-06 07:08:09 UTC')
    @revision.update_column(:created_at, replaced_at)

    r :get, comfy_admin_cms_site_page_revision_path(@site, @page, @revision)

    assert_response :success
    assert_select '.revision-summary h3', "Selected revision ##{@revision.id}"
    assert_select '.revision-summary', text: %r{snapshot contains the content that was replaced at 2024-05-06 07:08:09 UTC}
    assert_select '.revision-legend-item', count: 2
    assert_select '.revision-legend-item', text: 'Added since snapshot'
    assert_select '.revision-legend-item', text: 'Removed since snapshot'
    assert_select '.label', text: 'Selected snapshot'
    assert_select '.label', text: 'Current saved content (changes highlighted)'
    assert_select '.box.revisions a', text: "Revision ##{@revision.id} — snapshot replaced at 2024-05-06 07:08:09 UTC"
    assert_select "a[target='comfy-cms-revision-preview'][href$='/revisions/#{@revision.id}/preview']",
                  text: 'Preview selected snapshot'
  end

  def test_get_show_includes_historical_only_fragments
    data = @revision.data.deep_dup
    data['fragments_attributes'] << {
      'identifier' => 'retired',
      'tag' => 'text',
      'content' => 'retired historical content'
    }
    @revision.update!(data: data)

    r :get, comfy_admin_cms_site_page_revision_path(@site, @page, @revision)

    assert_response :success
    assert_nil assigns(:current_content)['retired']
    assert_equal 'retired historical content', assigns(:versioned_content)['retired']
    assert_select '.revision .label', text: 'retired'
    assert_match %r{retired historical content}, response.body
  end

  def test_get_preview_renders_historical_fragments_without_persistence
    @site.update_column(:locale, 'de')
    @page.layout.update_columns(
      content: '{{cms:text retired}}',
      app_layout: 'comfy/admin/cms'
    )
    @revision.update!(
      data: {
        'fragments_attributes' => [{
          'identifier' => 'retired',
          'tag' => 'text',
          'content' => 'historical preview content'
        }]
      }
    )
    original_fragments = @page.fragments.order(:identifier).pluck(:identifier, :tag, :content)
    original_updated_at = @page.reload.updated_at
    original_revision_count = @page.revisions.count

    assert_no_difference -> { Comfy::Cms::Page.count } do
      assert_no_difference -> { Comfy::Cms::Fragment.count } do
        assert_no_difference -> { Comfy::Cms::Revision.count } do
          path = preview_comfy_admin_cms_site_page_revision_path(@site, @page, @revision)
          r :get, path
        end
      end
    end

    assert_response :success
    assert_match %r{historical preview content}, response.body
    assert_equal 'text/html; charset=utf-8', response.content_type
    assert_equal '0', response.headers['X-XSS-Protection']
    assert_equal :de, I18n.locale
    assert_equal @site, assigns(:cms_site)
    assert_equal @page.layout, assigns(:cms_layout)
    assert_equal assigns(:record), assigns(:cms_page)
    assert_select 'body.c-comfy-admin-cms-revisions-page.a-preview'

    @page.reload
    assert_equal original_updated_at, @page.updated_at
    assert_equal original_revision_count, @page.revisions.count
    assert_equal original_fragments, @page.fragments.order(:identifier).pluck(:identifier, :tag, :content)
    assert_not @page.fragments.exists?(identifier: 'retired')
  end

  def test_get_show_for_invalid_record
    r :get, comfy_admin_cms_site_page_revision_path(@site, 'invalid', @revision)
    assert_response :redirect
    assert_redirected_to comfy_admin_cms_site_pages_path(@site)
    assert_equal 'Record Not Found', flash[:danger]
  end

  def test_get_show_failure
    r :get, comfy_admin_cms_site_page_revision_path(@site, @page, 'invalid')
    assert_response :redirect
    assert assigns(:record)
    assert_redirected_to edit_comfy_admin_cms_site_page_path(@site, assigns(:record))
    assert_equal 'Revision Not Found', flash[:danger]
  end

  def test_revert
    assert_difference -> { @page.revisions.count } do
      r :patch, revert_comfy_admin_cms_site_page_revision_path(@site, @page, @revision)
      assert_response :redirect
      assert_redirected_to edit_comfy_admin_cms_site_page_path(@site, @page)
      assert_equal 'Content Reverted', flash[:success]

      @page.reload

      assert_equal [
        { identifier: 'boolean',
          tag: 'checkbox',
          content: nil,
          datetime: nil,
          boolean: true },
        { identifier: 'file',
          tag: 'file',
          content: nil,
          datetime: nil,
          boolean: false },
        { identifier: 'datetime',
          tag: 'datetime',
          content: nil,
          datetime: comfy_cms_fragments(:datetime).datetime,
          boolean: false },
        { identifier: 'content',
          tag: 'text',
          content: 'old content',
          datetime: nil,
          boolean: false },
        { identifier: 'title',
          tag: 'text',
          content: 'old title',
          datetime: nil,
          boolean: false }
      ], @page.fragments_attributes
    end
  end
end
