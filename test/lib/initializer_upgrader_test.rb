# frozen_string_literal: true

require_relative '../test_helper'
require 'comfy_middle_seat/initializer_upgrader' unless defined?(ComfyMiddleSeat::InitializerUpgrader)
require 'open3'
require 'tmpdir'

class InitializerUpgraderTest < ActiveSupport::TestCase
  def test_migrates_legacy_initializer_and_preserves_backup
    with_app do |root|
      legacy_path = initializer_path(root, 'comfortable_media_surfer.rb')
      original = <<~RUBY
        ComfortableMediaSurfer.configure do |config|
          config.seeds_path = 'comfortable_media_surfer'
          config.homepage = 'comfortable-media-surfer'
        end
      RUBY
      write(legacy_path, original)

      output = StringIO.new
      upgrader(root, output).call

      current_path = initializer_path(root, 'comfy_middle_seat.rb')
      refute_path_exists legacy_path
      assert_equal original, File.read("#{legacy_path}.bak")
      assert_equal <<~RUBY, File.read(current_path)
        ComfyMiddleSeat.configure do |config|
          config.seeds_path = 'comfy_middle_seat'
          config.homepage = 'comfy-middle-seat'
        end
      RUBY
      assert_includes output.string, 'Upgraded config/initializers/comfortable_media_surfer.rb'
    end
  end

  def test_dry_run_does_not_modify_files
    with_app do |root|
      legacy_path = initializer_path(root, 'comfortable_media_surfer.rb')
      write(legacy_path, 'ComfortableMediaSurfer.configure {}')

      output = StringIO.new
      upgrader(root, output).call(dry_run: true)

      assert_path_exists legacy_path
      refute_path_exists "#{legacy_path}.bak"
      refute_path_exists initializer_path(root, 'comfy_middle_seat.rb')
      assert_includes output.string, 'Would create config/initializers/comfy_middle_seat.rb'
    end
  end

  def test_updates_renamed_initializer_with_legacy_content
    with_app do |root|
      current_path = initializer_path(root, 'comfy_middle_seat.rb')
      original = 'ComfortableMediaSurfer.configure {}'
      write(current_path, original)

      upgrader(root).call

      assert_equal 'ComfyMiddleSeat.configure {}', File.read(current_path)
      assert_equal original, File.read("#{current_path}.bak")
    end
  end

  def test_is_idempotent_for_current_initializer
    with_app do |root|
      current_path = initializer_path(root, 'comfy_middle_seat.rb')
      write(current_path, 'ComfyMiddleSeat.configure {}')

      output = StringIO.new
      upgrader(root, output).call

      assert_equal 'ComfyMiddleSeat.configure {}', File.read(current_path)
      refute_path_exists "#{current_path}.bak"
      assert_includes output.string, 'already up to date'
    end
  end

  def test_refuses_to_choose_between_two_initializers
    with_app do |root|
      write(initializer_path(root, 'comfortable_media_surfer.rb'), 'legacy')
      write(initializer_path(root, 'comfy_middle_seat.rb'), 'current')

      error = assert_raises(ComfyMiddleSeat::InitializerUpgrader::Error) do
        upgrader(root).call
      end

      assert_includes error.message, 'Both config/initializers/comfortable_media_surfer.rb'
    end
  end

  def test_refuses_to_overwrite_backup
    with_app do |root|
      legacy_path = initializer_path(root, 'comfortable_media_surfer.rb')
      write(legacy_path, 'legacy')
      write("#{legacy_path}.bak", 'existing backup')

      error = assert_raises(ComfyMiddleSeat::InitializerUpgrader::Error) do
        upgrader(root).call
      end

      assert_includes error.message, 'Backup already exists'
      assert_equal 'legacy', File.read(legacy_path)
      assert_equal 'existing backup', File.read("#{legacy_path}.bak")
    end
  end

  def test_executable_migrates_without_booting_rails
    with_app do |root|
      legacy_path = initializer_path(root, 'comfortable_media_surfer.rb')
      write(legacy_path, 'ComfortableMediaSurfer.configure {}')
      executable = Rails.root.join('exe/comfy-middle-seat-upgrade').to_s

      stdout, stderr, status = Open3.capture3(executable, '--root', root)

      assert status.success?, stderr
      assert_empty stderr
      assert_includes stdout, 'Upgraded config/initializers/comfortable_media_surfer.rb'
      assert_equal 'ComfyMiddleSeat.configure {}', File.read(initializer_path(root, 'comfy_middle_seat.rb'))
    end
  end

private

  def with_app
    Dir.mktmpdir('comfy-middle-seat-upgrade') do |root|
      FileUtils.mkdir_p(File.join(root, 'config/initializers'))
      yield root
    end
  end

  def initializer_path(root, name)
    File.join(root, 'config/initializers', name)
  end

  def write(path, content)
    File.binwrite(path, content)
  end

  def upgrader(root, output = StringIO.new)
    ComfyMiddleSeat::InitializerUpgrader.new(root: root, output: output)
  end
end
