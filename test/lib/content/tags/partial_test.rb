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

  def test_render_with_erb_injection
    tag = ComfyMiddleSeat::Content::Tags::Partial.new(
      context: @page,
      params: ["foo\#{:bar}", { 'key' => "va\#{:l}ue" }]
    )
    assert_match(%r{<%= render partial: "foo\\\#{:bar}", locals: {"key"\s*=>\s*"va\\\#{:l}ue"} %>}, tag.render)
  end
end
