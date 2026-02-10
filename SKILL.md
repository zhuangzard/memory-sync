---
name: memory-sync
description: 三层自动化记忆同步系统 — 每日同步、每周复利、白天微同步，实现OpenClaw Agent"永不失忆"。灵感来自Cali Castle的踩坑教程。
---

# Memory Sync — 三层自动化记忆架构

让你的OpenClaw Agent永不失忆。通过三层cron自动化 + QMD语义搜索，实现记忆的自动捕获、蒸馏和检索。

## 架构概览

```
┌─────────────────────────────────────────────┐
│              MEMORY.md (精华)                │ ← 每次session自动注入
│         精简的长期记忆 cheat sheet            │
├─────────────────────────────────────────────┤
│                                             │
│  Layer 1: Daily Sync (每晚)                 │ ← 全量蒸馏当天sessions
│  Layer 2: Weekly Compound (每周日)           │ ← 知识复利，更新MEMORY.md
│  Layer 3: Micro-Sync (白天每3h)             │ ← 安全网，防止遗漏
│                                             │
├─────────────────────────────────────────────┤
│  memory/YYYY-MM-DD.md  (每日日志)            │ ← 原始素材，按需检索
├─────────────────────────────────────────────┤
│  QMD Vector Search (语义搜索)                │ ← BM25 + Vector + Reranking
└─────────────────────────────────────────────┘
```

## 前置条件

- OpenClaw 运行中，已配置 cron 支持
- QMD memory backend 已启用（`memory.backend: "qmd"`）
- workspace 下有 `MEMORY.md` 和 `memory/` 目录

## 快速安装

```bash
# 自动设置三个cron job
bash {baseDir}/scripts/setup.sh

# 指定时区（默认 America/New_York）
bash {baseDir}/scripts/setup.sh --tz "Asia/Shanghai"

# 指定模型（默认 anthropic/claude-sonnet-4-5）
bash {baseDir}/scripts/setup.sh --model "anthropic/claude-sonnet-4-5"
```

## 三层详解

### Layer 1: Daily Context Sync — 每日蒸馏

**触发**: 每晚 23:00
**作用**: 拉取当天所有session对话，蒸馏成结构化日志

流程:
1. `sessions_list` 获取当天活跃sessions
2. `sessions_history` 读取每个session完整对话
3. 蒸馏为 `memory/YYYY-MM-DD.md`（结构化markdown）
4. 执行 `qmd update && qmd embed` 更新索引

日志格式:
```markdown
# YYYY-MM-DD Daily Log

## 重要决策
- ...

## 待办事项
- [ ] ...

## 关键对话
- ...

## 技术笔记
- ...

## 情绪/状态
- ...
```

### Layer 2: Weekly Memory Compound — 每周知识复利

**触发**: 每周日 22:00
**作用**: 读取本周7天日志，蒸馏更新MEMORY.md

流程:
1. 读取本周所有 `memory/YYYY-MM-DD.md`
2. 提取新偏好、决策模式、项目状态变化
3. 更新 MEMORY.md，剪枝过时信息
4. 执行 `qmd update && qmd embed`

### Layer 3: Hourly Micro-Sync — 白天安全网

**触发**: 白天每3小时 (10:00, 13:00, 16:00, 19:00, 22:00)
**作用**: 轻量检查，防止重要信息遗漏

流程:
1. 检查最近3小时是否有有意义的活动
2. 有 → append简要摘要到当天日志
3. 没有 → 静默退出，不发通知

## AGENTS.md 推荐补丁

在你的 AGENTS.md 中添加以下规则，强制agent用语义搜索而不是暴力读文件:

```markdown
## Memory Retrieval (MANDATORY)
Never read MEMORY.md or memory/*.md in full for lookups. Use memory_search/qmd:
1. memory_search("<question>") — 语义搜索
2. memory_get(<file>, from=<line>, lines=20) — 只拉需要的片段
3. Only if search returns nothing: fall back to reading files
每次写入memory文件后，确保qmd索引更新。
```

## Cron Job JSON（手动添加参考）

详见 `templates/` 目录下的prompt模板。

### Daily Sync
```json
{
  "name": "Memory: Daily Sync (11 PM)",
  "schedule": { "kind": "cron", "expr": "0 23 * * *", "tz": "YOUR_TZ" },
  "payload": {
    "kind": "agentTurn",
    "message": "见 templates/daily-sync-prompt.md",
    "model": "anthropic/claude-sonnet-4-5"
  },
  "sessionTarget": "isolated"
}
```

### Weekly Compound
```json
{
  "name": "Memory: Weekly Compound (Sunday 10 PM)",
  "schedule": { "kind": "cron", "expr": "0 22 * * 0", "tz": "YOUR_TZ" },
  "payload": {
    "kind": "agentTurn",
    "message": "见 templates/weekly-compound-prompt.md",
    "model": "anthropic/claude-sonnet-4-5"
  },
  "sessionTarget": "isolated"
}
```

### Micro-Sync
```json
{
  "name": "Memory: Micro-Sync (Every 3h)",
  "schedule": { "kind": "cron", "expr": "0 10,13,16,19,22 * * *", "tz": "YOUR_TZ" },
  "payload": {
    "kind": "agentTurn",
    "message": "见 templates/micro-sync-prompt.md",
    "model": "anthropic/claude-sonnet-4-5"
  },
  "sessionTarget": "isolated"
}
```

## 设计理念

> Memory infrastructure 比 agent intelligence 重要得多。一个有完善记忆系统的普通模型，比一个失忆的顶级模型有用得多。
> — Cali Castle

### 为什么分三层？
- **不能把所有东西塞进context window** — 那是把整个图书馆搬进考场
- **带一张精心整理的cheat sheet (MEMORY.md)** — 需要查资料时用语义搜索翻书
- **每日日志是原始素材** — MEMORY.md是蒸馏后的精华

### 为什么用isolated session？
- 记忆同步不会污染主session
- 用Sonnet而不是Opus，蒸馏任务不需要最强推理，省钱

## 致谢

- [Cali Castle](https://x.com/calicastle) — 三层架构原创设计
- [Eric Osiu](https://x.com/ericosiu) — Agent memory infrastructure 灵感
