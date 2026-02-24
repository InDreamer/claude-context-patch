# claude-context-patch

给 Claude Code 打一个“增大上下文 + 延后自动压缩”的补丁。目标默认值：

- Context window: `272000`
- Effective window: `258400`（95%）
- Auto-compact threshold: `244800`（90% of 272000）

> 说明：部分新版本构建会把阈值按「effective window 的 90%」计算，日志里会显示 `232560`，这是构建差异，不是脚本没生效。

## 30 秒上手

### 1) 一键打补丁

```bash
bash scripts/patch_claude_context_272k.sh
```

如果要指定 Claude 二进制路径：

```bash
bash scripts/patch_claude_context_272k.sh /opt/homebrew/Caskroom/claude-code/<version>/claude
```

### 2) 验证

```bash
claude -p --model sonnet --debug-file /tmp/claude_debug.log "ping"
rg "autocompact:" /tmp/claude_debug.log
```

预期看到：
- `effectiveWindow=258400`
- `threshold=244800` 或 `threshold=232560`（见上方说明）

### 3) 回滚

脚本会在执行时自动备份原文件，并打印回滚命令，直接复制执行即可。

---

## 给 Codex 当 Skill 用

把这个仓库放进你的 skills 目录即可：

```bash
mkdir -p ~/.codex/skills
cp -R /path/to/claude-context-patch ~/.codex/skills/claude-context-patch
```

然后在 Codex 里输入：

```text
$claude-context-patch patch
```

---

## 脚本做了什么

- 自动识别目标是 `cli.js` 还是原生 Mach-O 二进制
- 打补丁前先做带时间戳的备份
- 原生二进制使用等长替换，避免破坏文件结构
- 保留 `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` 逻辑
- macOS 下补丁后二进制会自动 ad-hoc 重签名

## 已知限制

- Claude Code 每个版本混淆符号都可能变；新版本若提示 `unknown build`，需要补 matcher。
- 这是非官方补丁，升级 Claude Code 后通常要重新打一次。

## 免责声明

你在修改第三方二进制。请自行评估风险并保留备份。
