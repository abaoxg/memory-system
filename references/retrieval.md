# 检索与注入策略

## 注入分层

上下文是稀缺资源。按层注入，越往下越省。

| 层 | 内容 | 何时注入 | 预算 |
|---|---|---|---|
| L0 | `INDEX.md` | 每轮固定 | < 2000 字符 |
| L1 | `MEMORY.md` | 每轮固定 | < 8000 字符 |
| L2 | `notes/<topic>.md` | 命中原任务关键词时 | 单个 < 6000 字符 |
| L3 | `facts/facts.md` 检索结果 | 需要具体数值时 | 取 top 20 行 |
| L4 | `archive/` | 仅点名历史时（`-a`） | 按需分页 |

## 命中判定

按优先级匹配，命中即停，不要全量加载：

1. 项目名 / 目标名 / 域名 / 包名
2. 专有名词（工具名、协议名、漏洞编号）
3. 标签（`-t` 参数）
4. 时间范围（`-r N`）

无命中 → 只带 L0 + L1，明确告知「无相关历史」。

## 检索命令

```bash
sh scripts/mem-search.sh "jadx"            # 关键词全库
sh scripts/mem-search.sh -t proj           # 标签
sh scripts/mem-search.sh -r 7              # 近 7 天变更
sh scripts/mem-search.sh -d notes "frida"  # 限定目录
sh scripts/mem-search.sh --brief "frida"   # 只出 文件:命中数
sh scripts/mem-search.sh --files           # 列出全部笔记
sh scripts/mem-search.sh -a "jadx"         # 含 archive
```

默认跳过 `archive/`，避免历史备份污染结果。

## 补读（渐进式）

先用 `--brief` 拿候选，再对候选文件分段读（`read_file` 的 `offset` / `max_bytes`）。
不要一次把整个 `notes/` 塞进上下文。

## 衰减权重

排序时给近期、精确命中加权：

```text
score = 2.0 * exact_match + 1.0 * tag_match + 0.5 * recency_bonus - 0.3 * age_days/30
```

`recency_bonus`：7 天内 = 1.0，30 天内 = 0.5，更早 = 0。

## 冲突处理

同一 key 多条事实，取 `updated` 最新一条。新旧差异大时向用户确认一句再定。

## 恢复播报格式

```text
已恢复：用户偏好 / 项目A(进行中) / 环境路径 · 共 3 条 notes
```

不复述内容，只报指针。
