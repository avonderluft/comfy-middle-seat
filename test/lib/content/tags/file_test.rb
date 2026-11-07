# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsFileTest < ActiveSupport::TestCase
  delegate  :rails_blob_path,
            :rails_representation_path,
            to: 'Rails.application.routes.url_helpers'

  setup do
    @page = comfy_cms_pages(:default)
  end

  # -- Tests -------------------------------------------------------------------

  def test_init
    tag = ComfyMiddleSeat::Content::Tags::File.new(context: @page, params: ['test'])
    assert_equal 'test',  tag.identifier
    assert_equal 'url',   tag.as
  end

  def test_init_with_params
    tag = ComfyMiddleSeat::Content::Tags::File.new(
      context: @page,
      params: ['test', {
        'as' => 'image',
        'resize' => '100x100',
        'gravity' => 'center',
        'crop' => '100x100+0+0'
      }]
    )
    assert_equal 'test',  tag.identifier
    assert_equal 'image', tag.as
    assert_equal ({
      'resize' => '100x100',
      'gravity' => 'center',
      'crop' => '100x100+0+0'
    }), tag.variant_attrs
  end

  def test_content
    frag = comfy_cms_fragments(:file)
    tag = ComfyMiddleSeat::Content::Tags::File.new(context: @page, params: [frag.identifier])
    assert_equal rails_blob_path(frag.attachments.first, only_path: true), tag.content
  end

  def test_content_as_link
    frag = comfy_cms_fragments(:file)
    tag = ComfyMiddleSeat::Content::Tags::File.new(
      context: @page,
      params: [frag.identifier, { 'as' => 'link', 'class' => 'html-class' }]
    )

    html = Nokogiri::HTML.fragment(tag.content)
    assert_equal 1, html.element_children.size
    link = html.at_css('a')
    assert_equal 'fragment.jpeg', link.text
    assert_equal ({
      'href' => rails_blob_path(frag.attachments.first, only_path: true),
      'class' => 'html-class', 'target' => '_blank', 'rel' => 'noopener'
    }), link.attributes.transform_values(&:value)
  end

  def test_content_as_image
    frag = comfy_cms_fragments(:file)
    tag = ComfyMiddleSeat::Content::Tags::File.new(
      context: @page,
      params: [frag.identifier, { 'as' => 'image', 'class' => 'html-class' }]
    )
    html = Nokogiri::HTML.fragment(tag.content)
    assert_equal 1, html.element_children.size
    assert_equal ({
      'src' => rails_blob_path(frag.attachments.first, only_path: true),
      'class' => 'html-class', 'alt' => 'fragment.jpeg', 'title' => 'fragment.jpeg'
    }), html.at_css('img').attributes.transform_values(&:value)
  end

  def test_content_as_image_with_variant
    frag = comfy_cms_fragments(:file)
    tag = ComfyMiddleSeat::Content::Tags::File.new(
      context: @page,
      params: [frag.identifier, { 'as' => 'image', 'resize' => '50x50' }]
    )
    variant = frag.attachments.first.variant(resize_to_fit: [50, 50])
    html = Nokogiri::HTML.fragment(tag.content)
    assert_equal 1, html.element_children.size
    assert_equal ({
      'src' => rails_representation_path(variant, only_path: true),
      'alt' => 'fragment.jpeg', 'title' => 'fragment.jpeg'
    }), html.at_css('img').attributes.transform_values(&:value)
  end

  def test_content_escapes_link_text_and_class
    frag = comfy_cms_fragments(:file)
    label = %q(<img src=x onerror="alert(1)"> Bob's "file" & more)
    css_class = %q(card' onclick='alert(2)' " onmouseover="alert(3))
    tag = ComfyMiddleSeat::Content::Tags::File.new(
      context: @page,
      params: [frag.identifier, { 'as' => 'link', 'label' => label, 'class' => css_class }]
    )

    [tag.content, tag.render].each do |output|
      html = Nokogiri::HTML.fragment(output)
      assert_equal 1, html.element_children.size
      link = html.at_css('a')
      assert_empty link.element_children
      assert_equal label, link.text
      assert_equal ({
        'href' => rails_blob_path(frag.attachments.first, only_path: true),
        'class' => css_class, 'target' => '_blank', 'rel' => 'noopener'
      }), link.attributes.transform_values(&:value)
    end
  end

  def test_content_escapes_image_attributes
    frag = comfy_cms_fragments(:file)
    label = %q('" onerror="alert(1)"><script>alert(2)</script> & more)
    css_class = %q(card' onerror='alert(3)' " onload="alert(4))
    tag = ComfyMiddleSeat::Content::Tags::File.new(
      context: @page,
      params: [frag.identifier, { 'as' => 'image', 'label' => label, 'class' => css_class }]
    )

    [tag.content, tag.render].each do |output|
      html = Nokogiri::HTML.fragment(output)
      assert_equal 1, html.css('*').size
      assert_equal ({
        'src' => rails_blob_path(frag.attachments.first, only_path: true),
        'class' => css_class, 'alt' => label, 'title' => label
      }), html.at_css('img').attributes.transform_values(&:value)
    end
  end

  def test_content_omits_blank_class
    frag = comfy_cms_fragments(:file)
    [nil, '', '  '].each do |css_class|
      %w[link image].each do |as|
        tag = ComfyMiddleSeat::Content::Tags::File.new(
          context: @page, params: [frag.identifier, { 'as' => as, 'class' => css_class }]
        )
        element = Nokogiri::HTML.fragment(tag.content).element_children.first
        refute element.key?('class')
      end
    end
  end

  def test_content_preserves_relative_blob_and_variant_urls_with_asset_host
    frag = comfy_cms_fragments(:file)
    attachment = frag.attachments.first
    helpers = ActionController::Base.helpers
    helpers.config.stubs(:asset_host).returns('https://assets.example.com')
    helpers.stubs(:compute_asset_host).raises('Attachments must not use the asset host')

    [{}, { 'resize' => '50x50' }].each do |variant_attrs|
      path = if variant_attrs.empty?
               rails_blob_path(attachment, only_path: true)
             else
               rails_representation_path(attachment.variant(resize_to_fit: [50, 50]), only_path: true)
             end
      %w[url link image].each do |as|
        tag = ComfyMiddleSeat::Content::Tags::File.new(
          context: @page, params: [frag.identifier, variant_attrs.merge('as' => as)]
        )
        if as == 'url'
          assert_equal path, tag.content
        else
          element = Nokogiri::HTML.fragment(tag.content).element_children.first
          assert_equal path, element[as == 'link' ? 'href' : 'src']
        end
      end
    end
  end

  def test_content_with_no_attachment
    tag = ComfyMiddleSeat::Content::Tags::File.new(context: @page, params: ['test'])
    assert_equal '', tag.content
  end
end
