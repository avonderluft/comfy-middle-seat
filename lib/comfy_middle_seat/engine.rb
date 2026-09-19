# frozen_string_literal: true

require 'comfy_middle_seat'
require 'rails'
require 'rails-i18n'
require 'comfy_bootstrap_form'
require 'active_link_to'
require 'kramdown'
require 'haml-rails'

module ComfyMiddleSeat
  class Engine < ::Rails::Engine
    initializer 'comfy_middle_seat.setup_assets' do |app|
      app.config.assets.paths << root.join('app/assets/builds')
      app.config.assets.precompile += %w[comfy/admin/cms/application.js comfy/admin/cms/application.css]
    end

    config.to_prepare do
      Dir.glob("#{Rails.root}app/decorators/comfy_middle_seat/*_decorator*.rb").each do |c|
        require_dependency(c)
      end
    end
  end
end
