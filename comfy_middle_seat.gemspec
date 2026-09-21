# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'comfy_middle_seat/version'

Gem::Specification.new do |spec|
  spec.name          = 'comfy_middle_seat'
  spec.version       = ComfyMiddleSeat::VERSION
  spec.authors       = ['Oleg Khabarov', 'Andrew vonderLuft']
  spec.email         = ['wonder@hey.com']
  spec.homepage      = 'https://github.com/avonderluft/comfy-middle-seat'
  spec.summary       = 'Rails 7.2+ CMS Engine'
  spec.description   = 'Comfy Middle Seat is a Rails 7.2+ CMS engine.'
  spec.license       = 'MIT'

  spec.post_install_message = <<~MESSAGE
    Please run rake comfy:compile_assets to compile assets.
    Upgrading from comfortable_media_surfer? Run bundle exec comfy-middle-seat-upgrade --dry-run first.
  MESSAGE
  spec.bindir = 'exe'
  spec.executables = ['comfy-middle-seat-upgrade']

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|doc)/})
  end

  spec.required_ruby_version = '>= 3.2.0'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata['documentation_uri'] = "#{spec.homepage}/blob/master/README.md#documentation"

  spec.add_dependency 'active_link_to',       '~> 1.0',   '>= 1.0.5'
  spec.add_dependency 'comfy_bootstrap_form', '~> 4.0',   '>= 4.0.0'
  spec.add_dependency 'haml-rails',           '>= 2.1', '< 4.0'
  spec.add_dependency 'image_processing',     '~> 1.2',   '>= 1.12.2'
  spec.add_dependency 'kaminari',             '~> 1.2',   '>= 1.2.2'
  spec.add_dependency 'kramdown',             '~> 2.4',   '>= 2.4.0'
  spec.add_dependency 'mimemagic',            '~> 0.4',   '>= 0.4.3'
  spec.add_dependency 'mini_magick',          '>= 4.12', '< 6.0'
  spec.add_dependency 'rails',                '>= 7.0.0'
  spec.add_dependency 'rails-i18n',           '>= 6.0.0'
end
