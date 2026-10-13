# frozen_string_literal: true

require_relative '../test_helper'

class FlashNoticesFrontendTest < ApplicationSystemTestCase
  setup do
    @site = comfy_cms_sites(:default)
    @cms_page = comfy_cms_pages(:default)
  end

  def test_success_and_info_disappear_but_other_notices_remain
    @cms_page.update!(is_published: false)
    show_success_notice
    page.execute_script(<<~JAVASCRIPT)
      document.querySelector('#cms-main').insertAdjacentHTML('beforeend', `
        <div id="info-flash" class="alert alert-info fade show" data-cms-flash>Information</div>
        <div id="warning-flash" class="alert alert-warning fade show" data-cms-flash>Warning</div>
        <div id="error-flash" class="alert alert-danger fade show" data-cms-flash>Error</div>
        <div id="persistent-info" class="alert alert-info">Persistent page status</div>
      `);
      window.jQuery('[data-cms-flash].alert-success').on('close.bs.alert', function () {
        document.body.dataset.flashHadFade = this.classList.contains('fade');
      });
      CMS.flashNotices.init();
    JAVASCRIPT

    assert_selector '[data-cms-flash].alert-success.show', text: 'Page updated'
    assert_selector '#info-flash'
    assert_no_selector '[data-cms-flash].alert-success', wait: 7
    assert_no_selector '#info-flash', wait: 7
    assert_selector 'body[data-flash-had-fade=true]'
    assert_selector '#warning-flash'
    assert_selector '#error-flash'
    assert_selector '#persistent-info'
    assert_selector '.page-publication-state', text: 'Unpublished.'
  end

  def test_hover_and_keyboard_focus_pause_auto_dismiss
    show_success_notice
    notice = find('[data-cms-flash].alert-success')
    notice.hover

    # Each pause condition must hold the notice beyond the real dismissal delay.
    sleep 5.5
    assert_selector '[data-cms-flash].alert-success.show'
    page.execute_script('document.querySelector("[data-cms-flash] button").focus()')
    find('h2').hover
    sleep 5.5
    assert_selector '[data-cms-flash].alert-success.show'

    page.execute_script('document.activeElement.blur()')
    assert_no_selector '[data-cms-flash].alert-success', wait: 7
  end

  def test_reduced_motion_removes_notice_without_fade
    show_success_notice
    page.execute_script(<<~JAVASCRIPT)
      const originalMatchMedia = window.matchMedia.bind(window);
      window.matchMedia = (query) => query === '(prefers-reduced-motion: reduce)'
        ? { matches: true }
        : originalMatchMedia(query);
      window.jQuery('[data-cms-flash].alert-success').on('close.bs.alert', function () {
        document.body.dataset.flashHadFade = this.classList.contains('fade');
      });
    JAVASCRIPT

    assert_no_selector '[data-cms-flash].alert-success', wait: 7
    assert_selector 'body[data-flash-had-fade=false]'
  end

  def test_dispose_cancels_timers_and_reinitialization_restarts_them
    show_success_notice
    page.execute_script('CMS.flashNotices.dispose()')
    sleep 5.5
    assert_selector '[data-cms-flash].alert-success.show'

    page.execute_script('CMS.flashNotices.init(); CMS.flashNotices.init()')
    assert_no_selector '[data-cms-flash].alert-success', wait: 7
  end

private

  def show_success_notice
    visit_p edit_comfy_admin_cms_site_page_path(@site, @cms_page)
    click_button 'Update Page'
    assert_selector '[data-cms-flash].alert-success[role=status]', text: 'Page updated'
    find('h2').hover
  end
end
