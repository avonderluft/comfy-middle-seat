# frozen_string_literal: true

module Comfy::ReorderAction
  extend ActiveSupport::Concern

  included do
    mattr_accessor :reorder_action_resource
  end

  def reorder
    resource_class = self.class.reorder_action_resource
    positions = (params.permit(order: [])[:order] || []).each_with_index.to_h

    if positions.present?
      site_resources = resource_class.where(site_id: @site.id)
      reordered_resources = site_resources.where(id: positions.keys)
      position = Arel::Nodes::Case.new(resource_class.arel_table[:id])
      positions.each do |id, index|
        position.when(id).then(index)
      end

      reordered_resources.update_all(position: position)
      if resource_class == Comfy::Cms::Page
        clear_reordered_page_content_cache(site_resources, reordered_resources)
      end
    end

    head :ok
  end

private

  def clear_reordered_page_content_cache(site_pages, reordered_pages)
    affected_pages = site_pages.where(id: reordered_pages.select(:id)).or(
      site_pages.where(id: reordered_pages.select(:parent_id))
    )
    affected_pages.update_all(content_cache: nil)
  end
end
