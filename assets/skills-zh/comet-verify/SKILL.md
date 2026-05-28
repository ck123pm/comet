---
name: comet-verify
description: "Comet 阶段 4：验证与收尾。用 /comet-verify 调用。验证实现符合设计，并处理开发分支。"
---

# Comet 阶段 4：验证与收尾（Verify）

## 前置条件

- 代码已提交（阶段 3 完成）
- tasks.md 全部任务已完成

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
bash "$COMET_STATE" check <change-name> verify
```

如果存在 `.harness/`，立刻生成当前阶段的 harness pack，再做规模评估或验证：

```bash
bash "$COMET_HARNESS" <change-name> verify --write
```

这会写出：
- `openspec/changes/<name>/.comet/handoff/verify-harness-context.md`
- `openspec/changes/<name>/.comet/handoff/verify-harness-context.json`

验证通过后继续 Step 1。验证失败时脚本会输出具体失败原因。

### 1. 改动规模评估

执行规模评估：

```bash
bash "$COMET_STATE" scale <change-name>
```

脚本自动统计任务数、增量规格数、变更文件数，判断使用 light 或 full 验证模式，并设置 verify_mode 字段。

### 1b. 验证失败决策（阻塞点）

验证不通过时必须暂停并等待用户决定修复或接受偏差。不得自动运行 `bash "$COMET_STATE" transition <change-name> verify-fail`，也不得自动调用 `/comet-build`。

暂停时必须列出：
- 失败项
- 是否属于 CRITICAL（构建失败、测试失败、安全问题、核心验收场景失败）
- 推荐处理方式

用户选择后按以下方式继续：
- **全部修复**：运行 `bash "$COMET_STATE" transition <change-name> verify-fail`，然后调用 `/comet-build`
- **逐项处理**：**CRITICAL 失败项必须修复**；非 CRITICAL 失败项可选择接受偏差，但**不允许跳过修复直接全部接受**

### 2a. 轻量验证（小改动）

当规模评估结果为"小"时，跳过 `openspec-verify-change`，直接执行以下检查：

0. 如果存在，先读取 `openspec/changes/<name>/.comet/handoff/verify-harness-context.md`
1. tasks.md 全部任务已完成 `[x]`
2. 改动文件与 tasks.md 描述一致
3. 构建通过
4. 相关测试通过
5. 无明显安全问题

### 2b. 完整验证（大改动）

当规模评估结果为"大"时：

**立即执行：** 使用 Skill 工具加载 `openspec-verify-change` 技能。禁止跳过此步骤。

技能加载后，先读取 `openspec/changes/<name>/.comet/handoff/verify-harness-context.md`，再按其上下文和技能指引验证。检查项：
1. tasks.md 全部任务已完成
2. 实现符合 `openspec/changes/<name>/design.md` 高层设计决策
3. 实现符合 Design Doc
4. 能力规格场景全部通过
5. proposal.md 目标已满足
6. delta spec 与 design doc 无矛盾
7. `docs/superpowers/specs/` 关联的设计文档可定位

**Spec 漂移处理**（用户决策点）：
- 若发现矛盾，**必须暂停并等待用户选择处理方式**
- 选项 A：在 design doc 追加 "Implementation Divergence" 节。选项 A 属于 verify 阶段允许产物
- 选项 B：**用户选择 B 后，运行 `bash "$COMET_STATE" transition <change-name> verify-fail`，然后调用 `/comet-build`**
- 选项 C：确认偏差可接受，继续验证

### 3. 收尾（Superpowers）

**立即执行：** 使用 Skill 工具加载 `superpowers:finishing-a-development-branch` 技能。禁止跳过此步骤。

这是用户决策点。必须暂停并等待用户选择分支处理方式。只有在用户完成选择且对应操作完成后，才允许写入 `branch_status: handled`。

### 4. 记录验证证据

```bash
mkdir -p docs/superpowers/reports
bash "$COMET_STATE" set <change-name> verification_report docs/superpowers/reports/YYYY-MM-DD-<change-name>-verify.md
bash "$COMET_STATE" set <change-name> branch_status handled
```

## 退出条件

- 验证报告通过
- 分支已处理
- **阶段守卫**：运行 `bash "$COMET_GUARD" <change-name> verify --apply`

```bash
bash "$COMET_GUARD" <change-name> verify --apply
```
