(() => {
  const defaultMessage =
    "You have unsaved changes. Are you sure you want to leave this page?";

  let forms = [];
  let baselines = new WeakMap();
  let submittingForms = new WeakSet();
  let navigationAllowed = false;

  const controlState = (control) => {
    if (!control.name) return null;

    const type = (control.type || "").toLowerCase();
    if (["button", "image", "reset", "submit"].includes(type)) return null;

    if (type === "checkbox" || type === "radio") {
      return [control.name, type, control.value, control.checked];
    }

    if (type === "file") {
      return [
        control.name,
        type,
        Array.from(control.files).map((file) => [
          file.name,
          file.size,
          file.lastModified,
        ]),
      ];
    }

    if (control instanceof HTMLSelectElement && control.multiple) {
      return [
        control.name,
        type,
        Array.from(control.selectedOptions).map((option) => option.value),
      ];
    }

    return [control.name, type, control.value];
  };

  const formState = (form) =>
    JSON.stringify(Array.from(form.elements).map(controlState).filter(Boolean));

  const syncEditors = () => {
    if (CMS.codemirror && CMS.codemirror.sync) CMS.codemirror.sync();
  };

  const dirtyForms = () => {
    syncEditors();
    return forms.filter(
      (form) =>
        form.isConnected &&
        baselines.has(form) &&
        baselines.get(form) !== formState(form)
    );
  };

  const formsRequiringWarning = () =>
    dirtyForms().filter((form) => !submittingForms.has(form));

  const warningMessage = (dirtyForm) =>
    dirtyForm.dataset.cmsUnsavedMessage || defaultMessage;

  const beforeUnload = (event) => {
    if (navigationAllowed || formsRequiringWarning().length === 0) return;

    event.preventDefault();
    event.returnValue = "";
  };

  const navigationTarget = (event) => {
    if (
      event.defaultPrevented ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    ) {
      return null;
    }

    const link = event.target.closest("a[href]");
    if (!link || link.hasAttribute("download")) return null;

    const target = link.getAttribute("target");
    if (target && !["_self", "_top", "_parent", window.name].includes(target)) {
      return null;
    }

    const url = new URL(link.href, document.location.href);
    if (
      url.origin === document.location.origin &&
      url.pathname === document.location.pathname &&
      url.search === document.location.search &&
      url.hash
    ) {
      return null;
    }

    return link;
  };

  const allowCurrentNavigation = () => {
    navigationAllowed = true;
    window.setTimeout(() => {
      navigationAllowed = false;
    }, 0);
  };

  const confirmLinkNavigation = (event) => {
    if (navigationAllowed || !navigationTarget(event)) return;

    const dirtyForm = formsRequiringWarning()[0];
    if (!dirtyForm) return;

    if (!window.confirm(warningMessage(dirtyForm))) {
      event.preventDefault();
      event.stopImmediatePropagation();
      return;
    }

    allowCurrentNavigation();
  };

  const confirmTurbolinksNavigation = (event) => {
    if (navigationAllowed) return;

    const dirtyForm = formsRequiringWarning()[0];
    if (!dirtyForm) return;

    if (!window.confirm(warningMessage(dirtyForm))) {
      event.preventDefault();
      return;
    }

    allowCurrentNavigation();
  };

  const markSubmitting = (event) => {
    const form = event.target;
    const submitterTarget = event.submitter && event.submitter.formTarget;
    const target = submitterTarget || form.target;

    if (
      target &&
      !["_self", "_top", "_parent", window.name].includes(target)
    ) {
      return;
    }

    submittingForms.add(form);
  };

  window.CMS.dirtyForms = {
    init() {
      forms = Array.from(
        document.querySelectorAll("form[data-cms-unsaved-message]")
      );
      baselines = new WeakMap();
      submittingForms = new WeakSet();
      navigationAllowed = false;

      for (const form of forms) baselines.set(form, formState(form));

      window.addEventListener("beforeunload", beforeUnload);
      document.addEventListener("click", confirmLinkNavigation, true);
      document.addEventListener("submit", markSubmitting, true);
      document.addEventListener(
        "turbolinks:before-visit",
        confirmTurbolinksNavigation
      );
    },

    dispose() {
      window.removeEventListener("beforeunload", beforeUnload);
      document.removeEventListener("click", confirmLinkNavigation, true);
      document.removeEventListener("submit", markSubmitting, true);
      document.removeEventListener(
        "turbolinks:before-visit",
        confirmTurbolinksNavigation
      );

      forms = [];
      baselines = new WeakMap();
      submittingForms = new WeakSet();
      navigationAllowed = false;
    },

    isDirty() {
      return dirtyForms().length > 0;
    },
  };
})();
