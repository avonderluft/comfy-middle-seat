import $ from "jquery";
import Alert from "bootstrap/js/src/alert";

(() => {
  const DELAY = 5000;
  let cleanups = [];

  const watch = (notice) => {
    let remaining = DELAY;
    let startedAt;
    let timer = null;
    let hovered = notice.matches(":hover");
    let focused = notice.contains(document.activeElement);

    const pause = () => {
      if (timer === null) return;
      window.clearTimeout(timer);
      timer = null;
      remaining = Math.max(0, remaining - (performance.now() - startedAt));
    };

    const resume = () => {
      if (timer !== null || hovered || focused || !notice.isConnected) return;
      startedAt = performance.now();
      timer = window.setTimeout(() => {
        timer = null;
        cleanup();
        if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
          notice.classList.remove("fade");
        }
        new Alert(notice).close();
      }, remaining);
    };

    const onMouseEnter = () => { hovered = true; pause(); };
    const onMouseLeave = () => { hovered = false; resume(); };
    const onFocusIn = () => { focused = true; pause(); };
    const onFocusOut = (event) => {
      focused = notice.contains(event.relatedTarget);
      if (!focused) resume();
    };
    const cleanup = () => {
      pause();
      notice.removeEventListener("mouseenter", onMouseEnter);
      notice.removeEventListener("mouseleave", onMouseLeave);
      notice.removeEventListener("focusin", onFocusIn);
      notice.removeEventListener("focusout", onFocusOut);
      $(notice).off("close.bs.alert", cleanup);
    };

    notice.addEventListener("mouseenter", onMouseEnter);
    notice.addEventListener("mouseleave", onMouseLeave);
    notice.addEventListener("focusin", onFocusIn);
    notice.addEventListener("focusout", onFocusOut);
    $(notice).on("close.bs.alert", cleanup);
    cleanups.push(cleanup);
    resume();
  };

  CMS.flashNotices = {
    init() {
      this.dispose();
      document.querySelectorAll(
        "[data-cms-flash].alert-success, [data-cms-flash].alert-info"
      ).forEach(watch);
    },

    dispose() {
      cleanups.forEach((cleanup) => cleanup());
      cleanups = [];
    },
  };
})();
