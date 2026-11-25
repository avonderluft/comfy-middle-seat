# frozen_string_literal: true

require_relative '../test_helper'

class RevisionsFrontendTest < ApplicationSystemTestCase
  def test_restore_persists_the_selected_revision
    site = comfy_cms_sites(:default)
    layout = comfy_cms_layouts(:default)
    selected = comfy_cms_revisions(:layout)
    expected = selected.data.slice('content', 'css', 'js')
    newer_data = {
      'content' => 'Newer snapshot content', 'css' => '/* Newer CSS */', 'js' => '// Newer JS'
    }
    newer = layout.revisions.create!(data: newer_data, created_at: selected.created_at + 1.second)

    visit_p comfy_admin_cms_site_layout_revision_path(site, layout, newer)
    within '#cms-right .box.revisions' do
      click_link "Revision ##{selected.id} —", exact: false
    end
    click_button "Restore revision ##{selected.id}"

    assert_current_path edit_comfy_admin_cms_site_layout_path(site, layout)
    assert_equal expected, layout.reload.attributes.slice(*expected.keys)
  end

  def test_compare_navigation_and_context
    site = comfy_cms_sites(:default)
    layout = comfy_cms_layouts(:default)
    revision = comfy_cms_revisions(:layout)
    context = (1..12).map { |line| "<p>Context #{line}</p>" }
    before = ['<h1>Old title</h1>', *context, '<footer>Old footer</footer>'].join("\n")
    after = ['<h1>New title</h1>', *context, '<footer>New footer</footer>'].join("\n")
    layout.update_column(:content, after)
    revision.update!(data: revision.data.merge('content' => before, 'css' => layout.css, 'js' => layout.js))

    visit_p comfy_admin_cms_site_layout_revision_path(site, layout, revision)

    assert_text 'Change 1 of 2'
    assert_selector '.revision-removed del', text: 'Old'
    assert_selector '.revision-added ins', text: 'New'
    assert_no_text 'Context 6'

    click_button 'Next change'
    assert_text 'Change 2 of 2'
    assert_selector '.revision-change-active', text: 'New footer'

    click_button 'Previous change'
    assert_text 'Change 1 of 2'
    find('.revision-gap summary', match: :first).click
    assert_text 'Context 6'
    click_button 'Show full content'
    assert_no_selector '.revision-gap:not([open])'
    click_button 'Collapse unchanged lines'
    assert_no_text 'Context 6'

    select 'Unified', from: 'View'
    assert_selector '.revision-comparison[data-view="unified"]'

    page.current_window.resize_to(375, 800)
    refresh
    assert_selector '.revision-comparison[data-view="unified"]'
  ensure
    page.current_window.resize_to(1200, 800) if page.driver.browser
  end
end
