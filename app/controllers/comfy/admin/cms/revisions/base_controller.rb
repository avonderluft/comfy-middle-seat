# frozen_string_literal: true

class Comfy::Admin::Cms::Revisions::BaseController < Comfy::Admin::Cms::BaseController
  helper_method :record_path, :preview_path

  before_action :load_record
  before_action :load_revision, except: :index
  before_action :authorize

  def index
    revision = @record.revisions.order(created_at: :desc).first
    if revision
      redirect_to action: :show, id: revision.id
    else
      redirect_to record_path
    end
  end

  def show
    @current_content    = @record.revision_fields.to_h { |field| [field, @record.send(field)] }
    @versioned_content  = @record.revision_fields.to_h { |field| [field, @revision.data[field]] }

    render 'comfy/admin/cms/revisions/show'
  end

  def revert
    @record.restore_from_revision(@revision)
    flash[:success] = I18n.t('comfy.admin.cms.revisions.reverted')
    redirect_to record_path
  end

protected

  def load_fragment_content
    current_content = @record.fragments.to_h do |fragment|
      [fragment.identifier, fragment.content]
    end
    versioned_content = @revision.data.fetch('fragments_attributes', []).to_h do |attributes|
      attributes = attributes.with_indifferent_access
      [attributes[:identifier], attributes[:content]]
    end
    identifiers = current_content.keys | versioned_content.keys

    @current_content = identifiers.to_h { |identifier| [identifier, current_content[identifier]] }
    @versioned_content = identifiers.to_h { |identifier| [identifier, versioned_content[identifier]] }
  end

  def render_fragment_preview(cms_page:, locale:)
    apply_revision_in_memory

    @cms_site   = @record.site
    @cms_layout = @record.layout
    @cms_page   = cms_page

    I18n.locale = locale
    response.headers['X-XSS-Protection'] = '0'

    app_layout = @cms_layout.app_layout.presence || false
    render inline: @record.render, layout: app_layout, content_type: 'text/html'
  end

  def apply_revision_in_memory
    @record.fragments.load_target
    @record.fragments.target.clear
    @record.assign_attributes(@revision.data.deep_dup)
  end

  def load_record
    raise 'not implemented'
  end

  def load_revision
    @revision = @record.revisions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:danger] = I18n.t('comfy.admin.cms.revisions.not_found')
    redirect_to record_path
  end

  def record_path
    raise 'not implemented'
  end

  def preview_path
    nil
  end
end
