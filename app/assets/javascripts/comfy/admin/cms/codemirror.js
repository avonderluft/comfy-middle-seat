import jQuery from "jquery";
import CodeMirror from "codemirror";
import "codemirror/mode/markdown/markdown";
import "codemirror/mode/htmlmixed/htmlmixed";

(() => {
  const codeMirrorInstances = [];
  window.CMS.codemirror = {
    init(root = document) {
      for (const textarea of root.querySelectorAll(
        "textarea[data-cms-cm-mode]"
      )) {
        const codemirror = CodeMirror.fromTextArea(textarea, {
          mode: textarea.dataset.cmsCmMode,
          tabSize: 2,
          lineWrapping: true,
          autoCloseTags: true,
          lineNumbers: true,
          viewportMargin: Infinity,
        });
        codemirror.on("change", () => {
          textarea.dispatchEvent(new Event("input", { bubbles: true }));
        });
        codeMirrorInstances.push(codemirror);
      }

      const tabsRoot =
        root.id === "form-fragments"
          ? root
          : root.querySelector("#form-fragments");
      jQuery(tabsRoot)
        .find('a[data-toggle="tab"]')
        .on("shown.bs.tab", () => {
          for (const codemirror of codeMirrorInstances) {
            codemirror.refresh();
          }
        });
    },
    sync(root = document) {
      for (const codemirror of codeMirrorInstances) {
        if (root.contains(codemirror.getTextArea())) codemirror.save();
      }
    },
    restore(root = document) {
      for (const codemirror of codeMirrorInstances) {
        const textarea = codemirror.getTextArea();
        if (!root.contains(textarea)) continue;

        codemirror.setValue(textarea.value);
        codemirror.refresh();
      }
    },
    dispose() {
      for (const codemirror of codeMirrorInstances) {
        codemirror.toTextArea();
      }
      codeMirrorInstances.length = 0;
    },
  };
})();
