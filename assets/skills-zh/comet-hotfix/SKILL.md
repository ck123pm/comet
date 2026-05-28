---
name: comet-hotfix
description: "Comet 预设路径：Bug fix / 热修复。跳过 brainstorming，直接 open → build → verify → archive。"
---

# Comet 预设路径：Hotfix

适用于修复现有行为问题、不引入新 capability 的快速流程。

## 开始前

```bash
COMET_ENV="${COMET_ENV:-$(find . "$HOME"/.*/skills "$HOME/.config" "$HOME/.gemini" -path '*/comet/scripts/comet-env.sh' -type f -print -quit 2>/dev/null)}"
if [ -z "$COMET_ENV" ]; then
  echo "ERROR: comet-env.sh not found. Ensure the comet skill is installed." >&2
  return 1
fi
. "$COMET_ENV"
```

如果项目存在 `.harness/`，在开始 hotfix 流程前先加载：
- 先读 `.harness/README.md`
- 再参考 `.harness/index/routing.md` 和 `.harness/index/priority.md`
- 核心规则是**按需注入**相关 `.harness` 文件

### 1. Quick Open

**立即执行：** 使用 Skill 工具加载 `openspec-new-change`。

初始化状态：

```bash
bash "$COMET_STATE" init <name> hotfix
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

### 2. Direct Build

使用 hotfix 默认值：`build_mode: direct`。跳过 `superpowers:brainstorming` 和 `superpowers:writing-plans`（除非任务 > 3 个；若超过 3 个任务，转入 `/comet-build` 的计划与执行方式选择）。

如果存在 `.harness/`，在动手实现前先生成 build 阶段 harness pack：

```bash
bash "$COMET_HARNESS" <change-name> build --write
```

按 `tasks.md` 逐项执行修复。

### 3. Verify

复用 `/comet-verify`，由 comet-verify 的规模评估决定使用轻量还是完整验证。

如果存在 `.harness/`，在验证前先生成 verify 阶段 harness pack：

```bash
bash "$COMET_HARNESS" <change-name> verify --write
```

**立即执行：** 使用 Skill 工具加载 `comet-verify`。

### 4. Archive

**立即执行：** 使用 Skill 工具加载 `comet-archive`。

## 连续执行模式

<IMPORTANT>
hotfix 是一次性连续执行流程，但以下场景必须暂停：

1. 满足升级条件时必须暂停并等待用户明确确认升级为完整 `/comet` 流程
2. 任务超过 3 个转入 `/comet-build` 时的工作区隔离和执行方式选择
3. 验证阶段（comet-verify）的验证失败决策和分支处理决策

升级相关场景一律按升级条件阻塞确认处理。
</IMPORTANT>

## 升级条件

满足任一条件即升级：
- 改动涉及 3+ 文件
- 需要架构调整
- 需要接口变更
- 需要新增 public API

满足升级条件时必须暂停并等待用户明确确认升级为完整 `/comet` 流程。不得直接进入 `/comet-design`，不得自动补充 Design Doc。

用户确认升级后：

```bash
bash "$COMET_STATE" set <name> workflow full
```

然后**立即使用 Skill 工具加载 `comet-design` skill**，回到完整流程。
