import {
  forgetNotice,
  noticeWasSeen,
  rememberNotice,
} from "./glot-cookie-notice-preference.mjs";

class GlotCookieNotice extends HTMLElement {
  connectedCallback() {
    if (noticeWasSeen(window.localStorage)) {
      this.hide();
    } else {
      this.show();
    }
  }

  show() {
    this.hidden = false;

    const notice = document.createElement("aside");
    notice.className = "cookie-notice";
    notice.setAttribute("aria-label", "Cookie notice");

    const copy = document.createElement("p");
    copy.className = "cookie-notice__copy";
    copy.append(
      "glot.io uses necessary browser storage and loads ",
      externalLink("Carbon Ads", "https://www.carbonads.net/privacy"),
      ", which may use cookies to measure ads. By continuing to use the site, you accept this. ",
      internalLink("Privacy policy", "/privacy"),
    );

    const dismiss = document.createElement("button");
    dismiss.className = "cookie-notice__dismiss";
    dismiss.type = "button";
    dismiss.textContent = "Got it";
    dismiss.addEventListener("click", () => {
      rememberNotice(window.localStorage);
      this.hide();
    });

    notice.append(copy, dismiss);
    this.replaceChildren(notice);
  }

  private hide() {
    this.hidden = true;
    this.replaceChildren();
  }
}

function internalLink(label: string, href: string) {
  const link = document.createElement("a");
  link.href = href;
  link.textContent = label;
  return link;
}

function externalLink(label: string, href: string) {
  const link = internalLink(label, href);
  link.rel = "noreferrer";
  return link;
}

let initialized = false;

export function initializePrivacyElements() {
  if (initialized) return;
  initialized = true;

  if (!customElements.get("glot-cookie-notice")) {
    customElements.define("glot-cookie-notice", GlotCookieNotice);
  }

  document.addEventListener("click", (event) => {
    const target = event.target;
    if (
      !(target instanceof Element) ||
      !target.closest("[data-cookie-notice-settings]")
    ) {
      return;
    }

    forgetNotice(window.localStorage);
    document.querySelectorAll<GlotCookieNotice>("glot-cookie-notice").forEach(
      (notice) => notice.show(),
    );
  });
}
