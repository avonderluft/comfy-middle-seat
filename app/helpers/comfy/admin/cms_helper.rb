# frozen_string_literal: true

require 'securerandom'

module Comfy
  module Admin
    module CmsHelper
      # Wrapper around Comfy::FormBuilder
      def comfy_form_with(**options, &)
        form_options = options.merge(builder: ComfyMiddleSeat::FormBuilder)
        form_options[:bootstrap]  = { layout: :horizontal }
        form_options[:local]      = true
        bootstrap_form_with(**form_options, &)
      end

      def comfy_admin_partial(path, params = {})
        render path, params
      rescue ActionView::MissingTemplate
        if ComfyMiddleSeat.config.reveal_cms_partials
          content_tag(:div, class: 'comfy-admin-partial') do
            path
          end
        end
      end

      def cms_draft_form_data(*key_parts, record:)
        namespace = session[:comfy_cms_draft_namespace] ||= SecureRandom.hex(16)
        {
          cms_draft_key: ['comfy-cms:draft:v1', namespace, *key_parts].join(':'),
          cms_draft_title: t('comfy.admin.cms.drafts.title', default: 'Unsaved draft found'),
          cms_draft_message: t(
            'comfy.admin.cms.drafts.message',
            default: 'A locally saved draft is available. Restore it or discard it?'
          ),
          cms_draft_files_message: t(
            'comfy.admin.cms.drafts.files_message',
            default: 'Selected files are not stored and must be selected again.'
          ),
          cms_draft_restore: t('comfy.admin.cms.drafts.restore', default: 'Restore draft'),
          cms_draft_discard: t('comfy.admin.cms.drafts.discard', default: 'Discard draft'),
          cms_save_failed: record.errors.any?
        }
      end

      # Injects some content somewhere inside cms admin area
      def cms_hook(name, options = {})
        ComfyMiddleSeat::ViewHooks.render(name, self, options)
      end

      # @param [String] fragment_id
      # @param [ActiveStorage::Blob] attachment
      # @param [Boolean] multiple
      # @return [String] {{ cms:page_file_link #{fragment_id}, ... }}
      def cms_page_file_link_tag(fragment_id:, attachment:, multiple:)
        filename  = ", filename: \"#{attachment.filename}\""  if multiple
        as        = ', as: image'                             if attachment.image?
        "{{ cms:page_file_link #{fragment_id}#{filename}#{as} }}"
      end

      # @param [Comfy::Cms::File] file
      # @return [String] {{ cms:file_link #{file.id}, ... }}
      def cms_file_link_tag(file)
        if file.attachment.image?
          "{{ cms:image #{file.label} }}"
        else
          "{{ cms:file_link #{file.id} }}"
        end
      end
    end
  end
end
