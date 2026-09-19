# frozen_string_literal: true

require 'fileutils'
require_relative 'version'

class ComfyMiddleSeat::InitializerUpgrader
  class Error < StandardError; end

  LEGACY_PATH = 'config/initializers/comfortable_media_surfer.rb'
  CURRENT_PATH = 'config/initializers/comfy_middle_seat.rb'
  REPLACEMENTS = {
    'ComfortableMediaSurfer' => 'ComfyMiddleSeat',
    'comfortable_media_surfer' => 'comfy_middle_seat',
    'comfortable-media-surfer' => 'comfy-middle-seat'
  }.freeze

  def initialize(root: Dir.pwd, output: $stdout)
    @root = File.expand_path(root)
    @output = output
  end

  def call(dry_run: false)
    legacy_path = expand(LEGACY_PATH)
    current_path = expand(CURRENT_PATH)

    if File.exist?(legacy_path) && File.exist?(current_path)
      raise Error, "Both #{LEGACY_PATH} and #{CURRENT_PATH} exist; merge them manually before rerunning."
    end

    if File.exist?(legacy_path)
      migrate(legacy_path, current_path, dry_run: dry_run)
    elsif File.exist?(current_path)
      update(current_path, dry_run: dry_run)
    else
      raise Error, "No CMS initializer found at #{LEGACY_PATH} or #{CURRENT_PATH}."
    end
  end

private

  def migrate(source, destination, dry_run:)
    backup = backup_path(source)
    ensure_backup_available!(backup)
    content = upgraded_content(source)

    if dry_run
      output "Would back up #{relative(source)} to #{relative(backup)}."
      output "Would create #{relative(destination)} with ComfyMiddleSeat references."
      output "Would remove #{relative(source)} after a successful conversion."
      return
    end

    FileUtils.cp(source, backup, preserve: true)
    write(destination, content, mode: File.stat(source).mode)
    FileUtils.rm(source)
    output "Upgraded #{LEGACY_PATH} to #{CURRENT_PATH}."
    output "Original initializer preserved at #{relative(backup)}."
  end

  def update(path, dry_run:)
    content = upgraded_content(path)
    if content == File.binread(path)
      output "#{CURRENT_PATH} is already up to date."
      return
    end

    backup = backup_path(path)
    ensure_backup_available!(backup)

    if dry_run
      output "Would back up #{relative(path)} to #{relative(backup)}."
      output "Would update legacy references in #{relative(path)}."
      return
    end

    FileUtils.cp(path, backup, preserve: true)
    write(path, content, mode: File.stat(path).mode)
    output "Updated legacy references in #{CURRENT_PATH}."
    output "Original initializer preserved at #{relative(backup)}."
  end

  def upgraded_content(path)
    REPLACEMENTS.reduce(File.binread(path)) do |content, (legacy, current)|
      content.gsub(legacy, current)
    end
  end

  def write(path, content, mode:)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
    File.chmod(mode & 0o7777, path)
  end

  def ensure_backup_available!(path)
    return unless File.exist?(path)

    raise Error, "Backup already exists at #{relative(path)}; move or remove it before rerunning."
  end

  def backup_path(path)
    "#{path}.bak"
  end

  def expand(path)
    File.join(@root, path)
  end

  def relative(path)
    path.delete_prefix("#{@root}/")
  end

  def output(message)
    @output.puts(message)
  end
end
