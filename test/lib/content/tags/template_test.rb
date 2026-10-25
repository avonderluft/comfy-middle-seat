# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsTemplateTest < ActiveSupport::TestCase
  def test_init
    tag = ComfyMiddleSeat::Content::Tags::Template.new(
      context: @page,
      params: ['path/to/template']
    )
    assert_equal 'path/to/template', tag.path
  end

  def test_init_without_path
    message = 'Missing template path for template tag'
    error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
      ComfyMiddleSeat::Content::Tags::Template.new(context: @page)
    end
    assert_equal message, error.message
  end

  def test_content
    tag = ComfyMiddleSeat::Content::Tags::Template.new(
      context: @page,
      params: ['path/to/template']
    )
    assert_equal '<%= render template: "path/to/template" %>', tag.content
    assert_equal true, tag.allow_erb?
  end

  def test_render
    tag = ComfyMiddleSeat::Content::Tags::Template.new(
      context: @page,
      params: ['path/to/template']
    )
    assert_equal '<%= render template: "path/to/template" %>', tag.render
  end

  def test_render_with_whitelist
    ComfyMiddleSeat.config.allowed_templates = ['allowed/path']
    tag = ComfyMiddleSeat::Content::Tags::Template.new(
      context: @page,
      params: ['allowed/path']
    )
    assert_equal '<%= render template: "allowed/path" %>', tag.render

    tag = ComfyMiddleSeat::Content::Tags::Template.new(
      context: @page,
      params: ['not_allowed/path']
    )
    assert_equal '', tag.render
  end

  def test_renderer_aliases
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)
    assert_nil ComfyMiddleSeat.config.allowed_templates
    assert_equal false, ComfyMiddleSeat.config.allow_erb

    %w[template render_template].each do |name|
      ['path/to/template', '"path/to/template"', "'path/to/template'"].each do |params|
        nodes = renderer.nodes(renderer.tokenize("{{ cms:#{name} #{params} }}"))
        assert_instance_of ComfyMiddleSeat::Content::Tags::Template, nodes.first
        assert_equal 'path/to/template', nodes.first.path
        assert_equal '<%= render template: "path/to/template" %>', renderer.render(nodes)
      end
    end
  end

  def test_renderer_aliases_with_whitelist
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)
    content = '<%= render template: "allowed/path" %>'
    assert_equal false, ComfyMiddleSeat.config.allow_erb

    [[nil, content], [[], ''], [['allowed/path'], content], [['other/path'], '']].each do |whitelist, expected|
      ComfyMiddleSeat.config.allowed_templates = whitelist

      %w[template render_template].each do |name|
        nodes = renderer.nodes(renderer.tokenize("{{ cms:#{name} 'allowed/path' }}"))
        assert_equal expected, renderer.render(nodes), "#{name} with whitelist #{whitelist.inspect}"
      end
    end
  end

  def test_renderer_aliases_without_path
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)

    %w[template render_template].each do |name|
      ['', '""'].each do |params|
        error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
          renderer.nodes(renderer.tokenize("{{ cms:#{name} #{params} }}"))
        end
        assert_equal 'Missing template path for template tag', error.message
      end
    end
  end

  def test_render_with_erb_injection
    tag = ComfyMiddleSeat::Content::Tags::Template.new(
      context: @page,
      params: ["va\#{:l}ue"]
    )
    assert_equal "<%= render template: \"va\\\#{:l}ue\" %>", tag.render
  end
end
