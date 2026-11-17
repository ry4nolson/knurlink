(function () {
  const M = window.Matcher;
  const PR_URL = "https://github.com/ry4nolson/knurlink/pull/1";
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const browsers = [
    { id: "chrome-work", app: "Chrome", profile: "work", color: "#2ea44f", private: true },
    { id: "chrome-personal", app: "Chrome", profile: "personal", color: "#2ea44f", private: true },
    { id: "brave", app: "Brave", color: "#ef5a2c", private: true },
    { id: "safari-personal", app: "Safari", profile: "personal", color: "#1593e6", private: false },
    { id: "safari-work", app: "Safari", profile: "work", color: "#1593e6", private: false },
    { id: "firefox", app: "Firefox", color: "#8e44ec", private: true },
  ];
  const byId = Object.fromEntries(browsers.map((b) => [b.id, b]));
  const titleOf = (b) => (b.profile ? `${b.app} (${b.profile})` : b.app);

  const sources = [
    { id: "slack", name: "Slack" },
    { id: "mail", name: "Mail" },
    { id: "messages", name: "Messages" },
    { id: "terminal", name: "Terminal" },
    { id: "notion", name: "Notion" },
  ];
  const sourceName = (id) => (sources.find((s) => s.id === id) || {}).name || id;

  const defaultRules = () => [
    { pattern: "tiktok.com", source: null, target: "brave", private: false },
    { pattern: "github.com/ry4nolson", source: null, target: "chrome-work", private: false },
    { pattern: "github.com", source: null, target: "chrome-personal", private: false },
    { pattern: "linear.app", source: "slack", target: "chrome-work", private: false },
    { pattern: "", source: "mail", target: "safari-personal", private: false },
    { pattern: "youtube.com", source: null, target: "firefox", private: true },
  ];
  let rules = defaultRules();

  const describe = (rule) => {
    const p = M.parsePattern(rule.pattern).normalized;
    const link = p || "any link";
    return rule.source ? `${link} from ${sourceName(rule.source)}` : link;
  };

  const el = (tag, attrs, ...children) => {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === null || v === undefined || v === false) continue;
      if (k === "class") node.className = v;
      else if (k === "style") node.style.cssText = v;
      else if (k.startsWith("on")) node.addEventListener(k.slice(2), v);
      else node.setAttribute(k, v === true ? "" : v);
    }
    for (const c of children.flat()) {
      if (c === null || c === undefined || c === false) continue;
      node.append(c.nodeType ? c : document.createTextNode(c));
    }
    return node;
  };

  const glyph = (b, size) =>
    el("span", { class: "glyph", style: `--c:${b.color};${size ? `--g:${size}px` : ""}`, "aria-hidden": "true" }, b.app[0]);

  const specsIcon = () => {
    const wrap = document.createElement("span");
    wrap.innerHTML = '<svg class="specs" viewBox="0 0 24 12" aria-hidden="true"><circle cx="6" cy="7" r="4"/><circle cx="18" cy="7" r="4"/><path d="M10 6.5q2-2 4 0"/></svg>';
    return wrap.firstChild;
  };

  const stage = document.getElementById("stage");
  const chat = document.getElementById("chat");
  const toast = document.getElementById("toast");
  const privChip = document.getElementById("privChip");

  const messages = [
    { who: "dana", text: ["this is the one i was talking about ", { url: "https://www.tiktok.com/@rickastleyofficial/video/7602274654413212950" }] },
    { who: "sam", text: ["pr is up for the website: ", { url: PR_URL }] },
    { who: "jo", text: ["people running three browsers at once: ", { url: "https://news.ycombinator.com/item?id=33156283" }] },
    { who: "dana", text: ["tiktok blocked at work? ", { url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }] },
    { who: "sam", text: ["launch at login uses this: ", { url: "https://developer.apple.com/documentation/servicemanagement/smappservice" }] },
  ];
  const avatarColor = { dana: "#d9822b", sam: "#3d6cf2", jo: "#2ea44f" };

  const pretty = (url) => url.replace(/^https?:\/\/(www\.)?/, "").replace(/\/$/, "");

  for (const m of messages) {
    chat.append(
      el("li", { class: "msg" },
        el("span", { class: "avatar", style: `--c:${avatarColor[m.who]}`, "aria-hidden": "true" }, m.who[0]),
        el("div", {},
          el("span", { class: "who" }, m.who),
          el("p", {}, m.text.map((part) =>
            typeof part === "string"
              ? part
              : el("a", { href: part.url, class: "demo-link", "data-url": part.url },
                  pretty(part.url).split("/").flatMap((s, i) => (i ? ["/", el("wbr"), s] : [s])))
          ))
        )
      )
    );
  }

  let toastTimer;
  function showToast(b, lines) {
    toast.replaceChildren(
      glyph(b, 22),
      el("div", {}, ...lines.map((l, i) => el(i === 0 ? "strong" : "span", {}, l)))
    );
    toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove("show"), 3600);
  }

  let privateHeld = false;
  function setPrivate(on) {
    privateHeld = on;
    privChip.setAttribute("aria-pressed", String(on));
    if (picker) picker.render();
  }

  let picker = null;

  function openLink(url, point) {
    const u = M.webURL(url);
    if (!u) return;
    const ranked = M.rankedRules(u, "slack", rules);
    const winner = ranked[0] && byId[ranked[0].rule.target];
    if (winner) {
      const r = ranked[0].rule;
      const priv = r.private && winner.private;
      showToast(winner, [
        `opened in ${titleOf(winner)}${priv ? ", private" : ""}`,
        `matched ${describe(r)}. no picker.`,
      ]);
      return;
    }
    showPicker(u, point);
  }

  function showPicker(url, point) {
    closePicker();
    const options = browsers;
    const n = options.length;
    const B = 66;
    const r = Math.max(132, (n * B * 1.24) / (2 * Math.PI));
    const side = 2 * (r + B / 2 + 12);
    const hubD = Math.min(176, 2 * r - B - 20);
    const suggested = M.suggestedDomain(url.hostname);

    const state = { selection: 0, remember: false };
    const root = el("div", { class: "picker", role: "dialog", "aria-label": `Open ${url.hostname} in` });
    root.style.width = root.style.height = `${side}px`;

    const bubbles = options.map((b, i) => {
      const angle = -Math.PI / 2 + (2 * Math.PI * i) / n;
      const btn = el("button", {
        class: "bubble",
        type: "button",
        style: `--x:${Math.cos(angle) * r}px;--y:${Math.sin(angle) * r}px;--d:${i * 12}ms`,
        onclick: () => finish(i),
        onmouseenter: () => { state.selection = i; render(); },
      },
        glyph(b),
        el("span", { class: "blabel" }, b.profile || b.app),
        i < 9 ? el("span", { class: "num" }, String(i + 1)) : null,
        el("span", { class: "priv" }, specsIcon())
      );
      return btn;
    });

    const caption = el("div", { class: "hub-cap" });
    const check = el("input", { type: "checkbox", onchange: (e) => { state.remember = e.target.checked; } });
    const hub = el("div", { class: "hub", style: `width:${hubD}px;height:${hubD}px` },
      el("div", { class: "hub-host" }, url.hostname),
      caption,
      el("label", { class: "hub-always" }, check, `Always for ${suggested}`),
      el("button", { class: "hub-x", type: "button", "aria-label": "Cancel", onclick: () => closePicker() }, "×")
    );
    root.append(...bubbles, hub);

    function render() {
      const sel = options[state.selection];
      bubbles.forEach((btn, i) => {
        const b = options[i];
        btn.classList.toggle("selected", i === state.selection);
        btn.classList.toggle("is-private", privateHeld && b.private);
        btn.classList.toggle("faded", privateHeld && !b.private);
        btn.setAttribute("aria-label", privateHeld && b.private ? `${titleOf(b)}, private window` : titleOf(b));
      });
      caption.replaceChildren();
      caption.classList.toggle("private", privateHeld && sel.private);
      if (privateHeld && sel.private) caption.append(specsIcon(), `${titleOf(sel)}, private`);
      else caption.append(titleOf(sel));
      check.checked = state.remember;
    }

    function finish(i) {
      const b = options[i];
      const priv = privateHeld && b.private;
      const remember = state.remember;
      closePicker();
      const lines = [`opened in ${titleOf(b)}${priv ? ", private" : ""}`];
      if (remember) {
        const normalized = M.parsePattern(suggested).normalized;
        const existing = rules.find((x) => !x.source && M.parsePattern(x.pattern).normalized === normalized);
        if (existing) existing.target = b.id;
        else rules.push({ pattern: normalized, source: null, target: b.id, private: false });
        renderRules();
        renderTester();
        lines.push(`saved a rule: ${normalized}. click it again.`);
      } else if (privateHeld && !b.private) {
        lines.push(`${b.app} can't open private windows, so it's a normal one.`);
      }
      showToast(b, lines);
    }

    function onKey(e) {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      const k = e.key;
      if (k === "Escape") closePicker();
      else if (k === "Enter") finish(state.selection);
      else if (k === "ArrowDown") { state.selection = Math.min(state.selection + 1, n - 1); render(); }
      else if (k === "ArrowUp") { state.selection = Math.max(state.selection - 1, 0); render(); }
      else if (k.toLowerCase() === "a") { state.remember = !state.remember; render(); }
      else if (/^[1-9]$/.test(k) && Number(k) <= Math.min(9, n)) finish(Number(k) - 1);
      else return;
      e.preventDefault();
    }

    function onPointerDown(e) {
      if (!root.contains(e.target) && !privChip.contains(e.target)) closePicker();
    }

    const stageRect = stage.getBoundingClientRect();
    const scale = Math.min(1, (stageRect.width - 12) / side, (stageRect.height - 12) / side);
    const visual = side * scale;
    const cx = point.x - stageRect.left;
    const cy = point.y - stageRect.top;
    const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
    root.style.left = `${clamp(cx - visual / 2, 6, stageRect.width - visual - 6)}px`;
    root.style.top = `${clamp(cy - visual / 2, 6, stageRect.height - visual - 6)}px`;
    root.style.transform = `scale(${scale})`;

    stage.append(root);
    stage.classList.add("dimmed");
    render();
    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onPointerDown, true);
    requestAnimationFrame(() => requestAnimationFrame(() => root.classList.add("open")));
    if (reduceMotion) root.classList.add("open");
    bubbles[0].focus({ preventScroll: true });

    picker = {
      render,
      close() {
        document.removeEventListener("keydown", onKey);
        document.removeEventListener("pointerdown", onPointerDown, true);
        root.remove();
        stage.classList.remove("dimmed");
      },
    };
  }

  function closePicker() {
    if (!picker) return;
    const p = picker;
    picker = null;
    p.close();
  }

  chat.addEventListener("click", (e) => {
    const a = e.target.closest(".demo-link");
    if (!a) return;
    e.preventDefault();
    let point = { x: e.clientX, y: e.clientY };
    if (!e.detail) {
      const rc = a.getBoundingClientRect();
      point = { x: rc.left + rc.width / 2, y: rc.top + rc.height / 2 };
    }
    openLink(a.dataset.url, point);
  });

  document.addEventListener("keydown", (e) => { if (e.key === "Shift" && !privateHeld) setPrivate(true); });
  document.addEventListener("keyup", (e) => { if (e.key === "Shift") setPrivate(false); });
  window.addEventListener("blur", () => { if (privateHeld && !privChip.dataset.sticky) setPrivate(false); });
  privChip.addEventListener("click", () => {
    const on = !privateHeld;
    privChip.dataset.sticky = on ? "1" : "";
    setPrivate(on);
  });

  const tUrl = document.getElementById("tUrl");
  const tSrc = document.getElementById("tSrc");
  const tResult = document.getElementById("tResult");
  const rulesBody = document.getElementById("rulesBody");
  const examples = document.getElementById("examples");

  tSrc.append(el("option", { value: "" }, "Any app"), ...sources.map((s) => el("option", { value: s.id }, s.name)));

  const exampleLinks = [
    { label: "the rickroll tiktok", url: "https://www.tiktok.com/@rickastleyofficial/video/7602274654413212950", src: "" },
    { label: "github.com/apple/swift", url: "https://github.com/apple/swift", src: "" },
    { label: "linear.app from Slack", url: "https://linear.app/changelog", src: "slack" },
    { label: "anything from Mail", url: "https://example.com", src: "mail" },
    { label: "youtube, privately", url: "m.youtube.com/watch?v=dQw4w9WgXcQ", src: "" },
    { label: "not a link", url: "hello there", src: "" },
  ];
  for (const ex of exampleLinks) {
    examples.append(el("button", {
      class: "chip", type: "button",
      onclick: () => { tUrl.value = ex.url; tSrc.value = ex.src; renderTester(); },
    }, ex.label));
  }

  function why(winner, runnerUp) {
    if (!runnerUp) return winner.rule.pattern.trim() ? "It's the only rule that matches." : "It's the only rule that matches, so the fallback takes it.";
    const [a, b] = [winner.specificity, runnerUp.specificity];
    if (a[0] !== b[0]) return "It has the longer domain.";
    if (a[1] !== b[1]) return "It has the longer path.";
    if (a[2] !== b[2]) return "It's scoped to an app. The other isn't.";
    return "They're tied, so the one higher in the list wins.";
  }

  const row = (label, ...value) => el("div", { class: "res-row" }, el("span", { class: "res-label" }, label), el("div", { class: "res-value" }, ...value));
  const status = (kind, text) => el("div", { class: `status ${kind}` }, el("span", { class: "dot", "aria-hidden": "true" }), text);

  function renderTester() {
    const input = tUrl.value;
    if (!input.trim()) {
      tResult.replaceChildren(status("idle", "Paste a link above to see where it would open."));
      return;
    }
    const url = M.webURL(input);
    if (!url) {
      tResult.replaceChildren(status("warn", "That's not a web link."));
      return;
    }
    const ranked = M.rankedRules(url, tSrc.value || null, rules);
    if (!ranked.length) {
      tResult.replaceChildren(status("idle", "No rule matches. The picker opens."));
      return;
    }
    const [winner, ...others] = ranked;
    const b = byId[winner.rule.target];
    const out = [row("Opens in", glyph(b, 18), el("strong", {}, titleOf(b)))];
    if (winner.rule.private) {
      out.push(row("Window", b.private
        ? el("span", { class: "privlabel" }, specsIcon(), "Private")
        : `Normal. ${b.app} can't open private windows.`));
    }
    out.push(row("Matched rule", el("code", {}, describe(winner.rule))));
    out.push(row("Why", why(winner, others[0])));
    if (others.length) {
      out.push(row("Also matched", el("ul", { class: "losers" }, others.map((o) =>
        el("li", {}, el("code", {}, describe(o.rule)), ` → ${titleOf(byId[o.rule.target])}`)
      ))));
    }
    tResult.replaceChildren(...out);
  }

  function renderRules() {
    rulesBody.replaceChildren(...rules.map((rule, i) => {
      const linkInput = el("input", {
        type: "text", value: rule.pattern, placeholder: "Any link", spellcheck: "false", autocomplete: "off",
        "aria-label": "Link",
        oninput: (e) => { rule.pattern = e.target.value; renderTester(); },
      });
      const srcSelect = el("select", { "aria-label": "From", onchange: (e) => { rule.source = e.target.value || null; renderTester(); } },
        el("option", { value: "" }, "Any app"),
        sources.map((s) => el("option", { value: s.id, selected: rule.source === s.id }, s.name))
      );
      const targetSelect = el("select", { "aria-label": "Opens in", onchange: (e) => { rule.target = e.target.value; renderTester(); } },
        browsers.map((b) => el("option", { value: b.id, selected: rule.target === b.id }, titleOf(b)))
      );
      const privBox = el("input", { type: "checkbox", checked: rule.private, "aria-label": "Private", onchange: (e) => { rule.private = e.target.checked; renderTester(); } });
      const del = el("button", {
        class: "del", type: "button", "aria-label": `Delete rule ${describe(rule)}`,
        onclick: () => { rules.splice(i, 1); renderRules(); renderTester(); },
      }, "×");
      return el("div", { class: "rules-row", role: "row" },
        el("span", { class: "cell cell-link", "data-label": "Link", role: "cell" }, linkInput),
        el("span", { class: "cell", "data-label": "From", role: "cell" }, srcSelect),
        el("span", { class: "cell", "data-label": "Opens in", role: "cell" }, targetSelect),
        el("span", { class: "cell cell-priv", "data-label": "Private", role: "cell" }, privBox),
        el("span", { class: "cell cell-del", role: "cell" }, del)
      );
    }));
    if (!rules.length) {
      rulesBody.append(el("p", { class: "empty" }, "No rules. Every link opens the picker."));
    }
  }

  document.getElementById("addRule").addEventListener("click", () => {
    rules.push({ pattern: "", source: null, target: browsers[0].id, private: false });
    renderRules();
    rulesBody.querySelector(".rules-row:last-child input")?.focus();
  });
  document.getElementById("resetRules").addEventListener("click", () => {
    rules = defaultRules();
    renderRules();
    renderTester();
  });
  tUrl.value = PR_URL;
  tUrl.addEventListener("input", renderTester);
  tSrc.addEventListener("change", renderTester);

  renderRules();
  renderTester();
})();
