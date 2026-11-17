(function (root) {
  const compoundSecondLevels = new Set(["co", "com", "org", "net", "gov", "ac", "edu"]);

  function stripScheme(value) {
    const i = value.indexOf("://");
    return i === -1 ? value : value.slice(i + 3);
  }

  function prefixUntil(value, stops) {
    let end = 0;
    while (end < value.length && !stops.includes(value[end])) end++;
    return value.slice(0, end);
  }

  function normalize(input) {
    let value = stripScheme(String(input).trim().toLowerCase());
    value = prefixUntil(value, "/?#");
    const at = value.lastIndexOf("@");
    if (at !== -1) value = value.slice(at + 1);
    const port = value.indexOf(":");
    if (port !== -1) value = value.slice(0, port);
    value = value.replace(/^[*.]+/, "").replace(/\.+$/, "");
    if (value.startsWith("www.")) value = value.slice(4);
    return value;
  }

  function hostMatches(host, pattern) {
    const p = normalize(pattern);
    if (!p) return false;
    const h = normalize(host);
    return h === p || h.endsWith("." + p);
  }

  function parsePattern(raw) {
    let value = stripScheme(String(raw || "").trim().toLowerCase());
    value = prefixUntil(value, "?#");
    const slash = value.indexOf("/");
    const hostPart = slash === -1 ? value : value.slice(0, slash);
    const pathPart = slash === -1 ? null : value.slice(slash + 1);
    const host = normalize(hostPart);
    const pathSegments = pathPart === null ? [] : pathPart.split("/").filter(Boolean);
    return {
      host,
      pathSegments,
      isEmpty: host === "",
      normalized: host === "" ? "" : [host, ...pathSegments].join("/"),
    };
  }

  function safeDecode(segment) {
    try { return decodeURIComponent(segment); } catch { return segment; }
  }

  function patternMatches(pattern, url) {
    if (pattern.isEmpty || !url.hostname || !hostMatches(url.hostname, pattern.host)) return false;
    const segments = url.pathname.toLowerCase().split("/").filter(Boolean).map(safeDecode);
    if (segments.length < pattern.pathSegments.length) return false;
    return pattern.pathSegments.every((s, i) => segments[i] === s);
  }

  function rankedRules(url, source, rules) {
    return rules
      .map((rule, offset) => {
        const pattern = parsePattern(rule.pattern);
        const requiredSource = rule.source || null;
        if (pattern.isEmpty && !requiredSource) return null;
        if (!pattern.isEmpty && !patternMatches(pattern, url)) return null;
        if (requiredSource && requiredSource !== source) return null;
        const specificity = [pattern.host.length, pattern.pathSegments.length, requiredSource ? 1 : 0];
        return { rule, specificity, offset };
      })
      .filter(Boolean)
      .sort((a, b) => {
        for (let i = 0; i < 3; i++) {
          if (a.specificity[i] !== b.specificity[i]) return b.specificity[i] - a.specificity[i];
        }
        return a.offset - b.offset;
      });
  }

  function webURL(input) {
    const trimmed = String(input).trim();
    if (!trimmed || /\s/.test(trimmed)) return null;
    const candidate = trimmed.includes("://") ? trimmed : "https://" + trimmed;
    let url;
    try { url = new URL(candidate); } catch { return null; }
    if (!["http:", "https:"].includes(url.protocol) || !url.hostname) return null;
    return url;
  }

  function suggestedDomain(host) {
    const h = normalize(host);
    const labels = h.split(".");
    if (labels.length <= 2 || !labels.some((l) => !/^[+-]?\d+$/.test(l))) return h;
    const top = labels[labels.length - 1];
    const second = labels[labels.length - 2];
    const count = top.length === 2 && compoundSecondLevels.has(second) ? 3 : 2;
    return labels.slice(-count).join(".");
  }

  const api = { normalize, hostMatches, parsePattern, patternMatches, rankedRules, webURL, suggestedDomain };
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.Matcher = api;
})(this);
