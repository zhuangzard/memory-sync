# 🧠 Memory Sync — OpenClaw 三层记忆系统

让你的 OpenClaw Agent 永不失忆。自动化记忆捕获、蒸馏和语义检索。

## 功能

- **三层自动同步**：每日全量蒸馏 + 每周知识复利 + 每3小时微同步
- **QMD 语义搜索**：本地 BM25 + 向量搜索，零API成本
- **CRUD 去重**：借鉴 OpenViking 范式，避免重复写入
- **6分类长期记忆**：Profile / Preferences / Entities / Events / Cases / Patterns
- **L0 摘要头**：知识文件开头快速过滤

## 架构

```
MEMORY.md (精华，每次session注入)
├── Layer 1: Daily Sync    — 每晚23:00，全量蒸馏当天对话
├── Layer 2: Weekly Compound — 每周日22:00，知识复利+清理
├── Layer 3: Micro-Sync    — 每3小时，安全网+检查点
├── memory/YYYY-MM-DD.md   — 每日原始日志
└── QMD Vector Search      — 本地语义搜索（BM25 + Vector）
```

---

## 从零安装（完整步骤）

### 第1步：确保 OpenClaw 已运行

```bash
# 检查OpenClaw状态
openclaw status

# 如果未安装
npm install -g openclaw
openclaw onboard
```

### 第2步：安装 QMD（本地语义搜索）

QMD 是本地搜索引擎，**不需要任何 API key**（不需要 OpenAI）。

```bash
# macOS
brew install tobi/tap/qmd

# Linux (VPS/Docker)
# 方法1: 从GitHub Releases下载
QMD_VERSION="0.3.0"  # 检查最新版本: https://github.com/tobi/qmd/releases
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac
curl -L "https://github.com/tobi/qmd/releases/download/v${QMD_VERSION}/qmd_${QMD_VERSION}_linux_${ARCH}.tar.gz" | tar xz
sudo mv qmd /usr/local/bin/

# 方法2: 如果有Go环境
go install github.com/tobi/qmd@latest

# 验证安装
qmd --version
```

### 第3步：配置 OpenClaw 使用 QMD 后端

编辑 OpenClaw 配置文件（通常在 `~/.openclaw/openclaw.json`）：

```json5
{
  "memory": {
    "backend": "qmd",
    "citations": "auto",
    "qmd": {
      "includeDefaultMemory": true,
      "update": {
        "interval": "5m",
        "debounceMs": 15000,
        "onBoot": true
      },
      "limits": {
        "maxResults": 6,
        "timeoutMs": 4000
      }
    }
  }
}
```

或者用 CLI 直接patch：

```bash
# 如果你有 openclaw CLI 权限
# 在OpenClaw聊天中让agent执行：
# gateway config.patch {"memory":{"backend":"qmd","qmd":{"includeDefaultMemory":true,"update":{"interval":"5m","onBoot":true}}}}
```

**重要**：配置后重启 OpenClaw：
```bash
openclaw gateway restart
```

### 第4步：初始化记忆文件

```bash
cd ~/.openclaw/workspace  # 或你的workspace路径

# 创建记忆目录
mkdir -p memory

# 创建MEMORY.md（如果不存在）
cat > MEMORY.md << 'EOF'
# MEMORY.md - 长期记忆

## 👤 Profile（身份档案）
## ⚙️ Preferences（偏好与规则）
## 🏢 Entities（关键实体）
## 📅 Events（重要事件）
## 📋 Cases（决策案例）
## 🧠 Patterns（经验规律）
EOF

# 初始化QMD索引
qmd update
qmd embed
```

### 第5步：安装 Memory Sync Skill

```bash
cd ~/.openclaw/workspace/skills

# 方法1: 克隆仓库
git clone https://github.com/zhuangzard/memory-sync.git

# 方法2: 手动下载
mkdir -p memory-sync
# 下载 SKILL.md, scripts/, templates/ 到此目录
```

### 第6步：设置 Cron 自动同步

```bash
# 自动设置三个cron job（推荐）
cd ~/.openclaw/workspace/skills/memory-sync
bash scripts/setup.sh

# 自定义时区（VPS常用UTC或亚洲时区）
bash scripts/setup.sh --tz "Asia/Shanghai"

# 自定义模型
bash scripts/setup.sh --tz "UTC" --model "deepseek/deepseek-chat"
```

**或者手动在OpenClaw中设置cron**（让agent执行）：

```
帮我设置memory-sync的三层cron：
1. Daily Sync: 每天23:00
2. Weekly Compound: 每周日22:00
3. Micro-Sync: 每3小时
参考 skills/memory-sync/SKILL.md 中的payload
```

### 第7步：验证

```bash
# 检查QMD索引
cd ~/.openclaw/workspace
qmd search "测试搜索"

# 检查cron是否设置成功（在OpenClaw中）
# 发送: /cron list
# 应该看到3个memory相关的job

# 手动触发一次micro-sync测试
# 在OpenClaw中: /cron run <micro-sync-job-id>
```

---

## 配置说明

### 时区
- 美东: `America/New_York`
- 北京: `Asia/Shanghai`
- UTC: `UTC`

### 模型选择
- 推荐: `anthropic/claude-sonnet-4-5`（质量好）
- 省钱: `deepseek/deepseek-chat`（免费）

### QMD vs OpenAI Embeddings

| 特性 | QMD（推荐） | OpenAI Embeddings |
|------|-------------|-------------------|
| 成本 | **免费** | 需要API key |
| 速度 | 本地，毫秒级 | 网络请求 |
| 隐私 | 数据不出机器 | 发送到OpenAI |
| 质量 | BM25+向量混合 | 纯向量 |
| 安装 | 需要装qmd | 需要OpenAI key |

---

## Docker / VPS 快速部署

如果你的 OpenClaw 跑在 Docker 中（如 Kevin 的环境）：

```bash
# 进入容器
docker exec -it <container_name> bash

# 安装QMD
# 在Dockerfile中添加，或直接在容器内：
curl -L "https://github.com/tobi/qmd/releases/download/v0.3.0/qmd_0.3.0_linux_amd64.tar.gz" | tar xz
mv qmd /usr/local/bin/

# 配置OpenClaw使用QMD
# 编辑 /path/to/openclaw.json，添加 memory.backend: "qmd"

# 安装skill
cd /path/to/workspace/skills
git clone https://github.com/zhuangzard/memory-sync.git

# 运行setup
cd memory-sync
bash scripts/setup.sh --tz "Asia/Shanghai"

# 重启OpenClaw
openclaw gateway restart
```

---

## 常见问题

### Q: qmd: command not found
安装QMD后确保在PATH中。Linux上可以 `sudo mv qmd /usr/local/bin/`。

### Q: 记忆搜索没结果
运行 `qmd update && qmd embed` 重建索引。确保 MEMORY.md 和 memory/ 不为空。

### Q: cron job报错 "model not allowed"
检查模型名是否正确，换一个可用的模型（如 `deepseek/deepseek-chat`）。

### Q: 之前用OpenAI embeddings，想切换到QMD
只需修改config中 `memory.backend` 为 `"qmd"`，重启即可。不需要迁移数据。

---

## 文件结构

```
memory-sync/
├── README.md          # 本文件
├── SKILL.md           # Skill规格说明
├── scripts/
│   └── setup.sh       # 自动设置cron
└── templates/
    ├── daily.txt      # Daily Sync payload模板
    ├── weekly.txt     # Weekly Compound payload模板
    └── micro.txt      # Micro-Sync payload模板
```

## 版本

- **v2.1** — 借鉴 OpenViking：L0摘要头、6分类记忆、CRUD去重
- **v2.0** — 三层架构 + 检查点提取 + 决策日志
- **v1.0** — 基础每日同步

## License

MIT
