# frozen_string_literal: true

require_relative 'mixins/file_content'

# This is like the the file_link tag, but specifically for images
# Identify the image by its label {{ cms:image label }}
#
# `class`   - any html classes that you want on the image tag. For example "class1 class2"
#
# Image sizing: resize_to_limit, resize_to_fit, resize_to_fill, resize_and_pad ("100x50").
# Legacy resize/gravity/crop expressions remain supported for MiniMagick.

class ComfyMiddleSeat::Content::Tags::Image < ComfyMiddleSeat::Content::Tag
  include ComfyMiddleSeat::Content::Tags::Mixins::FileContent

  attr_reader :identifier, :as, :variant_attrs

  def initialize(context:, params: [], source: nil)
    super

    options = params.extract_options!
    @identifier     = params[0]
    @as             = 'image'
    @class          = options['class']
    @variant_attrs  = options.slice(*ComfyMiddleSeat::Content::ImageTransformations::OPTIONS)

    return if @identifier.present?

    raise Error, 'Missing identifier label for image tag'
  end

  # @return [Comfy::Cms::File]
  def file_record
    @file_record ||= context.site.files.detect { |f| f.label == identifier }
  end

  # @return [ActiveStorage::Blob]
  def file
    file_record&.attachment
  end

  # @return [String]
  def label
    return '' if file_record.nil?

    file_record.label.presence || file.filename.to_s
  end
end

ComfyMiddleSeat::Content::Renderer.register_tag(
  :image, ComfyMiddleSeat::Content::Tags::Image
)
