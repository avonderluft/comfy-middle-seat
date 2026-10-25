# frozen_string_literal: true

require_relative '../../test_helper'
require 'mini_magick'
require 'stringio'
require 'zlib'

class ContentImageProcessingTest < ActiveSupport::TestCase
  def test_modern_transformations_with_mini_magick
    with_processor(:mini_magick) { assert_modern_transformations }
  end

  def test_modern_transformations_with_vips
    with_processor(:vips) { assert_modern_transformations }
  end

  def test_simple_legacy_resize_with_mini_magick
    with_processor(:mini_magick) { assert_simple_legacy_resize }
  end

  def test_simple_legacy_resize_with_vips
    with_processor(:vips) { assert_simple_legacy_resize }
  end

  def test_admin_presets_with_mini_magick
    with_processor(:mini_magick) { assert_admin_presets }
  end

  def test_admin_presets_with_vips
    with_processor(:vips) { assert_admin_presets }
  end

  def test_legacy_resize_gravity_and_crop_with_mini_magick
    with_processor(:mini_magick) do
      # Deliberately supply options out of processing order: resize must precede crop.
      options = { 'crop' => '30x60+0+0', 'gravity' => 'center', 'resize' => '30x60^' }
      assert_transformation(options, [30, 60]) do |image|
        pixels = image.get_pixels
        assert_rgb [0, 255, 0], pixels[5][15]
        assert_rgb [0, 255, 0], pixels[30][5]
        assert_rgb [0, 255, 0], pixels[30][25]
      end
    end
  end

private

  def assert_modern_transformations
    assert_transformation({ 'resize_to_fit' => '60x60' }, [60, 40])
    assert_transformation({ 'resize_to_fit' => '240x240' }, [240, 160])
    assert_transformation({ 'resize_to_limit' => '60x60' }, [60, 40])
    assert_transformation({ 'resize_to_limit' => '240x240' }, [120, 80])

    # A narrow centered crop retains only the middle (green) band.
    assert_transformation({ 'resize_to_fill' => '30x60' }, [30, 60]) do |image|
      pixels = image.get_pixels
      assert_rgb [0, 255, 0], pixels[5][15]
      assert_rgb [0, 255, 0], pixels[30][5]
      assert_rgb [0, 255, 0], pixels[30][25]
    end

    assert_transformation({ 'resize_and_pad' => '30x60' }, [30, 60]) do |image|
      pixels = image.get_pixels('RGBA')
      assert_rgb [255, 0, 0], pixels[30][5]
      assert_rgb [0, 255, 0], pixels[30][15]
      assert_rgb [0, 0, 255], pixels[30][25]

      # MiniMagick defaults to transparent padding; Vips defaults to black for RGB input.
      [pixels[5][15], pixels[55][15]].each do |pixel|
        assert pixel[3].zero? || pixel.first(3) == [0, 0, 0], "Expected padding, got #{pixel.inspect}"
      end
    end
  end

  def assert_simple_legacy_resize
    assert_transformation({ 'resize' => '60x60' }, [60, 40])
    assert_transformation({ 'resize' => '240x240' }, [240, 160])
    assert_transformation({ 'resize' => '60x60>' }, [60, 40])
    assert_transformation({ 'resize' => '240x240>' }, [120, 80])
  end

  def assert_admin_presets
    { redactor: [100, 75], thumb: [200, 150], icon: [28, 28] }.each do |name, dimensions|
      transformations = Comfy::Cms::File::VARIANT_SIZE.fetch(name)
      assert_equal({ resize_to_fill: dimensions }, transformations)
      assert_variant(transformations, dimensions)
    end
  end

  def assert_transformation(options, dimensions, &)
    transformations = ComfyMiddleSeat::Content::ImageTransformations.normalize(options)
    assert_variant(transformations, dimensions, &)
  end

  def assert_variant(transformations, dimensions)
    variant = @blob.variant(transformations)
    @variants << variant
    variant.processed
    with_image(variant.download) do |image|
      assert_equal dimensions, image.dimensions, "#{ActiveStorage.variant_processor}: #{transformations.inspect}"
      yield image if block_given?
    end
  end

  def assert_rgb(expected, actual)
    expected.zip(actual.first(3)).each do |channel, value|
      assert_in_delta channel, value, 2
    end
  end

  def with_image(data)
    image = MiniMagick::Image.read(data)
    yield image
  ensure
    image&.destroy!
  end

  def with_processor(processor)
    previous_processor = ActiveStorage.variant_processor
    previous_transformer = ActiveStorage.variant_transformer
    previous_max_dimension = ComfyMiddleSeat.config.max_image_dimension
    @variants = []

    # Changing variant_processor alone leaves Rails' boot-time transformer selected.
    ActiveStorage.variant_transformer = transformer_for(processor)
    ActiveStorage.variant_processor = processor
    ComfyMiddleSeat.config.max_image_dimension = 4096

    original = banded_png
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(original),
      filename: 'image-processing-bands.png',
      content_type: 'image/png',
      identify: false
    )
    assert @blob.variable?

    yield

    assert_equal original, @blob.download, 'Processing variants must not modify the original bytes'
    with_image(@blob.download) do |image|
      assert_equal [120, 80], image.dimensions
      pixels = image.get_pixels
      assert_rgb [255, 0, 0], pixels[40][20]
      assert_rgb [0, 255, 0], pixels[40][60]
      assert_rgb [0, 0, 255], pixels[40][100]
    end
  ensure
    begin
      purge_generated_images
    ensure
      ActiveStorage.variant_processor = previous_processor
      ActiveStorage.variant_transformer = previous_transformer
      ComfyMiddleSeat.config.max_image_dimension = previous_max_dimension
    end
  end

  def transformer_for(processor)
    return ActiveStorage::Transformers::ImageMagick if processor == :mini_magick

    begin
      require 'vips'
    rescue LoadError => e
      raise if ENV['CI']

      skip "Vips processing unavailable: #{e.message}"
    end
    ActiveStorage::Transformers::Vips
  end

  def purge_generated_images
    @variants.each do |variant|
      # Purge tracked images synchronously: transactional tests do not run purge_later jobs.
      if variant.is_a?(ActiveStorage::VariantWithRecord)
        variant.image&.purge
      end
      variant.destroy
    end
  ensure
    @blob&.purge
  end

  def banded_png
    # A filter byte followed by three vertical RGB bands, with no external fixture files.
    row = "\x00".b + ([255, 0, 0].pack('C*') * 40) +
          ([0, 255, 0].pack('C*') * 40) + ([0, 0, 255].pack('C*') * 40)
    header = [120, 80, 8, 2, 0, 0, 0].pack('NNC5')
    "\x89PNG\r\n\x1a\n".b + png_chunk('IHDR', header) +
      png_chunk('IDAT', Zlib::Deflate.deflate(row * 80)) + png_chunk('IEND', ''.b)
  end

  def png_chunk(type, data)
    [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
  end
end
