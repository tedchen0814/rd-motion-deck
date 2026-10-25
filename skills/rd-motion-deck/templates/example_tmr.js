// 範例：研發知識分享〈TMR 磁阻感測器：從原理到對位設計〉（12 頁，約 25 分鐘）
// 第 4、7、9 頁嵌入動畫（media/p04|p07|p09.mp4，封面＝最後畫面 PNG）。用法（見 SKILL.md §5）：
//   cp <本技能>/templates/{package.json,deck_helpers.js} <影片專案>/deck/
//   cp <本技能>/templates/example_tmr.js <影片專案>/deck/build_deck.js   # 再改成你的內容
//   cd <影片專案>/deck && npm install && node build_deck.js
// 注意：這是版型範例。規格數字只寫常見的量級並標「典型值」；圖表都是示意。
const path = require("path");
const pptxgen = require("pptxgenjs");
const { makeDeck } = require("./deck_helpers");

const pptx = new pptxgen();
pptx.layout = "LAYOUT_WIDE"; // 13.333 x 7.5 in
pptx.title = "TMR 磁阻感測器：從原理到對位設計";

const D = makeDeck(pptx, {
  theme: { bg: "121212", fg: "F2F0EA", accent: "FF7A1A" },          // 與影片 theme.json 相同
  colors: { pinned: "4D4D4D", free: "E8601A", barrier: "9A9A9A" },  // 固定層／自由層／穿隧層的角色色
  mediaDir: path.join(__dirname, "media"),
  footer: "TMR 磁阻感測器｜技術分享",
});
const { C, H, M, title, lightSlide, darkSlide, video, card, illustrative, source, bullets, table } = D;

// 1 封面（深色，不加頁碼頁尾）
{
  const s = darkSlide(null, { chrome: false });
  s.addText("技術分享・感測器", { x: 0.9, y: 1.6, w: 11.5, h: 0.5, fontFace: M, fontSize: 20, color: C.accent });
  s.addText("TMR 磁阻感測器", { x: 0.9, y: 2.2, w: 11.5, h: 1.4, fontFace: H, fontSize: 72, color: C.darkInk, bold: true });
  s.addText("從原理到對位設計", { x: 0.9, y: 3.7, w: 11.5, h: 0.8, fontFace: H, fontSize: 32, color: C.darkInk });
  s.addText("［講者姓名］・［日期］", { x: 0.9, y: 5.4, w: 8, h: 0.6, fontFace: M, fontSize: 20, color: "8A8A8A" });
  s.addNotes("開場 30 秒：今天只講三件事，講完大家應該能自己判斷對位公差夠不夠。");
}
// 2 今天帶走什麼
{
  const s = lightSlide("今天帶走什麼");
  title(s, "聽完這 25 分鐘，你可以…");
  card(s, 0.6, 2.2, 3.9, 3.6, "① 說出差別", "TMR 和霍爾元件\n量的東西不一樣", C.ink);
  card(s, 4.72, 2.2, 3.9, 3.6, "② 看懂規格", "datasheet 上哪幾個數字\n真的會影響你的設計", C.ink);
  card(s, 8.84, 2.2, 3.9, 3.6, "③ 檢查對位", "用一張檢查清單\n判斷磁鐵擺得夠不夠準", C.accentOnLight);
  s.addNotes("先講收穫，讓聽眾知道後面每一段在回答哪一題。");
}
// 3 問題情境（示意圖）
{
  const s = lightSlide("為什麼要在意");
  title(s, "磁鐵只偏一點點，角度就不準？");
  // magnet (circle) + sensor (square), slightly off-center
  s.addShape(pptx.ShapeType.ellipse, { x: 1.6, y: 2.4, w: 3.4, h: 3.4, fill: { color: C.panel }, line: { color: C.ink, width: 2 } });
  s.addShape(pptx.ShapeType.line, { x: 1.6, y: 4.1, w: 3.4, h: 0.001, line: { color: C.sub, width: 1, dashType: "dash" } });
  s.addShape(pptx.ShapeType.line, { x: 3.3, y: 2.4, w: 0.001, h: 3.4, line: { color: C.sub, width: 1, dashType: "dash" } });
  s.addShape(pptx.ShapeType.rect, { x: 3.45, y: 3.6, w: 0.75, h: 0.75, fill: { color: C.free }, line: { color: C.free } });
  s.addText("磁鐵中心", { x: 1.6, y: 5.9, w: 3.4, h: 0.4, fontFace: M, fontSize: 15, color: C.sub, align: "center" });
  s.addText("← 偏心的感測器", { x: 5.1, y: 3.7, w: 1.9, h: 0.5, fontFace: M, fontSize: 15, color: C.free });
  illustrative(s, 6.6, 2.2);
  bullets(s, ["同一顆磁鐵、同一顆 IC，量產時讀值卻不一致", "問題常常不在 IC，而在磁鐵和感測器的相對位置", "今天的目標：知道誤差從哪裡來、怎麼檢查"], 7.0, 2.4, 5.8, 3.6);
  s.addNotes("此圖為示意，非實測。可以請聽眾分享自己遇過的類似情況。");
}
// 4 🎬 原理（動畫）
{
  const s = lightSlide("原理・動畫");
  title(s, "平行低阻、反平行高阻");
  video(s, "p04", 0.6, 2.0, 8.0);
  const steps = ["① 固定層的磁化方向不動", "② 自由層跟著外加磁場轉", "③ 兩層夾角決定穿隧電阻：同向低、反向高"];
  steps.forEach((t, i) => s.addText(t, { x: 9.0, y: 2.1 + i * 1.3, w: 3.9, h: 1.15, fontFace: M, fontSize: 18, color: C.ink, valign: "top" }));
  s.addText("量的是「方向」", { x: 9.0, y: 6.0, w: 3.9, h: 0.6, fontFace: H, fontSize: 24, color: C.accentOnLight, align: "center" });
  s.addNotes("播放動畫（約 20 秒，靜音）。停在最後畫面，強調：電阻只跟夾角有關。\n預期問題：穿隧層是什麼材料？→ 常見是 MgO 薄膜，厚度約奈米等級（依製程而定）。");
}
// 5 總概念
{
  const s = lightSlide("總概念");
  title(s, "TMR 比值：電阻變化有多大");
  card(s, 0.9, 2.3, 3.6, 2.2, "R_P", "兩層同向時的電阻（低）", C.pinned);
  card(s, 4.85, 2.3, 3.6, 2.2, "R_AP", "兩層反向時的電阻（高）", C.free);
  card(s, 8.8, 2.3, 3.6, 2.2, "TMR 比值", "(R_AP − R_P) ÷ R_P", C.ink);
  s.addText("比值越大，同樣的角度變化產生的訊號越大，前端電路越好做。", { x: 0.9, y: 5.0, w: 11.5, h: 0.6, fontFace: M, fontSize: 20, color: C.ink });
  s.addNotes("帶走一句話先說一次：TMR 量的是磁場方向，不是大小。");
}
// 6 比較表
{
  const s = lightSlide("比較");
  title(s, "四種磁感測技術比一比");
  table(s, [
    ["技術", "主要感測", "電阻變化量級（典型）", "靈敏度", "功耗"],
    ["霍爾 Hall", "磁場分量大小", "—（電壓輸出）", "低", "較高"],
    ["AMR", "磁場方向", "約數 %", "中", "中"],
    ["GMR", "磁場方向", "約 10%～數十 %", "中高", "中"],
    ["TMR", "磁場方向", "可達 100% 以上", "高", "低"],
  ], 0.6, 2.2, 12.1, [2.2, 2.6, 3.3, 2.0, 2.0], { emphasizeRow: 4 });
  source(s, "典型量級，依各廠商規格書為準；用於角度量測時，AMR／GMR／TMR 通常操作在飽和磁場下。", { y: 6.1 });
  s.addNotes("不要背數字，記相對關係：TMR 訊號大、功耗低。實際選型一定回去查規格書。");
}
// 7 🎬 機制（動畫）
{
  const s = lightSlide("機制・動畫");
  title(s, "惠斯登電橋：把角度變成 sin／cos");
  video(s, "p07", 0.6, 2.0, 8.0);
  const steps = ["① 兩組電橋，固定層方向差 90°", "② 磁鐵轉一圈，輸出一組 sin、一組 cos", "③ 角度 = atan2(sin, cos)"];
  steps.forEach((t, i) => s.addText(t, { x: 9.0, y: 2.1 + i * 1.3, w: 3.9, h: 1.15, fontFace: M, fontSize: 18, color: C.ink, valign: "top" }));
  s.addNotes("播放動畫（約 22 秒）。停在 sin、cos 兩條線畫完時說明：用比值算角度，所以磁場強弱變化可以互相抵消。\n預期問題：為什麼用電橋？→ 差動輸出可以抵消共模的溫度漂移。");
}
// 8 數據：示意曲線
{
  const s = lightSlide("數據");
  title(s, "偏心越大，角度誤差越大");
  const labels = ["0", "", "", "", "", "偏心 →"];
  s.addChart(pptx.ChartType.line, [{ name: "角度誤差", labels, values: [0.2, 0.6, 1.4, 2.6, 4.2, 6.2] }], {
    x: 0.6, y: 2.0, w: 7.6, h: 4.4, chartColors: [C.accentOnLight], lineSize: 3, lineDataSymbol: "none",
    valAxisHidden: true, valGridLine: { style: "none" }, catAxisLabelFontFace: M, catAxisLabelFontSize: 14,
    showValAxisTitle: true, valAxisTitle: "角度誤差（a.u.）", valAxisTitleFontSize: 14,
    showLegend: false,
  });
  illustrative(s, 8.2, 2.0);
  bullets(s, ["趨勢：偏心或傾斜一變大，誤差上升得比直線快", "實際曲線取決於磁鐵尺寸、充磁方式、氣隙", "要定量，請用廠商的模擬工具或實測"], 8.7, 2.3, 4.1, 3.8, { size: 18 });
  source(s, "此圖為示意，非實測數據；縱軸為任意單位（a.u.）。", { y: 6.55, w: 7.6 });
  s.addNotes("此圖為示意。有實測資料時把這頁換成實測曲線，並在 source 寫上量測條件。");
}
// 9 🎬 常見誤判（動畫）
{
  const s = lightSlide("常見誤判・動畫");
  title(s, "三個常見誤判");
  video(s, "p09", 0.6, 2.0, 8.0);
  const items = [["❌ 只看靈敏度選型", "✅ 一起看溫漂、遲滯、工作磁場範圍"], ["❌ 對位只看中心", "✅ 偏心、傾斜、氣隙都要做公差分析"], ["❌ 周邊零件不影響", "✅ 鋼製螺絲、電感、喇叭都可能帶雜散磁場"]];
  items.forEach(([bad, good], i) => {
    s.addText(bad, { x: 9.0, y: 2.1 + i * 1.5, w: 3.9, h: 0.5, fontFace: M, fontSize: 17, color: C.sub });
    s.addText(good, { x: 9.0, y: 2.55 + i * 1.5, w: 3.9, h: 0.85, fontFace: H, fontSize: 17, color: C.ink, valign: "top" });
  });
  s.addNotes("播放動畫（約 24 秒）。每張卡翻面前停一下，讓聽眾先想「這樣做有什麼問題」。");
}
// 10 檢查清單（深色行動頁）
{
  const s = darkSlide("回去可以用");
  s.addText("對位設計檢查清單", { x: 0.9, y: 1.1, w: 11.5, h: 1.0, fontFace: H, fontSize: 40, color: C.darkInk });
  const qs = ["□ 規格書的工作磁場範圍，涵蓋最大與最小氣隙", "□ 偏心、傾斜、氣隙的公差疊加做過一次", "□ 周邊 10 mm 內的磁性零件列出來評估", "□ 溫度範圍內的角度誤差有預算"];
  qs.forEach((q, i) => s.addText(q, { x: 0.9, y: 2.4 + i * 1.0, w: 11.8, h: 0.8, fontFace: M, fontSize: 24, color: C.darkInk }));
  s.addNotes("「10 mm」是舉例的檢查範圍，依產品尺寸調整。這頁可以印出來給大家。");
}
// 11 帶走一句話（深色）
{
  const s = darkSlide("帶走一句話");
  s.addText("TMR 量的是", { x: 0.9, y: 2.0, w: 11.5, h: 1.0, fontFace: H, fontSize: 44, color: C.darkInk });
  s.addText([{ text: "磁場「方向」", options: { color: C.accent } }, { text: "，不是大小；" }],
    { x: 0.9, y: 3.0, w: 11.8, h: 1.1, fontFace: H, fontSize: 44, color: C.darkInk });
  s.addText("所以對位誤差，會直接變成角度誤差。", { x: 0.9, y: 4.2, w: 11.8, h: 1.0, fontFace: H, fontSize: 36, color: C.darkInk });
  s.addNotes("請聽眾用自己的話說一次，再進 Q&A。");
}
// 12 Q&A ＋ 參考資料
{
  const s = lightSlide("Q&A");
  title(s, "問題討論・參考資料");
  bullets(s, ["［請填入：感測器 IC 的 datasheet 名稱與版本］", "［請填入：廠商 app note（磁鐵選型／對位）］", "［請填入：論文或書籍］"], 0.6, 2.2, 12.1, 3.0);
  s.addText("影片版（含配音字幕）：［請填入連結］", { x: 0.6, y: 5.6, w: 12.1, h: 0.5, fontFace: M, fontSize: 18, color: C.accentOnLight });
  s.addNotes("參考資料只列真的看過的文件，不確定的就留空。");
}

pptx.writeFile({ fileName: path.join(__dirname, "TMR磁阻感測器_技術分享.pptx") }).then((f) => console.log("wrote", f));
