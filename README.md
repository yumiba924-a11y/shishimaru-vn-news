# VN30 図解新聞 — 運用手順

ベトナム株VN30の「図解新聞」を無料データ（VNDirect API）から毎日1枚出す自動化ツール。
端末（LSEG）不要。Claude Code / PowerShell 7 だけで回る。半自動（最後に目視1回）。

## 毎営業日これ1本
```powershell
pwsh -File scripts\run_daily.ps1          # 取得→解釈→図解→PNG/PDF。outputs\ に出る
pwsh -File scripts\run_daily.ps1 -Open     # 生成後そのままブラウザで開く
pwsh -File scripts\run_daily.ps1 -Log      # logs\ に実行ログを残す（無人運用向け）
```
ベトナム市場は日本時間17:00頃に引け → 夕方〜夜に回す（既定スケジュールは平日18:00 JST）。
※寄り付き前/場中に走らせても、当日未確定（全銘柄0）を自動でスキップし直近確定日を使う。

## 自動実行（毎営業日 18:00 JST）
```powershell
pwsh -File scripts\install_schedule.ps1    # Windowsタスクに登録（登録済み）
pwsh -File scripts\uninstall_schedule.ps1  # 解除
```
PCが落ちていた場合は次回起動時に追いかけ実行。生成後に目視1回で確定（半自動）。

## 出るもの（outputs\）
| ファイル | 中身 |
|---|---|
| `vn30_<日付>.json` | 30銘柄（終値/騰落/出来高/ウェイト）＋指数＋マクロの整形済みデータ（[1][2]） |
| `vn30_<日付>.interpreted.json` | 上記＋大見出し15字/内容60字＋寄与度（週次素材として保持）＋急変カード（[3]解釈） |
| `vn30_<日付>.news.json` | **人が編集**するニュースカード（CafeF等の要約）＋マクロ状態ラベル。雛形は自動生成 |
| `vn30_<日付>.html` | 図解新聞 1枚（[4]出力／v3ぶたまる型）。← 主成果物 |
| `vn30_<日付>.png` / `.pdf` | 静止版（共有・保存・印刷用） |

## 4段構成（各段は独立。壊れたらその段だけ差し替え）
```
scripts\fetch_vn30.ps1        [1][2] 取得・整形  … VNDirect finfo＋dchart＋マクロ＋ウェイト(close×株数)＋ガード
scripts\interpret.ps1         [3]    解釈        … 寄与度(綱引き)＋大見出し15字/内容60字＋急変カードを自動生成
scripts\render_zukai.ps1      [4]    出力        … JSON → 図解HTML(v2: 寄与度が主役/タイル/セクター/カード/マクロ)
scripts\run_daily.ps1         [5]    運用        … 上3つ＋PNG/PDF書き出しを一気に通す
scripts\install_schedule.ps1         スケジュール … 平日18:00自動実行を登録／uninstallで解除
```

## v3＝日次は「ぶたまる型」（今日のひとこと＋ニュースカードが主役）
- 日次レイアウト: マストヘッド「DAILY QUEST｜VN30分解新聞」→ 指数バー →
  **VN30ヒートマップ(時価総額で大小)＋今日のひとこと＋ししまる** → **ニュースカード4-5枚(主役)** → 状態ラベル付きマクロ帯。
- **ニュースカードは半自動**＝`outputs\vn30_<日付>.news.json` を人が編集（CafeF等の事実を1-2行・**転載不可**）。
  `**赤太字**`・`[[緑]]` で強調可。±3%急変は interpret が雛形を自動生成（既存は上書きしない）。
- ししまる画像は `assets\shishimaru.png`（CQCライオン）。
- **寄与度・セクター分解は日次から外し週次(ウィークリークエスト)の主役へ。** ただし interpreted.json には寄与度を保持（週次素材）。
- 寄与度の定義そのものは `VN30_zukai_v2_kousei.md`。contrib=ウェイト×騰落率（**概算**明記）、ウェイト＝終値×`config\constituents[].shares`÷VN30合計。

## マクロ帯のデータ源（per-item で縮退）
| 項目 | ソース | 失敗時 |
|---|---|---|
| USD/VND・ドン/円 | open.er-api.com（無料・キー不要） | config の手動値に縮退（"手動"表示） |
| 金(XAU) | gold-api.com（無料・キー不要） | 同上 |
| 原油 | 無料の安定源が無く既定で手動 | `config\vn30_universe.json` の `macro_fallback.oil_usd` を時々更新 |

**マクロ/トレンドの取得失敗は新聞本体を止めない**（該当ブロックだけ手動値/非表示に縮退）。

## 設定（手で直す所はここだけ）
- `config\vn30_universe.json` … VN30構成30銘柄＋セクター分類。
  **VN30は毎年1月・7月の第4月曜に入替** → 入替後に `constituents` と `last_reviewed` を更新。

## 既知の前提・注意
- データは無料ソース（VNDirect・非公式）由来。対外利用は出所明記＋免責が要る（HTML脚注に記載済）。
- 時価総額ウェイトは持っていないため、指数寄与の「pt数」は断定しない（見出しは定性表現）。
- マクロ帯の為替・商品は**参考値（手動）**。実運用では当日値に差替＋使用レート明記（社内ルール）。
- どんな相場（全面高/全面安/小動き/二極化）でもテンプレが崩れないことは合成データで検証済み。

## 次の発展（任意）
- 動く版（アニメ）は Claude Design へ `vn30_<日付>.interpreted.json` を渡してテンプレ化。
  静止版＝この HTML/将来PDF、動く版＝ブラウザ/URL の二段持ち。
- 週次の深掘り解説は別途（日次＝定点観測、週次＝洞察）。

詳細な背景・コンセプトは `VN30_zukai_design_v1.md`（設計書）と `VN30_handoff_to_claudecode.md`（引き継ぎ）を参照。
