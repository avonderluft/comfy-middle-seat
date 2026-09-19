(() => {
  const fragmentName = /\[fragments_attributes\]\[\d+\]\[identifier\]$/;

  const fieldState = (control) => {
    const type = (control.type || "").toLowerCase();

    if (type === "file") {
      return {
        control,
        kind: "file",
        files: Array.from(control.files),
      };
    }

    if (type === "checkbox" || type === "radio") {
      return {
        control,
        kind: "checked",
        value: control.value,
        checked: control.checked,
      };
    }

    if (control instanceof HTMLSelectElement && control.multiple) {
      return {
        control,
        kind: "selected",
        values: Array.from(control.selectedOptions).map(
          (option) => option.value
        ),
      };
    }

    return { control, kind: "value", value: control.value };
  };

  const fragmentStates = (root) => {
    const fragments = new Map();
    const identifierInputs = root.querySelectorAll(
      'input[type="hidden"][name*="[fragments_attributes]"][name$="[identifier]"]'
    );

    for (const identifierInput of identifierInputs) {
      if (!fragmentName.test(identifierInput.name)) continue;

      const prefix = identifierInput.name.slice(0, -"[identifier]".length);
      const fields = new Map();
      const controls = Array.from(root.querySelectorAll("[name]")).filter(
        (control) =>
          control.name.startsWith(`${prefix}[`) &&
          control.type !== "hidden" &&
          !control.disabled
      );

      for (const control of controls) {
        const key = control.name.slice(prefix.length);
        if (!fields.has(key)) fields.set(key, []);
        fields.get(key).push(fieldState(control));
      }

      const wrapper = identifierInput.closest(".form-group");
      fragments.set(identifierInput.value, {
        fields,
        hasAttachments:
          wrapper && wrapper.querySelector(".fragment-attachment") !== null,
      });
    }

    return fragments;
  };

  const meaningful = (state) => {
    if (state.kind === "file") return state.files.length > 0;
    if (state.kind === "checked") return state.checked;
    if (state.kind === "selected") return state.values.length > 0;
    return state.value !== "";
  };

  const compatible = (source, destination) => {
    if (!destination || source.kind === "file") return false;
    if (source.kind !== destination.kind) return false;
    if (source.kind === "checked") return source.value === destination.value;
    return true;
  };

  const correspondingState = (source, states, index) =>
    source.kind === "checked"
      ? states.find(
          (state) =>
            state.kind === "checked" && state.value === source.value
        )
      : states[index];

  const statesEqual = (source, baseline) => {
    if (source.kind === "file") {
      if (!baseline || baseline.kind !== "file") return false;
      return (
        source.files.length === baseline.files.length &&
        source.files.every(
          (file, index) =>
            file.name === baseline.files[index].name &&
            file.size === baseline.files[index].size &&
            file.lastModified === baseline.files[index].lastModified
        )
      );
    }

    if (!compatible(source, baseline)) return false;
    if (source.kind === "checked") return source.checked === baseline.checked;
    if (source.kind === "selected") {
      return (
        source.values.length === baseline.values.length &&
        source.values.every((value, index) => value === baseline.values[index])
      );
    }
    return source.value === baseline.value;
  };

  const stateChanged = (source, baselineStates, index) =>
    !statesEqual(source, correspondingState(source, baselineStates, index));

  const fragmentHasContent = (fragment) =>
    fragment.hasAttachments ||
    Array.from(fragment.fields.values()).some((states) =>
      states.some(meaningful)
    );

  const fragmentChanged = (sourceFragment, baselineFragment) => {
    if (!baselineFragment) return fragmentHasContent(sourceFragment);

    for (const [key, sourceStates] of sourceFragment.fields) {
      const baselineStates = baselineFragment.fields.get(key) || [];
      if (
        sourceStates.some((source, index) =>
          stateChanged(source, baselineStates, index)
        )
      ) {
        return true;
      }
    }

    return false;
  };

  const wouldDiscardContent = (
    sourceFragments,
    destinationFragments,
    baselineFragments
  ) => {
    for (const [identifier, sourceFragment] of sourceFragments) {
      const destinationFragment = destinationFragments.get(identifier);
      const baselineFragment = baselineFragments.get(identifier);
      if (!destinationFragment) {
        if (
          fragmentHasContent(sourceFragment) ||
          fragmentChanged(sourceFragment, baselineFragment)
        ) {
          return true;
        }
        continue;
      }

      if (
        sourceFragment.hasAttachments &&
        !destinationFragment.hasAttachments
      ) {
        return true;
      }

      for (const [key, sourceStates] of sourceFragment.fields) {
        const destinationStates = destinationFragment.fields.get(key) || [];
        const baselineStates = baselineFragment
          ? baselineFragment.fields.get(key) || []
          : [];

        for (let index = 0; index < sourceStates.length; index += 1) {
          const source = sourceStates[index];
          const destination = correspondingState(
            source,
            destinationStates,
            index
          );
          if (compatible(source, destination)) continue;

          if (
            meaningful(source) ||
            stateChanged(source, baselineStates, index)
          ) {
            return true;
          }
        }
      }
    }

    return false;
  };

  const restoreFragments = (sourceFragments, root) => {
    const destinationFragments = fragmentStates(root);

    for (const [identifier, sourceFragment] of sourceFragments) {
      const destinationFragment = destinationFragments.get(identifier);
      if (!destinationFragment) continue;

      for (const [key, sourceStates] of sourceFragment.fields) {
        const destinationStates = destinationFragment.fields.get(key) || [];

        for (let index = 0; index < sourceStates.length; index += 1) {
          const source = sourceStates[index];
          const destination = correspondingState(
            source,
            destinationStates,
            index
          );

          if (!compatible(source, destination)) continue;

          if (source.kind === "checked") {
            destination.control.checked = source.checked;
          } else if (source.kind === "selected") {
            for (const option of destination.control.options) {
              option.selected = source.values.includes(option.value);
            }
          } else {
            destination.control.value = source.value;
          }
        }
      }
    }
  };

  const responseFragment = (html) => {
    const template = document.createElement("template");
    template.innerHTML = html.trim();
    return template.content;
  };

  const statusMessage = (container, message, type) => {
    const current = document.querySelector("[data-cms-fragments-status]");
    if (current) current.remove();
    if (!message) return;

    const status = document.createElement("div");
    status.className = `alert alert-${type}`;
    status.dataset.cmsFragmentsStatus = "true";
    status.setAttribute("role", type === "danger" ? "alert" : "status");
    status.textContent = message;
    container.insertAdjacentElement("beforebegin", status);
  };

  const replaceFragments = (container, html, sourceFragments) => {
    // TODO: Only dispose of the widgets that were within the fragment.
    CMS.wysiwyg.dispose();
    CMS.timepicker.dispose();
    CMS.codemirror.dispose();

    container.innerHTML = html;
    restoreFragments(sourceFragments, container);

    CMS.fileLinks(container);
    // TODO: Container should also be passed here once the TODO above is addressed.
    CMS.wysiwyg.init();
    CMS.timepicker.init();
    CMS.codemirror.init();
  };

  window.CMS.pageFragments = () => {
    const toggle = document.querySelector("select#fragments-toggle");
    const container = document.querySelector("#form-fragments-container");
    if (toggle === null || container === null) return;

    const url = new URL(toggle.dataset.url, document.location.href);
    let currentLayoutId = toggle.value;
    let baselineFragments = fragmentStates(container);

    toggle.addEventListener("change", async () => {
      const requestedLayoutId = toggle.value;
      CMS.codemirror.sync(container);
      const sourceFragments = fragmentStates(container);

      toggle.disabled = true;
      container.setAttribute("aria-busy", "true");
      statusMessage(container, toggle.dataset.loadingMessage, "info");
      url.searchParams.set("layout_id", requestedLayoutId);

      try {
        const response = await fetch(url, { credentials: "same-origin" });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);

        const html = await response.text();
        const destinationFragments = fragmentStates(responseFragment(html));
        statusMessage(container, "", "info");

        if (
          wouldDiscardContent(
            sourceFragments,
            destinationFragments,
            baselineFragments
          ) &&
          !window.confirm(toggle.dataset.discardMessage)
        ) {
          toggle.value = currentLayoutId;
          return;
        }

        replaceFragments(container, html, sourceFragments);
        currentLayoutId = requestedLayoutId;
        baselineFragments = destinationFragments;
      } catch (error) {
        toggle.value = currentLayoutId;
        statusMessage(container, toggle.dataset.errorMessage, "danger");
        console.error("Unable to load layout fragments", error);
      } finally {
        toggle.disabled = false;
        container.removeAttribute("aria-busy");
      }
    });
  };
})();
