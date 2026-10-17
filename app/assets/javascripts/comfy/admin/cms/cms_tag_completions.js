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

const completionContext = (editor, requireSemicolon = false, start = null) => {
  if (editor.getOption("readOnly") || editor.somethingSelected() ||
      editor.listSelections().length !== 1) return null;

  const to = editor.getCursor();
  const line = editor.getLine(to.line);
  if (/\w/.test(line.charAt(to.ch))) return null;

  if (start && (start.line !== to.line || start.ch > to.ch)) return null;
  // Keep the menu's original start so spaces in a fuzzy query are not lost.
  const match = start
    ? /^(;{0,2}[\w ]*)$/.exec(line.slice(start.ch, to.ch))
    : /(?:^|[\s>])(;;[\w ]*|;?\w*)$/.exec(line.slice(0, to.ch));
  if (!match || (requireSemicolon && !match[1].startsWith(";"))) return null;

  const from = start || CodeMirror.Pos(to.line, to.ch - match[1].length);
  const before = editor.getRange(CodeMirror.Pos(0, 0), from);
  if (before.lastIndexOf("{{") > before.lastIndexOf("}}")) return null;

  return {
    from,
    to,
    selector: match[1].startsWith(";;"),
    query: match[1].replace(/^;{1,2}/, "").toLowerCase().replace(/ /g, ""),
  };
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

const matchRank = (alias, query) => {
  if (alias === query) return 0;
  if (alias.startsWith(query)) return 1;
  if (alias.includes(query)) return 2;

  let position = 0;
  for (const character of query) {
    position = alias.indexOf(character, position);
    if (position === -1) return Infinity;
    position += 1;
  }
  return 3;
};

const displayNames = {
  as: "asset (CSS)",
  css: "asset (CSS)",
  js: "asset (JavaScript)",
  com: "comment (block)",
  nt: "comment (note)",
};

const hints = (editor, start) => {
  const context = completionContext(editor, false, start);
  if (!context) return null;

  return {
    from: context.from,
    to: context.to,
    list: completions
      .map((completion) => ({
        completion,
        rank: Math.min(...completion.aliases.map((alias) => matchRank(alias, context.query))),
      }))
      .filter(({ rank }) => Number.isFinite(rank))
      .sort((a, b) => a.rank - b.rank)
      .map(({ completion }) => ({
        text: completion.text,
        displayText: `;${completion.shortcut} ${displayNames[completion.shortcut] || completion.name}`,
        hint(cm, data) {
          insertCompletion(cm, completion, data.from, data.to);
        },
      })),
  };
};

const showCompletions = (editor, context) => {
  editor.showHint({
    hint: (cm) => hints(cm, context.from),
    completeSingle: false,
    closeCharacters: /[\t\r\n()[\]{}:>,]/,
  });
};

export const cmsTagCompletionKeys = (mode) => {
  if (!["text/html", "htmlmixed", "text/x-markdown", "markdown"].includes(mode)) return {};

  return {
    Tab(editor) {
      const context = completionContext(editor, true);
      if (context?.selector) {
        showCompletions(editor, context);
        return;
      }
      const completion = context && byAlias.get(context.query);
      if (!completion) return CodeMirror.Pass;

      insertCompletion(editor, completion, context.from, context.to);
    },
    "Ctrl-Space"(editor) {
      const context = completionContext(editor);
      if (!context) return CodeMirror.Pass;

      showCompletions(editor, context);
    },
  };
};
