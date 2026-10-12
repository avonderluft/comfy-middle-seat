# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsBreadcrumbsTest < ActiveSupport::TestCase
  setup do
    @site   = comfy_cms_sites(:default)
    @layout = comfy_cms_layouts(:default)
    @page   = comfy_cms_pages(:default)
    @child = @site.pages.create!(layout: @layout, parent: @page, label: 'Child', slug: 'child')
    @gr_child = @site.pages.create!(layout: @layout, parent: @child, label: 'Gr-child', slug: 'gr-child')
    @gr_gr_child = @site.pages.create!(layout: @layout, parent: @gr_child, label: 'Gr-Gr-child', slug: 'gr-gr-child')
  end

  def test_init
    tag = ComfyMiddleSeat::Content::Tags::Breadcrumbs.new(
      context: @gr_gr_child,
      params: []
    )
    assert_equal ({}), tag.locals
  end

  def test_init_with_style
    tag = ComfyMiddleSeat::Content::Tags::Breadcrumbs.new(
      context: @gr_gr_child,
      params: [{ 'style' => 'font-weight: bold' }]
    )
    assert_equal '<style>#breadcrumbs {font-weight: bold}</style>', tag.style
  end

  def test_render_with_unpublished_context
    @gr_gr_child.update!(is_published: false)
    tag = ComfyMiddleSeat::Content::Tags::Breadcrumbs.new(
      context: @gr_gr_child,
      params: [{ 'style' => 'font-weight: bold' }]
    )

    assert_equal '', tag.render
  end

  def test_render_with_unpublished_parent
    @gr_child.update!(is_published: false)
    tag = ComfyMiddleSeat::Content::Tags::Breadcrumbs.new(context: @gr_gr_child.reload)

    assert_equal '', tag.render
  end

  def test_render_with_unpublished_grandparent
    @child.update!(is_published: false)

    %w[test production staging].each do |environment|
      Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new(environment))
      tag = ComfyMiddleSeat::Content::Tags::Breadcrumbs.new(context: @gr_gr_child.reload)

      assert_equal '', tag.render
    end
  end

  def test_render_with_unpublished_root
    @page.update!(is_published: false)
    tag = ComfyMiddleSeat::Content::Tags::Breadcrumbs.new(context: @gr_gr_child.reload)

    assert_equal '', tag.render
  end

  def test_render_in_development_with_unpublished_context_and_ancestors
    [@page, @child, @gr_gr_child].each { |page| page.update!(is_published: false) }
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new('development'))
    @gr_gr_child.expects(:published_with_ancestors?).never
    tag = ComfyMiddleSeat::Content::Tags::Breadcrumbs.new(context: @gr_gr_child)

    assert_equal '<div id="breadcrumbs"><a href=/>Default Page</a> &raquo; ' \
                 '<a href=/child>Child</a> &raquo; ' \
                 '<a href=/child/gr-child>Gr-child</a> &raquo; Gr-Gr-child</div>', tag.render
  end

  def test_translation_render_preserves_current_label
    @layout.update!(content: '{{ cms:breadcrumbs }}')
    translation = @gr_gr_child.translations.create!(locale: 'fr', label: 'Translated Descendant')

    assert_equal '<div id="breadcrumbs"><a href=/>Default Page</a> &raquo; ' \
                 '<a href=/child>Child</a> &raquo; ' \
                 '<a href=/child/gr-child>Gr-child</a> &raquo; Translated Descendant</div>',
                 translation.content_cache
  end

  def test_translation_render_with_unpublished_ancestor
    @child.update!(is_published: false)
    @layout.update!(content: '{{ cms:breadcrumbs }}')
    translation = @gr_gr_child.reload.translations.create!(locale: 'fr', label: 'Translated Descendant')

    assert_equal '', translation.content_cache
  end

  def test_render
    tag = ComfyMiddleSeat::Content::Tags::Breadcrumbs.new(
      context: @gr_gr_child,
      params: [{ 'style' => 'font-weight: bold' }]
    )
    html = "<style>#breadcrumbs {font-weight: bold}</style>\
<div id=\"breadcrumbs\"><a href=/>Default Page</a> &raquo; <a href=/child>Child</a> &raquo; \
<a href=/child/gr-child>Gr-child</a> &raquo; Gr-Gr-child</div>"
    assert_equal html, tag.render
  end
end
