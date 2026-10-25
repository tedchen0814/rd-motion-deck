# 技術踩坑紀錄

上游 soil-motion-deck 第一次實作（〈畢氏定理〉：簡報 13 頁、3 段動畫、110 秒影片）時踩過的坑。剪片、PptxGenJS 和影片製作的部分跟主題無關，研發版照樣適用。

## 規劃

1. **🎬 頁挑「變化就是重點」的頁。** 定義頁和表格頁用靜態版型就夠了，做成動畫反而比較慢。
2. **影片的分格跟著簡報走**，不要另外構思一支片。旁白一寫好，兩邊的用語就一致。
3. **共用的幾何寫在 `_dispatch_context.md`。** 前後兩格出現同一個元件（同一顆磁鐵、同一組座標軸）時，座標要完全一樣，所有 worker 照抄。

## 剪片

4. **剪在轉場重疊的範圍外。** 相鄰兩格有交叉淡入淡出時，兩格同時在畫面上，剪在那個範圍裡會混到前後格的畫面。`cut_clips.py` 用每一格的 `data-start`／`data-duration` 自動算出範圍，不必手算。直接切換的轉場沒有重疊，不用裁。
5. **片段一律重新編碼**：H.264、yuv420p、沒有音軌、`+faststart`，CRF 20。用 `-c copy` 只能在關鍵影格切，頭尾會多出半秒到兩秒。
6. **孿生版要整份複製再拿掉 audio 和字幕**，不要在原專案裡改 index.html 再改回來：輸出到一半如果出錯，原專案就壞了。

## PptxGenJS

7. **影片封面的格式**：`addMedia({ type: "video", path, cover })` 的 `cover` 用 `"image/png;base64,<資料>"`，前面不加 `data:`。
8. **字型不會內嵌**：投影的電腦沒有源石黑體，就會退回系統字型。交付時要提醒，或改用微軟正黑體重建。
9. **用 PowerPoint 本身輸出縮圖**（COM，唯讀開啟、不顯示視窗）才看得到真正的影片封面和字型；LibreOffice 的縮圖可能換掉字型，只能拿來看版面。
10. **圖表用 `addChart`**：示意圖的縱軸用 `valAxisHidden: true` 藏掉刻度數字，再用 `illustrative()` 蓋「示意」標籤。

## 影片

11. `assemble-index` 要在字幕建好之後才跑，不然 index 裡沒有字幕軌，畫面上完全沒有字幕。
12. 數字的倒數或累加，要在旁白唸到那個數字之前就停下來。
13. 用 dash 描線的路徑不能用 `stroke-linecap: square`，不然線還沒畫出來就先露出一個小點。
14. 翻牌卡的正反兩面疊在一起：在兩面的容器上加 `data-layout-allow-overlap`。
15. 「示意」標籤放在畫面右上角，不要放在字幕區（y > 896 px），否則 B 影片的字幕會蓋住它。

## 研發版第一次完整測試（去耦電容，4 格、50 秒影片，簡報 9 頁、2 段動畫）

16. **共用電路圖要把每個接點都寫死。** 這次只寫了電源、VDD、IC、地線的座標，沒寫 IC 的接地腳；兩個 worker 各自補上，一個畫在 x 1100、一個畫在 x 900，crossfade 時看得出來。`_dispatch_context.md` 的共用幾何要列出所有會出現的連線端點。
17. **同一個座標只寫在一個地方。** 「示意」標籤的位置在 Video direction 和 rd-motion-deck 規則各寫了一次，數字不一樣，worker 只好自己選。改座標時兩處要一起改，或只留一處。
18. **Windows 的 Python**：`python` 可能是 Microsoft Store 的空殼（exit code 49）。用 `py -3` 執行腳本；`fetch_fonts.sh` 要加 `PYTHON=<真正的 python.exe 路徑>`。
19. **響度一次調到位**：增益會被 limiter 吃掉一部分，量一次、調一次常常會超過（這次 −15.6 → −12.9 → −14.0）。調完一定再量一次。
20. **沒裝源石黑體**時，`makeDeck` 傳 `fonts: { head: "Microsoft JhengHei", body: "Microsoft JhengHei" }`，版面照樣成立。
21. **PptxGenJS 折線圖的類別軸**：最後一個類別放「時間 →」會被擠成兩行。類別標籤全部留空，另外用 `addText` 放軸標。

## 第二次完整測試（TMR 範例，7 格、92 秒影片，簡報 12 頁、3 段動畫）

22. **每個 clip 要有自己的 `data-track-index`。** 07 格的上下兩條細線放在同一個 track，`assemble-index.mjs` 直接拒絕組裝（後面的 `transitions inject` 才會報「no frame clips found」）。派工時就提醒 worker：一個 track 同一時間只放一個 clip。
23. **「示意」標籤的字級也要寫死。** 只寫位置時，有的 worker 用 mono-tag 0.78cqw，有的用中文下限 1.4cqw。這次統一成 1.4cqw。
24. **誤判翻牌頁的封面不用 `@first`。** 每格都從空白開始，`@first` 會是空畫面。改用 `@秒數` 指到三張 ❌ 都出現、還沒翻面的時間（這次是剪輯後 1.8 秒）。
25. **頁面右側的文字摘要會先露出答案**：誤判頁的封面藏住答案，但右側的 ❌／✅ 摘要直接寫出來了。不想提前揭曉的話，右側只列 ❌，✅ 放講者備註。

## 發布成 repo 時發現的問題（2026-10-25）

26. **HyperFrames 下架了 `faceless-explainer`。** 2026-10-21 起 HyperFrames 只發布知識型 skills，workflow skills（含 `faceless-explainer` 與它的 `assemble-index.mjs`、`frame-packets.mjs` 等腳本）都拿掉了。`hyperframes skills update` 會刪除已下架的 skill；`hyperframes init` 也會向 GitHub 同步核心 skill。對策：從下架前的 commit `207c8a4` 安裝，並設定 `HYPERFRAMES_SKIP_SKILLS=1`。
27. **公司電腦的執行原則**：群組原則設成 `RemoteSigned` 時，雲端硬碟或網路磁碟上的 `.ps1` 會被擋，`-ExecutionPolicy Bypass` 也沒用。用 `irm` 下載成 scriptblock 執行，或把檔案放在本機磁碟。
