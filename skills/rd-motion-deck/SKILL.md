---
name: rd-motion-deck
description: 研發知識分享的動畫簡報：一次做出兩樣東西。A 是一份 .pptx 技術分享簡報，關鍵機制頁嵌入會動的原理動畫（靜音，講者邊播邊講）；B 是同一份內容的配音字幕解說影片（MP4），給沒到場的人、新人訓練或會前預讀。使用者要做「技術分享」「知識分享」「讀書會」「內部教育訓練」「新人 onboarding」「原理介紹」的簡報，而且提到動畫、影片、「讓原理動起來」「把機制做成動畫」「簡報加解說影片」時就要使用此技能，即使沒說出技能名稱。適用電子、電機、機構、韌體、材料、測試驗證等工程主題（例如訊號時序、PDN、TMR 感測、IP 防水測試、失效機制）。對象是學生或老師上課時改用 soil-motion-deck；只要靜態簡報、不要動畫時改用 soil-html-deck 或 pptx。
---

# 研發知識分享動畫簡報：一次製作，兩份成品

| 成品 | 內容 | 給誰用 |
|---|---|---|
| **A 簡報**（.pptx） | 技術分享簡報。2–4 個 🎬 機制頁嵌入動畫片段，片段**靜音、沒有字幕**，講者邊播邊講 | 現場分享、讀書會 |
| **B 影片**（MP4） | 同一份內容的完整解說片：配音、字幕、三色主題 | 沒到場的同事、新人訓練、會前預讀、知識庫 |

兩份成品共用同一套動畫：先做 B，再從 B 的「靜音孿生版」把 🎬 頁那幾格剪出來，嵌進 A。動畫只做一次，兩邊的秒數、用語、顏色完全一致。

本技能改寫自 [mathruffian-dot/soil-motion-deck](https://github.com/mathruffian-dot/soil-motion-deck)（MIT）：影片與剪片的技術流程照原樣沿用，內容架構從「SOIL 教學六引擎」換成「研發知識分享」的敘事。

做影片的部分以上游技能為準：

- **`motion-explainer`**（[mathruffian-dot/claude-motion-explainer](https://github.com/mathruffian-dot/claude-motion-explainer)），以及它帶的 `motion-design`、`review-loop` 和 HyperFrames 官方 skills：腳本、旁白、分格製作、字幕、三色主題、審查、輸出。

簡報內容架構在本文 §2 和 `references/rd-structure.md`，不需要 `soil-teaching-deck`。

## 0. 環境與路徑

| 代號 | 是什麼 | 常見位置 |
|---|---|---|
| `<rmd>` | 本技能資料夾 | `~/.claude/skills/rd-motion-deck` |
| `<me>` | motion-explainer 技能資料夾 | `~/.claude/skills/motion-explainer` |

Windows（PowerShell）先確認：

```powershell
Get-ChildItem "$HOME\.claude\skills" -Directory | Where-Object Name -in "rd-motion-deck","motion-explainer","review-loop","motion-design" | Select-Object FullName
```

少了任何一個，請使用者重跑本技能 repo（[tedchen0814/rd-motion-deck](https://github.com/tedchen0814/rd-motion-deck)）的一鍵安裝腳本：它會安裝 motion-explainer、motion-design、review-loop、HyperFrames 與官方 skills、edge-tts，並做環境檢查。也可以照 claude-motion-explainer 的 README 手動安裝。沒裝之前，可以先做到 §2 的頁面架構，以及只放佔位框的簡報；影片和片段要等裝好才能做。

其他需求：Node.js 22+、ffmpeg、Python 3、HyperFrames、edge-tts（預設 TTS，不需要 GPU）。使用者的內容是研究用途、不含公司資訊，所以 edge-tts 與 Breeze TTS 2（需要 NVIDIA GPU）都可以用。簡報用 PptxGenJS 3.12.0（`templates/package.json`）。字型預設源石黑體 H／M；沒裝就改用微軟正黑體（見 §5）。

**HyperFrames skills 是固定版本**：HyperFrames 在 2026-10-21 下架了 `faceless-explainer`，但 motion-explainer 的流程要用它。安裝腳本從下架前的 commit 安裝，並設定環境變數 `HYPERFRAMES_SKIP_SKILLS=1`。因此：
- **不要執行 `hyperframes skills update`**，也不要照 faceless-explainer 開頭「先更新 skill」的提示去更新，否則 `faceless-explainer` 會被刪掉。
- 執行 `hyperframes init` 時確認 `HYPERFRAMES_SKIP_SKILLS=1` 有生效（環境變數不在時，在指令前加上它）。
- 找不到 `<fe>`（faceless-explainer）時，請使用者重跑安裝腳本。

**Windows**：`python` 可能是 Microsoft Store 的空殼，改用 `py -3` 執行本文和 motion-explainer 的 Python 腳本；`fetch_fonts.sh` 前面加 `PYTHON=<python.exe 的完整路徑>`。

**沒有 sub-agent 的 agent**：motion-explainer 說「每格派一個 sub-agent 平行做」的地方，改成自己照順序一格一格做。

## 1. 開場訪談（一次問完）

知識分享的關鍵是「聽眾已經知道什麼、聽完要能做什麼」，不是課綱。一次問完這些，使用者已經講過的就不要再問：

1. **主題與範圍**：要講什麼、不講什麼（例如「講 TMR 原理和對位設計，不講 ASIC 內部」）。
2. **聽眾**：同部門 RD、跨部門（ME／EE／韌體／品保／PM）、新人，還是混合？他們的先備知識到哪裡？這決定術語要不要解釋、公式要不要出現。
3. **時間**：分享多長（常見 20、30、45 分鐘），要不要留 Q&A。
4. **帶走一句話**：聽完最該記住的一句話。使用者說不出來，就在 §2 幫他提出 2–3 個候選讓他選。
5. **素材**：有沒有 datasheet、app note、量測資料（CSV／截圖）、論文、自己的筆記。有實測數據就用實測；沒有的話，波形、曲線、趨勢圖做成示意圖並標示「示意」（§2.4）。
6. **成品**：A+B（預設）、只要 A、只要 B。只要 A 也照樣先做 B，因為旁白決定每一格的節奏，動畫才會自然；只是不交 B，旁白就不必讓使用者試聽。
7. **配色**：預設「影片三色 + 三明治」：
   - 影片（以及簡報裡的動畫視窗）用 motion-explainer 的三色，預設黑底 `#121212`、白字 `#F2F0EA`、橘色重點 `#FF7A1A`。
   - 簡報的封面、章節頁、結語是深色頁；內容頁是淺色頁，動畫放在深色的「播放視窗」裡。會議室投影機偏暗時，淺色內容頁比較看得清楚，這也是預設內容頁用淺色的原因。
   - 使用者有自己的顏色（個人慣用色、讀書會範本）就照用。
8. **旁白聲音**：照 motion-explainer 的規則。

motion-explainer 自己的開場訪談（平台、長度、聲音、三色）在這裡已經問過，**不要再問一次**。片長也不受它「60–90 秒」的建議限制：片長等於旁白長度，通常是每個 🎬 頁 15–25 秒，加上前後幾格。

## 2. 內容架構：故事線、頁面角色、🎬 機制頁

每一步做完都把結果給使用者確認，確認後才往下走。工程師聽眾最在意「為什麼要在意」和「這跟我的設計有什麼關係」，所以故事線從問題開始，不從定義開始。

### 2.1 定位（一張卡）

```
主題：TMR 磁阻感測器：從原理到對位設計
聽眾：EE + ME 混合，知道霍爾元件，沒用過 TMR
時間：30 分鐘（含 Q&A 5 分鐘）
帶走一句話：TMR 量的是「磁場方向」不是「磁場大小」，所以對位誤差會直接變成角度誤差。
聽完要能：① 說出 TMR 和霍爾的差別 ② 看懂 datasheet 的關鍵規格 ③ 做對位公差檢查
三個常見誤判：……（之後變成陷阱頁和 🎬 迷思翻轉）
```

### 2.2 故事線（預設骨架，依主題增刪）

| 段落 | 頁面角色 | 目的 |
|---|---|---|
| 開場 | 封面 → 今天帶走什麼 | 先講結論和聽眾的收穫 |
| 為什麼要在意 | 問題情境 | 一個工程上會遇到的現象或問題 |
| 原理 | 心智模型 🎬 → 總概念 | 用最少的術語建立「它怎麼運作」 |
| 實務 | 比較表、數據／曲線、設計要點 | 跟選型、設計、量測接起來 |
| 陷阱 | 常見誤判 🎬 | 「以為是 A → 其實是 B」 |
| 收尾 | 檢查清單（行動）→ 帶走一句話 → Q&A ＋ 參考資料 | 讓聽眾回去能用 |

頁數抓法：大約每分鐘 0.6–0.8 頁（30 分鐘約 18–24 頁），🎬 頁一頁約算 1.5 分鐘（播放加講解）。

### 2.3 頁面角色表，標出 🎬 動畫頁

每頁寫「角色、唯一主重點、版型」。要做動畫的頁加 `animate` 欄位：

```
第 4 頁：平行低阻、反平行高阻 🎬
- 頁面角色：心智模型
- 唯一主重點：自由層跟著外加磁場轉，和固定層的夾角決定電阻
- animate: { frame: 02-tunnel, poster: last }
```

`frame` 是這一頁在影片裡那一格的檔名（不含 `.html`），§3 寫分鏡時就固定下來。每段長度由旁白決定，不在這裡指定。

**哪些頁值得做動畫**（全份 2–4 頁，每段 15–25 秒）：「隨時間或隨參數改變」本身就是重點的頁。詳細的分領域清單在 `references/rd-structure.md`，常見的有：

| 類型 | 例子 |
|---|---|
| 物理機制 | 磁化方向轉動、電子穿隧、熱傳導路徑、應力集中 |
| 訊號與時序 | I²C／SPI 時序、上電順序、PWM 與濾波、反射與振鈴 |
| 電流與能量路徑 | 回流路徑、PDN 壓降、ESD 放電路徑 |
| 參數掃描 | 氣隙變大 → 磁場變弱、頻率變高 → 阻抗變化 |
| 機構與組裝 | 組裝順序、公差疊加、密封件壓縮 |
| 測試流程 | IP 等級噴水／浸水步驟、跌落、溫循 |
| 誤判翻轉 | 「以為是 A」→ 打叉 → 「其實是 B」 |

**不適合**：定義清單、規格表、參考資料、議程。這些用靜態版型就好，做成動畫反而比較慢。

### 2.4 示意圖與數據的規則

工程聽眾會拿圖去對照自己的經驗，所以「這張圖是量的還是畫的」一定要讓人一眼看出來。

- **示意圖**（自己畫的波形、曲線、趨勢、能帶圖、磁場分布）：簡報上用 `D.illustrative(s, …)` 在圖的右上角蓋「示意」標籤；影片那一格的畫面角落也要有「示意」字樣，片段被剪進簡報時才不會遺失。示意圖可以畫出趨勢與形狀，但軸上不放看起來像實測值的精確刻度數字，只標方向（例如「氣隙 ↑」「磁場 ↓」），或標「任意單位（a.u.）」。
- **實測數據**：使用者給了資料就照實畫，圖下方用 `D.source(s, …)` 註明來源與條件（溫度、電壓、樣本數、量測儀器）。
- **規格數字**（datasheet 的典型值）：寫上「典型值，依廠商規格書為準」，並在參考資料頁列出出處。不確定的數字寧可用定性描述（高／中／低），也不要自己編。
- 有效位數和單位要一致，簡報和影片用同一組數字。

## 3. 從簡報流程寫影片腳本（交接）

影片的分格順著簡報的流程走，不另外構思一支片。先在影片專案的 `BRIEF.md` 寫一張對照表，檔名在這裡就決定：

| 簡報頁 | 影片格（檔名） | 旁白要講什麼 | 用途 |
|---|---|---|---|
| 3 問題情境 | `01-why` | 為什麼要在意 | 只在影片裡用 |
| 🎬 4 | `02-tunnel` | 這一頁的唯一主重點 | 剪成 `p04` |
| 5–6 總概念、比較 | `03-ratio` | 總概念＋關鍵規格 | 只在影片裡用 |
| 🎬 7 | `04-bridge` | 這一頁的唯一主重點 | 剪成 `p07` |
| … | … | … | … |
| 結語 | `07-takeaway` | 帶走一句話 | 只在影片裡用 |

剪片段的名稱用 `p` + 兩位數頁碼（`p04`、`p07`），和 `build_deck.js` 裡 `video(s, "p07", …)` 的名稱一致。

接著照 motion-explainer 的格式寫 `SCRIPT.md`（每格一句 `## Line N`）和 `STORYBOARD.md`（每格的 `src` 用上表的檔名）。旁白素材直接拿 §2 的產出：

- 定位卡的「帶走一句話」→ 最後一格的旁白，一字不改；簡報結語頁也用同一句。
- 「三個常見誤判」→ 誤判翻轉那一格的三段旁白。
- 每個 🎬 頁的「唯一主重點」→ 那一格旁白的最後一句。
- 長度用每秒 4–4.5 個中文字估算，🎬 那一格的旁白約 70–100 字（15–25 秒）。
- 英文術語第一次出現時唸全名（例如「穿隧磁阻，TMR」），之後用縮寫。TTS 唸英文縮寫和元件型號容易出錯，旁白生成後先試聽這幾個詞，唸錯就照 motion-explainer 的發音修正方式處理。

🎬 格交給 worker 時，`_dispatch_context.md` 要多寫這六條（這幾格會被單獨拿出來，在沒有聲音、沒有字幕的情況下播放）：

1. **只看畫面也看得懂**：關鍵的數字、標籤、單位、結論都寫在畫面上，不能只靠旁白。
2. **從空白開始，最後停在結論**：最後一個狀態要完整、靜止至少 1 秒，因為它就是投影片上的封面。
3. **重要內容不要放在字幕區**（y > 896 px）：影片的字幕會蓋住它；簡報裡雖然沒有字幕，但同一格兩邊都要能用。
4. **示意圖要標「示意」**：放在畫面右上角、字幕區以外，整段都看得到（§2.4）。座標只在 `_dispatch_context.md` 寫一次，不要在 Video direction 再寫一組。
5. **共用幾何列出所有接點**：元件框、電源線、地線之外，接地腳、連接點的座標也要寫死，不然每個 worker 會各自補，crossfade 時對不上。
6. 前後格的銜接（同一個元件、同一個座標系）照常做；剪片時會自動去掉轉場重疊的部分。共用的幾何（元件位置、座標軸範圍）寫在 `_dispatch_context.md`，所有 worker 照抄。

接下來完全照 motion-explainer 的流程：旁白 → 鏡頭 → 每一格（有 sub-agent 就平行，沒有就依序）→ 組裝、字幕、配色 → draft 審查 → 輸出 B。

## 4. 靜音孿生版 → 剪出 🎬 片段

下面以 `$FILM` 代表影片專案的完整路徑：

```bash
python <rmd>/scripts/make_silent.py --project "$FILM"            # 建立 $FILM-silent：拿掉所有 audio 軌和字幕
(cd "$FILM-silent" && npx hyperframes render --quality high --output renders/silent.mp4)
python <rmd>/scripts/cut_clips.py --project "$FILM" --video "$FILM-silent/renders/silent.mp4" \
    --map p04=02-tunnel p07=04-bridge p09=06-pitfalls@first --out "$FILM/deck/media"
```

- `cut_clips.py` 讀 `index.html` 裡每一格的開始和長度，從「和前一格重疊的部分結束」剪到「和下一格重疊的部分開始」，不管哪一種轉場都不會混到前後格。它會印出每段長度，把長度寫進講者備註。
- 封面圖預設是最後一格（停在結論）。逐段指定的話，在 `--map` 後面加 `@first` 或 `@秒數`。誤判翻轉頁不想提前洩漏答案，就用 `@first`。
- **影片有任何修改**（任何一格、配色、長度）：重跑 `make_silent.py`、輸出、`cut_clips.py`。孿生版是一份快照，不會自動跟著改。

## 5. 做簡報

1. 建立簡報資料夾。**一定要用本技能的 `package.json`**：HyperFrames 專案根目錄的 `package.json` 是 `"type": "module"`，沒有自己的 `package.json` 的話，`require` 會失敗。

```bash
mkdir -p "$FILM/deck" && cp <rmd>/templates/package.json <rmd>/templates/deck_helpers.js "$FILM/deck/"
cp <rmd>/templates/example_tmr.js "$FILM/deck/build_deck.js"     # 從範例改起
(cd "$FILM/deck" && npm install)
```

2. 改寫 `build_deck.js`。**版面一律用 `LAYOUT_WIDE`（13.333 × 7.5 吋）**，`deck_helpers.js` 的座標都是照這個寬度設計的。字型預設標題 `GenSekiGothic2 TW H`、內文 `GenSekiGothic2 TW M`；播放的電腦沒有源石黑體的話，`makeDeck` 傳 `fonts: { head: "Microsoft JhengHei", body: "Microsoft JhengHei" }`。

```js
const path = require("path");
const pptxgen = require("pptxgenjs");
const { makeDeck } = require("./deck_helpers");
const pptx = new pptxgen();
pptx.layout = "LAYOUT_WIDE";
const D = makeDeck(pptx, { theme: { bg: "121212", fg: "F2F0EA", accent: "FF7A1A" },
  mediaDir: path.join(__dirname, "media"), footer: "TMR 磁阻感測器｜技術分享" });
const s = D.lightSlide("原理・動畫");
D.title(s, "平行低阻、反平行高阻");
D.video(s, "p04", 0.6, 2.0, 8.0);   // 左側 8 吋寬的播放視窗（16:9），下方有播放提示
// 右側 x = 9.0、寬 3.9 吋：放 2–3 行步驟或結論，沒播放時這一頁也看得懂
pptx.writeFile({ fileName: path.join(__dirname, "主題名稱.pptx") });
```

`deck_helpers.js` 提供的元件：`lightSlide`／`darkSlide`（自動加頁碼與頁尾）、`title`、`card`、`video`、`illustrative`（「示意」標籤）、`source`（資料來源註腳）、`bullets`、`table`。

3. 🎬 頁的版面：左邊放動畫（8.0 × 4.5 吋），右邊放 2–3 行步驟或結論。
4. **講者備註**：每頁都寫，內容是講者要講的重點，而不是投影片文字的重複。🎬 頁另外寫片長、在哪裡停下來解說。全份的備註裡還要有：
   - **預期會被問的問題與回答**（每個段落 1–2 題，放在最相關的頁）。
   - 數據頁的來源與量測條件；示意頁註明「此圖為示意，非實測」。
   - 講不完時可以跳過哪幾頁（標「可略」）。
5. 收尾三頁：檢查清單（深色行動頁，給聽眾回去能用的 3–6 條）、帶走一句話（深色）、Q&A ＋ 參考資料（淺色；列出 datasheet、app note、論文的名稱，使用者沒給就留「［請填入］」，不要編造文獻）。
6. `node build_deck.js`。片段還沒剪好時，`video()` 會先放一個佔位框，可以先排版。

**使用者已經有一份簡報**：PptxGenJS 不能修改現有的 .pptx。用 `python -m markitdown <檔案>.pptx` 讀出每頁內容（沒有 markitdown 就請使用者貼文字），把要保留的頁照原樣寫進 `build_deck.js`，選定的頁改成 🎬 版面，整份重新產生。交付時說明這是重建的新檔案，原檔沒有被改動。

## 6. 審查

```bash
python <rmd>/scripts/thumbs.py "$FILM/deck/<簡報>.pptx" --out "$FILM/deck/thumbs"   # 每頁一張 PNG + 總覽圖 deck-*.png
```

逐張看總覽圖，對照下面的清單：

- [ ] 🎬 頁的封面是動畫的那一格，不是黑框或佔位文字
- [ ] 動畫視窗沒有被其他文字或圖形蓋到；下方的播放提示看得到
- [ ] 每頁只有一個主重點；文字量投影時看得清楚（內文不小於 16 pt）
- [ ] **所有示意圖（簡報與影片）都有「示意」標籤**；實測圖都有來源與條件
- [ ] 規格數字標了「典型值」或出處；簡報和影片的數字、單位、術語一致
- [ ] 專有名詞第一次出現有全名或解釋，符合 §1 聽眾的程度
- [ ] 公式、計算、單位換算自己驗算過一次
- [ ] 講者備註有：重點、🎬 片長、預期問題與回答、可略的頁
- [ ] 參考資料沒有編造的文獻；不確定的留「［請填入］」
- [ ] B 影片的審查照 `review-loop` 做完（每個子句截一格，逐張看），並確認「示意」字樣沒有被字幕蓋到

## 7. 交付

交出 .pptx 和 MP4 的路徑，並說明：

- 🎬 頁是哪幾頁、各幾秒、封面用了哪一格。
- 預估講完的時間，以及標「可略」的頁。
- 播放那台電腦要先裝好源石黑體（.pptx 不內嵌字型；沒裝會退回系統字型），或改用微軟正黑體重建。
- 影片已經嵌進 .pptx，PowerPoint 和 Keynote 都能直接播放。Google 簡報匯入時可能不會保留嵌入的影片；要用的話把 `media/*.mp4` 上傳到雲端硬碟再插入。
- 旁白發音（特別是英文縮寫和元件型號）請使用者用耳朵聽一遍。唸錯的用 motion-explainer 的 `fix_voice.py` 修；修完要重剪片段、重建簡報。
- 列出所有標「［請填入］」的地方，讓使用者補上。

`references/lessons.md` 是上游第一次實作時踩過的技術坑（剪片、PptxGenJS、影片製作），遇到問題先查這裡。
