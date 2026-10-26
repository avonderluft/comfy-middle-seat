# frozen_string_literal: true

class Comfy::Admin::Cms::TagUsageController < Comfy::Admin::Cms::BaseController
  before_action :authorize

  def index
    @report = ComfyMiddleSeat::Content::TagUsage.new(
      sites: Comfy::Cms::Site.where(id: @site.id), scope: 'selected_sites'
    ).call
    @candidate_config = ComfyMiddleSeat::Content::TagUsageReport.new(@report).config
  end

protected

  def load_admin_site
    # A report must never silently inventory a different site from the requested one.
    @site = Comfy::Cms::Site.find(params[:site_id])
    session[:site_id] = @site.id
  end
end
