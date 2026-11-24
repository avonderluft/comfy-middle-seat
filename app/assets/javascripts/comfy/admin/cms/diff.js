import jQuery from "jquery";

const initialized = new WeakSet();
const contextLines = 3;

function element(tag, className, value) {
  const node = document.createElement(tag);
  node.className = className;
  if (value !== undefined) node.textContent = value;
  return node;
}

function compareLines(diff, before, after) {
  // Encode whole lines as tokens so edits cannot match parts of adjacent lines.
  const tokens = new Map();
  const encode = (lines) => lines.map((line) => {
    if (!tokens.has(line)) tokens.set(line, tokens.size);
    return String.fromCharCode(tokens.get(line));
  }).join("");
  const oldLines = encode(before);
  const newLines = encode(after);

  if (tokens.size > 65536) {
    return [[-1, before.length], [1, after.length]];
  }
  return diff.diff_main(oldLines, newLines, false).map(([type, lines]) => [type, lines.length]);
}

function lineCell(line, number, type, pieces) {
  if (line === undefined) return element("div", "revision-cell revision-empty");

  const cell = element("div", `revision-cell revision-${type}`);
  const marker = { added: "+", removed: "−", context: "" }[type];
  const code = element("code", "revision-code");
  for (const [changed, text] of pieces || [[false, line]]) {
    code.append(changed ? element(type === "added" ? "ins" : "del", "", text) : text);
  }

  cell.append(element("span", "revision-line-number", number),
    element("span", "revision-marker", marker), code);
  return cell;
}

function renderSection(section, diff, labels, changes, gaps) {
  const source = section.querySelector(".revision-source");
  const output = section.querySelector("[data-revision-lines]");
  const readLines = (selector) => source.querySelector(selector).textContent.match(/[^\n]*\n|[^\n]+$/g) || [];
  const before = readLines("[data-revision-before]");
  const after = readLines("[data-revision-after]");
  const edits = compareLines(diff, before, after);
  let oldIndex = 0;
  let newIndex = 0;
  output.replaceChildren();

  function contextRows(container, count) {
    for (let line = 0; line < count; line++) {
      const row = element("div", "revision-row revision-context-row");
      row.append(lineCell(before[oldIndex], ++oldIndex, "context"),
        lineCell(after[newIndex], ++newIndex, "context"));
      container.append(row);
    }
  }

  for (let index = 0; index < edits.length;) {
    const [type, count] = edits[index];
    if (type === 0) {
      const leading = index > 0 ? Math.min(count, contextLines) : 0;
      const trailing = index < edits.length - 1 ? Math.min(count - leading, contextLines) : 0;
      const collapsed = count - leading - trailing;
      contextRows(output, leading);
      if (collapsed) {
        const gap = element("details", "revision-gap");
        gap.append(element("summary", "", labels.unchangedLines.replace("%{lines}", collapsed)));
        contextRows(gap, collapsed);
        output.append(gap);
        gaps.push(gap);
      }
      contextRows(output, trailing);
      index++;
      continue;
    }

    const block = element("div", "revision-change");
    let removed = 0;
    let added = 0;
    while (index < edits.length && edits[index][0] !== 0) {
      const [operation, length] = edits[index++];
      if (operation < 0) removed += length;
      else added += length;
    }

    for (let line = 0; line < Math.max(removed, added); line++) {
      const oldLine = line < removed ? before[oldIndex] : undefined;
      const newLine = line < added ? after[newIndex] : undefined;
      let oldPieces;
      let newPieces;
      if (oldLine !== undefined && newLine !== undefined) {
        const pieces = diff.diff_main(oldLine.replace(/\n$/, ""), newLine.replace(/\n$/, ""), false);
        oldPieces = pieces.filter(([operation]) => operation <= 0).map(([operation, text]) => [operation !== 0, text]);
        newPieces = pieces.filter(([operation]) => operation >= 0).map(([operation, text]) => [operation !== 0, text]);
      }
      const row = element("div", "revision-row");
      row.append(lineCell(oldLine, oldLine === undefined ? null : ++oldIndex, "removed", oldPieces),
        lineCell(newLine, newLine === undefined ? null : ++newIndex, "added", newPieces));
      block.append(row);
    }
    output.append(block);
    changes.push(block);
  }
  if (!edits.length) output.append(element("p", "text-muted px-2", labels.noChanges));
  source.hidden = true;
}

function initializeComparison(comparison) {
  if (initialized.has(comparison)) return;
  initialized.add(comparison);

  const diff = new window.diff_match_patch();
  const changes = [];
  const gaps = [];
  const labels = comparison.dataset;
  for (const section of comparison.querySelectorAll(".revision")) {
    renderSection(section, diff, labels, changes, gaps);
  }

  const toolbar = comparison.querySelector(".revision-toolbar");
  const view = toolbar.querySelector("[data-revision-view]");
  const context = toolbar.querySelector("[data-revision-context]");
  const position = toolbar.querySelector("[data-revision-position]");
  const previous = toolbar.querySelector("[data-revision-previous]");
  const next = toolbar.querySelector("[data-revision-next]");
  let active = 0;

  function showChange(index, scroll = false) {
    changes[active]?.classList.remove("revision-change-active");
    active = index;
    changes[active]?.classList.add("revision-change-active");
    previous.disabled = active === 0;
    next.disabled = active >= changes.length - 1;
    position.textContent = changes.length
      ? labels.changePosition.replace("%{position}", active + 1).replace("%{total}", changes.length)
      : labels.noChanges;
    if (scroll) {
      const toolbarTop = parseFloat(window.getComputedStyle(toolbar).top);
      changes[active].style.scrollMarginTop = `${toolbarTop + toolbar.offsetHeight + 12}px`;
      changes[active].scrollIntoView({ block: "start" });
    }
  }

  function updateContextButton() {
    const allOpen = gaps.every((gap) => gap.open);
    context.textContent = allOpen ? labels.collapseUnchanged : labels.showFullContent;
  }

  view.value = window.matchMedia("(max-width: 767px)").matches ? "unified" : "split";
  comparison.dataset.view = view.value;
  view.addEventListener("change", () => { comparison.dataset.view = view.value; });
  previous.addEventListener("click", () => showChange(active - 1, true));
  next.addEventListener("click", () => showChange(active + 1, true));
  context.hidden = gaps.length === 0;
  context.textContent = labels.showFullContent;
  context.addEventListener("click", () => {
    const open = gaps.some((gap) => !gap.open);
    gaps.forEach((gap) => { gap.open = open; });
    updateContextButton();
  });
  gaps.forEach((gap) => gap.addEventListener("toggle", updateContextButton));
  showChange(0);
  toolbar.hidden = false;
}

window.CMS.diff = () => {
  document.querySelectorAll(".revision-comparison").forEach(initializeComparison);
  jQuery(".revision:has(.diff)").prettyTextDiff({
    cleanup: true,
    originalContainer: ".original",
    changedContainer: ".current",
    diffContainer: ".diff .content",
  });
};
