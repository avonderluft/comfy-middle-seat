# frozen_string_literal: true

require_relative '../test_helper'

class CmsTagCompletionsFrontendTest < ApplicationSystemTestCase
  # Independent expectations: do not load the implementation's completion catalog.
  # shortcut, full-name alias, canonical body, selected placeholder
  TAGS = [
    ['md', 'markdown', 'markdown content', 'content'],
    ['tx', 'text', 'text field', 'field'],
    ['ta', 'textarea', 'textarea content', 'content'],
    ['wys', 'wysiwyg', 'wysiwyg content', 'content'],
    ['da', 'date', 'date field', 'field'],
    ['dt', 'datetime', 'datetime field', 'field'],
    ['num', 'number', 'number field', 'field'],
    ['cb', 'checkbox', 'checkbox field', 'field'],
    ['fi', 'file', 'file attachment, as: link', 'attachment'],
    ['fs', 'files', 'files attachments, as: link', 'attachments'],
    ['im', 'image', 'image "image label"', 'image label'],
    ['au', 'audio', 'audio "path/to/audio"', 'path/to/audio'],
    ['fl', 'file_link', 'file_link file_id, as: link', 'file_id'],
    ['pfl', 'page_file_link', 'page_file_link attachment, as: link', 'attachment'],
    ['sn', 'snippet', 'snippet identifier', 'identifier'],
    ['as', 'asset', 'asset layout_identifier, type: css, as: tag', 'layout_identifier'],
    ['css', 'asset', 'asset layout_identifier, type: css, as: tag', 'layout_identifier'],
    ['js', 'asset', 'asset layout_identifier, type: js, as: tag', 'layout_identifier'],
    ['hlp', 'helper', 'helper method_name', 'method_name'],
    ['par', 'partial', 'partial "path/to/partial"', 'path/to/partial'],
    ['tpl', 'template', 'template "path/to/template"', 'path/to/template'],
    ['cr', 'breadcrumbs', 'breadcrumbs', nil],
    ['ch', 'children', 'children', nil],
    ['si', 'siblings', 'siblings', nil],
    ['com', 'comment', "comment }}\nComment here\n{{ cms:endcomment", 'Comment here'],
    ['nt', 'note', 'comment "Note"', 'Note'],
    ['ec', 'endcomment', 'endcomment', nil],
    ['end', 'end', 'end', nil]
  ].freeze

  setup do
    @site = comfy_cms_sites(:default)
    @editor_selector = '#layout_content'
  end

  def test_tab_expands_every_shortcut_and_full_name_alias_with_selected_placeholder
    visit_layout

    TAGS.each do |shortcut, _name, body, placeholder|
      assert_expansion shortcut, body, placeholder
    end

    # The asset alias means CSS; the JS variant is explicitly requested with ;js.
    TAGS.uniq { |entry| entry[1] }.each do |_shortcut, name, body, placeholder|
      assert_expansion name, body, placeholder
    end

    ['Before ', "Before\n", '<p>'].each do |prefix|
      prepare_editor prefix
      type_keys ';md', :tab
      assert_equal "#{prefix}{{ cms:markdown content }}", editor_value
      assert_equal 'content', editor_selection
    end
  end

  def test_hint_menu_lists_filters_accepts_and_dismisses_without_duplicate_tags
    visit_layout
    prepare_editor ''
    type_keys [:control, ' ']
    assert_selector '.CodeMirror-hints', count: 1
    expected = TAGS.map { |shortcut, name, _body, _placeholder| "#{name == 'note' ? 'comment' : name} (;#{shortcut})" }
    assert_equal expected.sort, all('.CodeMirror-hint').map(&:text).sort
    type_keys :escape
    assert_no_selector '.CodeMirror-hints'
    assert_equal '', editor_value

    [
      ['mark', ['markdown (;md)'], :enter, '{{ cms:markdown content }}', 'content'],
      [';md', ['markdown (;md)'], :tab, '{{ cms:markdown content }}', 'content'],
      [';page_f', ['page_file_link (;pfl)'], :enter, '{{ cms:page_file_link attachment, as: link }}', 'attachment']
    ].each do |prefix, labels, accept_key, expected_tag, placeholder|
      prepare_editor 'Before '
      type_keys prefix, [:control, ' ']
      assert_selector '.CodeMirror-hints', count: 1
      assert_equal labels, all('.CodeMirror-hint').map(&:text)
      type_keys accept_key
      assert_no_selector '.CodeMirror-hints'
      assert_equal "Before #{expected_tag}", editor_value
      assert_equal placeholder, editor_selection
    end

    prepare_editor ''
    type_keys ';f', [:control, ' ']
    assert_selector '.CodeMirror-hints', count: 1
    assert_equal ['file (;fi)', 'file_link (;fl)', 'files (;fs)'], all('.CodeMirror-hint').map(&:text).sort
    type_keys :escape
    assert_no_selector '.CodeMirror-hints'
    assert_equal ';f', editor_value
    type_keys 'oo'
    assert_equal ';foo', editor_value

    prepare_editor ''
    type_keys ';not_a_cms_tag', [:control, ' ']
    assert_no_selector '.CodeMirror-hints'
    assert_equal ';not_a_cms_tag', editor_value

    ['{{ cms:', '{{ cms:markdown ', '{{ cms:markdown content }}'].each do |existing|
      prepare_editor existing
      type_keys [:control, ' ']
      assert_no_selector '.CodeMirror-hints'
      assert_equal existing, editor_value
      type_keys :escape
      assert_no_selector '.CodeMirror-hints'
    end
  end

  def test_menu_filters_while_typing_and_comment_blocks_preserve_indentation
    visit_layout
    prepare_editor ''
    type_keys [:control, ' ']
    assert_selector '.CodeMirror-hints', count: 1
    type_keys ';md'
    assert_selector '.CodeMirror-hint', count: 1, text: 'markdown (;md)'
    type_keys :enter
    assert_equal '{{ cms:markdown content }}', editor_value
    assert_equal 'content', editor_selection

    prepare_editor "<div>\n  "
    type_keys ';com', :tab
    assert_equal "<div>\n  {{ cms:comment }}\n  Comment here\n  {{ cms:endcomment }}", editor_value
    assert_equal 'Comment here', editor_selection
  end

  def test_unsafe_tab_triggers_pass_through_and_other_keys_keep_their_normal_behavior
    visit_layout
    # A lower-priority keyMap makes CodeMirror.Pass observable without calling
    # completion functions or depending on how CodeMirror indents invalid HTML.
    editor_script <<~JAVASCRIPT
      cm.setOption('keyMap', {
        Tab: function(editor) { editor.testTabFallbacks = (editor.testTabFallbacks || 0) + 1; },
        fallthrough: 'default'
      });
    JAVASCRIPT

    [
      ['', 0, nil],
      ['ordinary text', 13, nil],
      [';unknown', 8, nil],
      ['word;md', 7, nil],
      ['(;md', 4, nil],
      [';mdsuffix', 3, nil],
      [';md', 3, 0],
      ['{{ cms:markdown ;md', 19, nil],
      ["{{ cms:comment\n;md", 18, nil]
    ].each do |value, cursor, anchor|
      prepare_editor value, cursor: cursor, anchor: anchor
      assert_tab_falls_through value
      type_keys [:control, ' ']
      assert_no_selector '.CodeMirror-hints' unless ['', 'ordinary text'].include?(value)
      assert_equal value, editor_value
      type_keys :escape
    end

    prepare_editor ";md\n;tx"
    editor_script <<~JAVASCRIPT
      cm.setSelections([
        {anchor: {line: 0, ch: 3}, head: {line: 0, ch: 3}},
        {anchor: {line: 1, ch: 3}, head: {line: 1, ch: 3}}
      ]);
    JAVASCRIPT
    assert_tab_falls_through ";md\n;tx"
    type_keys [:control, ' ']
    assert_no_selector '.CodeMirror-hints'
    assert_equal ";md\n;tx", editor_value
    type_keys :escape

    editor_script "cm.setOption('keyMap', 'default');"
    prepare_editor ''
    type_keys ';md', :escape, '!', :enter, 'plain'
    assert_equal ";md!\nplain", editor_value
    assert_no_selector '.CodeMirror-hints'
  end

  def test_one_undo_reverts_only_the_expansion
    visit_layout
    prepare_editor ''
    type_keys 'Keep this text ', ';md'
    assert_equal 'Keep this text ;md', editor_value
    type_keys :tab
    assert_equal 'Keep this text {{ cms:markdown content }}', editor_value
    type_keys [:control, 'z']
    assert_equal 'Keep this text ;md', editor_value
  end

  def test_css_javascript_and_plain_fields_do_not_offer_cms_completions
    visit_layout
    ['#layout_css', '#layout_js'].each do |selector|
      @editor_selector = selector
      assert_selector "#{selector} + .CodeMirror"
      prepare_editor ''
      type_keys ';md', :tab
      assert_includes editor_value, ';md'
      refute_includes editor_value, '{{ cms:'
      type_keys [:control, ' ']
      assert_no_selector '.CodeMirror-hints'
      refute_includes editor_value, '{{ cms:'
    end

    fill_in 'Layout Name', with: ';md'
    find_field('Layout Name').send_keys [:control, ' '], :tab
    assert_field 'Layout Name', with: ';md'
    assert_no_selector '.CodeMirror-hints'
  end

  def test_markdown_expansion_saves_literal_content_without_affecting_plain_or_visual_fields
    cms_page = comfy_cms_pages(:default)
    comfy_cms_layouts(:default).update!(content: <<~TEXT)
      {{ cms:markdown content }}
      {{ cms:text plain }}
      {{ cms:wysiwyg rich }}
    TEXT
    visit_p edit_comfy_admin_cms_site_page_path(@site, cms_page)
    @editor_selector = '#fragment-content'
    assert_selector '#fragment-content[data-cms-cm-mode="text/x-markdown"]', visible: :hidden
    assert_selector '#fragment-content + .CodeMirror'
    assert_equal 'text/x-markdown', editor_script("return cm.getOption('mode');")
    fill_in 'fragment-plain', with: ';md'
    find_field('fragment-plain').send_keys [:control, ' '], :tab
    assert_field 'fragment-plain', with: ';md'
    assert_no_selector '.CodeMirror-hints'

    rich = find('.redactor-editor')
    rich.click
    type_keys [:control, 'a'], ';md', [:control, ' '], :tab
    assert_equal ';md', rich.text
    assert_no_selector '.CodeMirror-hints'

    prepare_editor "# Heading\n\n"
    type_keys ';sn', :tab
    assert_equal 'identifier', editor_selection
    type_keys 'saved_snippet'
    expected = "# Heading\n\n{{ cms:snippet saved_snippet }}"
    assert_equal expected, editor_value

    click_button 'Update Page'
    assert_text 'Page updated'
    assert_equal expected, cms_page.reload.fragments.find_by!(identifier: 'content').content.gsub("\r\n", "\n")
    assert_equal ';md', cms_page.fragments.find_by!(identifier: 'plain').content
    visit_p edit_comfy_admin_cms_site_page_path(@site, cms_page)
    assert_selector '#fragment-content + .CodeMirror'
    assert_equal expected, editor_value
  end

private

  def visit_layout
    visit_p new_comfy_admin_cms_site_layout_path(@site)
    assert_selector '#layout_content[data-cms-cm-mode="text/html"]', visible: :hidden
    assert_selector '#layout_content + .CodeMirror'
    assert_equal 'text/html', editor_script("return cm.getOption('mode');")
  end

  def editor_script(script)
    page.evaluate_script <<~JAVASCRIPT
      (() => {
        const cm = document.querySelector(#{@editor_selector.to_json}).nextElementSibling.CodeMirror;
        #{script}
      })()
    JAVASCRIPT
  end

  def prepare_editor(value, cursor: value.length, anchor: nil)
    editor_script <<~JAVASCRIPT
      cm.setValue(#{value.to_json});
      cm.setSelection(cm.posFromIndex(#{anchor || cursor}), cm.posFromIndex(#{cursor}));
      cm.clearHistory();
      cm.focus();
      cm.getInputField().focus();
    JAVASCRIPT
  end

  def type_keys(*keys)
    # Session#send_keys clicks the hidden CodeMirror input and fails Cuprite's
    # overlap check. Dispatch real browser keys directly to the focused input.
    page.driver.browser.keyboard.type(*keys)
  end

  def editor_value
    editor_script 'return cm.getValue();'
  end

  def editor_selection
    editor_script 'return cm.getSelection();'
  end

  def assert_expansion(trigger, body, placeholder)
    prepare_editor ''
    type_keys ";#{trigger}", :tab
    expected = "{{ cms:#{body} }}"
    assert_equal expected, editor_value, "Expansion for ;#{trigger}"
    assert_equal placeholder.to_s, editor_selection, "Selection for ;#{trigger}"
    expected_cursor = placeholder ? expected.index(placeholder) : expected.length
    assert_equal expected_cursor, editor_script('return cm.indexFromPos(cm.getCursor("from"));'), "Cursor for ;#{trigger}"
  end

  def assert_tab_falls_through(value)
    before = editor_script 'return cm.testTabFallbacks || 0;'
    type_keys :tab
    assert_equal before + 1, editor_script('return cm.testTabFallbacks || 0;'), "Tab should pass through for #{value.inspect}"
    assert_equal value, editor_value
    assert_no_selector '.CodeMirror-hints'
  end
end
