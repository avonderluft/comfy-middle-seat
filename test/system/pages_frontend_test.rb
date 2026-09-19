# frozen_string_literal: true

require_relative '../test_helper'

class PagesFrontendTest < ApplicationSystemTestCase
  setup do
    @site = comfy_cms_sites(:default)
  end

  def test_new_identifier
    visit_p new_comfy_admin_cms_site_page_path(@site)
    fill_in 'Label', with: 'Test Page'
    assert_equal 'test-page', find_field('Slug').value
  end

  def test_publish_and_unpublish_children
    child = comfy_cms_pages(:child)
    visit_p edit_comfy_admin_cms_site_page_path(@site, comfy_cms_pages(:default))

    accept_confirm('Unpublish all child pages?') do
      click_link 'Unpublish children'
    end
    assert_text 'Child pages unpublished'
    refute child.reload.is_published?

    accept_confirm('Publish all child pages?') do
      click_link 'Publish children'
    end
    assert_text 'Child pages published'
    assert child.reload.is_published?
  end

  def test_change_to_invalid_fragment_and_back
    valid_layout = comfy_cms_layouts(:default)
    valid_layout.update_column(:content, '{{ cms:text content }}')

    invalid_layout = comfy_cms_layouts(:child)
    invalid_layout.update_column(:content, '{{ cms:wysiwyg }}')

    cms_page = comfy_cms_pages(:default)
    visit_p edit_comfy_admin_cms_site_page_path(@site, cms_page)
    assert_field 'page[fragments_attributes][0][content]', type: 'text'

    accept_confirm('Some content cannot be preserved in the selected layout. Replace it anyway?') do
      select invalid_layout.label, from: 'Layout'
    end
    assert_equal 'Missing identifier for fragment tag: {{ cms:wysiwyg }}', find('.alert-danger').text.strip

    select valid_layout.label, from: 'Layout'
    assert_field 'page[fragments_attributes][0][content]', type: 'text'
  end

  def test_layout_change_preserves_shared_unsaved_content_and_warns_before_discard
    current_layout = comfy_cms_layouts(:default)
    current_layout.update_column(:content, <<~TEXT)
      {{ cms:text content }}
      {{ cms:text old_layout_only }}
    TEXT

    new_layout = comfy_cms_layouts(:child)
    new_layout.update_column(:content, <<~TEXT)
      {{ cms:text content }}
      {{ cms:text new_layout_only }}
    TEXT

    cms_page = comfy_cms_pages(:default)
    visit_p edit_comfy_admin_cms_site_page_path(@site, cms_page)
    fill_in 'fragment-content', with: 'Unsaved shared content'
    fill_in 'fragment-old_layout_only', with: 'Unsaved content to discard'

    dismiss_confirm('Some content cannot be preserved in the selected layout. Replace it anyway?') do
      select new_layout.label, from: 'Layout'
    end

    assert_equal current_layout.id.to_s, find_field('Layout').value
    assert_field 'fragment-content', with: 'Unsaved shared content'
    assert_field 'fragment-old_layout_only', with: 'Unsaved content to discard'

    accept_confirm('Some content cannot be preserved in the selected layout. Replace it anyway?') do
      select new_layout.label, from: 'Layout'
    end

    assert_field 'fragment-content', with: 'Unsaved shared content'
    assert_field 'fragment-new_layout_only', with: ''
    assert_no_field 'fragment-old_layout_only'
  end

  def test_layout_change_warns_when_cleared_content_cannot_be_preserved
    current_layout = comfy_cms_layouts(:default)
    current_layout.update_column(:content, '{{ cms:text content }}')

    new_layout = comfy_cms_layouts(:child)
    new_layout.update_column(:content, '{{ cms:text replacement }}')

    cms_page = comfy_cms_pages(:default)
    visit_p edit_comfy_admin_cms_site_page_path(@site, cms_page)
    fill_in 'fragment-content', with: ''

    dismiss_confirm('Some content cannot be preserved in the selected layout. Replace it anyway?') do
      select new_layout.label, from: 'Layout'
    end

    assert_equal current_layout.id.to_s, find_field('Layout').value
    assert_field 'fragment-content', with: ''
  end

  def test_layout_load_error_keeps_current_content_and_restores_selector
    current_layout = comfy_cms_layouts(:default)
    new_layout = comfy_cms_layouts(:child)
    cms_page = comfy_cms_pages(:default)

    visit_p edit_comfy_admin_cms_site_page_path(@site, cms_page)
    page.execute_script(<<~JAVASCRIPT)
      window.fetch = () => new Promise((_resolve, reject) => {
        window.setTimeout(() => reject(new Error("test layout failure")), 500);
      });
    JAVASCRIPT

    select new_layout.label, from: 'Layout'
    assert_field 'Layout', disabled: true
    assert_text 'Loading layout content…'
    assert_text 'Layout content could not be loaded. Your current content has been kept.'
    assert_field 'Layout', disabled: false
    assert_equal current_layout.id.to_s, find_field('Layout').value
    assert_selector '.CodeMirror-code', text: 'content'
  end

  def test_dirty_navigation_warns_but_successful_submit_does_not
    cms_page = comfy_cms_pages(:default)
    path = edit_comfy_admin_cms_site_page_path(@site, cms_page)
    visit_p path
    fill_in 'Label', with: 'Unsaved page label'

    dismiss_confirm('You have unsaved changes. Are you sure you want to leave this page?') do
      click_link 'Cancel'
    end

    assert_current_path path
    assert_field 'Label', with: 'Unsaved page label'

    click_button 'Update Page'
    assert_text 'Page, siblings, and parent updated'
    assert_equal 'Unsaved page label', cms_page.reload.label
  end
end
