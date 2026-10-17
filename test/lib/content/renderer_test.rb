# frozen_string_literal: true

require_relative '../../test_helper'

class ContentRendererTest < ActiveSupport::TestCase
  class TestTag < ComfyMiddleSeat::Content::Tag
    def content
      'test tag content'
    end
  end

  class TestNestedTag < ComfyMiddleSeat::Content::Tag
    def content
      'test {{cms:test}} content'
    end
  end

  class TestBlockTag < ComfyMiddleSeat::Content::Block
    # ...
  end

  DEFAULT_REGISTERED_TAGS = {
    'wysiwyg' => ComfyMiddleSeat::Content::Tags::Wysiwyg,
    'text' => ComfyMiddleSeat::Content::Tags::Text,
    'textarea' => ComfyMiddleSeat::Content::Tags::Textarea,
    'markdown' => ComfyMiddleSeat::Content::Tags::Markdown,
    'datetime' => ComfyMiddleSeat::Content::Tags::Datetime,
    'date' => ComfyMiddleSeat::Content::Tags::Date,
    'number' => ComfyMiddleSeat::Content::Tags::Number,
    'checkbox' => ComfyMiddleSeat::Content::Tags::Checkbox,
    'file' => ComfyMiddleSeat::Content::Tags::File,
    'files' => ComfyMiddleSeat::Content::Tags::Files,
    'snippet' => ComfyMiddleSeat::Content::Tags::Snippet,
    'asset' => ComfyMiddleSeat::Content::Tags::Asset,
    'file_link' => ComfyMiddleSeat::Content::Tags::FileLink,
    'image' => ComfyMiddleSeat::Content::Tags::Image,
    'page_file_link' => ComfyMiddleSeat::Content::Tags::PageFileLink,
    'helper' => ComfyMiddleSeat::Content::Tags::Helper,
    'partial' => ComfyMiddleSeat::Content::Tags::Partial,
    'template' => ComfyMiddleSeat::Content::Tags::Template,
    'audio' => ComfyMiddleSeat::Content::Tags::Audio,
    'breadcrumbs' => ComfyMiddleSeat::Content::Tags::Breadcrumbs,
    'children' => ComfyMiddleSeat::Content::Tags::Children,
    'siblings' => ComfyMiddleSeat::Content::Tags::Siblings
  }.freeze

  setup do
    @page     = comfy_cms_pages(:default)
    @template = ComfyMiddleSeat::Content::Renderer.new(@page)

    ComfyMiddleSeat::Content::Renderer.register_tag(:test, TestTag)
    ComfyMiddleSeat::Content::Renderer.register_tag(:test_nested, TestNestedTag)
    ComfyMiddleSeat::Content::Renderer.register_tag(:test_block, TestBlockTag)
  end

  teardown do
    ComfyMiddleSeat::Content::Renderer.tags.delete('test')
    ComfyMiddleSeat::Content::Renderer.tags.delete('test_nested')
    ComfyMiddleSeat::Content::Renderer.tags.delete('test_block')
  end

  # Test helper so we don't have to do this each time
  def render_string(string, template = @template)
    tokens = template.tokenize(string)
    nodes  = template.nodes(tokens)
    template.render(nodes)
  end

  # -- Tests -------------------------------------------------------------------

  def test_tags
    assert_equal DEFAULT_REGISTERED_TAGS.merge(
      'test' => ContentRendererTest::TestTag,
      'test_nested' => ContentRendererTest::TestNestedTag,
      'test_block' => ContentRendererTest::TestBlockTag
    ), ComfyMiddleSeat::Content::Renderer.tags
  end

  def test_register_tags
    ComfyMiddleSeat::Content::Renderer.register_tag(:other, TestTag)
    assert_equal DEFAULT_REGISTERED_TAGS.merge(
      'test' => ContentRendererTest::TestTag,
      'test_nested' => ContentRendererTest::TestNestedTag,
      'test_block' => ContentRendererTest::TestBlockTag,
      'other' => ContentRendererTest::TestTag
    ), ComfyMiddleSeat::Content::Renderer.tags
  ensure
    ComfyMiddleSeat::Content::Renderer.tags.delete('other')
  end

  def test_tokenize
    assert_equal ['test text'], @template.tokenize('test text')
  end

  def test_tokenize_with_tag
    assert_equal ['test ', { tag_class: 'tag', tag_params: '', source: '{{cms:tag}}' }, ' text'],
                 @template.tokenize('test {{cms:tag}} text')
  end

  def test_tokenize_with_tag_and_params
    expected = [
      'test ',
      { tag_class: 'tag', tag_params: 'name, key:val', source: '{{cms:tag name, key:val}}' },
      ' text'
    ]
    assert_equal expected, @template.tokenize('test {{cms:tag name, key:val}} text')
  end

  def test_tokenize_with_invalid_tag
    assert_equal ['test {{abc:tag}} text'],
                 @template.tokenize('test {{abc:tag}} text')
  end

  def test_tokenize_with_newlines
    expected = [
      { tag_class: 'test', tag_params: '', source: '{{cms:test}}' },
      "\n",
      { tag_class: 'test', tag_params: '', source: '{{cms:test}}' }
    ]
    assert_equal expected, @template.tokenize("{{cms:test}}\n{{cms:test}}")
  end

  def test_comment_block_skips_all_content_before_tag_parsing
    source = <<~CONTENT
      before{{ cms:comment }}
      Private note, <script>hidden()</script>, <%= hidden_helper %>
      {{cms:unknown invalid: [}}
      {{cms:markdown}}
      {{cms:partial}}
      {{cms:end}}
      {{cms:unterminated
      {{ cms:endcomment }}after
    CONTENT
    ComfyMiddleSeat::Content::ParamsParser.expects(:new).never
    ComfyMiddleSeat::Content::Tags::Markdown.expects(:new).never
    ComfyMiddleSeat::Content::Tags::Partial.expects(:new).never

    assert_equal "beforeafter\n", render_string(source)
    ComfyMiddleSeat.config.allow_erb = true
    assert_equal "beforeafter\n", render_string(source)
    assert_includes source, 'Private note'
  end

  def test_short_comments_are_quoted_and_do_not_parse_their_contents
    notes = [
      '{{cms:comment "Private note"}}',
      "{{ cms:comment 'Private note' }}",
      '{{cms:comment ""}}',
      '{{cms:comment "Ignore {{cms:unknown}} and {{cms:endcomment}} here"}}',
      '{{cms:comment "Say \\"hello\\" and use \\\\ paths"}}',
      '{{cms:comment “Smart quotes”}}',
      '{{cms:comment ‘Smart quotes’}}',
      "{{cms:comment \"Multiple\nlines\"}}"
    ]
    notes.each do |note|
      assert_equal 'beforeafter', render_string("before#{note}after"), note
    end
  end

  def test_comment_blocks_support_nesting_and_quoted_notes
    source = <<~CONTENT
      before{{cms:comment}}
      Outer note
      {{cms:comment "A literal {{cms:endcomment}} is not a closing delimiter"}}
      {{cms:comment}}Inner note{{cms:endcomment}}
      Still hidden
      {{cms:endcomment}}after
    CONTENT
    assert_equal "beforeafter\n", render_string(source)
  end

  def test_comment_blocks_do_not_interfere_with_regular_blocks
    tokens = @template.tokenize('a {{cms:test_block}}b{{cms:comment}}{{cms:end}}{{cms:test_block}}{{cms:endcomment}}c{{cms:end}} d')
    nodes = @template.nodes(tokens)

    assert_equal 3, nodes.length
    assert_instance_of TestBlockTag, nodes[1]
    assert_equal 'bc', nodes[1].nodes.join
  end

  def test_comments_preserve_surrounding_whitespace_and_tag_source
    source = "a\n{{cms:comment}}private{{cms:endcomment}}\n{{ cms:text content }}"
    tokens = @template.tokenize(source)

    assert_equal ["a\n", "\n", { tag_class: 'text', tag_params: 'content', source: '{{ cms:text content }}' }], tokens
    assert_equal "a\n\ncontent", @template.render(@template.nodes(tokens))
    assert_equal "a\n\n{{ cms:text content }}", @template.strip_comments(source)
  end

  def test_strip_comments_preserves_trailing_whitespace_for_formatters
    ["{{cms:text content}}\n\n", "\n\n", "<p>Text</p>\n"].each do |source|
      assert_equal source, @template.strip_comments(source)
    end
    assert_equal "\n\n", @template.strip_comments("{{cms:comment \"note\"}}\n\n")
    assert_equal "\n\n", @template.strip_comments("{{cms:comment}}hidden{{cms:endcomment}}\n\n")
  end

  def test_adjacent_comments_and_empty_blocks
    assert_equal 'ab', render_string('a{{cms:comment}}{{cms:endcomment}}{{cms:comment "note"}}b')
    assert_empty @template.tokenize('{{cms:comment}}{{cms:endcomment}}')
  end

  def test_unclosed_comment_blocks_raise_clear_errors
    ['{{cms:comment}}hidden', '{{cms:comment}}{{cms:comment}}hidden{{cms:endcomment}}'].each do |source|
      error = assert_raises ComfyMiddleSeat::Content::Renderer::SyntaxError do
        @template.tokenize(source)
      end
      assert_equal 'Unclosed CMS comment: expected {{cms:endcomment}}', error.message
    end
  end

  def test_orphan_comment_closing_tag_raises_clear_error
    error = assert_raises ComfyMiddleSeat::Content::Renderer::SyntaxError do
      @template.tokenize('before{{cms:endcomment}}after')
    end
    assert_equal 'Unexpected {{cms:endcomment}} without {{cms:comment}}', error.message
  end

  def test_malformed_short_comments_raise_clear_errors
    [
      '{{cms:comment unquoted note}}',
      '{{cms:comment "unclosed note}}',
      '{{cms:comment "note" extra}}',
      '{{cms:comment "one" "two"}}',
      '{{cms:comment "note"',
      '{{cms:comment'
    ].each do |source|
      error = assert_raises ComfyMiddleSeat::Content::Renderer::SyntaxError do
        @template.tokenize(source)
      end
      assert_match 'Invalid CMS comment:', error.message
    end
  end

  def test_comment_closing_tag_rejects_parameters
    error = assert_raises ComfyMiddleSeat::Content::Renderer::SyntaxError do
      @template.tokenize('{{cms:comment}}hidden{{cms:endcomment extra}}')
    end
    assert_match 'Invalid CMS comment closing tag:', error.message
  end

  def test_comment_prefix_does_not_consume_other_tag_names
    assert_equal 'commentary', @template.tokenize('{{cms:commentary content}}').first[:tag_class]
    assert_equal 'endcomment_extra', @template.tokenize('{{cms:endcomment_extra}}').first[:tag_class]
  end

  def test_comment_in_snippet_output_is_not_rendered_or_evaluated
    comfy_cms_snippets(:default).update_column(:content, 'before{{cms:comment}}{{cms:snippet default}}{{cms:endcomment}}after')
    assert_equal 'beforeafter', render_string('{{cms:snippet default}}')
  end

  def test_markdown_comments_are_removed_before_formatting
    source = <<~CONTENT
      {{cms:comment "Internal note"}}
      {{cms:comment}}
      [link]: https://hidden.example.com
      {{cms:markdown}}
      {{cms:endcomment}}
      Visible [link]
    CONTENT
    comfy_cms_fragments(:default).update_column(:content, source)
    comfy_cms_snippets(:default).update_columns(content: source, markdown: true)

    assert_equal "\n<p>Visible [link]</p>\n", render_string('{{cms:markdown content}}')
    assert_equal "\n<p>Visible [link]</p>\n", render_string('{{cms:snippet default}}')
    assert_equal source, comfy_cms_fragments(:default).reload.content
    assert_equal source, comfy_cms_snippets(:default).reload.content
  end

  def test_comments_in_translation_fragment_content
    translation = comfy_cms_translations(:default)
    translation.fragments.find_by!(identifier: 'content').update!(content: 'before{{cms:comment "Note"}}after')
    renderer = ComfyMiddleSeat::Content::Renderer.new(translation)

    assert_equal 'beforeafter', render_string('{{cms:text content}}', renderer)
  end

  def test_nodes
    tokens = @template.tokenize('test')
    nodes = @template.nodes(tokens)
    assert_equal ['test'], nodes
  end

  def test_nodes_with_tags
    tokens = @template.tokenize('test {{cms:test}} content {{cms:test}}')
    nodes = @template.nodes(tokens)
    assert_equal 4, nodes.count
    assert_equal 'test ', nodes[0]
    assert nodes[1].is_a?(ContentRendererTest::TestTag)
    assert_equal ' content ', nodes[2]
    assert nodes[3].is_a?(ContentRendererTest::TestTag)
  end

  def test_nodes_with_tag_with_params
    tokens = @template.tokenize('{{cms:test param, key: value}}')
    nodes = @template.nodes(tokens)
    assert_equal 1, nodes.count
    assert nodes[0].is_a?(ContentRendererTest::TestTag)
    tag = nodes[0]
    assert_equal @page, tag.context
    assert_equal ['param', { 'key' => 'value' }], tag.params
    assert_equal '{{cms:test param, key: value}}', tag.source
  end

  def test_nodes_with_block_tag
    string = 'a {{cms:test_block}} b {{cms:end}} c'
    tokens = @template.tokenize(string)
    nodes = @template.nodes(tokens)
    assert_equal 3, nodes.count

    assert_equal 'a ', nodes[0]
    assert_equal ' c', nodes[2]

    block = nodes[1]
    assert block.is_a?(ContentRendererTest::TestBlockTag)
    assert_equal [' b '], block.nodes
  end

  def test_nodes_with_block_tag_and_tag
    string = 'a {{cms:test_block}} b {{cms:test}} c {{cms:end}} d'
    tokens = @template.tokenize(string)
    nodes = @template.nodes(tokens)
    assert_equal 3, nodes.count
    assert_equal 'a ', nodes[0]
    assert_equal ' d', nodes[2]

    block = nodes[1]
    assert block.is_a?(ContentRendererTest::TestBlockTag)
    assert_equal 3, block.nodes.count
    assert_equal ' b ', block.nodes[0]
    assert_equal ' c ', block.nodes[2]

    tag = block.nodes[1]
    assert tag.is_a?(ContentRendererTest::TestTag)
    assert_equal ['test tag content'], tag.nodes
  end

  def test_nodes_with_nested_block_tag
    string = 'a {{cms:test_block}} b {{cms:test_block}} c {{cms:end}} d {{cms:end}} e'
    tokens = @template.tokenize(string)
    nodes = @template.nodes(tokens)
    assert_equal 3, nodes.count
    assert_equal 'a ', nodes[0]
    assert_equal ' e', nodes[2]

    block = nodes[1]
    assert block.is_a?(ContentRendererTest::TestBlockTag)
    assert_equal 3, block.nodes.count
    assert_equal ' b ', block.nodes[0]
    assert_equal ' d ', block.nodes[2]

    block = block.nodes[1]
    assert_equal [' c '], block.nodes
  end

  def test_nodes_with_unclosed_block_tag
    string = 'a {{cms:test_block}} b'
    tokens = @template.tokenize(string)
    message = 'unclosed block detected'
    error = assert_raises ComfyMiddleSeat::Content::Renderer::SyntaxError do
      @template.nodes(tokens)
    end
    assert_equal message, error.message
  end

  def test_nodes_with_closed_tag
    string = 'a {{cms:end}} b'
    tokens = @template.tokenize(string)
    message = 'closing unopened block'
    error = assert_raises ComfyMiddleSeat::Content::Renderer::SyntaxError do
      @template.nodes(tokens)
    end
    assert_equal message, error.message
  end

  def test_nodes_with_invalid_tag
    string = 'a {{cms:invalid}} b'
    tokens = @template.tokenize(string)
    message = 'Unrecognized tag: {{cms:invalid}}'
    error = assert_raises ComfyMiddleSeat::Content::Renderer::SyntaxError do
      @template.nodes(tokens)
    end
    assert_equal message, error.message
  end

  def test_sanitize_erb
    out = @template.sanitize_erb('<% test %>', false)
    assert_equal '&lt;% test %&gt;', out

    out = @template.sanitize_erb('<% test %>', true)
    assert_equal '<% test %>', out
  end

  def test_render
    out = render_string('test')
    assert_equal 'test', out
  end

  def test_render_with_tag
    out = render_string('a {{cms:text content}} z')
    assert_equal 'a content z', out
  end

  def test_render_with_erb
    out = render_string('<%= 1 + 1 %>')
    assert_equal '&lt;%= 1 + 1 %&gt;', out
  end

  def test_render_with_erb_allowed
    ComfyMiddleSeat.config.allow_erb = true
    out = render_string('<%= 1 + 1 %>')
    assert_equal '<%= 1 + 1 %>', out
  end

  def test_render_with_erb_allowed_via_tag
    out = render_string('{{cms:partial path}}')
    assert_equal '<%= render partial: "path", locals: {} %>', out
  end

  def test_render_with_nested_tag
    string = 'a {{cms:text content}} b'
    comfy_cms_fragments(:default).update_column(:content, 'c {{cms:snippet default}} d')
    comfy_cms_snippets(:default).update_column(:content, 'e {{cms:helper test}} f')
    out = render_string(string)
    assert_equal 'a c e <%= test() %> f d b', out
  end

  def test_render_stack_overflow
    # making self-referencing content loop here
    comfy_cms_snippets(:default).update_column(:content, 'a {{cms:snippet default}} b')
    message = 'Deep tag nesting or recursive nesting detected'
    error = assert_raises ComfyMiddleSeat::Content::Renderer::Error do
      render_string('{{cms:snippet default}}')
    end
    assert_equal message, error.message
  end

  def test_render_with_more_than_max_depth_tags_but_without_stack_overflow
    test_string =
      Array.new(ComfyMiddleSeat::Content::Renderer::MAX_DEPTH * 2) { '{{cms:text content}}' }.join(' ')
    out = render_string(test_string)
    expected =
      Array.new(ComfyMiddleSeat::Content::Renderer::MAX_DEPTH * 2) { 'content' }.join(' ')
    assert_equal expected, out
  end
end
