# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsHelperTest < ActiveSupport::TestCase
  def test_init
    tag = ComfyMiddleSeat::Content::Tags::Helper.new(context: @page, params: ['helper_method'])
    assert_equal 'helper_method', tag.method_name
    assert_equal [], tag.params
  end

  def test_init_with_params
    tag = ComfyMiddleSeat::Content::Tags::Helper.new(
      context: @page,
      params: ['helper_method', 'param', { 'key' => 'val' }]
    )
    assert_equal 'helper_method', tag.method_name
    assert_equal ['param', { 'key' => 'val' }], tag.params
  end

  def test_init_without_method_name
    message = 'Missing method name for helper tag'
    error = assert_raises ComfyMiddleSeat::Content::Tag::Error do
      ComfyMiddleSeat::Content::Tags::Helper.new(context: @page)
    end
    assert_equal message, error.message
  end

  def test_content
    tag = ComfyMiddleSeat::Content::Tags::Helper.new(
      context: @page,
      params: ['method_name', 'param', { 'key' => 'val' }]
    )
    assert_match(%r{<%= method_name\("param",{"key"\s*=>\s*"val"}\) %>}, tag.content)
  end

  def test_render
    tag = ComfyMiddleSeat::Content::Tags::Helper.new(
      context: @page,
      params: ['method_name', 'param', { 'key' => 'val' }]
    )
    assert_match(%r{<%= method_name\("param",{"key"\s*=>\s*"val"}\) %>}, tag.render)
  end

  def test_render_with_whitelist
    ComfyMiddleSeat.config.allowed_helpers = %i[tester eval]
    tag = ComfyMiddleSeat::Content::Tags::Helper.new(context: @page, params: ['tester'])
    assert_equal '<%= tester() %>', tag.render

    tag = ComfyMiddleSeat::Content::Tags::Helper.new(context: @page, params: ['eval'])
    assert_equal '<%= eval() %>', tag.render

    tag = ComfyMiddleSeat::Content::Tags::Helper.new(context: @page, params: ['not_whitelisted'])
    assert_nil tag.render
  end

  def test_render_with_blacklist
    ComfyMiddleSeat::Content::Tags::Helper::BLACKLIST.each do |method|
      tag = ComfyMiddleSeat::Content::Tags::Helper.new(context: @page, params: [method])
      assert_nil tag.render
    end
  end

  def test_render_with_erb_injection
    tag = ComfyMiddleSeat::Content::Tags::Helper.new(
      context: @page,
      params: ["foo\#{:bar}", "foo\#{Kernel.exec('poweroff')"]
    )
    assert_equal "<%= foo\#{:bar}(\"foo\\\#{Kernel.exec('poweroff')\") %>", tag.render
  end
end
