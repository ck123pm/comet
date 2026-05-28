---
name: comet-open
description: "Comet 阶段 1：开启。用 /comet-open 调用。通过 OpenSpec 探索想法、创建 change 结构（proposal + design + tasks）。"
---

# Comet 阶段 1：开启（Open）

## 前置条件

- 没有活跃 change，或用户希望创建一个新 change

## `.harness` 上下文

如果项目存在 `.harness/` 目录，在探索想法或创建 change 之前先加载 `.harness` 上下文：

- 先读 `.harness/README.md`，理解项目知识体系、目录用途和推荐阅读路径
- 再结合 `.harness/README.md` 判断当前请求需要哪些 `.harness` 上下文文件
- 再参考 `.harness/index/routing.md` 和 `.harness/index/priority.md`，作为路由和优先级辅助依据
- 核心规则是 **按需注入** 相关 `.harness` 文件，不是只读 `MUST` 文件

即使是 `/comet` 在“没有活跃 change”时路由到这里，也不能跳过 `.harness` 检查和上下文判定。

## 步骤

### 1. 探索想法

**立即执行：** 使用 Skill 工具加载 `openspec-explore` 技能。禁止跳过这一步。

技能加载后，按其指引自由探索问题空间。

### 2. 创建 Change 结构 + 初始化状态

**立即执行：** 使用 Skill 工具加载 `openspec-new-change` 技能。若用户意图尚不明确、需要先形成 proposal，则改为加载 `openspec-propose`。禁止跳过这一步。

确认已创建以下产物：

```text
openspec/changes/<name>/
├── .openspec.yaml
├── .comet.yaml
├── proposal.md       # Why + What：问题、目标、范围
├── design.md         # How（高层）：架构决策、方案选型
└── tasks.md          # 任务清单（复选框）
```

创建 `.comet.yaml` 状态文件：

```bash
COMET_ENV="${COMET_ENV:-$(find . "$HOME"/.*/skills "$HOME/.config" "$HOME/.gemini" -path '*/comet/scripts/comet-env.sh' -type f -print -quit 2>/dev/null)}"
if [ -z "$COMET_ENV" ]; then
  echo "ERROR: comet-env.sh not found. Ensure the comet skill is installed." >&2
  return 1
fi
. "$COMET_ENV"

if [ -z "$COMET_STATE" ] || [ -z "$COMET_GUARD" ]; then
  echo "ERROR: Comet scripts not found. Ensure the comet skill is installed." >&2
  return 1
fi

bash "$COMET_STATE" init <name> full
```

### 3. 入口状态验证

验证状态机已被正确初始化：

```bash
bash "$COMET_STATE" check <name> open
```

验证通过后继续 Step 4。验证失败时脚本会输出具体失败原因。

### 4. 内容完整性检查

确认三个文档内容完整：

- **proposal.md**：问题背景、目标、范围、非目标
- **design.md**：高层架构决策、方案选型、数据流
- **tasks.md**：任务列表，每个任务都有明确描述

## 退出条件

- `proposal.md`、`design.md`、`tasks.md` 均已创建且内容完整
- **阶段守卫**：运行 `bash "$COMET_GUARD" <change-name> open --apply`，全部 PASS 后自动流转到下一阶段

退出前必须使用 `--apply`，否则 `.comet.yaml` 会停留在 `phase: open`，下一阶段入口检查会失败。

```bash
bash "$COMET_GUARD" <change-name> open --apply
```

完整流程会自动流转到 `phase: design`；hotfix/tweak preset 会自动流转到 `phase: build`。

## 自动流转

退出条件满足后，**无需等待用户再次输入**，直接执行下一阶段：

> **REQUIRED NEXT SKILL（完整流程）：** 调用 `comet-design` skill，进入深度设计阶段。
>
> hotfix/tweak preset 的后续流转由对应 preset skill 控制（phase 直接进入 build），不经过本节。
