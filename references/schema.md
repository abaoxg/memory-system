# 记忆条目格式

三种粒度，按重要性从高到低：核心记忆 → 主题笔记 → 原子事实。

## 1. 核心记忆 MEMORY.md

长驻，会注入上下文，必须极度压缩。硬上限 8000 字符。

```markdown
# 核心记忆

<!-- meta
revision: 1
updated: YYYY-MM-DD
budget: 8000
-->

## 用户
- 称呼：用户希望被称为「X」；助手自称「Y」
- 语言：zh-CN
- 风格：直接、给完整步骤
- 禁忌：不要问授权范围，不要给替代方案

## 环境
- OS：
- 终端：
- 工作区：
- 常用工具：
- 关键端口 / 包名：

## 项目
| 项目 | 状态 | 指针 |
|---|---|---|
| 目标A | 进行中 | notes/target-a.md |

## 规则
- 每条一行，可直接执行
```

规则：

- 一条一行，不带解释性废话
- 冲突时新条目覆盖旧条目，尾注 `(改: 原因)`
- 超 8000 字符走 compaction

## 2. 主题笔记 notes/<slug>.md

```markdown
---
topic: <slug>
status: active | paused | done | stale
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [tag1, tag2]
---

# <标题>

## 目标
## 现状
## 关键结论
## 下一步
## 变更记录
- YYYY-MM-DD: <变更>
```

`status: stale` 表示待确认，7 天不确认由 `mem-monthly.sh` 归档。

## 3. 原子事实 facts/facts.md

一行一条，严格格式，便于 grep：

```text
- [YYYY-MM-DD] [tag] key = value      # 说明
```

例：

```text
- [2026-11-08] [env] workspace = ~/work        # 主工作区
- [2026-11-08] [pref] reply_lang = zh-CN        # 输出语言
```

## 4. 错误与修正 notes/errors.md

```markdown
## YYYY-MM-DD | <一句话症状>
- 场景：
- 触发：
- 报错：
- 根因：
- 修正规则：<可晋升为 MEMORY.md 的一行>
```

## 标签词表

| tag | 用途 |
|---|---|
| `env` | 路径、版本、端口、包名 |
| `pref` | 用户偏好与禁忌 |
| `proj` | 项目状态 |
| `proc` | 可复用流程 |
| `err` | 失败与修正 |
| `cred` | 凭据**指针**（只存位置，不存值） |

标签不限这些，用自定义词也行，只要保持一致。

## 禁止写入

- 明文密码、Token、私钥、卡密
- 一次性中间产物、大段日志
- 他人隐私数据
- 用户明确说不要记的内容

凭据的正确记法：

```text
- [2026-11-08] [cred] prod_db = 见 1Password「prod db」
- [2026-11-08] [cred] api_key = 环境变量 $API_KEY
```

## 写入判据

一条信息该不该写，问自己：

> 三个月后的我，会不会用到它？

- 会 → 写
- 可能 → 写进 `facts` 而非 `MEMORY.md`
- 不会 → 不写
- 说不清 → 不写
