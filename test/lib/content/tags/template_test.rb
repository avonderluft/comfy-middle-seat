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

  def test_render_with_erb_injection
    tag = ComfyMiddleSeat::Content::Tags::Template.new(
      context: @page,
      params: ["va\#{:l}ue"]
    )
    assert_equal "<%= render template: \"va\\\#{:l}ue\" %>", tag.render
  end
end
