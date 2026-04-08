# CMoney AILab Plugin Marketplace

CMoney AILab 團隊共用的 Claude Code Plugin Marketplace。

## 首次安裝（每人一次）

### 前置條件

- 已加入 `cm-ailab-cc-plugins` GitHub Org（請聯繫管理員取得邀請）
- 已安裝 `gh` CLI 並登入（`gh auth login`）

### 安裝步驟

在 Claude Code 中執行：

```
/plugin marketplace add cm-ailab-cc-plugins/marketplace
/plugin install mp@cm-ailab-cc-plugins
```

安裝完成後執行 `/mp:setup` 驗證環境是否正常。

## 可用命令

安裝 `mp` plugin 後即可使用：

| 命令 | 功能 |
|------|------|
| `/mp:setup` | 環境檢查與設定 |
| `/mp:validate` | 本地驗證 plugin 結構 |
| `/mp:list` | 列出所有可用 plugin |
| `/mp:search <keyword>` | 搜尋 plugin |
| `/mp:my-plugins` | 列出自己發佈的 plugin |
| `/mp:publish` | 發佈新 plugin |
| `/mp:update <name>` | 更新 plugin 版本 |
| `/mp:deprecate <name>` | 標記 plugin 為棄用 |

## 發佈 Plugin

```
/mp:publish
```

Claude Code 會引導你完成命名、描述、結構建立、推送和 PR 建立。

## 專案級自動配置（可選）

在團隊專案的 `.claude/settings.json` 加入以下設定，新成員 clone 專案後自動取得 marketplace：

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
