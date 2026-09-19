# frozen_string_literal: true

# Loading engine only if this is not a standalone installation
unless defined? ComfyMiddleSeat::Application
  require_relative 'comfy_middle_seat/engine'
end

require_relative 'comfy_middle_seat/version'
require_relative 'comfy_middle_seat/error'
require_relative 'comfy_middle_seat/configuration'
require_relative 'comfy_middle_seat/routing'
require_relative 'comfy_middle_seat/access_control/admin_authentication'
require_relative 'comfy_middle_seat/access_control/admin_authorization'
require_relative 'comfy_middle_seat/access_control/public_authentication'
require_relative 'comfy_middle_seat/access_control/public_authorization'
require_relative 'comfy_middle_seat/render_methods'
require_relative 'comfy_middle_seat/view_hooks'
require_relative 'comfy_middle_seat/form_builder'
require_relative 'comfy_middle_seat/seeds'
require_relative 'comfy_middle_seat/seeds/layout/importer'
require_relative 'comfy_middle_seat/seeds/layout/exporter'
require_relative 'comfy_middle_seat/seeds/page/importer'
require_relative 'comfy_middle_seat/seeds/page/exporter'
require_relative 'comfy_middle_seat/seeds/snippet/importer'
require_relative 'comfy_middle_seat/seeds/snippet/exporter'
require_relative 'comfy_middle_seat/seeds/file/importer'
require_relative 'comfy_middle_seat/seeds/file/exporter'
require_relative 'comfy_middle_seat/content'
require_relative 'comfy_middle_seat/extensions'

module ComfyMiddleSeat
  Version = ComfyMiddleSeat::VERSION

  class << self
    attr_writer :logger

    # Modify CMS configuration
    # Example:
    #   ComfyMiddleSeat.configure do |config|
    #     config.cms_title = 'ComfyMiddleSeat'
    #   end
    def configure
      yield configuration
    end

    # Accessor for ComfyMiddleSeat::Configuration
    def configuration
      @configuration ||= Configuration.new
    end
    alias config configuration

    def logger
      @logger ||= Rails.logger
    end
  end
end
