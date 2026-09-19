# frozen_string_literal: true

class Comfy::Admin::Cms::Revisions::TranslationController < Comfy::Admin::Cms::Revisions::BaseController
  def show
    load_fragment_content
    render 'comfy/admin/cms/revisions/show'
  end

  def preview
    render_fragment_preview(cms_page: @page, locale: @record.locale)
  end

private

  def load_record
    @page   = @site.pages.find(params[:page_id])
    @record = @page.translations.find(params[:translation_id])
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = I18n.t('comfy.admin.cms.revisions.record_not_found')
    redirect_to comfy_admin_cms_site_pages_path(@site)
  end

  def record_path
    edit_comfy_admin_cms_site_page_translation_path(@site, @page, @record)
  end

  def preview_path
    preview_comfy_admin_cms_site_page_translation_revision_path(
      @site,
      @page,
      @record,
      @revision
    )
  end
end
