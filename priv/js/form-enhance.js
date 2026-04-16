/**
 * form-enhance.js — Progressive enhancement for Bastion forms.
 *
 * Intercepts submissions from <form data-enhance> elements and submits
 * them via fetch rather than a full-page navigation.  On response, the
 * form's nearest ancestor with a [data-enhance-target] attribute is
 * replaced with the fragment returned by the server.  If no target
 * attribute is present, the form element itself is replaced.
 *
 * Redirect responses (3xx) are followed as a full-page navigation so
 * flash messages and session state work exactly as in the plain tier.
 *
 * Usage in templates (.march.html):
 *
 *   <form method="post" action="/register" data-enhance>
 *     <.Form.Input name="email" type_="email" label="Email" gate={gate} />
 *     <button type="submit">Register</button>
 *   </form>
 *
 * The server handler is unchanged — the same action handles both the
 * plain POST and the enhanced fetch POST.  The server detects enhanced
 * requests via the "X-Bastion-Enhance: 1" request header and may return
 * only a fragment (the form HTML) rather than the full page.
 *
 * Server-side detection (in a controller):
 *
 *   fn is_enhanced_request(conn) do
 *     match Request.get_header(conn, "x-bastion-enhance") do
 *     Some("1") -> true
 *     _         -> false
 *     end
 *   end
 */

(function () {
  "use strict";

  const ENHANCE_ATTR = "data-enhance";
  const TARGET_ATTR = "data-enhance-target";
  const ENHANCE_HEADER = "X-Bastion-Enhance";

  /**
   * Initialise enhanced form handling.
   * Call once after DOM ready, or call again after dynamic content injection.
   */
  function init() {
    document.addEventListener("submit", handleSubmit, { capture: true });
  }

  /**
   * Handle a form submit event.  Only acts on forms with data-enhance.
   */
  async function handleSubmit(event) {
    const form = event.target;
    if (!form || form.tagName !== "FORM") return;
    if (!form.hasAttribute(ENHANCE_ATTR)) return;

    event.preventDefault();

    const action = form.getAttribute("action") || window.location.pathname;
    const method = (form.getAttribute("method") || "post").toUpperCase();
    const target = findTarget(form);

    setSubmitting(form, true);

    try {
      const body = buildBody(form);
      const response = await fetch(action, {
        method,
        headers: buildHeaders(form),
        body,
        redirect: "manual",  // handle 3xx ourselves
      });

      if (isRedirect(response)) {
        // Follow redirect as a full-page navigation — flash + session work normally.
        window.location.href = response.headers.get("location") || action;
        return;
      }

      if (!response.ok && response.status >= 500) {
        // Server error — fall back to full-page submit so the dev error overlay shows.
        form.removeAttribute(ENHANCE_ATTR);
        form.submit();
        return;
      }

      const html = await response.text();
      replaceTarget(target, html, form);

      // Re-attach enhance listeners on the newly rendered form fragment.
      const newForm = target.querySelector("form[" + ENHANCE_ATTR + "]");
      if (newForm) {
        // Focus first invalid field for accessibility.
        const firstError = newForm.querySelector("[aria-invalid='true']");
        if (firstError) firstError.focus();
      }
    } catch (err) {
      // Network error — fall back to full-page.
      console.warn("[form-enhance] fetch failed, falling back to full-page submit:", err);
      form.removeAttribute(ENHANCE_ATTR);
      form.submit();
    } finally {
      setSubmitting(form, false);
    }
  }

  /**
   * Build fetch headers for an enhanced form request.
   */
  function buildHeaders(form) {
    const headers = new Headers();
    headers.set(ENHANCE_HEADER, "1");

    const contentType = form.getAttribute("enctype") || "application/x-www-form-urlencoded";
    // For multipart/form-data, do NOT set Content-Type — the browser sets it
    // with the correct boundary when using FormData.
    if (contentType !== "multipart/form-data") {
      headers.set("Content-Type", contentType);
    }

    // Signal that we accept an HTML fragment response.
    headers.set("Accept", "text/html, text/fragment");
    return headers;
  }

  /**
   * Build the request body from the form's fields.
   *
   * For multipart/form-data (file uploads), returns a FormData object.
   * For everything else, returns a URL-encoded string.
   */
  function buildBody(form) {
    const enctype = form.getAttribute("enctype") || "application/x-www-form-urlencoded";
    if (enctype === "multipart/form-data") {
      return new FormData(form);
    }
    const params = new URLSearchParams(new FormData(form));
    return params.toString();
  }

  /**
   * Find the element to replace when the response arrives.
   *
   * Walks up from the form looking for [data-enhance-target].
   * Falls back to the form itself if no target found.
   */
  function findTarget(form) {
    let el = form;
    while (el) {
      if (el.hasAttribute && el.hasAttribute(TARGET_ATTR)) return el;
      el = el.parentElement;
    }
    return form;
  }

  /**
   * Replace `target` with the HTML fragment using idiomorph for minimal
   * DOM churn (preserves focus, form state in sibling elements, etc.).
   */
  function replaceTarget(target, html, originalForm) {
    const tmp = document.createElement("div");
    tmp.innerHTML = html.trim();
    const fragment = tmp.firstElementChild || tmp;

    if (window.Idiomorph) {
      // Use idiomorph for smart DOM morphing if available (vendored).
      Idiomorph.morph(target, fragment, { morphStyle: "outerHTML" });
    } else {
      // Plain innerHTML swap as a fallback.
      target.outerHTML = fragment.outerHTML;
    }
  }

  /**
   * Indicate submission in progress by disabling the submit button(s)
   * and setting a data attribute the app can use to show a spinner.
   */
  function setSubmitting(form, submitting) {
    if (!form || !form.querySelectorAll) return;
    const buttons = form.querySelectorAll("[type='submit']");
    buttons.forEach(function (btn) {
      if (submitting) {
        btn.setAttribute("data-submitting", "true");
        btn.disabled = true;
      } else {
        btn.removeAttribute("data-submitting");
        btn.disabled = false;
      }
    });
  }

  /**
   * Returns true for 3xx redirect responses.
   * fetch with redirect:"manual" gives type:"opaqueredirect" for 3xx.
   */
  function isRedirect(response) {
    return response.type === "opaqueredirect" ||
           (response.status >= 300 && response.status < 400);
  }

  // Auto-init when the DOM is ready.
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  // Expose for re-initialisation after dynamic content injection.
  window.BastionForms = { init };
})();
