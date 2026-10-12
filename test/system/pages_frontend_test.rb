# frozen_string_literal: true

require_relative '../test_helper'

class PagesFrontendTest < ApplicationSystemTestCase
  setup do
    @site = comfy_cms_sites(:default)
  end

  def test_harbor_admin_colors_and_button_states
    visit_p comfy_admin_cms_site_pages_path(@site)
    assert_selector '#cms-left', style: { 'background-color' => 'rgb(23, 43, 58)' }

    create_button = find_link('Create New Page')
    assert_matches_style create_button, 'background-color' => 'rgb(15, 118, 110)', 'color' => 'rgb(255, 255, 255)'
    create_button.hover
    assert_matches_style create_button, 'background-color' => 'rgb(11, 94, 87)'

    page.execute_script('document.querySelector(".page-header .btn").focus()')
    assert_selector '.page-header .btn:focus'
    refute_equal 'none', create_button.style('box-shadow')['box-shadow']

    child = comfy_cms_pages(:child)
    within "#comfy_cms_page_#{child.id} > .row" do
      add_button = find_link('Add Child Page')
      add_button.hover
      assert_matches_style add_button, 'background-color' => 'rgb(224, 242, 239)', 'white-space' => 'nowrap'
    end
  end

  def test_new_identifier
    visit_p new_comfy_admin_cms_site_page_path(@site)
    fill_in 'Label', with: 'Test Page'
    assert_equal 'test-page', find_field('Slug').value
  end

  def test_lazy_tree_opens_and_reopens_without_duplicate_pages
    child = comfy_cms_pages(:child)
    grandchild = @site.pages.create!(
      label: 'Grandchild',
      slug: 'grandchild',
      parent: child,
      layout: comfy_cms_layouts(:default)
    )

    visit_p comfy_admin_cms_site_pages_path(@site)
    assert_no_selector "#comfy_cms_page_#{grandchild.id}"

    find("#comfy_cms_page_#{child.id} a.toggle").click
    assert_selector "#comfy_cms_page_#{grandchild.id}", count: 1

    find("#comfy_cms_page_#{child.id} a.toggle").click
    assert_no_selector "#comfy_cms_page_#{grandchild.id}"
    find("#comfy_cms_page_#{child.id} a.toggle").click
    assert_selector "#comfy_cms_page_#{grandchild.id}", count: 1
  end

  def test_untouched_page_form_navigates_without_confirmation
    cms_page = comfy_cms_pages(:default)
    visit_p comfy_admin_cms_site_pages_path(@site)
    find("a[href='#{edit_comfy_admin_cms_site_page_path(@site, cms_page)}']", match: :first).click
    assert_current_path edit_comfy_admin_cms_site_page_path(@site, cms_page)
    page.execute_script('window.confirm = () => { throw new Error("Unexpected confirmation") }')

    click_link 'Cancel'

    assert_current_path comfy_admin_cms_site_pages_path(@site)
    visit_p edit_comfy_admin_cms_site_page_path(@site, cms_page)
    assert_no_selector '.modal', text: 'Unsaved draft found', wait: 0.5
  end

  def test_publish_and_unpublish_page_from_index
    cms_page = comfy_cms_pages(:child)
    visit_p comfy_admin_cms_site_pages_path(@site)

    within "#comfy_cms_page_#{cms_page.id} > .row" do
      click_link 'Unpublish'
    end
    assert_text 'Page unpublished'
    refute cms_page.reload.is_published?

    within "#comfy_cms_page_#{cms_page.id} > .row" do
      click_link 'Publish'
    end
    assert_text 'Page published'
    assert cms_page.reload.is_published?
  end

  def test_published_descendant_hidden_by_ancestor
    root = comfy_cms_pages(:default)
    child = comfy_cms_pages(:child)
    root.update!(is_published: false)

    visit_p comfy_admin_cms_site_pages_path(@site)
    within "#comfy_cms_page_#{child.id} > .row" do
      assert_text 'Hidden by unpublished ancestor'
      assert_link 'Unpublish'
      assert_selector '.item-title a.draft', text: child.label
    end

    visit_p edit_comfy_admin_cms_site_page_path(@site, child)
    assert_selector '.publication-status', text: 'Publish its ancestors to make this page visible.'

    visit_p comfy_admin_cms_site_pages_path(@site)
    within "#comfy_cms_page_#{root.id} > .row" do
      click_link 'Publish'
    end
    within "#comfy_cms_page_#{child.id} > .row" do
      assert_no_selector '.publication-status'
      assert_selector '.item-title a.published', text: child.label
    end
    assert child.reload.is_published?
  end

  def test_publish_and_unpublish_children
    child = comfy_cms_pages(:child)
    visit_p edit_comfy_admin_cms_site_page_path(@site, comfy_cms_pages(:default))

    assert_no_link 'Unpublish descendants'
    click_button 'Child pages'
    assert_selector '#child-pages-menu[aria-expanded=true]'
    assert_button 'Publish descendants', disabled: true
    assert_no_link 'Publish descendants'
    disabled_action = find_button('Publish descendants', disabled: true)
    refute_equal find_link('Unpublish descendants').style('color'), disabled_action.style('color')
    assert_matches_style disabled_action, 'pointer-events' => 'none'
    page.execute_script('document.querySelector("#child-pages-actions button:disabled").click()')
    assert child.reload.is_published?
    assert_current_path edit_comfy_admin_cms_site_page_path(@site, comfy_cms_pages(:default))
    dismiss_confirm('Unpublish all descendant pages?') do
      click_link 'Unpublish descendants'
    end
    assert child.reload.is_published?

    click_button 'Child pages'
    accept_confirm('Unpublish all descendant pages?') do
      click_link 'Unpublish descendants'
    end
    assert_text 'Descendant pages unpublished'
    refute child.reload.is_published?

    click_button 'Child pages'
    assert_button 'Unpublish descendants', disabled: true
    assert_no_link 'Unpublish descendants'
    accept_confirm('Publish all descendant pages?') do
      click_link 'Publish descendants'
    end
    assert_text 'Descendant pages published'
    assert child.reload.is_published?
    click_button 'Child pages'
    assert_button 'Publish descendants', disabled: true
    assert_link 'Unpublish descendants'
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

  def test_navigation_saves_draft_without_confirmation
    cms_page = comfy_cms_pages(:default)
    path = edit_comfy_admin_cms_site_page_path(@site, cms_page)
    visit_p path
    fill_in 'Label', with: 'Unsaved page label'
    page.execute_script('window.confirm = () => { throw new Error("Unexpected confirmation") }')

    click_link 'Cancel'
    assert_current_path comfy_admin_cms_site_pages_path(@site)

    visit_p path
    assert_selector '.modal', text: 'Unsaved draft found'
    click_button 'Restore draft'
    assert_field 'Label', with: 'Unsaved page label'
  end

  def test_draft_restores_dynamic_layout_fields_and_warns_about_files
    original_layout = comfy_cms_layouts(:default)
    original_layout.update_column(:content, '{{ cms:text content }}')

    draft_layout = comfy_cms_layouts(:child)
    draft_layout.update_column(:content, <<~TEXT)
      {{ cms:text content }}
      {{ cms:text draft_only }}
      {{ cms:file upload }}
    TEXT

    cms_page = comfy_cms_pages(:default)
    path = edit_comfy_admin_cms_site_page_path(@site, cms_page)
    visit_p path
    fill_in 'Label', with: 'Locally drafted page'
    select draft_layout.label, from: 'Layout'
    assert_field 'fragment-draft_only'
    fill_in 'fragment-content', with: 'Shared draft content'
    fill_in 'fragment-draft_only', with: 'Layout-specific draft content'
    attach_file 'fragment-upload', Rails.root.join('test/fixtures/files/image.jpg')

    click_link 'Cancel'
    visit_p path

    assert_selector '.modal', text: 'Unsaved draft found'
    assert_text 'Selected files are not stored and must be selected again.'
    click_button 'Restore draft'

    assert_field 'Label', with: 'Locally drafted page'
    assert_field 'Layout', with: draft_layout.id.to_s
    assert_field 'fragment-content', with: 'Shared draft content'
    assert_field 'fragment-draft_only', with: 'Layout-specific draft content'
    assert_equal '', find_field('fragment-upload').value
  end

  def test_validation_failure_keeps_draft_until_success_is_acknowledged
    cms_page = comfy_cms_pages(:default)
    path = edit_comfy_admin_cms_site_page_path(@site, cms_page)
    visit_p path
    fill_in 'Label', with: ''
    click_button 'Update Page'
    assert_text 'Failed to update page'

    click_link 'Cancel'
    visit_p path
    assert_selector '.modal', text: 'Unsaved draft found'
    click_button 'Restore draft'
    assert_field 'Label', with: ''

    fill_in 'Label', with: 'Recovered valid page'
    click_button 'Update Page'
    assert_text 'Page, siblings, and parent updated'

    click_link 'Cancel'
    visit_p path
    assert_no_selector '.modal', text: 'Unsaved draft found', wait: 0.5
    assert_field 'Label', with: 'Recovered valid page'
  end
end
