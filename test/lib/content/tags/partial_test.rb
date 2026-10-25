# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsPartialTest < ActiveSupport::TestCase
  def test_init
    tag = ComfyMiddleSeat::Content::Tags::Partial.new(
      context: @page,
      params: ['path/to/partial']
    )
    assert_equal 'path/to/partial', tag.path
    assert_equal ({}), tag.locals
  end

  def test_init_with_locals
    tag = ComfyMiddleSeat::Content::Tags::Partial.new(
      context: @page,
      params: ['path/to/partial', { 'key' => 'val' }]
    )
    assert_equal 'path/to/partial', tag.path
    assert_equal ({ 'key' => 'val' }), tag.locals
  end

  def test_init_without_path
    message = 'Missing path for partial tag'
    error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
      ComfyMiddleSeat::Content::Tags::Partial.new(
        context: @page,
        params: [{ 'key' => 'val' }]
      )
    end
    assert_equal message, error.message
  end

  def test_content
    tag = ComfyMiddleSeat::Content::Tags::Partial.new(
      context: @page,
      params: ['path/to/partial', { 'key' => 'val' }]
    )
    assert_match(%r{<%= render partial: "path/to/partial", locals: {"key"\s*=>\s*"val"} %>}, tag.content)
  end

  def test_render
    tag = ComfyMiddleSeat::Content::Tags::Partial.new(
      context: @page,
      params: ['path/to/partial', { 'key' => 'val' }]
    )
    assert_match(%r{<%= render partial: "path/to/partial", locals: {"key"\s*=>\s*"val"} %>}, tag.render)
  end

  def test_render_with_whitelist
    ComfyMiddleSeat.config.allowed_partials = ['safe/path']

    tag = ComfyMiddleSeat::Content::Tags::Partial.new(
      context: @page,
      params: ['path/to/partial']
    )
    assert_equal '', tag.render

    tag = ComfyMiddleSeat::Content::Tags::Partial.new(
      context: @page,
      params: ['safe/path']
    )
    assert_equal '<%= render partial: "safe/path", locals: {} %>', tag.render
  end

  def test_renderer_aliases
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)
    assert_nil ComfyMiddleSeat.config.allowed_partials
    assert_equal false, ComfyMiddleSeat.config.allow_erb

    %w[partial render_partial].each do |name|
      nodes = renderer.nodes(renderer.tokenize("{{ cms:#{name} path/to/partial }}"))
      assert_instance_of ComfyMiddleSeat::Content::Tags::Partial, nodes.first
      assert_equal 'path/to/partial', nodes.first.path
      assert_equal ({}), nodes.first.locals
      assert_equal '<%= render partial: "path/to/partial", locals: {} %>', renderer.render(nodes)
    end
  end

  def test_renderer_aliases_with_locals
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)
    examples = [
      ['path/to/partial, key: val', 'path/to/partial', { 'key' => 'val' }],
      ['"layouts/embed_video", id:MYpbvXgpIzc', 'layouts/embed_video', { 'id' => 'MYpbvXgpIzc' }],
      ["'layouts/sign' date: '12 April 1979'", 'layouts/sign', { 'date' => '12 April 1979' }]
    ]

    examples.each do |params, path, locals|
      %w[partial render_partial].each do |name|
        nodes = renderer.nodes(renderer.tokenize("{{ cms:#{name} #{params} }}"))
        assert_instance_of ComfyMiddleSeat::Content::Tags::Partial, nodes.first
        assert_equal path, nodes.first.path
        assert_equal locals, nodes.first.locals
        assert_equal "<%= render partial: #{path.inspect}, locals: #{locals} %>", renderer.render(nodes)
      end
    end
  end

  def test_renderer_aliases_with_whitelist
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)
    content = '<%= render partial: "safe/path", locals: {} %>'
    assert_equal false, ComfyMiddleSeat.config.allow_erb

    [[nil, content], [[], ''], [['safe/path'], content], [['other/path'], '']].each do |whitelist, expected|
      ComfyMiddleSeat.config.allowed_partials = whitelist

      %w[partial render_partial].each do |name|
        nodes = renderer.nodes(renderer.tokenize("{{ cms:#{name} 'safe/path' }}"))
        assert_equal expected, renderer.render(nodes), "#{name} with whitelist #{whitelist.inspect}"
      end
    end
  end

  def test_renderer_aliases_without_path
    renderer = ComfyMiddleSeat::Content::Renderer.new(@page)

    %w[partial render_partial].each do |name|
      ['', '""', 'key: val'].each do |params|
        error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
          renderer.nodes(renderer.tokenize("{{ cms:#{name} #{params} }}"))
        end
        assert_equal 'Missing path for partial tag', error.message
      end
    end
  end

  def test_render_with_erb_injection
    tag = ComfyMiddleSeat::Content::Tags::Partial.new(
      context: @page,
      params: ["foo\#{:bar}", { 'key' => "va\#{:l}ue" }]
    )
    assert_match(%r{<%= render partial: "foo\\\#{:bar}", locals: {"key"\s*=>\s*"va\\\#{:l}ue"} %>}, tag.render)
  end
end
