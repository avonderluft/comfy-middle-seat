# frozen_string_literal: true

# Inventory raw CMS content without expanding tags or consulting rendered caches.
class ComfyMiddleSeat::Content::TagUsage
  BATCH_SIZE = 1000
  KINDS = {
    'partial' => 'partial',
    'render_partial' => 'partial',
    'helper' => 'helper',
    'template' => 'template',
    'render_template' => 'template'
  }.freeze

  def initialize(sites: nil, scope: nil)
    @sites = sites || Comfy::Cms::Site.all
    @scope = scope || (sites.nil? ? 'all_sites' : 'selected_sites')
  end

  def call
    @renderer = ComfyMiddleSeat::Content::Renderer.new(nil)
    @entries = {}
    @warnings = []
    @source_count = 0
    @allowlists = %w[partial helper template].to_h do |kind|
      allowed = ComfyMiddleSeat.config.public_send("allowed_#{kind}s")
      next [kind, nil] unless allowed.is_a?(Array)

      # Only helper rendering stringifies allowlists; view paths use exact membership.
      [kind, kind == 'helper' ? allowed.map(&:to_s) : allowed.dup]
    end

    sites = site_details
    site_ids = sites.map { |site| site[:id] }
    scan_content(Comfy::Cms::Layout.where(site_id: site_ids), 'layout')
    scan_content(Comfy::Cms::Snippet.where(site_id: site_ids), 'snippet')
    scan_fragments(Comfy::Cms::Page.where(site_id: site_ids), 'page')
    scan_fragments(Comfy::Cms::Translation.joins(:page).where(comfy_cms_pages: { site_id: site_ids }), 'translation')

    {
      scope: @scope,
      sites: sites,
      source_count: @source_count,
      complete: @warnings.empty?,
      entries: @entries.sort_by { |key, _entry| key }.map { |_key, entry| entry.merge(sources: entry[:sources].values) },
      warnings: @warnings
    }
  end

private

  def site_details
    sites = []
    collect = ->(site) { sites << { id: site.id, identifier: site.identifier, label: site.label } }
    if @sites.respond_to?(:find_each)
      @sites.find_each(batch_size: BATCH_SIZE, &collect)
    else
      @sites.each(&collect)
    end
    sites.uniq { |site| site[:id] }.sort_by { |site| site[:id] }
  end

  def scan_content(records, type)
    records.select(:id, :site_id, :label, :content).readonly.find_each(batch_size: BATCH_SIZE) do |record|
      scan(record.content, {
             site_id: record.site_id, type: type, id: record.id,
             label: record.label, field: 'content', page_id: nil
           })
    end
  end

  def scan_fragments(records, type)
    table = records.klass.table_name
    columns = ["#{table}.id", "#{table}.label", 'comfy_cms_pages.site_id']
    columns << "#{table}.page_id" if type == 'translation'

    # Pluck owner metadata rather than loading pages, their caches or associations.
    records.in_batches(of: BATCH_SIZE) do |batch|
      sources = batch.pluck(*columns).to_h do |id, label, site_id, page_id|
        [id, { site_id: site_id, type: type, id: id, label: label, page_id: page_id }]
      end
      fragments = Comfy::Cms::Fragment.where(record_type: records.klass.polymorphic_name, record_id: sources.keys)
      fragments.select(:id, :record_id, :identifier, :content).readonly.find_each(batch_size: BATCH_SIZE) do |fragment|
        content = fragment.content
        next unless content.is_a?(String)

        scan(content, sources.fetch(fragment.record_id).merge(field: fragment.identifier))
      end
    end
  end

  def scan(content, source)
    @source_count += 1
    @renderer.tokenize(content).each do |token|
      next unless token.is_a?(Hash) && (kind = KINDS[token[:tag_class]])

      scan_token(token, kind, source)
    end
  rescue ComfyMiddleSeat::Content::Renderer::SyntaxError => e
    @warnings << { source: source, message: "Cannot tokenize source: #{e.message}" }
  end

  def scan_token(token, kind, source)
    name = ComfyMiddleSeat::Content::ParamsParser.new(token[:tag_params]).params.first
    unless name.is_a?(String) && name.present?
      @warnings << { source: source, message: "Missing, blank or non-string name in #{token[:source]}" }
      return
    end

    entry = @entries[[kind, name]] ||= { kind: kind, name: name, status: status(kind, name), sources: {} }
    entry[:sources][source] = source
  rescue ComfyMiddleSeat::Content::ParamsParser::Error => e
    @warnings << { source: source, message: "Cannot parse #{token[:source]}: #{e.message}" }
  end

  def status(kind, name)
    if (allowed = @allowlists[kind])
      allowed.include?(name) ? 'explicitly_allowed' : 'blocked'
    elsif kind == 'helper' && ComfyMiddleSeat::Content::Tags::Helper::BLACKLIST.include?(name)
      'blocked'
    else
      'allowed_by_default'
    end
  end
end
