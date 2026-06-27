# Yarr Patches

针对 [nkanaev/yarr](https://github.com/nkanaev/yarr) 的自定义构建。

## 已应用的 Patches

### 1. 内容过滤 (crawler_filter)

根据关键词过滤 RSS 文章，匹配的文章不会被存储，已存储的匹配文章会在定时清理时删除。

**环境变量配置**：

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `YARR_FILTER_TITLE` | 标题过滤关键词（逗号分隔） | `广告,推广,赞助` |
| `YARR_FILTER_CONTENT` | 内容过滤关键词（逗号分隔） | `点击查看,扫码关注` |

**使用示例**：

```bash
# Docker
docker run -d \
  -e YARR_FILTER_TITLE="广告,推广" \
  -e YARR_FILTER_CONTENT="点击查看" \
  -p 7070:7070 \
  ghcr.io/lzc256/build:yarr

# Docker Compose
services:
  yarr:
    image: ghcr.io/lzc256/build:yarr
    environment:
      - YARR_FILTER_TITLE=广告,推广
      - YARR_FILTER_CONTENT=点击查看
    ports:
      - "7070:7070"
```

**特性**：
- 多关键词用逗号分隔，自动去除空格
- 不设置环境变量时不过滤，行为与原版一致
- 过滤在文章入库前执行，被过滤的文章不会占用存储空间
- 已存储的文章如果匹配过滤关键词，会在每24小时的定时清理时删除
- 已加星标(STARRED)的文章不会被过滤删除

### 2. Fever API 限制放宽 (increase_fever_limit)

将 Fever API 返回的文章数量限制从 50 提升到 500，适配更多阅读器。

### 3. 保留期缩短 (reduce_retention)

将文章保留期从 90 天缩短到 30 天，每 feed 最少保留 20 条（原版为 90 天/50 条）。

## 镜像地址

```
ghcr.io/lzc256/build:yarr
ghcr.io/lzc256/build:yarr-<commit>
```
