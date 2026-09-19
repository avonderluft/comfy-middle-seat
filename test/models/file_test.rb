# frozen_string_literal: true

require_relative '../test_helper'

class CmsFileTest < ActiveSupport::TestCase
  def test_fixtures_validity
    Comfy::Cms::File.all.each do |file|
      assert file.valid?, file.errors.full_messages.to_s
      assert file.attachment
      assert file.attachment.blob
    end
  end

  def test_validations
    file = Comfy::Cms::File.new
    assert file.invalid?
    assert_has_errors_on file, :site, :file, :label
  end

  def test_creation
    assert_difference ['Comfy::Cms::File.count', 'ActiveStorage::Attachment.count'] do
      file = comfy_cms_sites(:default).files.create(
        label: 'test',
        description: 'test file',
        file: fixture_file_upload('image.jpg', 'image/jpeg')
      )
      assert_equal 1, file.position
    end
  end

  def test_creation_scopes_position_to_site
    foreign_site = Comfy::Cms::Site.create!(identifier: 'foreign', hostname: 'foreign.example.com')
    foreign_file = foreign_site.files.create!(
      file: fixture_file_upload('document.pdf', 'application/pdf')
    )
    foreign_file.update_column(:position, 10)

    file = comfy_cms_sites(:default).files.create!(
      file: fixture_file_upload('image.jpg', 'image/jpeg')
    )

    assert_equal 1, file.position
  end

  def test_creation_without_label
    assert_difference ['Comfy::Cms::File.count', 'ActiveStorage::Attachment.count'] do
      file = comfy_cms_sites(:default).files.create(
        description: 'test file',
        file: fixture_file_upload('image.jpg', 'image/jpeg')
      )
      assert_equal 1, file.position
      assert_equal 'image.jpg', file.label
    end
  end

  def test_update_invalidates_site_page_content_cache
    page = comfy_cms_pages(:default)
    page.update_column(:content_cache, 'cached content')

    comfy_cms_files(:default).update!(label: 'Updated file')

    assert_nil page.reload.read_attribute(:content_cache)
  end

  def test_save_without_changes_does_not_invalidate_page_content_cache
    page = comfy_cms_pages(:default)
    page.update_column(:content_cache, 'cached content')

    comfy_cms_files(:default).save!

    assert_equal 'cached content', page.reload.read_attribute(:content_cache)
  end

  def test_destroy_invalidates_site_page_content_cache
    page = comfy_cms_pages(:default)
    foreign_site = Comfy::Cms::Site.create!(identifier: 'foreign', hostname: 'foreign.example.com')
    foreign_layout = foreign_site.layouts.create!(identifier: 'foreign')
    foreign_page = foreign_site.pages.create!(label: 'Foreign', layout: foreign_layout)
    page.update_column(:content_cache, 'cached content')
    foreign_page.update_column(:content_cache, 'protected content')

    comfy_cms_files(:default).destroy!

    assert_nil page.reload.read_attribute(:content_cache)
    assert_equal 'protected content', foreign_page.reload.read_attribute(:content_cache)
  end

  def test_scope_with_images
    assert_equal 1, Comfy::Cms::File.with_attached_attachment.with_images.count
    active_storage_blobs(:default).update_column(:content_type, 'application/pdf')
    assert_equal 0, Comfy::Cms::File.with_attached_attachment.with_images.count
  end

  def test_search_matches_label_description_and_filename
    file = comfy_cms_files(:default)
    file.update_columns(label: 'Brand Guide', description: 'Editorial standards')
    file.attachment.blob.update_column(:filename, 'press-kit.pdf')

    assert_equal [file.id], Comfy::Cms::File.search('BRAND').pluck(:id)
    assert_equal [file.id], Comfy::Cms::File.search('editorial').pluck(:id)
    assert_equal [file.id], Comfy::Cms::File.search('press-kit').pluck(:id)
  end
end
