# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsSiblingsTest < ActiveSupport::TestCase
  setup do
    @site   = comfy_cms_sites(:default)
    @layout = comfy_cms_layouts(:default)
    @page   = comfy_cms_pages(:default)
    @first = @site.pages.create!(layout: @layout, parent: @page, label: 'First', slug: 'first')
    @second = @site.pages.create!(layout: @layout, parent: @page, label: 'Second', slug: 'second')
    @third = @site.pages.create!(layout: @layout, parent: @page, label: 'Third', slug: 'third')
    @fourth = @site.pages.create!(layout: @layout, parent: @page, label: 'Fourth', slug: 'fourth')
    @fifth = @site.pages.create!(layout: @layout, parent: @page, label: 'Fifth', slug: 'fifth')
  end

  def test_init
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(
      context: @third,
      params: []
    )
    assert_equal ({}), tag.locals
  end

  def test_init_with_style
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(
      context: @third,
      params: [{ 'style' => 'font-weight: bold' }]
    )
    assert_equal '<style>#siblings {font-weight: bold}</style>', tag.style
  end

  def test_render
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(
      context: @third,
      params: [{ 'style' => 'font-weight: bold' }]
    )
    html = "<style>#siblings {font-weight: bold}</style><div id=\"siblings\">\
<a href=/second>Second</a> &laquo;&nbsp;<em>Previous</em> \
&bull; <em>Next</em>&nbsp;&raquo; <a href=/fourth>Fourth</a></div>"
    assert_equal html, tag.render
  end

  def test_render_skips_unpublished_siblings
    @second.update!(is_published: false)
    @fourth.update!(is_published: false)
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(context: @third)

    assert_equal [comfy_cms_pages(:child), @first, @third, @fifth], tag.sibs
    assert_includes tag.render, 'First'
    assert_includes tag.render, 'Fifth'
    refute_includes tag.render, 'Second'
    refute_includes tag.render, 'Fourth'
  end

  def test_render_with_unpublished_context
    @third.update!(is_published: false)
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(
      context: @third,
      params: [{ 'style' => 'font-weight: bold' }]
    )

    assert_empty tag.sibs
    assert_equal '', tag.render
  end

  def test_render_with_unpublished_parent
    @page.update!(is_published: false)

    %w[test production staging].each do |environment|
      Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new(environment))
      tag = ComfyMiddleSeat::Content::Tags::Siblings.new(context: @third.reload)

      assert_empty tag.sibs
      assert_equal '', tag.render
    end
  end

  def test_render_with_unpublished_grandparent
    @second.update!(parent: @first)
    @third.update!(parent: @first)
    @fourth.update!(parent: @first)
    @page.update!(is_published: false)
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(context: @third.reload)

    assert_empty tag.sibs
    assert_equal '', tag.render
  end

  def test_render_in_development_with_unpublished_ancestry_and_siblings
    [@page, @second, @third, @fourth].each { |page| page.update!(is_published: false) }
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new('development'))
    @third.expects(:published_with_ancestors?).never
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(context: @third)

    assert_includes tag.render, 'Second'
    assert_includes tag.render, 'Fourth'
  end

  def test_checks_shared_ancestry_once
    Comfy::Cms::Page.any_instance.expects(:published_with_ancestors?).once.returns(true)
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(context: @third)

    assert_includes tag.render, 'Second'
    assert_includes tag.render, 'Fourth'
  end

  def test_translation_render
    @layout.update!(content: '{{ cms:siblings }}')
    translation = @third.translations.create!(locale: 'fr', label: 'Translated Third')

    assert_equal ComfyMiddleSeat::Content::Tags::Siblings.new(context: @third).render,
                 translation.content_cache
    assert_includes translation.content_cache, 'Second'
    assert_includes translation.content_cache, 'Fourth'
  end

  def test_translation_render_with_unpublished_ancestor
    @page.update!(is_published: false)
    @layout.update!(content: '{{ cms:siblings }}')
    translation = @third.reload.translations.create!(locale: 'fr', label: 'Translated Third')

    assert_equal '', translation.content_cache
  end

  def test_render_with_no_siblings
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(
      context: @page,
      params: []
    )
    assert_equal '', tag.render
  end

  def test_render_with_exclusions
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(
      context: @third,
      params: [{ 'exclude' => 'second,fourth' }]
    )
    html = "<div id=\"siblings\"><a href=/first>First</a> &laquo;&nbsp;<em>Previous</em> \
&bull; <em>Next</em>&nbsp;&raquo; <a href=/fifth>Fifth</a></div>"
    assert_equal html, tag.render
  end

  def test_render_with_current_page_excluded
    tag = ComfyMiddleSeat::Content::Tags::Siblings.new(
      context: @second,
      params: [{ 'exclude' => 'second,fourth' }]
    )
    html = '<div id="siblings"></div>'
    assert_equal html, tag.render
  end
end
