# frozen_string_literal: true

require_relative '../../image_transformations'

# A mixin for tags that returns the file as their content.
module ComfyMiddleSeat::Content::Tags::Mixins
  module FileContent
    # @param [ActiveStorage::Blob] file
    # @param ["link", "image", "url"] as
    # @param [{String => String}] variant_attrs Modern or legacy image options
    # @param [String] label alt text for `as: "image"`, link text for `as: "link"`
    # @return [String]
    def content(file: self.file, as: self.as, variant_attrs: self.variant_attrs, label: self.label)
      return '' unless file

      url_helpers = Rails.application.routes.url_helpers

      attachment_url =
        if variant_attrs.present? && file.variable?
          transformations = ComfyMiddleSeat::Content::ImageTransformations.normalize(variant_attrs)
          variant = file.variant(transformations)
          url_helpers.rails_representation_path(variant, only_path: true)
        else
          url_helpers.rails_blob_path(file, only_path: true)
        end

      helpers = ActionController::Base.helpers

      # Blob and variant URLs are not pipeline assets; HTML builders keep them
      # relative instead of applying image_tag's asset-host settings.
      case as
      when 'link'
        helpers.content_tag(:a, label, href: attachment_url, class: @class.presence, target: '_blank', rel: 'noopener')
      when 'image'
        helpers.tag.img(src: attachment_url, class: @class.presence, alt: label, title: label)
      else
        attachment_url
      end
    end
  end
end
