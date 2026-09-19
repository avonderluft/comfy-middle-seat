# frozen_string_literal: true

require_relative '../test_helper'

class TranslationsFrontendTest < ApplicationSystemTestCase
  setup do
    @site = comfy_cms_sites(:default)
    @page = comfy_cms_pages(:default)
    @translation = comfy_cms_translations(:default)
  end

  def test_layout_change_preserves_shared_unsaved_content
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

    visit_p edit_comfy_admin_cms_site_page_translation_path(@site, @page, @translation)
    fill_in 'fragment-content', with: 'Unsaved translated content'
    fill_in 'fragment-old_layout_only', with: 'Unsaved translated content to discard'

    accept_confirm('Some content cannot be preserved in the selected layout. Replace it anyway?') do
      select new_layout.label, from: 'Layout'
    end

    assert_field 'fragment-content', with: 'Unsaved translated content'
    assert_field 'fragment-new_layout_only', with: ''
    assert_no_field 'fragment-old_layout_only'
  end

  def test_draft_syncs_codemirror_survives_preview_and_can_be_discarded
    layout = comfy_cms_layouts(:default)
    layout.update_column(:content, <<~TEXT)
      {{ cms:textarea content }}
      {{ cms:wysiwyg rich_content }}
    TEXT
    path = edit_comfy_admin_cms_site_page_translation_path(@site, @page, @translation)
    visit_p path
    fill_in 'Label', with: 'Locally drafted translation'
    page.execute_script(<<~JAVASCRIPT)
      document.querySelector(".CodeMirror").CodeMirror.setValue("Translated CodeMirror draft");
      document.querySelector(".redactor-editor").innerHTML = "<p>Translated Redactor draft</p>";
    JAVASCRIPT

    preview_window = window_opened_by { click_button 'Preview' }
    within_window(preview_window) do
      assert_text 'Translated CodeMirror draft'
      assert_text 'Translated Redactor draft'
    end
    preview_window.close

    accept_confirm('You have unsaved changes. Are you sure you want to leave this page?') do
      click_link 'Return to Page'
    end
    visit_p path
    assert_selector '.modal', text: 'Unsaved draft found'
    click_button 'Restore draft'

    assert_field 'Label', with: 'Locally drafted translation'
    assert_selector '.CodeMirror-code', text: 'Translated CodeMirror draft'
    assert_selector '.redactor-editor', text: 'Translated Redactor draft'

    accept_confirm('You have unsaved changes. Are you sure you want to leave this page?') do
      click_link 'Return to Page'
    end
    visit_p path
    assert_selector '.modal', text: 'Unsaved draft found'
    click_button 'Discard draft'

    assert_field 'Label', with: 'Default Translation'
    assert_selector '.CodeMirror-code', text: 'translated content'
  end
end
