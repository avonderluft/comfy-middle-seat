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
end
