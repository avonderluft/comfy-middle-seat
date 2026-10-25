# frozen_string_literal: true

require_relative '../test_helper'

class RoutingIntergrationTest < ActionDispatch::IntegrationTest
  def teardown
    Rails.application.reload_routes!
  end

  def test_asset_tags_follow_custom_routes_and_serve_css_and_javascript
    page = comfy_cms_pages(:default)
    layout = page.layout
    renderer = ComfyMiddleSeat::Content::Renderer.new(page)

    ['/custom', '/nested/cms/'].each do |prefix|
      Rails.application.routes.draw { comfy_route :cms, path: prefix }
      %w[asset layout_asset].each do |name|
        %w[css js].each do |type|
          source = "{{ cms:#{name} #{layout.identifier}, type: #{type} }}"
          path = renderer.render(renderer.nodes(renderer.tokenize(source)))
          expected = "#{prefix.chomp('/')}/cms-#{type}/#{page.site_id}/#{layout.identifier}/#{layout.cache_buster}.#{type}"
          assert_equal expected, path

          html_source = "{{ cms:#{name} #{layout.identifier}, type: #{type}, as: tag }}"
          html = Nokogiri::HTML.fragment(renderer.render(renderer.nodes(renderer.tokenize(html_source))))
          element = html.at_css(type == 'css' ? 'link' : 'script')
          assert_equal path, element[type == 'css' ? 'href' : 'src']
          assert_equal(type == 'css' ? 'text/css' : 'text/javascript', element['type'])
          if type == 'css'
            assert_equal 'screen', element['media']
            assert_equal 'stylesheet', element['rel']
          end

          get path
          assert_response :success
          assert_equal(type == 'css' ? layout.css : layout.js, response.body)
        end
      end
    end
  end

  def test_asset_tags_respect_the_route_sets_application_prefix
    options = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options[:script_name] = '/app'
    Rails.application.routes.draw { comfy_route :cms, path: '/content' }
    page = comfy_cms_pages(:default)
    %w[css js].each do |type|
      tag = ComfyMiddleSeat::Content::Tags::Asset.new(
        context: page, params: [page.layout.identifier, { 'type' => type }]
      )
      assert_equal "/app/content/cms-#{type}/#{page.site_id}/#{page.layout.identifier}/#{page.layout.cache_buster}.#{type}",
                   tag.content
    end
  ensure
    Rails.application.routes.default_url_options.replace(options)
  end

  def test_cms_public_prefix
    assert_nil ComfyMiddleSeat.config.public_cms_path

    Rails.application.routes.draw do
      comfy_route :cms, path: '/custom'
    end

    assert_equal '/custom', ComfyMiddleSeat.config.public_cms_path
  end
end
