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

- Repo 名稱：`plugin-<動作>-<對象>`（全英文小寫，用 `-` 分隔）
- 範例：`plugin-query-mongo`、`plugin-review-code`、`plugin-gen-report`

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
  "name": "plugin-query-mongo",
  "version": "1.0.0",
  "description": "以自然語言查詢 MongoDB，自動生成並執行 query",
  "keywords": ["mongodb", "query"],
  "author": {
    "name": "Nero",
    "email": "nero_xu@cmoney.com.tw"
  }
}
```

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
  ├── 在 marketplace repo 建 branch
  ├── 更新 marketplace.json（加入新 plugin entry）
  └── gh pr create 到 marketplace repo（base: main）
        │
        ▼
GitHub Actions CI 自動驗證
  ├── 結構驗證（plugin.json 存在、必填欄位、命名規範、semver）
  ├── 內容驗證（依類型檢查 skill/hook/agent/mcp 格式）
  ├── Plugin repo 可 clone
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
  ├── 推 code 到 plugin repo
  ├── 更新 marketplace.json 版本號
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
| `/mp:deprecate <name>` | 「我想淘汰這個 plugin」 | 標記 plugin 為棄用 |
| `/mp:setup` | 「幫我設定團隊 marketplace」 | 一鍵 onboarding |

### 5.3 互動設計原則

- **永遠提供選項**：命名、描述、keywords 都主動建議 2-3 個選項
- **主動檢查衝突**：發佈前搜尋現有 plugin，提示類似功能
- **建議優化**：根據現有 plugin 的命名風格和 keyword 慣例給建議
- **非工程友善**：解釋每步在做什麼，隱藏 Git 操作細節

## 6. CI 自動化驗證

### 6.1 結構驗證（必過，否則 PR 不能合併）

| 檢查項目 | 說明 |
|---------|------|
| `plugin.json` 存在 | `.claude-plugin/plugin.json` 必須存在 |
| 必填欄位完整 | `name`、`version`、`description`、`keywords`（≥2 個） |
| 命名規範 | repo 名稱符合 `plugin-<動作>-<對象>` 格式 |
| 版本格式 | semver 格式（`x.y.z`） |
| Plugin repo 可 clone | 目標 plugin repo 存在且可存取 |

### 6.2 內容驗證（按 plugin 類型，必過）

| Plugin 類型 | 檢查內容 |
|------------|---------|
| Skill | `skills/` 下至少一個 `SKILL.md`，有 frontmatter `description` |
| Hook | `hooks.json` 格式正確，event type 為合法值 |
| Agent | `.md` 檔有合法 YAML frontmatter |
| MCP Server | `command` 欄位存在，指向有效執行檔 |
| LSP Server | 設定格式正確 |

### 6.3 品質檢查（警告，不擋 PR）

- `description` 字數 < 10 → 警告太短
- 沒有 `README.md` → 建議補上
- `keywords` 與現有 plugin 重複度高 → 提醒可能有類似 plugin

## 7. 團隊 Onboarding

### 7.1 初始建置（做一次）

1. 建立 GitHub Org `cm-ailab-cc-plugins`
2. 建立 `marketplace` repo（index + CI + templates）
3. 建立 `plugin-mp` repo（管理工具，自舉為第一個 plugin）
4. 設定 `CODEOWNERS`（指定 marketplace PR 的必要審核者）
5. 邀請團隊成員加入 org

### 7.2 成員 Onboarding（每人一次）

1. 接受 GitHub Org 邀請
2. 在 Claude Code 中執行 `/mp:setup` 或說「幫我設定團隊 marketplace」

`/mp:setup` 自動化流程：
```
✓ 檢查 gh CLI... 已安裝
✓ 檢查 gh auth... 已登入
✓ 檢查 org 成員資格... 確認
✓ 加入 marketplace... 完成
✓ 安裝 mp plugin... 完成
✓ 設定 GITHUB_TOKEN...
  ⚠ 未設定 → 引導設定（背景自動更新需要）

🎉 設定完成！
```

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
      "name": "plugin-mp",
      "source": {
        "source": "github",
        "repo": "cm-ailab-cc-plugins/plugin-mp"
      },
      "description": "Marketplace 管理工具 — 發佈、搜尋、更新 plugin",
      "version": "1.0.0",
      "keywords": ["marketplace", "management"],
      "author": {
        "name": "Nero",
        "email": "nero_xu@cmoney.com.tw"
      }
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
