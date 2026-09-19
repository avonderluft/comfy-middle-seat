import Modal from "bootstrap/js/src/modal";

(() => {
  const VERSION = 1;
  const DEBOUNCE_DELAY = 500;
  const fragmentIdentifierName =
    /\[fragments_attributes\]\[\d+\]\[identifier\]$/;
  const ignoredNames = new Set([
    "authenticity_token",
    "cms_draft_key",
    "_method",
    "utf8",
  ]);

  let forms = [];
  let timers = new Map();
  let changedForms = new Set();
  let suspendedForms = new Set();
  let formHandlers = new Map();
  let baselines = new WeakMap();
  let prompt = null;

  const safely = (operation, fallback = null) => {
    try {
      return operation();
    } catch (error) {
      console.warn("CMS draft storage is unavailable", error);
      return fallback;
    }
  };

  const readStoredValue = (storageName, key) =>
    safely(() => window[storageName].getItem(key));

  const writeStoredValue = (storageName, key, value) =>
    safely(() => {
      window[storageName].setItem(key, value);
      return true;
    }, false);

  const removeStoredValue = (storageName, key) =>
    safely(() => {
      window[storageName].removeItem(key);
      return true;
    }, false);

  const parseStoredValue = (value) => {
    if (!value) return null;

    return safely(() => JSON.parse(value));
  };

  const syncEditors = (root) => {
    if (CMS.codemirror && CMS.codemirror.sync) CMS.codemirror.sync(root);
    if (CMS.wysiwyg && CMS.wysiwyg.sync) CMS.wysiwyg.sync(root);
  };

  const restoreEditors = (root) => {
    if (CMS.codemirror && CMS.codemirror.restore) {
      CMS.codemirror.restore(root);
    }
    if (CMS.wysiwyg && CMS.wysiwyg.restore) CMS.wysiwyg.restore(root);
  };

  const fragmentDefinitions = (form) => {
    const definitions = [];
    const inputs = form.querySelectorAll(
      'input[type="hidden"][name*="[fragments_attributes]"][name$="[identifier]"]'
    );

    for (const input of inputs) {
      if (!fragmentIdentifierName.test(input.name)) continue;

      definitions.push({
        identifier: input.value,
        prefix: input.name.slice(0, -"[identifier]".length),
      });
    }

    return definitions;
  };

  const controlState = (control) => {
    const type = (control.type || "").toLowerCase();

    if (["button", "image", "reset", "submit", "file"].includes(type)) {
      return null;
    }

    if (type === "checkbox" || type === "radio") {
      return { kind: "checked", value: control.value, checked: control.checked };
    }

    if (control instanceof HTMLSelectElement && control.multiple) {
      return {
        kind: "selected",
        values: Array.from(control.selectedOptions).map((option) => option.value),
      };
    }

    return { kind: "value", value: control.value };
  };

  const addState = (entries, key, state) => {
    let entry = entries.find((candidate) => candidate.key === key);
    if (!entry) {
      entry = { key, states: [] };
      entries.push(entry);
    }
    entry.states.push(state);
  };

  const snapshot = (form) => {
    const definitions = fragmentDefinitions(form);
    const normal = [];
    const fragments = [];
    let filesSelected = false;

    const fragmentEntry = (identifier) => {
      let entry = fragments.find(
        (candidate) => candidate.identifier === identifier
      );
      if (!entry) {
        entry = { identifier, fields: [] };
        fragments.push(entry);
      }
      return entry;
    };

    for (const control of Array.from(form.elements)) {
      if (!control.name || ignoredNames.has(control.name)) continue;

      const type = (control.type || "").toLowerCase();
      if (type === "file") {
        if (control.files && control.files.length > 0) filesSelected = true;
        continue;
      }

      const state = controlState(control);
      if (!state) continue;

      const definition = definitions.find((candidate) =>
        control.name.startsWith(`${candidate.prefix}[`)
      );
      if (definition) {
        const suffix = control.name.slice(definition.prefix.length);
        if (suffix === "[identifier]" || suffix === "[tag]") continue;
        addState(fragmentEntry(definition.identifier).fields, suffix, state);
      } else {
        addState(normal, control.name, state);
      }
    }

    const layout = form.querySelector("#fragments-toggle");
    return {
      version: VERSION,
      savedAt: Date.now(),
      layoutId: layout ? layout.value : null,
      normal,
      fragments,
      filesSelected,
    };
  };

  const comparableSnapshot = (value) => ({
    version: value.version,
    layoutId: value.layoutId,
    normal: value.normal,
    fragments: value.fragments,
    filesSelected: value.filesSelected,
  });

  const snapshotsEqual = (left, right) =>
    JSON.stringify(comparableSnapshot(left)) ===
    JSON.stringify(comparableSnapshot(right));

  const destinationState = (control) => ({
    control,
    ...controlState(control),
  });

  const correspondingState = (source, destinations, index) => {
    if (source.kind === "checked") {
      return destinations.find(
        (destination) =>
          destination.kind === "checked" && destination.value === source.value
      );
    }
    return destinations[index];
  };

  const applyStates = (sourceStates, controls) => {
    const destinations = controls
      .map(destinationState)
      .filter((state) => state.kind);

    sourceStates.forEach((source, index) => {
      const destination = correspondingState(source, destinations, index);
      if (!destination || source.kind !== destination.kind) return;

      if (source.kind === "checked") {
        destination.control.checked = source.checked;
      } else if (source.kind === "selected") {
        for (const option of destination.control.options) {
          option.selected = source.values.includes(option.value);
        }
      } else {
        destination.control.value = source.value;
      }
    });
  };

  const applySnapshot = (form, value, { skipLayout = false } = {}) => {
    const layout = form.querySelector("#fragments-toggle");

    for (const entry of value.normal || []) {
      if (skipLayout && layout && entry.key === layout.name) continue;
      const controls = Array.from(form.elements).filter(
        (control) => control.name === entry.key
      );
      applyStates(entry.states || [], controls);
    }

    const definitions = fragmentDefinitions(form);
    for (const fragment of value.fragments || []) {
      const definition = definitions.find(
        (candidate) => candidate.identifier === fragment.identifier
      );
      if (!definition) continue;

      for (const field of fragment.fields || []) {
        const name = `${definition.prefix}${field.key}`;
        const controls = Array.from(form.elements).filter(
          (control) => control.name === name
        );
        applyStates(field.states || [], controls);
      }
    }

    restoreEditors(form);
  };

  const save = (form) => {
    if (!form.isConnected) return;
    if (form.querySelector('[aria-busy="true"]')) {
      schedule(form);
      return;
    }

    syncEditors(form);
    const value = snapshot(form);
    const baseline = baselines.get(form);
    const saved = baseline && snapshotsEqual(value, baseline)
      ? removeStoredValue("localStorage", form.dataset.cmsDraftKey)
      : writeStoredValue(
          "localStorage",
          form.dataset.cmsDraftKey,
          JSON.stringify(value)
        );
    if (saved) changedForms.delete(form);
  };

  const schedule = (form) => {
    if (suspendedForms.has(form)) return;
    changedForms.add(form);
    window.clearTimeout(timers.get(form));
    timers.set(
      form,
      window.setTimeout(() => {
        timers.delete(form);
        save(form);
      }, DEBOUNCE_DELAY)
    );
  };

  const saveImmediately = (form) => {
    window.clearTimeout(timers.get(form));
    timers.delete(form);
    changedForms.add(form);
    save(form);
  };

  const flushChangedForms = () => {
    for (const form of Array.from(changedForms)) saveImmediately(form);
  };

  const onSubmit = (event) => {
    const form = event.target.closest("form[data-cms-draft-key]");
    if (!form) return;

    saveImmediately(form);
  };

  const acknowledgeSavedDraft = () => {
    const meta = document.querySelector('meta[name="cms-saved-draft-key"]');
    if (!meta) return;

    if (meta.content) removeStoredValue("localStorage", meta.content);
    meta.remove();
  };

  const closePrompt = (target = prompt) => {
    if (!target || prompt !== target) return;

    target.element.classList.remove("fade");
    target.modal.hide();
    target.modal.dispose();
    target.element.remove();
    for (const backdrop of document.querySelectorAll(".modal-backdrop")) {
      backdrop.remove();
    }
    document.body.classList.remove("modal-open");
    document.body.style.removeProperty("padding-right");
    prompt = null;
  };

  const showPrompt = (form, value) => {
    closePrompt();

    const element = document.createElement("div");
    element.className = "modal";
    element.tabIndex = -1;
    element.setAttribute("role", "dialog");
    element.setAttribute("aria-modal", "true");
    element.innerHTML = `
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header"><h5 class="modal-title"></h5></div>
          <div class="modal-body">
            <p data-cms-draft-message></p>
            <p class="alert alert-warning mb-0" data-cms-draft-file-message></p>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-outline-danger" data-cms-draft-discard></button>
            <button type="button" class="btn btn-primary" data-cms-draft-restore></button>
          </div>
        </div>
      </div>`;

    element.querySelector(".modal-title").textContent =
      form.dataset.cmsDraftTitle || "Unsaved draft found";
    element.querySelector("[data-cms-draft-message]").textContent =
      form.dataset.cmsDraftMessage ||
      "A locally saved draft is available. Restore it or discard it?";

    const fileMessage = element.querySelector(
      "[data-cms-draft-file-message]"
    );
    fileMessage.textContent =
      form.dataset.cmsDraftFilesMessage ||
      "Selected files are not stored and must be selected again.";
    fileMessage.hidden = !value.filesSelected;

    const discardButton = element.querySelector("[data-cms-draft-discard]");
    discardButton.textContent =
      form.dataset.cmsDraftDiscard || "Discard draft";
    discardButton.addEventListener("click", () => {
      removeStoredValue("localStorage", form.dataset.cmsDraftKey);
      closePrompt();
    });

    const restoreButton = element.querySelector("[data-cms-draft-restore]");
    restoreButton.textContent =
      form.dataset.cmsDraftRestore || "Restore draft";
    restoreButton.addEventListener("click", async () => {
      const activePrompt = prompt;
      discardButton.disabled = true;
      restoreButton.disabled = true;

      const layout = form.querySelector("#fragments-toggle");
      let layoutLoaded = true;
      if (
        layout &&
        value.layoutId &&
        value.layoutId !== layout.value &&
        CMS.pageFragments &&
        CMS.pageFragments.loadLayout
      ) {
        layoutLoaded = await CMS.pageFragments.loadLayout(value.layoutId, {
          confirmDiscard: false,
          preserveFragments: false,
        });
      }

      if (!form.isConnected || prompt !== activePrompt) return;
      applySnapshot(form, value, { skipLayout: !layoutLoaded });
      closePrompt(activePrompt);
    });

    document.body.appendChild(element);
    const modal = new Modal(element, { backdrop: "static", keyboard: false });
    prompt = { element, modal };
    modal.show();
  };

  const initializeForm = (form) => {
    suspendedForms.add(form);
    try {
      syncEditors(form);
      const current = snapshot(form);
      baselines.set(
        form,
        form.dataset.cmsSaveFailed === "true" ? null : current
      );

      const value = parseStoredValue(
        readStoredValue("localStorage", form.dataset.cmsDraftKey)
      );
      if (!value || value.version !== VERSION) return;

      if (snapshotsEqual(value, current)) {
        if (baselines.get(form)) {
          removeStoredValue("localStorage", form.dataset.cmsDraftKey);
        }
        return;
      }

      showPrompt(form, value);
    } finally {
      suspendedForms.delete(form);
    }
  };

  window.CMS.draftForms = {
    init() {
      forms = Array.from(document.querySelectorAll("form[data-cms-draft-key]"));
      timers = new Map();
      changedForms = new Set();
      suspendedForms = new Set();
      formHandlers = new Map();
      baselines = new WeakMap();
      acknowledgeSavedDraft();

      for (const form of forms) {
        const scheduleSave = () => schedule(form);
        formHandlers.set(form, scheduleSave);
        form.addEventListener("input", scheduleSave);
        form.addEventListener("change", scheduleSave);
        form.addEventListener("cms:fragments-changed", scheduleSave);
        initializeForm(form);
      }
      document.addEventListener("submit", onSubmit, true);
      window.addEventListener("beforeunload", flushChangedForms);
      window.addEventListener("pagehide", flushChangedForms);
    },

    dispose() {
      document.removeEventListener("submit", onSubmit, true);
      window.removeEventListener("beforeunload", flushChangedForms);
      window.removeEventListener("pagehide", flushChangedForms);
      for (const [form, scheduleSave] of formHandlers) {
        form.removeEventListener("input", scheduleSave);
        form.removeEventListener("change", scheduleSave);
        form.removeEventListener("cms:fragments-changed", scheduleSave);
      }
      flushChangedForms();
      for (const timer of timers.values()) window.clearTimeout(timer);
      closePrompt();

      forms = [];
      timers = new Map();
      changedForms = new Set();
      suspendedForms = new Set();
      formHandlers = new Map();
      baselines = new WeakMap();
    },
  };
})();
