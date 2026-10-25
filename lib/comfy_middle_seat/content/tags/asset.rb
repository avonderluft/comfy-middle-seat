# frozen_string_literal: true

# This tag allows for linking of js and css content defined on the layout.
# Looks something like this:
#   {{cms:asset layout_identifier, type: css, as: tag}}
#
# `type` - css | js - what we're outputting here
# `as`   - url (default) | tag - output url or wrap it in the appropriate tag
#
class ComfyMiddleSeat::Content::Tags::Asset < ComfyMiddleSeat::Content::Tag
  attr_reader :identifier, :type, :as

  def initialize(context:, params: [], source: nil)
    super

    options = params.extract_options!
    @identifier = params[0]
    @type       = options['type']
    @as         = options['as'] || 'url'

    return if @identifier.present?

    raise Error, 'Missing layout identifier for asset tag'
  end

  def layout
    @layout ||= context.site.layouts.find_by(identifier: @identifier)
  end

  def content
    return '' unless layout

    url_helpers = Rails.application.routes.url_helpers
    options = { site_id: context.site.id, identifier: layout.identifier, cache_buster: layout.cache_buster, format: @type }
    helpers = ActionController::Base.helpers

    # These are CMS endpoints, not pipeline assets. Use HTML builders to avoid
    # adding asset-host prefixes or applying asset-pipeline settings to the URL.
    case @type
    when 'css'
      path = url_helpers.comfy_cms_render_css_path(**options)
      @as == 'tag' ? helpers.tag.link(href: path, media: 'screen', rel: 'stylesheet', type: 'text/css') : path
    when 'js'
      path = url_helpers.comfy_cms_render_js_path(**options)
      @as == 'tag' ? helpers.content_tag(:script, '', src: path, type: 'text/javascript') : path
    end
  end
end

%i[asset layout_asset].each do |name|
  ComfyMiddleSeat::Content::Renderer.register_tag(name, ComfyMiddleSeat::Content::Tags::Asset)
end
