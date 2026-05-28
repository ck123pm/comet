---
name: comet-tweak
description: "Comet 预设路径：非 bug 小改动。跳过 brainstorming 和完整计划，直接 open → lightweight build → light verify → archive。"
---

# Comet 预设路径：Tweak

适用于文案、配置、文档或 prompt 的局部优化。

## 开始前

```bash
COMET_ENV="${COMET_ENV:-$(find . "$HOME"/.*/skills "$HOME/.config" "$HOME/.gemini" -path '*/comet/scripts/comet-env.sh' -type f -print -quit 2>/dev/null)}"
if [ -z "$COMET_ENV" ]; then
  echo "ERROR: comet-env.sh not found. Ensure the comet skill is installed." >&2
  return 1
fi
. "$COMET_ENV"
```

如果项目存在 `.harness/`，在开始 tweak 流程前先加载：
- 先读 `.harness/README.md`
- 再参考 `.harness/index/routing.md` 和 `.harness/index/priority.md`
- 核心规则是**按需注入**相关 `.harness` 文件

### 1. Quick Open

**立即执行：** 使用 Skill 工具加载 `openspec-new-change`。

```bash
bash "$COMET_STATE" init <name> tweak
```

如果存在 `.harness/`，现在生成 open 阶段 harness pack：

```bash
bash "$COMET_HARNESS" <name> open --write
```

然后验证并流转：

```bash
bash "$COMET_STATE" check <name> open
bash "$COMET_GUARD" <change-name> open --apply
```

### 2. Lightweight Build

使用 tweak 默认值：`build_mode: direct`。跳过 `superpowers:brainstorming` 和 `superpowers:writing-plans`。

如果存在 `.harness/`，在动手实现前先生成 build 阶段 harness pack：

```bash
bash "$COMET_HARNESS" <change-name> build --write
```

按 `tasks.md` 逐项执行改动。

### 3. Lightweight Verify

复用 `/comet-verify`。Tweak 必须保持轻量验证条件：≤ 3 个任务、≤ 4 个文件、无 delta spec、无新 capability。

如果存在 `.harness/`，在验证前先生成 verify 阶段 harness pack：

```bash
bash "$COMET_HARNESS" <change-name> verify --write
```

**立即执行：** 使用 Skill 工具加载 `comet-verify`。

### 4. Archive

**立即执行：** 使用 Skill 工具加载 `comet-archive`。

## 连续执行模式

<IMPORTANT>
tweak 是一次性连续执行流程，但以下场景必须暂停：

1. 满足升级条件时必须暂停并等待用户明确确认升级为完整 `/comet` 流程
2. 验证阶段（comet-verify）的验证失败决策和分支处理决策

升级相关场景一律按升级条件阻塞确认处理。
</IMPORTANT>

## 升级条件

满足任一条件即升级：
- 改动涉及 5+ 文件
- 需要跨模块协调
- 需要 5+ 新测试
- 需要新增 capability
- 需要 delta spec

满足升级条件时必须暂停并等待用户明确确认升级为完整 `/comet` 流程。不得直接进入 `/comet-design`，不得自动补充 Design Doc。

用户确认升级后：

```bash
bash "$COMET_STATE" set <name> workflow full
```

然后**立即使用 Skill 工具加载 `comet-design` skill**，回到完整流程。
