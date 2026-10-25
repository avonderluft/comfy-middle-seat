# frozen_string_literal: true

require_relative '../../test_helper'

class ContentImageTransformationsTest < ActiveSupport::TestCase
  Transformations = ComfyMiddleSeat::Content::ImageTransformations
  Error = ComfyMiddleSeat::Content::Tag::Error

  def test_modern_operations_on_both_processors
    %i[mini_magick vips].each do |processor|
      Transformations::OPERATIONS.each do |operation|
        assert_equal({ operation.to_sym => [400, 300] },
                     Transformations.normalize({ operation => ' 400 x 300 ' }, processor: processor))
      end
    end
    assert_empty Transformations.normalize({})
    assert_equal({ resize_to_limit: [400, 300] }, Transformations.normalize({ resize_to_limit: '400x300' }))
  end

  def test_rejects_malformed_dimensions
    [nil, true, 100, [], {}, '', '100', '100x', 'x100', '1.5x10', '-1x10', '0x10',
     '10x0', '10x20junk', '10x20x30', '10x20>'].each do |value|
      error = assert_raises(Error) { Transformations.normalize({ 'resize_to_fill' => value }) }
      assert_match(%r{dimensions}i, error.message)
    end
  end

  def test_configurable_limit_rejects_instead_of_clamping
    assert_equal({ resize_to_fit: [4096, 4096] }, Transformations.normalize({ 'resize_to_fit' => '4096x4096' }))
    %w[4097x1 1x4097].each do |size|
      error = assert_raises(Error) { Transformations.normalize({ 'resize_to_fit' => size }) }
      assert_match(%r{4096}, error.message)
    end
    ComfyMiddleSeat.config.max_image_dimension = 6000
    assert_equal({ resize_to_fit: [5000, 4000] }, Transformations.normalize({ 'resize_to_fit' => '5000x4000' }))
    [nil, 0, -1, '4096'].each do |value|
      ComfyMiddleSeat.config.max_image_dimension = value
      error = assert_raises(Error) { Transformations.normalize({ 'resize_to_fit' => '20x10' }) }
      assert_match(%r{max_image_dimension}, error.message)
    end
  ensure
    ComfyMiddleSeat.config.max_image_dimension = 4096
  end

  def test_rejects_conflicting_and_unknown_operations
    [
      { 'resize_to_fit' => '20x10', 'resize_to_fill' => '20x10' },
      { 'resize_to_limit' => '20x10', 'resize' => '20x10' },
      { 'resize_to_fill' => '20x10', 'gravity' => 'center' },
      { 'resize_and_pad' => '20x10', 'crop' => '20x10' },
      { 'system' => 'anything' }
    ].each do |options|
      assert_raises(Error) { Transformations.normalize(options) }
    end
  end

  def test_portable_legacy_resize
    %i[mini_magick vips].each do |processor|
      assert_equal({ resize_to_fit: [100, 50] },
                   Transformations.normalize({ 'resize' => '100x50' }, processor: processor))
      assert_equal({ resize_to_limit: [100, 50] },
                   Transformations.normalize({ 'resize' => '100x50>' }, processor: processor))
    end
  end

  def test_complex_legacy_options_preserve_processing_order_only_on_mini_magick
    options = { 'crop' => '100x50+5-10', 'resize' => '200x100^', 'gravity' => 'north' }
    transformations = Transformations.normalize(options, processor: :mini_magick)
    assert_equal %i[resize gravity crop], transformations.keys
    assert_equal({ resize: '200x100^', gravity: 'north', crop: '100x50+5-10' }, transformations)
    error = assert_raises(Error) { Transformations.normalize(options, processor: :vips) }
    assert_match(%r{require MiniMagick}, error.message)
  end

  def test_legacy_validation
    [
      { 'resize' => nil }, { 'resize' => 100 }, { 'resize' => '50%' }, { 'resize' => '100x' },
      { 'resize' => '100x20;anything' }, { 'resize' => '0x20' }, { 'resize' => '9000x20' },
      { 'crop' => '20x10' }, { 'crop' => '20x10', 'gravity' => 'center' },
      { 'crop' => '20x10+0' }, { 'crop' => {} }, { 'crop' => '9000x20+0+0' },
      { 'gravity' => 'center' }, { 'resize' => '20x10', 'gravity' => 'invalid' }
    ].each do |options|
      assert_raises(Error) { Transformations.normalize(options, processor: :mini_magick) }
    end
  end

  def test_all_image_and_file_tags_use_the_new_operations
    page = comfy_cms_pages(:default)
    fragment = comfy_cms_fragments(:file)
    library_file = comfy_cms_files(:default)
    tags = ComfyMiddleSeat::Content::Tags
    [
      [tags::File, fragment.identifier],
      [tags::Files, fragment.identifier],
      [tags::PageFileLink, fragment.identifier],
      [tags::FileLink, library_file.id.to_s],
      [tags::Image, library_file.label]
    ].each do |tag_class, identifier|
      Transformations::OPERATIONS.each do |operation|
        tag = tag_class.new(context: page, params: [identifier, { operation => '40x30' }])
        attachment = tag.send(:file)
        variant = attachment.variant(operation.to_sym => [40, 30])
        path = Rails.application.routes.url_helpers.rails_representation_path(variant, only_path: true)
        assert_equal({ operation => '40x30' }, tag.variant_attrs)
        assert_includes tag.content, path, "#{tag_class}: #{operation}"
      end
    end
  end

  def test_multiple_files_each_receive_the_transformation
    fragment = comfy_cms_fragments(:file)
    attachments = [fragment.attachments.first, comfy_cms_files(:default).attachment]
    fragment.stubs(:attachments).returns(attachments)
    tag = ComfyMiddleSeat::Content::Tags::Files.new(
      context: comfy_cms_pages(:default), params: [fragment.identifier, { 'resize_to_fill' => '40x30' }]
    )
    tag.stubs(:fragment).returns(fragment)
    expected = attachments.map do |attachment|
      Rails.application.routes.url_helpers.rails_representation_path(
        attachment.variant(resize_to_fill: [40, 30]), only_path: true
      )
    end.join(' ')
    assert_equal expected, tag.content
  end

  def test_nonvariable_files_keep_the_original_url
    %w[image/svg+xml application/pdf application/zip].each do |content_type|
      blob = active_storage_blobs(:fragment)
      blob.update!(content_type: content_type)
      tag = ComfyMiddleSeat::Content::Tags::File.new(
        context: comfy_cms_pages(:default), params: ['file', { 'resize_to_limit' => '40x30' }]
      )
      attachment = tag.send(:file)
      refute attachment.variable?
      attachment.expects(:variant).never
      tag.stubs(:file).returns(attachment)
      assert_equal Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true), tag.content
      tag.variant_attrs.replace('resize' => '9000x9000^', 'crop' => '100x100+0+0')
      assert_equal Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true), tag.content
    end
  end

  def test_missing_attachment_and_invalid_options
    tag = ComfyMiddleSeat::Content::Tags::File.new(
      context: comfy_cms_pages(:default), params: ['missing', { 'resize_to_limit' => '40x30' }]
    )
    assert_equal '', tag.content
    tag.variant_attrs.replace('resize_to_limit' => '9000x9000')
    assert_equal '', tag.content
    tag = ComfyMiddleSeat::Content::Tags::File.new(
      context: comfy_cms_pages(:default), params: ['file', { 'resize_to_limit' => 'bad' }]
    )
    assert_raises(Error) { tag.content }
  end
end
