# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsImageTest < ActiveSupport::TestCase
  delegate :rails_blob_path, to: 'Rails.application.routes.url_helpers'

  setup do
    @page = comfy_cms_pages(:default)
    @file = comfy_cms_files(:default)
  end

  # -- Tests -------------------------------------------------------------------

  def test_init
    tag = ComfyMiddleSeat::Content::Tags::Image.new(context: @page, params: ['my_image'])
    assert_equal 'my_image', tag.identifier
    assert_equal 'image', tag.as
  end

  def test_init_without_identifier
    message = 'Missing identifier label for image tag'
    error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
      ComfyMiddleSeat::Content::Tags::Image.new(context: @page)
    end
    assert_equal message, error.message
  end

  def test_file
    tag = ComfyMiddleSeat::Content::Tags::Image.new(context: @page, params: [@file.label])
    assert_instance_of Comfy::Cms::File, tag.file_record

    tag = ComfyMiddleSeat::Content::Tags::Image.new(context: @page, params: ['invalid'])
    assert_nil tag.file_record
  end

  def test_content
    tag = ComfyMiddleSeat::Content::Tags::Image.new(
      context: @page,
      params: [@file.label, { 'as' => 'image', 'class' => 'html-class' }]
    )
    [tag.content, tag.render].each do |output|
      html = Nokogiri::HTML.fragment(output)
      assert_equal 1, html.element_children.size
      assert_equal ({
        'src' => rails_blob_path(tag.file, only_path: true),
        'class' => 'html-class', 'alt' => 'default file', 'title' => 'default file'
      }), html.at_css('img').attributes.transform_values(&:value)
    end
  end

  def test_content_escapes_file_record_label_and_class
    label = %q('" onerror="alert(1)"><script>alert(2)</script> & image)
    css_class = %q(image' onerror='alert(3)' " onload="alert(4))
    @file.update!(label: label)
    tag = ComfyMiddleSeat::Content::Tags::Image.new(
      context: @page, params: [label, { 'class' => css_class }]
    )
    html = Nokogiri::HTML.fragment(tag.render)
    assert_equal 1, html.css('*').size
    assert_equal ({
      'src' => rails_blob_path(tag.file, only_path: true),
      'class' => css_class, 'alt' => label, 'title' => label
    }), html.at_css('img').attributes.transform_values(&:value)
  end

  def test_content_when_not_found
    tag = ComfyMiddleSeat::Content::Tags::Image.new(context: @page, params: ['invalid'])
    assert_equal '', tag.content
    assert_equal '', tag.render
  end
end
