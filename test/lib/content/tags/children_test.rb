# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsChildrenTest < ActiveSupport::TestCase
  setup do
    @site   = comfy_cms_sites(:default)
    @layout = comfy_cms_layouts(:default)
    @page   = comfy_cms_pages(:default)
    @parent = @site.pages.create!(layout: @layout, parent: @page, label: 'Parent', slug: 'parent')
    @child1 = @site.pages.create!(layout: @layout, parent: @parent, label: 'Child1', slug: 'child1')
    @child2 = @site.pages.create!(layout: @layout, parent: @parent, label: 'Child2', slug: 'child2')
    @child3 = @site.pages.create!(layout: @layout, parent: @parent, label: 'Child3', slug: 'child3')
    @child4 = @site.pages.create!(layout: @layout, parent: @parent, label: 'Child4', slug: 'child4')
    @child5 = @site.pages.create!(layout: @layout, parent: @parent, label: 'Child5', slug: 'child5', is_published: false)
  end

  def test_init
    tag = ComfyMiddleSeat::Content::Tags::Children.new(
      context: @parent,
      params: []
    )
    assert_equal ({}), tag.locals
  end

  def test_init_with_style
    tag = ComfyMiddleSeat::Content::Tags::Children.new(
      context: @parent,
      params: [{ 'style' => 'font-weight: bold' }]
    )
    assert_equal "<style>#children {font-weight: bold}</style>\n", tag.style
  end

  def test_render
    tag = ComfyMiddleSeat::Content::Tags::Children.new(
      context: @parent,
      params: [{ 'style' => 'font-weight: bold' }]
    )
    html = "<style>#children {font-weight: bold}</style>\n\
<ul id=\"children\">\n\
  <li><a href=/parent/child1>Child1</a></li>\n\
  <li><a href=/parent/child2>Child2</a></li>\n\
  <li><a href=/parent/child3>Child3</a></li>\n\
  <li><a href=/parent/child4>Child4</a></li>\n\
</ul>"

    assert_equal html, tag.render
  end

  def test_render_with_exclusions
    tag = ComfyMiddleSeat::Content::Tags::Children.new(
      context: @parent,
      params: [{ 'exclude' => 'child2,child3' }]
    )
    html = "<ul id=\"children\">\n\
  <li><a href=/parent/child1>Child1</a></li>\n\
  <li><a href=/parent/child4>Child4</a></li>\n\
</ul>"
    assert_equal html, tag.render
  end

  def test_render_with_unpublished_context
    @parent.update!(is_published: false)

    %w[test production staging].each do |environment|
      Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new(environment))
      tag = ComfyMiddleSeat::Content::Tags::Children.new(
        context: @parent,
        params: [{ 'style' => 'font-weight: bold' }]
      )
      assert_empty tag.page_children
      assert_equal '', tag.render
    end
  end

  def test_render_with_unpublished_ancestor
    @page.update!(is_published: false)
    tag = ComfyMiddleSeat::Content::Tags::Children.new(context: @parent.reload)

    assert_empty tag.page_children
    assert_equal '', tag.render
  end

  def test_render_in_development_with_unpublished_ancestry_and_children
    @page.update!(is_published: false)
    @parent.update!(is_published: false)
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new('development'))
    @parent.expects(:published_with_ancestors?).never
    tag = ComfyMiddleSeat::Content::Tags::Children.new(
      context: @parent,
      params: [{ 'exclude' => 'child2' }]
    )

    assert_includes tag.render, 'Child1'
    assert_includes tag.render, 'Child5'
    refute_includes tag.render, 'Child2'
  end

  def test_checks_shared_ancestry_once
    Comfy::Cms::Page.any_instance.expects(:published_with_ancestors?).once.returns(true)
    tag = ComfyMiddleSeat::Content::Tags::Children.new(context: @parent)

    assert_equal [@child1, @child2, @child3, @child4], tag.page_children
    refute_includes tag.render, 'Child5'
  end

  def test_translation_render
    @layout.update!(content: '{{ cms:children }}')
    translation = @parent.translations.create!(locale: 'fr', label: 'Translated Parent')

    assert_equal ComfyMiddleSeat::Content::Tags::Children.new(context: @parent).render,
                 translation.content_cache
    assert_includes translation.content_cache, 'Child1'
    refute_includes translation.content_cache, 'Child5'
  end

  def test_translation_render_with_unpublished_ancestor
    @page.update!(is_published: false)
    @layout.update!(content: '{{ cms:children }}')
    translation = @parent.reload.translations.create!(locale: 'fr', label: 'Translated Parent')

    assert_equal '', translation.content_cache
  end

  def test_render_with_no_kids
    tag = ComfyMiddleSeat::Content::Tags::Children.new(
      context: @child4,
      params: []
    )
    assert_equal '', tag.render
  end
end
