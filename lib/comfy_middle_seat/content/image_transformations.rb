# frozen_string_literal: true

# Restrict CMS-authored transformations to bounded image operations. Never pass
# arbitrary tag options through to an image processor.
class ComfyMiddleSeat::Content::ImageTransformations
  OPERATIONS = %w[resize_to_limit resize_to_fit resize_to_fill resize_and_pad].freeze
  LEGACY_OPTIONS = %w[resize gravity crop].freeze
  OPTIONS = (OPERATIONS + LEGACY_OPTIONS).freeze
  GRAVITIES = %w[northwest north northeast west center east southwest south southeast].freeze

  def self.normalize(options, processor: ActiveStorage.variant_processor)
    new(options, processor).normalize
  end

  def initialize(options, processor)
    @options = options.stringify_keys
    @processor = processor
  end

  def normalize
    return {} if @options.empty?

    unknown = @options.keys - OPTIONS
    error!("Unknown image options: #{unknown.join(', ')}") if unknown.any?
    modern = @options.keys & OPERATIONS
    if modern.size > 1 || (modern.any? && @options.keys.intersect?(LEGACY_OPTIONS))
      error!('Use one resize operation; do not mix modern and legacy image options')
    end

    if modern.any?
      operation = modern.first
      { operation.to_sym => dimensions(@options[operation], operation) }
    else
      legacy_transformations
    end
  end

private

  def dimensions(value, operation)
    match = value.is_a?(String) && %r{\A\s*(\d+)\s*x\s*(\d+)\s*\z}.match(value)
    error!("#{operation} must be dimensions such as \"400x300\"") unless match
    validate_dimensions(match[1].to_i, match[2].to_i)
  end

  def validate_dimensions(width, height)
    limit = ComfyMiddleSeat.config.max_image_dimension
    unless limit.is_a?(Integer) && limit.positive?
      error!('max_image_dimension must be a positive integer')
    end
    unless width.positive? && height.positive? && width <= limit && height <= limit
      error!("Image dimensions must be between 1 and #{limit} pixels; adjust max_image_dimension if needed")
    end
    [width, height]
  end

  def legacy_transformations
    if @options.key?('resize')
      size, modifier = legacy_resize
      if @options.keys == ['resize'] && ['', '>'].include?(modifier)
        operation = modifier == '>' ? :resize_to_limit : :resize_to_fit
        return { operation => size }
      end
    end

    validate_legacy_crop if @options.key?('crop')

    if @options.key?('gravity') && !GRAVITIES.include?(@options['gravity'])
      error!("Unsupported gravity; choose #{GRAVITIES.join(', ')}")
    end
    unless @options.key?('resize') || @options.key?('crop')
      error!('Legacy gravity requires resize or crop')
    end
    unless @processor == :mini_magick
      error!('Legacy crop, gravity, and resize modifiers require MiniMagick; use a modern resize option with Vips')
    end

    # image_processing combines these operations itself. The order matters for
    # existing resize/gravity/crop expressions; combine_options is unsupported.
    @options.slice(*LEGACY_OPTIONS).symbolize_keys
  end

  def legacy_resize
    value = @options['resize']
    match = value.is_a?(String) && %r{\A(\d+)x(\d+)([!<>^]?)\z}.match(value)
    error!('Legacy resize must be WxH with an optional >, <, !, or ^ suffix; use a modern resize option') unless match
    [validate_dimensions(match[1].to_i, match[2].to_i), match[3]]
  end

  def validate_legacy_crop
    value = @options['crop']
    match = value.is_a?(String) && %r{\A(\d+)x(\d+)[+-]\d+[+-]\d+\z}.match(value)
    error!('Legacy crop requires explicit offsets: WxH+X+Y; use resize_to_fill for a centered crop') unless match
    validate_dimensions(match[1].to_i, match[2].to_i)
  end

  def error!(message)
    raise ComfyMiddleSeat::Content::Tag::Error, message
  end
end
