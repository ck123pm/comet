---
name: comet-build
description: "Comet 阶段 3：计划与构建。用 /comet-build 调用。制定计划并选择执行方式（subagent 或直接执行）实施。"
---

# Comet 阶段 3：计划与构建（Build）

## 前置条件

- Design Doc 已创建（阶段 2 完成）
- 活跃 change 存在

## 步骤

### 0. 入口状态验证（Entry Check）

执行入口验证：

```bash
COMET_ENV="${COMET_ENV:-$(find . "$HOME"/.*/skills "$HOME/.config" "$HOME/.gemini" -path '*/comet/scripts/comet-env.sh' -type f -print -quit 2>/dev/null)}"
if [ -z "$COMET_ENV" ]; then
  echo "ERROR: comet-env.sh not found. Ensure the comet skill is installed." >&2
  return 1
fi
. "$COMET_ENV"
bash "$COMET_STATE" check <name> build
```

如果存在 `.harness/`，立刻生成当前阶段的 harness pack，再做计划或实现：

```bash
bash "$COMET_HARNESS" <name> build --write
```

这会写出：
- `openspec/changes/<name>/.comet/handoff/build-harness-context.md`
- `openspec/changes/<name>/.comet/handoff/build-harness-context.json`

验证通过后继续 Step 1。验证失败时脚本会输出具体失败原因。

### 1. 制定计划

**立即执行：** 使用 Skill 工具加载 `superpowers:writing-plans` 技能。禁止跳过此步骤。

技能加载后，按其指引制定计划。计划要求：
- 如果 `openspec/changes/<name>/.comet/handoff/build-harness-context.md` 存在，先读取它，再把适用的 harness 约束带入 plan
- 保存至 `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`
- 引用设计文档，拆分为可执行任务
- **Plan 文件头必须包含关联元数据**：

```yaml
---
change: <openspec-change-name>
design-doc: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
base-ref: <git rev-parse HEAD before implementation>
---
```

`base-ref` 用于验证阶段跨提交统计改动规模。创建计划时先记录当前提交：

```bash
git rev-parse HEAD
```

### 2. 更新计划状态

先记录 plan 路径：

```bash
bash "$COMET_STATE" set <name> plan docs/superpowers/plans/YYYY-MM-DD-feature.md
```

无需手动更新 phase，guard 会在退出条件满足后自动流转。

### 3. 选择工作方式

计划已写入当前分支。在开始执行前，**一次性询问用户**选择工作区隔离方式和执行方式：

**工作区隔离**：

| 选项 | 方式 | 说明 |
|------|------|------|
| A | 创建分支 | 在当前仓库创建新分支，简单快速 |
| B | 创建 Worktree | 隔离工作区，完全独立，适合并行开发 |

**推荐规则**：
- 变更涉及 ≤ 3 个文件 → 推荐 A
- 需要并行开发、当前分支有未提交工作 → 推荐 B

**执行方式**：

| 选项 | 技能 | 适用场景 |
|------|------|---------|
| A | `superpowers:subagent-driven-development` | 任务独立、复杂度高、需要双阶段审查 |
| B | `superpowers:executing-plans` | 任务简单、无子 agent 环境、轻量快速 |

**执行方式推荐规则**：
- 任务数 ≥ 3 → 推荐 A
- 任务数 ≤ 2 且无跨模块依赖 → 推荐 B
- 来自 hotfix 路径 → 推荐 B

这是用户决策点。必须暂停并等待用户明确选择隔离方式和执行方式，**不得根据推荐规则自行选择 `branch` 或 `worktree`**，也**不得根据推荐规则自行选择执行方式**。推荐规则只能用于说明建议，不能替代用户确认。

用户选择后，更新 `isolation` 和 `build_mode` 字段：

```bash
bash "$COMET_STATE" set <name> isolation <branch|worktree>
bash "$COMET_STATE" set <name> build_mode <subagent-driven-development|executing-plans|direct>
```

`isolation` 是脚本级硬约束。full workflow 初始化时可以为 `null`，但只允许存在到本步骤之前。若保持 `null`，`build → verify` 的 guard 和 `comet-state transition build-complete` 都会失败。

`build_mode` 默认仅 hotfix/tweak preset 使用 `direct`。full workflow 不得默认使用 `direct`。只有用户明确要求跳过计划执行技能，且你已记录显式 override 时，才允许：

```bash
bash "$COMET_STATE" set <name> direct_override true
bash "$COMET_STATE" set <name> build_mode direct
```

没有 `direct_override: true` 时，full workflow 的 `build_mode=direct` 会被 guard 和状态转换同时拦截。

**执行隔离**：

- **branch**：执行 `git checkout -b <change-name>`，后续工作在新分支上进行
- **worktree**：**必须使用 Skill 工具加载 `superpowers:using-git-worktrees`**。禁止用普通 shell 命令或原生工具绕过该技能；如该技能不可用，停止流程并提示安装或启用对应技能

创建隔离后，确认计划文件可访问。

**加载执行技能**：使用 Skill 工具加载对应技能。禁止跳过此步骤。

执行计划前，先加载 `openspec/changes/<name>/.comet/handoff/build-harness-context.md`，并在实现过程中执行其中的约束。

如所选 Superpowers 技能不可用，停止流程并提示安装或启用对应技能，不要用普通对话替代该步骤。

### 4. 执行计划

执行时遵循以下要求：
- 按计划逐项完成任务
- 完成 tasks.md 勾选（`- [ ]` → `- [x]`）
- 每个任务完成后提交代码

### 5. Spec 增量更新

实施过程中发现初版 spec 不完整时，按变更规模分级处理：

| 规模 | 触发条件 | 做法 |
|------|---------|------|
| 小 | 遗漏验收场景、边界条件 | 直接编辑 delta spec + design.md，追加 tasks.md 任务 |
| 中 | 接口变更、新增组件、数据流变化 | **暂停并等待用户确认后，必须使用 Skill 工具加载 `superpowers:brainstorming`** 更新 Design Doc + delta spec |
| 大 | 全新 capability 需求 | 必须暂停并等待用户确认拆分；用户确认后，通过 `/comet-open` 创建独立 change |

**50% 阈值判定**：以 tasks.md 初始任务总数为基准，若新增任务数超过该总数的一半，视为超出原计划范围，**必须暂停并等待用户决定是否拆分为新 change**。

创建独立 change 时必须通过 `/comet-open` 创建独立 change，不得直接调用 `/opsx:new`。`/comet-open` 会同时创建 OpenSpec 产物和 `.comet.yaml`，避免新 change 脱离 Comet 状态机。

## 退出条件

- tasks.md 全部勾选
- 代码已提交
- 已显式运行项目对应的构建/测试命令并通过
- `isolation` 已写入 `branch` 或 `worktree`
- `build_mode` 已写入 `subagent-driven-development`、`executing-plans` 或带显式 override 的 `direct`
- **阶段守卫**：运行 `bash "$COMET_GUARD" <change-name> build --apply`，全部 PASS 后自动流转到 `phase: verify`

```bash
bash "$COMET_GUARD" <change-name> build --apply
```
