# frozen_string_literal: true

require_relative '../test_helper'

class LayoutsFrontendTest < ApplicationSystemTestCase
  setup do
    @site = comfy_cms_sites(:default)
  end

  def test_add_child_layout_wraps_only_when_space_is_tight
    visit_p comfy_admin_cms_site_layouts_path(@site)

    [1280, 1024, 375].each do |width|
      page.current_window.resize_to(width, 800)
      all('.layout-actions a', text: 'Add Child Layout').each do |button|
        assert_equal 1, button.evaluate_script(<<~JAVASCRIPT)
          (() => {
            const range = document.createRange();
            range.selectNodeContents(this);
            return range.getClientRects().length;
          })()
        JAVASCRIPT
      end
    end

    page.current_window.resize_to(200, 800)
    button = find_link('Add Child Layout', match: :first)
    assert_operator button.evaluate_script(<<~JAVASCRIPT), :>, 1
      (() => {
        const range = document.createRange();
        range.selectNodeContents(this);
        return range.getClientRects().length;
      })()
    JAVASCRIPT
    assert button.evaluate_script('this.getBoundingClientRect().right <= window.innerWidth')
  ensure
    page.current_window.resize_to(1200, 800)
  end

  def test_new_identifier
    visit_p new_comfy_admin_cms_site_layout_path(@site)
    fill_in 'Layout Name', with: 'Test Layout'
    assert_equal 'test-layout', find_field('Identifier').value
  end
end
