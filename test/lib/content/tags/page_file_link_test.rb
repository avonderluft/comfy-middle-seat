# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsPageFileLinkTest < ActiveSupport::TestCase
  delegate :rails_blob_path, to: 'Rails.application.routes.url_helpers'

  setup do
    @page = comfy_cms_pages(:default)
    @file = comfy_cms_files(:default)
  end

  # -- Tests -------------------------------------------------------------------

  def test_init
    tag = ComfyMiddleSeat::Content::Tags::PageFileLink.new(context: @page, params: ['123'])
    assert_equal '123', tag.identifier
    assert_equal 'url', tag.as
  end

  def test_init_with_params
    tag = ComfyMiddleSeat::Content::Tags::PageFileLink.new(
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
    message = 'Missing identifier for page file link tag'
    error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
      ComfyMiddleSeat::Content::Tags::PageFileLink.new(context: @page)
    end
    assert_equal message, error.message
  end

  def test_content
    fragment = comfy_cms_fragments(:file)
    tag = ComfyMiddleSeat::Content::Tags::PageFileLink.new(context: @page, params: [fragment.identifier])
    out = rails_blob_path(tag.file, only_path: true)
    assert_equal out, tag.content
    assert_equal out, tag.render
  end

  def test_content_as_link
    fragment = comfy_cms_fragments(:file)
    tag = ComfyMiddleSeat::Content::Tags::PageFileLink.new(
      context: @page, params: [fragment.identifier, { 'as' => 'link', 'class' => 'file-link' }]
    )
    html = Nokogiri::HTML.fragment(tag.render)
    assert_equal 1, html.element_children.size
    link = html.at_css('a')
    assert_equal tag.file.filename.to_s, link.text
    assert_equal ({
      'href' => rails_blob_path(tag.file, only_path: true),
      'class' => 'file-link', 'target' => '_blank', 'rel' => 'noopener'
    }), link.attributes.transform_values(&:value)
  end

  def test_content_as_image_escapes_class
    fragment = comfy_cms_fragments(:file)
    css_class = %q(image' onerror='alert(1)' " onload="alert(2))
    tag = ComfyMiddleSeat::Content::Tags::PageFileLink.new(
      context: @page, params: [fragment.identifier, { 'as' => 'image', 'class' => css_class }]
    )
    html = Nokogiri::HTML.fragment(tag.render)
    assert_equal 1, html.css('*').size
    assert_equal ({
      'src' => rails_blob_path(tag.file, only_path: true),
      'class' => css_class, 'alt' => tag.file.filename.to_s, 'title' => tag.file.filename.to_s
    }), html.at_css('img').attributes.transform_values(&:value)
  end

  def test_content_when_not_found
    tag = ComfyMiddleSeat::Content::Tags::PageFileLink.new(context: @page, params: ['invalid'])
    assert_equal '', tag.content
    assert_equal '', tag.render
  end
end
