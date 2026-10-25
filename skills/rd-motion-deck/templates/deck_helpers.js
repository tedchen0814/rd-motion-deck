// R&D knowledge-sharing deck helpers (PptxGenJS 3.12+, LAYOUT_WIDE 13.333 x 7.5 in).
// Adapted from soil-motion-deck (MIT). Sandwich structure: dark cover / section / action / ending,
// light content pages; animations sit in a dark "player window" so the film's three-color theme
// reads as a screen inside a light page.
//
//   const pptxgen = require("pptxgenjs");
//   const { makeDeck } = require("./deck_helpers");
//   const pptx = new pptxgen(); pptx.layout = "LAYOUT_WIDE";
//   const D = makeDeck(pptx, { theme: { bg: "121212", fg: "F2F0EA", accent: "FF7A1A" },
//                              mediaDir: __dirname + "/media", footer: "主題｜技術分享" });
//   const s = D.lightSlide("原理・動畫"); D.title(s, "平行低阻、反平行高阻"); D.video(s, "p04", 0.6, 2.0, 8.0);
//
// Options: theme {bg, fg, accent}, colors {...overrides / extra role colors}, fonts {head, body},
//          mediaDir, footer (text on every content slide; null = none), playHint (null = none),
//          pageNumbers (default true).
const fs = require("fs");
const path = require("path");

function makeDeck(pptx, opts = {}) {
  const t = opts.theme || {};
  const C = Object.assign({
    dark: t.bg || "121212", darkInk: t.fg || "F2F0EA", accent: t.accent || "FF7A1A",
    light: "F7F5F0", ink: "1F1F1F", sub: "5A5A5A", line: "D9D4C7", panel: "ECE7DC",
    accentOnLight: "E8601A", // one step darker than the film accent, readable on light pages
  }, opts.colors || {});
  const H = (opts.fonts && opts.fonts.head) || "GenSekiGothic2 TW H"; // titles, badges, emphasis
  const M = (opts.fonts && opts.fonts.body) || "GenSekiGothic2 TW M"; // body text
  const mediaDir = opts.mediaDir || path.join(process.cwd(), "media");
  const playHint = opts.playHint === undefined ? "▶ 點一下播放（靜音動畫，講者邊播邊講）" : opts.playHint;
  const footer = opts.footer || null;
  const pageNumbers = opts.pageNumbers !== false;

  function chrome(s, onDark) {
    if (footer) s.addText(footer, { x: 0.6, y: 7.05, w: 9.0, h: 0.3, fontFace: M, fontSize: 10,
      color: onDark ? "8A8A8A" : C.sub, margin: 0 });
    if (pageNumbers) s.slideNumber = { x: 12.2, y: 7.0, w: 0.6, h: 0.35, fontFace: M, fontSize: 10,
      color: onDark ? "8A8A8A" : C.sub, align: "right" };
  }
  function badge(s, text, onDark) {
    s.addText(text, { x: 0.6, y: 0.35, w: 2.6, h: 0.45, fontFace: H, fontSize: 16, bold: true,
      color: onDark ? C.dark : "FFFFFF", fill: { color: onDark ? C.accent : C.ink }, align: "center", valign: "middle" });
  }
  function title(s, text, o = {}) {
    s.addText(text, { x: 0.6, y: 0.95, w: 12.1, h: 1.0, fontFace: H, fontSize: o.size || 36, bold: true,
      color: o.color || C.ink, valign: "top", margin: 0 });
  }
  // role: badge text (null = no badge). chrome: false for the cover.
  function lightSlide(role, o = {}) {
    const s = pptx.addSlide();
    s.background = { color: C.light };
    if (role) badge(s, role, false);
    if (o.chrome !== false) chrome(s, false);
    return s;
  }
  function darkSlide(role, o = {}) {
    const s = pptx.addSlide();
    s.background = { color: C.dark };
    if (role) badge(s, role, true);
    if (o.chrome !== false) chrome(s, true);
    return s;
  }
  // Embed media/<name>.mp4 at (x, y), width w, 16:9, inside a dark frame; poster = media/<name>.png.
  // Missing clip -> a placeholder, so the deck can be laid out before the film is rendered.
  function video(s, name, x, y, w) {
    const h = w * 9 / 16;
    const mp4 = path.join(mediaDir, `${name}.mp4`);
    const png = path.join(mediaDir, `${name}.png`);
    s.addShape(pptx.ShapeType.rect, { x: x - 0.06, y: y - 0.06, w: w + 0.12, h: h + 0.12,
      fill: { color: C.dark }, line: { color: C.dark } });
    if (fs.existsSync(mp4)) {
      // PptxGenJS expects the cover as "image/png;base64,..." (no "data:" prefix).
      const cover = fs.existsSync(png) ? "image/png;base64," + fs.readFileSync(png).toString("base64") : undefined;
      s.addMedia({ type: "video", path: mp4, x, y, w, h, cover });
    } else {
      s.addText(`［動畫 ${name}.mp4 尚未產生］`, { x, y, w, h, fontFace: M, fontSize: 18, color: C.darkInk, align: "center" });
    }
    if (playHint) s.addText(playHint, { x, y: y + h + 0.12, w, h: 0.35, fontFace: M, fontSize: 13, color: C.sub });
    return { x, y, w, h };
  }
  function card(s, x, y, w, h, head, body, color) {
    s.addShape(pptx.ShapeType.roundRect, { x, y, w, h, rectRadius: 0.12, fill: { color: C.panel }, line: { color: color || C.line, width: 1.5 } });
    s.addText(head, { x: x + 0.25, y: y + 0.18, w: w - 0.5, h: 0.6, fontFace: H, fontSize: 22, color: color || C.ink });
    s.addText(body, { x: x + 0.25, y: y + 0.8, w: w - 0.5, h: h - 0.95, fontFace: M, fontSize: 17, color: C.ink, valign: "top" });
  }
  // "示意" stamp for hand-drawn / illustrative charts. (x, y) = top-right corner of the chart area.
  function illustrative(s, x, y, text) {
    const w = 1.1;
    s.addText(text || "示意", { x: x - w, y, w, h: 0.4, fontFace: H, fontSize: 14, bold: true,
      color: C.accentOnLight, fill: { color: "FFFFFF" }, line: { color: C.accentOnLight, width: 1.25 },
      align: "center", valign: "middle" });
  }
  // Source / measurement-condition note under a chart or table.
  function source(s, text, o = {}) {
    s.addText(text, { x: o.x || 0.6, y: o.y || 6.6, w: o.w || 12.1, h: 0.35, fontFace: M, fontSize: 11,
      color: C.sub, italic: true, margin: 0 });
  }
  // Bulleted list; items are strings. Returns nothing.
  function bullets(s, items, x, y, w, h, o = {}) {
    s.addText(items.map((t) => ({ text: t, options: { bullet: true, breakLine: true } })),
      { x, y, w, h, fontFace: M, fontSize: o.size || 20, color: o.color || C.ink, valign: "top", paraSpaceAfter: 8 });
  }
  // Simple table: rows[0] is the header. emphasizeRow (index) gets the accent tint.
  function table(s, rows, x, y, w, colW, o = {}) {
    const head = { fill: { color: C.ink }, color: "FFFFFF", fontFace: H, fontSize: o.size || 17, bold: true, align: "center", valign: "middle" };
    const body = rows.slice(1).map((r, i) => r.map((t) => ({ text: t, options: {
      fontFace: M, fontSize: o.size || 17, align: "center", valign: "middle", color: C.ink,
      fill: { color: o.emphasizeRow === i + 1 ? "FCE9DD" : "FFFFFF" } } })));
    s.addTable([rows[0].map((t) => ({ text: t, options: head })), ...body],
      { x, y, w, colW, rowH: o.rowH || 0.7, border: { type: "solid", pt: 1, color: C.line } });
  }
  return { C, H, M, badge, title, lightSlide, darkSlide, video, card, illustrative, source, bullets, table };
}

module.exports = { makeDeck };
