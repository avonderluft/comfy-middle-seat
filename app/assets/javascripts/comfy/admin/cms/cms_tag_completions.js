import CodeMirror from "codemirror";
import "codemirror/addon/hint/show-hint";

const tag = (shortcut, name, params = "", placeholder = null, aliases = []) => ({
  shortcut,
  name,
  aliases: [shortcut, name, ...aliases],
  text: `{{ cms:${name}${params ? ` ${params}` : ""} }}`,
  placeholder,
});

const completions = [
  tag("md", "markdown", "content", "content"),
  tag("tx", "text", "field", "field"),
  tag("ta", "textarea", "content", "content"),
  tag("wys", "wysiwyg", "content", "content"),
  tag("da", "date", "field", "field"),
  tag("dt", "datetime", "field", "field"),
  tag("num", "number", "field", "field"),
  tag("cb", "checkbox", "field", "field"),
  tag("fi", "file", "attachment, as: link", "attachment"),
  tag("fs", "files", "attachments, as: link", "attachments"),
  tag("im", "image", '"image label"', "image label"),
  tag("au", "audio", '"path/to/audio"', "path/to/audio"),
  tag("fl", "file_link", "file_id, as: link", "file_id"),
  tag("pfl", "page_file_link", "attachment, as: link", "attachment"),
  tag("sn", "snippet", "identifier", "identifier"),
  tag("as", "asset", "layout_identifier, type: css, as: tag", "layout_identifier"),
  tag("css", "asset", "layout_identifier, type: css, as: tag", "layout_identifier"),
  tag("js", "asset", "layout_identifier, type: js, as: tag", "layout_identifier"),
  tag("hlp", "helper", "method_name", "method_name"),
  tag("par", "partial", '"path/to/partial"', "path/to/partial"),
  tag("tpl", "template", '"path/to/template"', "path/to/template"),
  tag("cr", "breadcrumbs"),
  tag("ch", "children"),
  tag("si", "siblings"),
  {
    ...tag("com", "comment", "", "Comment here"),
    text: "{{ cms:comment }}\nComment here\n{{ cms:endcomment }}",
  },
  tag("nt", "comment", '"Note"', "Note", ["note"]),
  tag("ec", "endcomment"),
  tag("end", "end"),
];

const byAlias = new Map();
for (const completion of completions) {
  for (const alias of completion.aliases) {
    // Shared full names use the primary entry: asset => ;as, comment => ;com.
    if (!byAlias.has(alias)) byAlias.set(alias, completion);
  }
}

const completionContext = (editor, requireSemicolon = false) => {
  if (editor.getOption("readOnly") || editor.somethingSelected() ||
      editor.listSelections().length !== 1) return null;

  const to = editor.getCursor();
  const line = editor.getLine(to.line);
  if (/\w/.test(line.charAt(to.ch))) return null;

  const match = /(?:^|[\s>])(;?\w*)$/.exec(line.slice(0, to.ch));
  if (!match || (requireSemicolon && !match[1].startsWith(";"))) return null;

  const from = CodeMirror.Pos(to.line, to.ch - match[1].length);
  const before = editor.getRange(CodeMirror.Pos(0, 0), from);
  if (before.lastIndexOf("{{") > before.lastIndexOf("}}")) return null;

  return { from, to, query: match[1].replace(/^;/, "").toLowerCase() };
};

const insertCompletion = (editor, completion, from, to) => {
  const indent = editor.getLine(from.line).match(/^\s*/)[0];
  const text = completion.text.replace(/\n/g, `\n${indent}`);
  const start = editor.indexFromPos(from);

  editor.operation(() => {
    // A distinct history origin keeps the expansion separate from preceding typing.
    editor.replaceRange(text, from, to, "cms-completion");
    if (completion.placeholder) {
      const offset = text.indexOf(completion.placeholder);
      editor.setSelection(
        editor.posFromIndex(start + offset),
        editor.posFromIndex(start + offset + completion.placeholder.length)
      );
    } else {
      editor.setCursor(editor.posFromIndex(start + text.length));
    }
  });
};

const hints = (editor) => {
  const context = completionContext(editor);
  if (!context) return null;

  return {
    from: context.from,
    to: context.to,
    list: completions
      .filter((completion) => completion.aliases.some((alias) => alias.startsWith(context.query)))
      .map((completion) => ({
        text: completion.text,
        displayText: `${completion.name} (;${completion.shortcut})`,
        hint(cm, data) {
          insertCompletion(cm, completion, data.from, data.to);
        },
      })),
  };
};

export const cmsTagCompletionKeys = (mode) => {
  if (!["text/html", "htmlmixed", "text/x-markdown", "markdown"].includes(mode)) return {};

  return {
    Tab(editor) {
      const context = completionContext(editor, true);
      const completion = context && byAlias.get(context.query);
      if (!completion) return CodeMirror.Pass;

      insertCompletion(editor, completion, context.from, context.to);
    },
    "Ctrl-Space"(editor) {
      if (!completionContext(editor)) return CodeMirror.Pass;

      editor.showHint({
        hint: hints,
        completeSingle: false,
        closeCharacters: /[\s()[\]{}:>,]/,
      });
    },
  };
};
