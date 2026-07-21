function setMeta(attribute, key, content) {
  let element = [...document.head.querySelectorAll(`meta[${attribute}]`)].find(
    (candidate) => candidate.getAttribute(attribute) === key,
  );

  if (!element) {
    element = document.createElement("meta");
    element.setAttribute(attribute, key);
    document.head.append(element);
  }

  element.setAttribute("content", content);
}

export function setMetadata(
  title,
  description,
  canonicalUrl,
  robots,
  openGraphType,
) {
  document.title = title;

  setMeta("name", "description", description);
  setMeta("name", "robots", robots);
  setMeta("name", "twitter:card", "summary_large_image");
  setMeta("name", "twitter:title", title);
  setMeta("name", "twitter:description", description);
  setMeta("property", "og:site_name", "glot.io");
  setMeta("property", "og:locale", "en_US");
  setMeta("property", "og:title", title);
  setMeta("property", "og:description", description);
  setMeta("property", "og:type", openGraphType);
  setMeta("property", "og:url", canonicalUrl);

  let canonical = document.head.querySelector('link[rel="canonical"]');
  if (!canonical) {
    canonical = document.createElement("link");
    canonical.setAttribute("rel", "canonical");
    document.head.append(canonical);
  }
  canonical.setAttribute("href", canonicalUrl);

  if (openGraphType !== "article") {
    document.head
      .querySelectorAll('meta[property^="article:"]')
      .forEach((element) => element.remove());
  }
}
