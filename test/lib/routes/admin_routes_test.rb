# frozen_string_literal: true

require_relative '../../test_helper'

class AdminRoutesTest < ActionDispatch::IntegrationTest
  def setup
    @site = comfy_cms_sites(:default)
  end

  def teardown
    Rails.application.reload_routes!
  end

  def test_cms_admin_routes
    assert_routing '/admin', controller: 'comfy/admin/cms/base', action: 'jump'
    assert_routing '/auth/identity/callback',
                   controller: 'comfy/cms/content',
                   action: 'show',
                   cms_path: 'auth/identity/callback'
  end

  def test_page_revision_preview_routes
    page = comfy_cms_pages(:default)
    translation = comfy_cms_translations(:default)
    revision = comfy_cms_revisions(:page)

    assert_equal "/admin/sites/#{@site.id}/pages/#{page.id}/revisions/#{revision.id}/preview",
                 preview_comfy_admin_cms_site_page_revision_path(@site, page, revision)
    assert_equal(
      "/admin/sites/#{@site.id}/pages/#{page.id}/translations/#{translation.id}/revisions/#{revision.id}/preview",
      preview_comfy_admin_cms_site_page_translation_revision_path(@site, page, translation, revision)
    )
  end
end
