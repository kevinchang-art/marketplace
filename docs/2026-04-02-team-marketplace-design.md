# Team Marketplace 設計文件

> 建立日期：2026-04-02
> 狀態：Draft

## 1. 目標

為 CMoney AILab 團隊建立一個 Claude Code Plugin Marketplace，讓工程與非工程人員都能輕鬆發佈、發現、安裝彼此的 Plugin。

### 核心原則

- **全員可參與**：跨職能發展，不區分工程/非工程
- **對話式操作**：透過 Claude Code 自然語言或斜線命令管理，不需理解 Git 細節
- **品質把關**：自動化 CI 驗證 + 人工審核雙層機制
- **零額外基礎設施**：完全基於 GitHub Free plan

## 2. 架構

### 2.1 GitHub 組織

- **Org 名稱**：`cm-ailab-cc-plugins`
- **帳號**：由 `ailabcmoney` GitHub 帳號建立
- **方案**：GitHub Free（private repo 無限、成員無限、Actions 2000 min/月）

### 2.2 Repo 結構

採用 **Marketplace index + 獨立 Plugin repo** 架構：

```
GitHub Org: cm-ailab-cc-plugins
├── marketplace                      ← Index repo
│   ├── .claude-plugin/
│   │   └── marketplace.json         ← Plugin 目錄索引
│   ├── .github/
│   │   └── workflows/
│   │       └── validate.yml         ← CI 自動驗證
│   ├── templates/                   ← Plugin scaffold 範本
│   │   ├── skill/
│   │   ├── hook/
│   │   ├── agent/
│   │   ├── mcp-server/
│   │   └── mixed/
│   └── docs/
│       └── 本文件
│
├── plugin-query-mongo               ← 獨立 Plugin repo（範例）
├── plugin-review-code
└── plugin-mp                        ← 管理工具本身（自舉）
```

### 2.3 本地工作目錄

```
~/CMoney/cm-ailab-cc-plugins/
├── marketplace/
├── plugin-mp/
└── plugin-xxx/（自己開發的 plugin）
```

### 2.4 選擇獨立 repo 而非 monorepo 的理由

- 預期全員都會發佈 plugin，數量會快速增長
- 獨立 repo 天然隔離，各人管各人的
- 避免 monorepo 的變更衝突和 repo 膨脹

## 3. Plugin 規範

### 3.1 命名規範

- **`plugin.json.name`**：canonical ID，格式為 `<動作>-<對象>`（全英文小寫，用 `-` 分隔）
  - 範例：`query-mongo`、`review-code`、`gen-report`
- **Repo 名稱**：`plugin-` + `plugin.json.name`
  - 範例：`plugin-query-mongo`、`plugin-review-code`、`plugin-gen-report`
- **Claude Code 中的引用**：`<name>@cm-ailab-cc-plugins`
  - 範例：`query-mongo@cm-ailab-cc-plugins`
- CI 驗證 repo 名稱必須等於 `plugin-` + `plugin.json.name`

### 3.2 Plugin 結構

每個 plugin repo 必須包含：

```
plugin-xxx/
├── .claude-plugin/
│   └── plugin.json          ← 必要：清單檔
├── skills/                  ← 可選：斜線命令
│   └── <skill-name>/
│       └── SKILL.md
├── agents/                  ← 可選：代理定義
│   └── <agent-name>.md
├── hooks/                   ← 可選：事件鉤子
│   └── hooks.json
├── mcp-servers/             ← 可選：MCP 伺服器設定
└── README.md                ← 建議：說明文件
```

### 3.3 plugin.json 必填欄位

```json
{
  "name": "query-mongo",
  "version": "1.0.0",
  "type": "skill",
  "description": "以自然語言查詢 MongoDB，自動生成並執行 query",
  "keywords": ["mongodb", "query"],
  "author": {
    "name": "Nero",
    "github": "Nero-2307"
  }
}
```

`type` 欄位合法值：

| 值 | 包含內容 | 安全等級 |
|---|---------|---------|
| `skill` | 僅 SKILL.md | 低風險（純指令文字） |
| `agent` | Agent 定義 | 低風險（純指令文字） |
| `hook` | hooks.json（事件觸發執行命令） | 高風險（可執行程式碼） |
| `mcp` | MCP Server 設定（長駐服務） | 高風險（可執行程式碼） |
| `mixed` | 以上任意組合 | 依包含的最高風險等級 |

**安全規則**：專案 `.claude/settings.json` 中的 `enabledPlugins` 只能自動啟用 `skill` 和 `agent` 類型。`hook`、`mcp`、`mixed` 類型的 plugin 需要使用者在 Claude Code 中手動確認才會啟用。

### 3.5 Deprecation 機制

在 marketplace.json 的 plugin entry 中加入 `deprecated` 欄位：

```json
{
  "name": "query-mongo",
  "deprecated": true,
  "replacement": "query-db"
}
```

行為定義：

| 操作 | deprecated plugin 的行為 |
|------|------------------------|
| `/mp:search` | 預設隱藏，加 `--all` 才顯示（標記為已棄用） |
| `/mp:list` | 顯示但標記為已棄用 |
| 已安裝的 plugin | 繼續運作，但啟動時顯示棄用警告 |
| 新安裝 | 允許但顯示警告，建議改用 `replacement` |

`replacement` 欄位為可選，指向建議替代的 plugin name。

### 3.4 分類方式

- 不做硬分類（不用資料夾或 prefix 分類）
- 使用 `keywords` 標籤（至少 2 個）
- 使用 `description` 描述（具體說明功能）
- Claude Code 透過語意搜尋匹配

## 4. 發佈流程

### 4.1 流程圖

```
使用者說「我想發佈 plugin」或 /mp:publish
        │
        ▼
Claude Code 引導式對話
  ├── 建議命名（提供 2-3 選項）
  ├── 建議描述（根據使用者說明草擬）
  ├── 建議 keywords（核心 + 可選）
  ├── 確認 plugin 類型（skill/hook/agent/mcp/mixed）
  └── 檢查類似 plugin（避免重複）
        │
        ▼
Claude Code 自動執行
  ├── gh repo create cm-ailab-cc-plugins/plugin-xxx --private
  ├── Scaffold plugin 結構（從 templates/ 產生）
  ├── git push 到 plugin repo
  ├── git tag v1.0.0 並 push tag
  ├── 在 marketplace repo 建 branch
  ├── 更新 marketplace.json（加入新 plugin entry，ref 指向 tag）
  └── gh pr create 到 marketplace repo（base: main）
        │
        ▼
GitHub Actions CI 自動驗證
  ├── 結構驗證（plugin.json 存在、必填欄位、命名規範、semver）
  ├── 內容驗證（依 type 欄位檢查對應格式）
  ├── 交叉驗證（type 宣告與 repo 實際內容一致）
  ├── 版本一致性（ref tag = v + plugin.json.version）
  └── 品質警告（description 太短、缺 README、keyword 重複）
        │
        ▼
Reviewer 人工審核（透過 CODEOWNERS 指定）
        │
        ▼
合併 → 全員下次啟動自動更新
```

### 4.2 更新流程

```
使用者說「更新我的 plugin」或 /mp:update plugin-xxx
        │
        ▼
Claude Code
  ├── 讀取目前版本
  ├── 問 bump patch / minor / major
  ├── 更新 plugin.json version
  ├── 推 code 到 plugin repo
  ├── git tag vX.Y.Z 並 push tag
  ├── 更新 marketplace.json 的 ref 指向新 tag
  └── 發 PR
        │
        ▼
CI 驗證 → Reviewer 審核 → 合併
```

## 5. mp Plugin（管理工具）

### 5.1 概述

`plugin-mp` 是 marketplace 的第一個 plugin（自舉），提供所有管理功能。

### 5.2 支援的操作

所有操作都可透過**斜線命令**或**自然語言**觸發。

#### 核心操作

| 斜線命令 | 自然語言觸發範例 | 功能 |
|---------|----------------|------|
| `/mp:publish` | 「我想發佈一個新的 plugin」「幫我建一個 plugin 分享給團隊」 | 引導式發佈新 plugin |
| `/mp:update <name>` | 「更新我的 query-mongo plugin」 | 更新既有 plugin 版本 |
| `/mp:validate` | 「幫我檢查這個 plugin 結構對不對」 | 本地驗證 plugin 結構（CI 同等檢查） |

#### 查詢操作

| 斜線命令 | 自然語言觸發範例 | 功能 |
|---------|----------------|------|
| `/mp:search <keyword>` | 「有沒有人做過 MongoDB 相關的 plugin？」 | 搜尋 marketplace 中的 plugin |
| `/mp:list` | 「團隊有哪些 plugin 可以用？」 | 列出所有 plugin |
| `/mp:my-plugins` | 「我發佈過哪些 plugin？」 | 列出自己的 plugin |

#### 管理操作

| 斜線命令 | 自然語言觸發範例 | 功能 |
|---------|----------------|------|
| `/mp:deprecate <name>` | 「我想淘汰這個 plugin」 | 標記 plugin 為棄用（見 §3.5） |
| `/mp:setup` | 「幫我設定團隊 marketplace」 | 一鍵 onboarding |

### 5.3 互動設計原則

- **永遠提供選項**：命名、描述、keywords 都主動建議 2-3 個選項
- **主動檢查衝突**：發佈前搜尋現有 plugin，提示類似功能
- **建議優化**：根據現有 plugin 的命名風格和 keyword 慣例給建議
- **非工程友善**：解釋每步在做什麼，隱藏 Git 操作細節

## 6. CI 自動化驗證

CI 只做**靜態/結構驗證**，不做 runtime 驗證（不執行命令、不啟動服務）。

### 6.1 結構驗證（必過，否則 PR 不能合併）

| 檢查項目 | 說明 |
|---------|------|
| `plugin.json` 存在 | `.claude-plugin/plugin.json` 必須存在 |
| 必填欄位完整 | `name`、`version`、`type`、`description`、`keywords`（≥2 個）、`author.github` |
| 命名規範 | repo 名稱符合 `plugin-<動作>-<對象>` 格式 |
| 版本格式 | semver 格式（`x.y.z`） |
| `type` 合法 | 值為 `skill`、`agent`、`hook`、`mcp`、`mixed` 之一 |
| Git tag 存在 | marketplace.json 中 `ref` 指向的 tag 存在於 plugin repo |

### 6.2 內容驗證（按 `type` 欄位決定，必過）

| Plugin 類型 | 檢查內容 |
|------------|---------|
| `skill` | `skills/` 下至少一個 `SKILL.md`，有 frontmatter `description` |
| `hook` | `hooks.json` 格式正確，event type 為合法值 |
| `agent` | `.md` 檔有合法 YAML frontmatter |
| `mcp` | MCP 設定中 `command` 欄位存在（不驗證執行檔是否可用） |
| `mixed` | 依實際包含的類型分別檢查 |

### 6.3 交叉驗證（防止 type 宣告繞過，必過）

`type` 宣告必須與 repo 實際內容一致：

- 若 `type` 不含 `hook` 或 `mixed`，repo 中不得存在 `hooks.json`
- 若 `type` 不含 `mcp` 或 `mixed`，repo 中不得存在 MCP 設定
- 若 `type` 為 `mixed`，必須包含兩種以上類型的實際內容

### 6.4 版本一致性驗證（必過）

- CI 以 marketplace.json 中 `ref` 指向的 **tag commit** 為準，checkout 該 commit 後讀取 `.claude-plugin/plugin.json.version`
- tag 名稱必須等於 `v` + 該 commit 中的 `plugin.json.version`
  - 例如：tag commit 內 `plugin.json.version = "1.2.0"` → `ref` 必須是 `"v1.2.0"`
- 不讀 plugin repo 的 default branch，避免後續變更造成誤判
- 驗證 marketplace.json entry 的 `name` 欄位等於 tag commit 內 `plugin.json.name`

### 6.5 品質檢查（警告，不擋 PR）

- `description` 字數 < 10 → 警告太短
- 沒有 `README.md` → 建議補上
- `keywords` 與現有 plugin 重複度高 → 提醒可能有類似 plugin

## 7. 團隊 Onboarding

### 7.1 初始建置（做一次）

1. 建立 GitHub Org `cm-ailab-cc-plugins`
2. 建立 `marketplace` repo（index + CI + templates）
3. 建立 `plugin-mp` repo（管理工具，自舉為第一個 plugin）
4. 設定 `CODEOWNERS`（指定 marketplace PR 的必要審核者）
5. 設定 Org 權限：Member 可建立 repo（Settings → Member privileges → Repository creation → Private）
6. 邀請團隊成員加入 org

### 7.2 成員 Onboarding（每人一次）

1. 接受 GitHub Org 邀請
2. 首次安裝（使用 Claude Code 原生命令）：
   ```
   /plugin marketplace add cm-ailab-cc-plugins/marketplace
   /plugin install mp@cm-ailab-cc-plugins
   ```
   或在團隊專案中 clone 後信任 `.claude/settings.json` 即自動取得。

3. 安裝完成後可用 `/mp:setup` 驗證與修復環境：

`/mp:setup` 自動化流程：
```
✓ 檢查 gh CLI... 已安裝
✓ 檢查 gh auth... 已登入
✓ 檢查 org 成員資格... 確認
✓ 檢查 marketplace... 已加入
✓ 檢查 mp plugin... 已安裝
✓ 設定 GITHUB_TOKEN...
  ⚠ 未設定 → 引導設定（背景自動更新需要）

🎉 環境正常！
```

> **注意**：`/mp:setup` 是驗證/修復工具，不是首次安裝入口。首次安裝需使用原生 `/plugin` 命令或透過專案設定自動取得。

### 7.3 專案級自動配置（可選）

在團隊專案的 `.claude/settings.json` 加入：

```json
{
  "extraKnownMarketplaces": {
    "cm-ailab-cc-plugins": {
      "source": {
        "source": "github",
        "repo": "cm-ailab-cc-plugins/marketplace"
      }
    }
  },
  "enabledPlugins": {
    "mp@cm-ailab-cc-plugins": true
  }
}
```

效果：新成員 clone 專案 → 信任設定 → 自動取得 marketplace + mp 管理工具。

> **安全規則**：`enabledPlugins` 只應自動啟用 `type` 為 `skill` 或 `agent` 的 plugin。`hook`、`mcp`、`mixed` 類型的 plugin 需使用者在 Claude Code 中手動確認後才啟用。

### 7.4 認證處理

| 情境 | 處理方式 |
|------|---------|
| 手動操作（`/mp:publish` 等） | 用成員自己的 `gh auth` |
| 背景自動更新 | 需設 `GITHUB_TOKEN` 環境變數 |
| 沒有 `gh` CLI | `/mp:setup` 引導安裝 |

## 8. marketplace.json 格式

```json
{
  "name": "cm-ailab-cc-plugins",
  "owner": {
    "name": "CMoney AILab",
    "email": "ailab@cmoney.com.tw"
  },
  "metadata": {
    "description": "CMoney AILab 團隊共用的 Claude Code Plugin Marketplace",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "mp",
      "source": {
        "source": "github",
        "repo": "cm-ailab-cc-plugins/plugin-mp",
        "ref": "v1.0.0"
      },
      "description": "Marketplace 管理工具 — 發佈、搜尋、更新 plugin",
      "keywords": ["marketplace", "management"]
    }
  ]
}
```

## 9. 技術決策記錄

| 決策 | 選項 | 選擇 | 理由 |
|------|------|------|------|
| 託管平台 | GitHub vs GitLab | GitHub | 全員可達（無 VPN 限制），原生 Claude Code 支援 |
| GitHub 帳號 | Nero-2307 vs ailabcmoney | ailabcmoney | 團隊用途，與個人帳號分離 |
| Org vs 個人帳號 | Org vs ailabcmoney 下直接建 repo | 新建 Org | 隔離 plugin repo 與其他產品 repo |
| Repo 結構 | Monorepo vs 獨立 repo | 獨立 repo | 預期快速成長，獨立 repo 天然隔離 |
| 管理介面 | Git PR / CLI 指令 / Web UI | Claude Code 對話 | 全員都用 Claude Code，門檻最低 |
| 管理工具實作 | 純 GitHub 流程 / Skill / MCP Server | Skill（mp plugin） | 零基礎設施、靜態檔案、自舉 |
| 發佈審核 | 無審核 / 自助 / 人工 / 分級 | CI 自動驗證 + 人工審核 | 品質把關同時減輕人為負擔 |
| 分類方式 | 職能 / 用途 / Tag / 無 | Keywords + 命名規範 | 不與跨職能價值衝突，靠語意搜尋 |
| 版本鎖定 | ref(tag) / sha / 無 | ref 指向 git tag | 明確且人類可讀，不需 SHA 的精確度 |
| 可執行 plugin 安全 | 無限制 / capability tier / 手動確認 | 按 type 限制自動啟用 | hook/mcp/mixed 需手動確認，降低供應鏈風險 |
| CI 驗證範圍 | 含 runtime / 純靜態 | 純靜態結構檢查 | CI 環境無法可靠驗證 runtime 行為 |
| Plugin 類型識別 | 自動偵測 / 明確欄位 | plugin.json 的 `type` 欄位 | CI 需要明確依據，避免猜測 |
