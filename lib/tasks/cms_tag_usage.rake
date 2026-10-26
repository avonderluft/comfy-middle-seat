# frozen_string_literal: true

namespace :comfy do
  namespace :cms do
    # The development application and engine share a root, so Rails loads this file twice.
    if Rake::Task.task_defined?('comfy:cms:tag_usage') && Rake::Task['comfy:cms:tag_usage'].actions.any? { |action| action.source_location&.first == __FILE__ }
      next
    end

    desc 'Inventory CMS partials, helpers and templates (SITE=identifier FORMAT=text|json|config)'
    task tag_usage: :environment do
      format = ENV.fetch('FORMAT', 'text')
      abort 'FORMAT must be text, json or config.' unless %w[text json config].include?(format)

      sites = Comfy::Cms::Site.all
      scope = 'all_sites'
      if ENV.key?('SITE')
        identifier = ENV.fetch('SITE')
        sites = sites.where(identifier: identifier)
        abort "Unknown site identifier: #{identifier.inspect}" unless sites.exists?

        scope = 'selected_sites'
      end

      report = ComfyMiddleSeat::Content::TagUsage.new(sites: sites, scope: scope).call
      output = ComfyMiddleSeat::Content::TagUsageReport.new(report)
      $stdout.puts output.public_send(format)
      output.warnings.each { |warning| warn warning }
      abort 'Tag usage scan incomplete; resolve warnings and scan again.' unless report[:complete]
    end
  end
end
