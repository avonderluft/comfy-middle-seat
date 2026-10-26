# frozen_string_literal: true

module Comfy::Admin::Cms::TagUsageHelper
  def tag_usage_source_path(source)
    case source[:type]
    when 'layout'
      edit_comfy_admin_cms_site_layout_path(source[:site_id], source[:id])
    when 'snippet'
      edit_comfy_admin_cms_site_snippet_path(source[:site_id], source[:id])
    when 'page'
      edit_comfy_admin_cms_site_page_path(source[:site_id], source[:id])
    when 'translation'
      edit_comfy_admin_cms_site_page_translation_path(source[:site_id], source[:page_id], source[:id])
    end
  end

  def tag_usage_source_label(source)
    type = t("activerecord.models.comfy/cms/#{source[:type]}")
    "#{type} ##{source[:id]}: #{source[:label]}"
  end
end
