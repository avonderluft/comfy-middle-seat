# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsFileLinkTest < ActiveSupport::TestCase
  delegate :rails_blob_path, to: 'Rails.application.routes.url_helpers'

  setup do
    @page = comfy_cms_pages(:default)
    @file = comfy_cms_files(:default)
  end

  # -- Tests -------------------------------------------------------------------

  def test_init
    tag = ComfyMiddleSeat::Content::Tags::FileLink.new(context: @page, params: ['123'])
    assert_equal '123', tag.identifier
    assert_equal 'url', tag.as
  end

  def test_init_with_params
    tag = ComfyMiddleSeat::Content::Tags::FileLink.new(
      context: @page,
      params: [
        '123', {
          'as' => 'image',
          'resize' => '100x100',
          'gravity' => 'center',
          'crop' => '100x100+0+0'
        }
      ]
    )
    assert_equal '123', tag.identifier
    assert_equal 'image', tag.as
    assert_equal ({
      'resize' => '100x100',
      'gravity' => 'center',
      'crop' => '100x100+0+0'
    }), tag.variant_attrs
  end

  def test_init_without_identifier
    message = 'Missing identifier for file link tag'
    error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
      ComfyMiddleSeat::Content::Tags::FileLink.new(context: @page)
    end
    assert_equal message, error.message
  end

  def test_file
    tag = ComfyMiddleSeat::Content::Tags::FileLink.new(context: @page, params: [@file.id])
    assert_instance_of Comfy::Cms::File, tag.file_record

    tag = ComfyMiddleSeat::Content::Tags::FileLink.new(context: @page, params: ['invalid'])
    assert_nil tag.file_record
  end

  def test_content
    tag = ComfyMiddleSeat::Content::Tags::FileLink.new(context: @page, params: [@file.id])
    out = rails_blob_path(tag.file, only_path: true)
    assert_equal out, tag.content
    assert_equal out, tag.render
  end

  def test_content_as_link
    tag = ComfyMiddleSeat::Content::Tags::FileLink.new(
      context: @page,
      params: [@file.id, { 'as' => 'link', 'class' => 'html-class' }]
    )
    [tag.content, tag.render].each do |output|
      html = Nokogiri::HTML.fragment(output)
      assert_equal 1, html.element_children.size
      link = html.at_css('a')
      assert_equal 'default file', link.text
      assert_equal ({
        'href' => rails_blob_path(tag.file, only_path: true),
        'class' => 'html-class', 'target' => '_blank', 'rel' => 'noopener'
      }), link.attributes.transform_values(&:value)
    end
  end

  def test_content_as_image
    tag = ComfyMiddleSeat::Content::Tags::FileLink.new(
      context: @page,
      params: [@file.id, { 'as' => 'image', 'class' => 'html-class' }]
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

  def test_content_escapes_file_record_label
    label = %q('<img src=x onerror="alert(1)"> & "file")
    @file.update!(label: label)
    tag = ComfyMiddleSeat::Content::Tags::FileLink.new(
      context: @page, params: [@file.id, { 'as' => 'link' }]
    )
    html = Nokogiri::HTML.fragment(tag.render)
    assert_equal 1, html.css('*').size
    assert_equal label, html.at_css('a').text
    assert_equal ({
      'href' => rails_blob_path(tag.file, only_path: true), 'target' => '_blank', 'rel' => 'noopener'
    }), html.at_css('a').attributes.transform_values(&:value)
  end

  def test_content_uses_filename_when_file_record_label_is_blank
    @file.update_column(:label, '')
    %w[link image].each do |as|
      tag = ComfyMiddleSeat::Content::Tags::FileLink.new(context: @page, params: [@file.id, { 'as' => as }])
      element = Nokogiri::HTML.fragment(tag.content).element_children.first
      if as == 'link'
        assert_equal tag.file.filename.to_s, element.text
      else
        assert_equal tag.file.filename.to_s, element['alt']
        assert_equal tag.file.filename.to_s, element['title']
      end
    end
  end

  def test_content_when_not_found
    tag = ComfyMiddleSeat::Content::Tags::FileLink.new(context: @page, params: ['invalid'])
    assert_equal '', tag.content
    assert_equal '', tag.render
  end
end
