# frozen_string_literal: true

require 'json'

class ComfyMiddleSeat::Content::TagUsageReport
  KINDS = %w[partial helper template].freeze
  STATUSES = {
    'explicitly_allowed' => 'Explicitly allowed',
    'allowed_by_default' => 'Allowed by default',
    'blocked' => 'Blocked'
  }.freeze

  def initialize(report)
    @report = report
  end

  def json
    JSON.pretty_generate(@report)
  end

  def text
    lines = [
      "Tag usage — #{scope}",
      "Sites: #{@report[:sites].map { |site| site[:identifier].inspect }.join(', ')}",
      "Sources scanned: #{@report[:source_count]}",
      @report[:complete] ? 'Scan complete.' : 'Scan incomplete; review warnings.',
      'Counts are saved source fields, not runtime executions.'
    ]
    KINDS.each do |kind|
      lines << "\n#{kind.capitalize}s"
      entries = entries_for(kind)
      lines << '  No matching tags found.' if entries.empty?
      entries.each do |entry|
        lines << "  #{entry[:name].inspect} — #{STATUSES.fetch(entry[:status])} — #{entry[:sources].size} source(s)"
      end
    end
    "#{lines.join("\n")}\n"
  end

  def config
    lines = [
      '# Candidate allowlists only. Review every name before applying.',
      '# Discovery is not security approval; blocked names are included.',
      '# Replacing allowlists blocks omitted names, including existing approved uses.',
      "# Scope: #{scope}. Sites: #{@report[:sites].map { |site| site[:identifier].inspect }.join(', ')}"
    ]
    if @report[:scope] != 'all_sites'
      lines << '# Site-filtered report: NOT a complete application-wide allowlist.'
    end
    lines << '# INCOMPLETE SCAN: resolve warnings before using these lists.' unless @report[:complete]
    lines << 'ComfyMiddleSeat.configure do |config|'
    KINDS.each do |kind|
      names = entries_for(kind).map { |entry| entry[:name] }.uniq.sort
      if names.empty?
        lines << "  config.allowed_#{kind}s = []"
      else
        lines << "  config.allowed_#{kind}s = ["
        names.each { |name| lines << "    #{name.inspect}," }
        lines << '  ]'
      end
    end
    lines << 'end'
    "#{lines.join("\n")}\n"
  end

  def warnings
    @report[:warnings].map do |warning|
      source = warning[:source]
      location = "site #{source[:site_id]}, #{source[:type]} #{source[:id]}, field #{source[:field].inspect}"
      "Warning (#{location}): #{warning[:message].inspect}"
    end
  end

private

  def scope
    @report[:scope] == 'all_sites' ? 'all sites' : 'selected sites'
  end

  def entries_for(kind)
    @report[:entries].select { |entry| entry[:kind] == kind }.sort_by { |entry| entry[:name] }
  end
end
