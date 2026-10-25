# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsAssetTest < ActiveSupport::TestCase
  setup do
    @page = comfy_cms_pages(:default)
  end

  def test_init
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(
      context: @page,
      params: ['default']
    )
    assert_equal 'default', tag.identifier
    assert_nil tag.type
    assert_equal 'url', tag.as
  end

  def test_init_with_params
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(
      context: @page,
      params: ['default', { 'type' => 'css', 'as' => 'tag' }]
    )
    assert_equal 'default', tag.identifier
    assert_equal 'css', tag.type
    assert_equal 'tag', tag.as
  end

  def test_init_without_identifier
    message = 'Missing layout identifier for asset tag'
    error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
      ComfyMiddleSeat::Content::Tags::Asset.new(context: @page)
    end
    assert_equal message, error.message
  end

  def test_layout
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(context: @page, params: ['default'])
    assert tag.layout.is_a?(Comfy::Cms::Layout)
  end

  def test_content_for_invalid
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(context: @page, params: ['default'])
    assert_nil tag.content
  end

  def test_content_for_css
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(
      context: @page,
      params: ['default', { 'type' => 'css' }]
    )
    out = "/cms-css/#{@page.site_id}/#{@page.layout.identifier}/#{@page.layout.cache_buster}.css"
    assert_equal out, tag.content
  end

  def test_content_for_css_as_tag
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(
      context: @page,
      params: ['default', { 'type' => 'css', 'as' => 'tag' }]
    )
    out = "/cms-css/#{@page.site_id}/#{@page.layout.identifier}/#{@page.layout.cache_buster}.css"
    out = %(<link href="#{out}" media="screen" rel="stylesheet" type="text/css">)
    assert_equal out, tag.content
  end

  def test_content_uses_routes_not_a_manually_overridden_prefix
    ComfyMiddleSeat.config.public_cms_path = '/not-a-real-route'
    %w[css js].each do |type|
      tag = ComfyMiddleSeat::Content::Tags::Asset.new(context: @page, params: ['default', { 'type' => type }])
      assert_equal "/cms-#{type}/#{@page.site_id}/default/#{@page.layout.cache_buster}.#{type}", tag.content
    end
  end

  def test_content_for_js
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(
      context: @page,
      params: ['default', { 'type' => 'js' }]
    )
    out = "/cms-js/#{@page.site_id}/#{@page.layout.identifier}/#{@page.layout.cache_buster}.js"
    assert_equal out, tag.content
  end

  def test_content_for_js_as_tag
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(
      context: @page,
      params: ['default', { 'type' => 'js', 'as' => 'tag' }]
    )
    out = "/cms-js/#{@page.site_id}/#{@page.layout.identifier}/#{@page.layout.cache_buster}.js"
    out = %(<script src="#{out}" type="text/javascript"></script>)
    assert_equal out, tag.content
  end

  def test_alias_has_identical_rendering_and_defaults
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)
    %w[asset layout_asset].each do |name|
      assert_equal ComfyMiddleSeat::Content::Tags::Asset, renderer.class.tags[name]
      [nil, 'css', 'js', 'invalid'].each do |type|
        %w[url tag].each do |as|
          options = { 'type' => type, 'as' => as }
          expected = ComfyMiddleSeat::Content::Tags::Asset.new(context: @page, params: ['default', options.dup]).render.to_s
          source = "{{ cms:#{name} default, as: #{as}#{", type: #{type}" if type} }}"
          nodes = renderer.nodes(renderer.tokenize(source))
          assert_equal expected, renderer.render(nodes)
        end
      end
    end
  end

  def test_alias_preserves_missing_identifier_error
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)
    error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
      renderer.nodes(renderer.tokenize('{{ cms:layout_asset }}'))
    end
    assert_equal 'Missing layout identifier for asset tag', error.message
  end

  def test_invalid_type_and_missing_layout_preserve_existing_behavior
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(context: @page, params: ['default', { 'type' => 'invalid' }])
    assert_nil tag.content
    tag = ComfyMiddleSeat::Content::Tags::Asset.new(context: @page, params: ['missing', { 'type' => 'css' }])
    assert_equal '', tag.content
  end

  def test_other_sites_layout_cannot_be_rendered
    other_site = Comfy::Cms::Site.create!(identifier: 'other-site', hostname: 'other.example.com')
    other_site.layouts.create!(identifier: 'private-layout', css: 'private css')
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)
    %w[asset layout_asset].each do |name|
      nodes = renderer.nodes(renderer.tokenize("{{ cms:#{name} private-layout, type: css }}"))
      assert_equal '', renderer.render(nodes)
    end
  end

  def test_html_does_not_add_the_application_asset_host
    helpers = ActionController::Base.helpers
    helpers.stubs(:compute_asset_host).raises('CMS assets must not use the asset host')
    %w[css js].each do |type|
      tag = ComfyMiddleSeat::Content::Tags::Asset.new(
        context: @page, params: ['default', { 'type' => type, 'as' => 'tag' }]
      )
      html = Nokogiri::HTML.fragment(tag.content)
      element = html.at_css(type == 'css' ? 'link' : 'script')
      assert_equal "/cms-#{type}/#{@page.site_id}/default/#{@page.layout.cache_buster}.#{type}",
                   element[type == 'css' ? 'href' : 'src']
    end
  end
end
