# frozen_string_literal: true

require 'strscan'

# Processing content follows these stages:
#
#   string        - Text with tags. like this: "some {{cms:fragment content}} text"
#   tokenization  - Splits string into a list of strings and hashes that define tags
#                   Example: ["some ", {tag_class: "fragment", tag_params: ""}, " text"]
#   nodefying     - Initializes Tag instances from tag hashes and returns list
#                   like this: ["some ", (FragmentTagInstance), " text"]
#   rendering     - Recursively iterates through nodes. Tag instances get their
#                   `render` method called. Result of that is tokenized, nodefied
#                   and rendered once again until there are no tags to expand.
#                   Resulting list is flattened and joined into a final rendered string.
#
class ComfyMiddleSeat::Content::Renderer
  class SyntaxError < StandardError; end
  class Error < StandardError; end

  MAX_DEPTH = 100

  # tags are in this format: {{ cms:tag_class params }}
  TAG_REGEX = %r{\{\{\s*?cms:(?<class>\w+)(?<params>.*?)\}\}}
  COMMENT_START_REGEX = %r{\{\{\s*cms:(?<comment>comment|endcomment)(?=\s|\}\}|\z)}
  TOKEN_REGEX = %r{#{COMMENT_START_REGEX}|#{TAG_REGEX}}
  COMMENT_NOTE_REGEX = %r{(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|“(?:\\.|[^”\\])*”|‘(?:\\.|[^’\\])*’)\s*\}\}}m

  class << self
    # @return [Hash<String, Class<ComfyMiddleSeat::Content::Tag>>]
    def tags
      @tags ||= {}
    end

    # @param [String] name
    # @param [Class<ComfyMiddleSeat::Content::Tag>] klass
    def register_tag(name, klass)
      tags[name.to_s] = klass
    end
  end

  # @param [Comfy::Cms::WithFragments, nil] context
  def initialize(context)
    @context = context
  end

  # This is how we render content out. Takes context (cms page) and content
  # nodes
  # @param [Array<String, ComfyMiddleSeat::Content::Tag>]
  # @param [Boolean] allow_erb
  # @param [Integer] depth current tag nesting position
  def render(nodes, allow_erb = ComfyMiddleSeat.config.allow_erb, depth = 0)
    if depth >= MAX_DEPTH
      raise Error, 'Deep tag nesting or recursive nesting detected'
    end

    nodes.map do |node|
      case node
      when String
        sanitize_erb(node, allow_erb)
      else
        tokens  = tokenize(node.render)
        nodes   = nodes(tokens)
        render(nodes, allow_erb || node.allow_erb?, depth.next)
      end
    end.join
  end

  def sanitize_erb(string, allow_erb)
    if allow_erb
      string.to_s
    else
      string.to_s.gsub('<%', '&lt;%').gsub('%>', '%&gt;')
    end
  end

  # Splitting text with tags into tokens we can process down the line
  # @return [Array<String, {Symbol => String}>]
  def tokenize(string, preserve_whitespace: false)
    tokens = []
    ss = StringScanner.new(string.to_s)
    while (string = ss.scan_until(TOKEN_REGEX))
      text = string.sub(ss[0], '')
      tokens << text unless text.empty?
      case ss[:comment]
      when 'comment'
        skip_comment(ss)
      when 'endcomment'
        raise SyntaxError, 'Unexpected {{cms:endcomment}} without {{cms:comment}}'
      else
        tokens << {
          tag_class: ss[:class],
          tag_params: ss[:params].strip,
          source: ss[0]
        }
      end
    end
    text = ss.rest
    tokens << text if text.present? || (preserve_whitespace && !text.empty?)
    tokens
  end

  # Remove comments before formatters such as Markdown can transform their contents.
  def strip_comments(string)
    tokenize(string, preserve_whitespace: true).map { |token| token.is_a?(Hash) ? token[:source] : token }.join
  end

  # Constructing node tree for content. It's a list of strings and tags with
  # their own `nodes` method that has array of strings and tags with their own
  # `nodes` method that... you get the idea.
  # @param [Array<String, {Symbol => String}>] tokens
  # @return [Array<String, ComfyMiddleSeat::Content::Tag>]
  def nodes(tokens)
    nodes = [[]]
    tokens.each do |token|
      case token

      # tag signature
      when Hash
        case tag_class = token[:tag_class]

        # This handles {{cms:end}} tag. Stopping collecting block nodes.
        when 'end'
          if nodes.one?
            raise SyntaxError, 'closing unopened block'
          end

          nodes.pop

        else
          # @type [Class<ComfyMiddleSeat::Content::Tag>]
          klass = self.class.tags[tag_class] ||
                  raise(SyntaxError, "Unrecognized tag: #{token[:source]}")

          # @type [ComfyMiddleSeat::Content::Tag]
          tag = klass.new(
            context: @context,
            params: ComfyMiddleSeat::Content::ParamsParser.new(token[:tag_params]).params,
            source: token[:source]
          )
          nodes.last << tag

          # If it's a block tag we start collecting nodes into it
          if tag.is_a?(ComfyMiddleSeat::Content::Block)
            nodes << tag.nodes
          end
        end

      # text
      else
        nodes.last << token
      end
    end

    if nodes.count > 1
      raise SyntaxError, 'unclosed block detected'
    end

    nodes.flatten
  end

private

  # Comments are lexical: their contents must never become tag instances or form fields.
  def skip_comment(scanner)
    return unless comment_block?(scanner)

    depth = 1
    while scanner.scan_until(COMMENT_START_REGEX)
      if scanner[:comment] == 'comment'
        depth += 1 if comment_block?(scanner)
      else
        unless scanner.skip(%r{\s*\}\}})
          raise SyntaxError, 'Invalid CMS comment closing tag: use {{cms:endcomment}} without parameters'
        end

        depth -= 1
        return if depth.zero?
      end
    end
    raise SyntaxError, 'Unclosed CMS comment: expected {{cms:endcomment}}'
  end

  def comment_block?(scanner)
    scanner.skip(%r{\s*})
    return true if scanner.skip(%r{\}\}})
    return false if scanner.skip(COMMENT_NOTE_REGEX)

    raise SyntaxError, 'Invalid CMS comment: use {{cms:comment "note"}} or {{cms:comment}}...{{cms:endcomment}}'
  end
end
