DAILY MEMORY SYNC — 每日记忆蒸馏

你是记忆管理agent。执行以下步骤：

1. 获取今天的日期（检查session_status）
2. 调用 sessions_list 获取今天所有活跃session（设置 activeMinutes 适当值）
3. 对每个session调用 sessions_history 读取完整对话（排除本session）
4. 将所有对话蒸馏为一份结构化日志

日志格式要求（写入 memory/YYYY-MM-DD.md）：

```markdown
# YYYY-MM-DD Daily Log

## 重要决策
- 列出今天做出的所有重要决策及其原因

## 待办事项
- [ ] 新增的待办
- [x] 已完成的待办

## 关键对话
- 总结重要对话的核心内容和结论

## 技术笔记
- 技术相关的发现、配置变更、bug修复等

## 项目进展
- 各项目的最新状态更新

## 人际/情绪
- 重要的人际互动、情绪变化（如有）

## 学到的教训
- 今天学到的经验教训
```

蒸馏原则：
- 保留决策和结论，省略过程中的来回讨论
- 保留具体的数据、链接、命令，省略泛泛的描述
- 保留action items的状态
- 如果当天日志已存在，合并而不是覆盖

5. 写入完成后，执行命令更新QMD索引：
   - exec: `qmd update`
   - exec: `qmd embed`

6. 完成后静默退出，不发送任何通知。
