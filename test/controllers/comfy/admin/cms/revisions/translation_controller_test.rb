# frozen_string_literal: true

require_relative '../../../../../test_helper'

class Comfy::Admin::Cms::Revisions::TranslationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @site         = comfy_cms_sites(:default)
    @page         = comfy_cms_pages(:default)
    @translation  = comfy_cms_translations(:default)
    @revision     = comfy_cms_revisions(:translation)
  end

  def test_get_index
    r :get, comfy_admin_cms_site_page_translation_revisions_path(@site, @page, @translation)
    assert_response :redirect
    assert_redirected_to action: :show, id: @revision
  end

  def test_get_index_with_no_revisions
    Comfy::Cms::Revision.delete_all
    r :get, comfy_admin_cms_site_page_translation_revisions_path(@site, @page, @translation)
    assert_response :redirect
    assert_redirected_to edit_comfy_admin_cms_site_page_translation_path(@site, @page, @translation)
  end

  def test_get_show
    r :get, comfy_admin_cms_site_page_translation_revision_path(@site, @page, @translation, @revision)
    assert_response :success
    assert assigns(:record)
    assert assigns(:revision)
    assert assigns(:record).is_a?(Comfy::Cms::Translation)
    assert_template :show
  end

  def test_get_show_includes_historical_only_fragments_and_preview_link
    data = @revision.data.deep_dup
    data['fragments_attributes'] << {
      'identifier' => 'retired',
      'tag' => 'text',
      'content' => 'retired translation content'
    }
    @revision.update!(data: data)

    r :get, comfy_admin_cms_site_page_translation_revision_path(@site, @page, @translation, @revision)

    assert_response :success
    assert_nil assigns(:current_content)['retired']
    assert_equal 'retired translation content', assigns(:versioned_content)['retired']
    assert_select '.revision .label', text: 'retired'
    assert_select "a[target='comfy-cms-revision-preview'][href$='/revisions/#{@revision.id}/preview']",
                  text: 'Preview selected snapshot'
  end

  def test_get_preview_renders_historical_fragments_without_persistence
    @translation.layout.update_column(:content, '{{cms:text retired}}')
    @revision.update!(
      data: {
        'fragments_attributes' => [{
          'identifier' => 'retired',
          'tag' => 'text',
          'content' => 'historical translation preview'
        }]
      }
    )
    original_fragments = @translation.fragments.order(:identifier).pluck(:identifier, :tag, :content)
    original_attributes = @translation.reload.attributes
    original_revision_count = @translation.revisions.count

    assert_no_difference -> { Comfy::Cms::Translation.count } do
      assert_no_difference -> { Comfy::Cms::Fragment.count } do
        assert_no_difference -> { Comfy::Cms::Revision.count } do
          path = preview_comfy_admin_cms_site_page_translation_revision_path(
            @site,
            @page,
            @translation,
            @revision
          )
          r :get, path
        end
      end
    end

    assert_response :success
    assert_match %r{historical translation preview}, response.body
    assert_equal 'text/html; charset=utf-8', response.content_type
    assert_equal '0', response.headers['X-XSS-Protection']
    assert_equal :fr, I18n.locale
    assert_equal @site, assigns(:cms_site)
    assert_equal @translation.layout, assigns(:cms_layout)
    assert_equal @page, assigns(:cms_page)

    @translation.reload
    assert_equal original_attributes, @translation.attributes
    assert_equal original_revision_count, @translation.revisions.count
    assert_equal original_fragments, @translation.fragments.order(:identifier).pluck(:identifier, :tag, :content)
    assert_not @translation.fragments.exists?(identifier: 'retired')
  end

  def test_get_show_for_invalid_record
    r :get, comfy_admin_cms_site_page_translation_revision_path(@site, @page, 'invalid', @revision)
    assert_response :redirect
    assert_redirected_to comfy_admin_cms_site_pages_path(@site)
    assert_equal 'Record Not Found', flash[:danger]
  end

  def test_get_show_failure
    r :get, comfy_admin_cms_site_page_translation_revision_path(@site, @page, @translation, 'invalid')
    assert_response :redirect
    assert assigns(:record)
    assert_redirected_to edit_comfy_admin_cms_site_page_translation_path(@site, @page, assigns(:record))
    assert_equal 'Revision Not Found', flash[:danger]
  end

  def test_revert
    assert_difference -> { @translation.revisions.count } do
      r :patch, revert_comfy_admin_cms_site_page_translation_revision_path(@site, @page, @translation, @revision)
      assert_response :redirect
      assert_redirected_to edit_comfy_admin_cms_site_page_translation_path(@site, @page, @translation)
      assert_equal 'Content Reverted', flash[:success]

      @translation.reload

      assert_equal [{
        identifier: 'content',
        tag: 'text',
        content: 'old content',
        datetime: nil,
        boolean: false
      }], @translation.fragments_attributes
    end
  end
end
