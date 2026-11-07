# frozen_string_literal: true

require_relative '../../../test_helper'

class ContentTagsFilesTest < ActiveSupport::TestCase
  delegate :rails_blob_path, to: 'Rails.application.routes.url_helpers'

  setup do
    @page = comfy_cms_pages(:default)
  end

  # -- Tests -------------------------------------------------------------------

  def test_init
    tag = ComfyMiddleSeat::Content::Tags::Files.new(context: @page, params: ['test'])
    assert_equal 'test',  tag.identifier
    assert_equal 'url',   tag.as
  end

  def test_init_with_params
    tag = ComfyMiddleSeat::Content::Tags::Files.new(
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
    frag = @page.fragments.create!(
      identifier: 'test'
    )
    frag.update_attribute(:tag, 'files')
    frag.update_attribute(:files, fixture_file_upload('image.jpg', 'image/jpeg'))
    tag = ComfyMiddleSeat::Content::Tags::Files.new(context: @page, params: [frag.identifier])
    out = frag.attachments.map { |a| rails_blob_path(a, only_path: true) }.join(' ')
    assert_equal out, tag.content
  end

  def test_content_preserves_multiple_files_and_space_separators
    frag = @page.fragments.create!(identifier: 'test', tag: 'files')
    frag.attachments.attach([
      fixture_file_upload('image.jpg', 'image/jpeg'),
      fixture_file_upload('document.pdf', 'application/pdf')
    ])
    attachments = frag.attachments.to_a
    assert_equal 2, attachments.size

    %w[url link image].each do |as|
      tag = ComfyMiddleSeat::Content::Tags::Files.new(
        context: @page,
        params: [frag.identifier, { 'as' => as, 'class' => 'file-card', 'label' => 'not used for multiple files' }]
      )
      paths = attachments.map { |attachment| rails_blob_path(attachment, only_path: true) }
      if as == 'url'
        assert_equal paths.join(' '), tag.content
        next
      end

      html = Nokogiri::HTML.fragment(tag.content)
      element_name = as == 'link' ? 'a' : 'img'
      assert_equal [element_name, 'text', element_name], html.children.map(&:name)
      assert_equal ' ', html.children[1].text
      html.element_children.each_with_index do |element, index|
        label = attachments[index].filename.to_s
        if as == 'link'
          assert_equal label, element.text
          assert_empty element.element_children
          assert_equal ({
            'href' => paths[index], 'class' => 'file-card', 'target' => '_blank', 'rel' => 'noopener'
          }), element.attributes.transform_values(&:value)
        else
          assert_equal ({
            'src' => paths[index], 'class' => 'file-card', 'alt' => label, 'title' => label
          }), element.attributes.transform_values(&:value)
        end
      end
    end
  end

  def test_content_no_attachments
    tag = ComfyMiddleSeat::Content::Tags::Files.new(context: @page, params: ['test'])
    assert_equal '', tag.content
  end
end
