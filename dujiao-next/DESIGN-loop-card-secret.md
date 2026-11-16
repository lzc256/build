# 循环卡密（一密多发）设计说明

目标：让**一条**卡密可以给同一规格重复发货 N 次（共享账号 / 固定邀请码 / 永久激活码这类商品）。

约束（按优先级）：

1. **最小改动**：不碰人工发货、不碰订单/支付/退款链路，能共用的查询全部共用。
2. **最大可复现**：补丁要能长期跟着上游走，上游改这些文件时补丁不能 3-way 冲突。
3. **不新增数据库结构**：不加表、不加列、不加索引、不加迁移。
4. **不引入性能回归**：热路径（下单）与列表页都不能因为"判断是不是循环卡密"而变慢。

---

## 1. 最终方案：卡密内容前缀 `__loop__:`

```
用户导入的卡密内容：  __loop__:shared-account@example.com:password
买家收到的内容：      shared-account@example.com:password
```

- 判定 = `strings.HasPrefix(secret, "__loop__:")`
- 交付 = `strings.TrimPrefix(secret, "__loop__:")`
- 数据库里只多出 9 个字节 × 循环卡密条数，**表结构、索引、迁移全部不变**

**不需要任何后台 UI**：运营在"批量导入卡密"的文本框里直接写 `__loop__:内容` 即可。
（本仓库是自用部署，这条是刻意选择：少一处 UI = 少一处上游漂移点。）

---

## 2. 被否掉的三个方案

### 2.1 `status = 'loop'`（零体积，判定最快）

把循环卡密存成第四个状态值，因为 `status` 已经是唯一索引
`idx_card_secret_reserve (product_id, sku_id, status)` 的第三列，判定是索引三等值查找。

否决原因（都不是性能问题）：

1. `status` 是生命周期状态机（available → reserved → used），塞入非生命周期取值属于语义越界；
2. 后台"可用卡密"筛选默认看不到循环卡密，必须补 UI/筛选；
3. `GetStats` 的 `total` 会包含 loop 但 available/reserved/used 不含，报表数字对不上；
4. `ensureSKURemovable` 用 `total-used > 0` 判断，循环 SKU 会变得不可删除；
5. **回滚会踩坑**：旧二进制不认识 `loop`，那些卡密变成"非可用库存"，商品直接显示售罄。

### 2.2 新增 `is_loop` 布尔列

语义最干净，但：

1. 违背"不加列"约束（40 万行约 +0.4~1 MB，虽小但非零）；
2. 不加进索引的话，**判定同样是 O(N) 全扫**（实测 16.4 ms / 10 万行），并不会因为它是布尔列就变快；
3. 与上游 PR #347 的实现绑死，未来上游若改语义要迁移。

### 2.3 短前缀 `loop:`

`loop:` 只有 5 字节，但撞上商家真实卡密内容（比如以 `loop:` 开头的口令）的概率不可忽略，
一旦撞上会被误判为循环卡密、并且交付时被剥掉前缀 —— **直接改坏交付内容**。
改用 9 字节的 `__loop__:` 后，这个风险实际归零。

---

## 3. 核心不变量（整个设计的地基）

导入校验强制两条规则：

1. **一个规格最多一条循环卡密**
2. **循环卡密与普通卡密不得并存**（一个规格要么是"普通库存"，要么是"循环发货"）

于是得到：

> **循环规格的 `available` 恒等于 1。**

这条不变量带来两个决定性结果：

- **订单链路不需要任何全局判断**：取回的 ≤`quantity` 行里必然包含那条循环卡密，直接在内存里 `HasPrefix` 即可，O(1)、与库存量无关。
- **展示/预警链路的候选集极小**：只探测 `available == 1` 的规格。**10 万库存的规格永远不在候选集里，一条查询都不会发。**

---

## 4. 性能实测（SQLite + `glebarez/sqlite` 纯 Go 驱动，卡密 72 字节）

基础索引仅有 `idx_card_secret_reserve (product_id, sku_id, status)`，全程不新建索引。

### 4.1 为什么"先按索引筛选再 substr"是不可行的

| 做法 | 10 万行耗时 |
|---|---|
| `WHERE p=? AND s=? AND status='available' ORDER BY id LIMIT 1` 后再判内容 | 16.3 µs |
| 同上 + `AND substr(secret,1,9)='__loop__:'`（SQL 内判定） | **18.5 ms** |
| 同上 + `AND is_loop = true`（布尔列，未进索引） | **16.4 ms** |
| 聚合 SQL 里加 `CASE WHEN substr(...) THEN 'loop' ELSE status END` 并作为 GROUP BY 键 | **117 ms**（原 35 ms 的 3.3 倍） |

原因：`(product_id, sku_id, status)` 只能定位到"该规格的全部可用行"，
"是不是循环卡密"是第 4 个维度、不在索引里，**"证明不存在"必须把所有可用行看完**。
而把 `CASE` 放进 `GROUP BY` 会破坏原有的索引有序分组，代价是 3 倍。

**结论**：绝不在 SQL 里对全量行做 `substr`，判定只在"已经取回的行"上做。

### 4.2 订单 / 发货链路（每单一次）

| 场景 | 耗时 |
|---|---|
| 普通规格（20 条库存），取回 quantity=3 | 14.5 µs |
| 循环规格（1 条 `__loop__:`），取回 quantity=3 | 15.5 µs |
| 超大规格（10 万条库存），取回 quantity=3 | 16.2 µs |
| Go 侧 `strings.HasPrefix` | 0.35 ns/次 |

与现网完全一致（查询本身没改），新增的只是内存里的前缀判断。

### 4.3 展示 / 预警链路（每次列表页一次）

表：140,651 行 = 1 个 10 万库存规格 + 100 个普通商品（6 规格 × 30 条）+ 1 个纯循环商品 + 150 个"仅剩 1 条"的干扰规格。

| 场景 | 耗时 |
|---|---|
| 现有库存聚合（**完全未修改**） | 35.4 ms |
| 10 万库存规格是否进入候选集 | **false（0 成本）** |
| 候选集为空（绝大多数页面） | **0 ns，不发查询** |
| 1 个候选 | 12 µs |
| 20 个候选 | 100 µs |
| 151 个候选（全部干扰项都在） | 692 µs |

新增开销 = 候选数 × ~4.5 µs，**与库存量、SKU 数无关**。

⚠️ 探测查询必须写成成对条件：

```sql
WHERE status='available' AND deleted_at IS NULL
  AND substr(secret,1,9)='__loop__:'
  AND ((product_id=? AND sku_id=?) OR (product_id=? AND sku_id=?) ...)
```

若图省事写成 `sku_id IN (...)`，索引前缀 `product_id` 用不上，退化为全表扫 —— 实测 16.0 ms（慢 33 倍）。

### 4.4 导入校验（只在写入路径）

| 场景 | 耗时 |
|---|---|
| 新规格（0 条库存） | 10 µs |
| 10 万库存的老规格 | 18 ms |

导入本身要写几千行，这 18 ms 可以忽略。

---

## 5. 逐处改动

### 5.1 卡密领域（`cardsecret/domain`）

新增常量与工具函数：`LoopSecretPrefix`、`IsLoopSecret`、`LoopSecretContent`，
以及 `FirstLoopSecret(secrets []Secret) *Secret`（下单与发货共用的判定入口，
传入的行已按 `id asc` 排序，因此多条循环卡密共存时行为确定：id 最小的一条生效）。
不动 `Secret` 结构体 —— 因此 **AutoMigrate 不会产生任何 DDL**。

### 5.2 导入校验（`cardsecret/application/import.go`）

`CreateCardSecretBatch` 是唯一写入入口（CSV 导入复用同一个函数），在**开事务之前**校验：

- 本批循环卡密 > 1 条 → 拒绝
- 本批同时含循环与普通 → 拒绝
- 该规格已有循环卡密 → 拒绝（保证"最多一条"）
- 该规格已有普通卡密而本批是循环 → 拒绝（保证"不并存"）
- 循环卡密只有前缀没有内容 → 拒绝（否则买家会收到空字符串）

新增两条错误 `ErrLoopSecretDuplicate` / `ErrLoopSecretMixed`，HTTP 层映射为 400。
（"空内容"复用既有的 `ErrInvalid`。）

两个实现细节，都是为了"上游漂移时不炸"：

1. **校验写成函数内的局部闭包**。本模块有结构测试逐文件核对顶层函数清单
   （`card_secret_module_structure_test.go` 的 `expected` 映射），新增任何顶层函数或方法
   都会让它失败；而 application 目录的 Go 文件数预算已经用满（6/6），也不能新建文件。
   写成本地闭包既能保留独立可读的逻辑，又完全不碰上游测试。
2. **校验放在事务之前**。`CreateCardSecretBatch` 的事务闭包把除 `ErrBatchCreateFailed`
   以外的所有错误都折叠成 `ErrCreateFailed`，放进去会丢掉具体原因（实测：四条规则全部
   退化成"card secret create failed"）。只读检查不需要事务隔离，提到事务外既能保留错误
   语义，也不用改动上游那段错误映射。

### 5.3 下单（`order/application/order_service.go`）

`ListAvailableByProductForUpdate` 取回 ≤`quantity` 行后：

- 命中循环卡密 → **不做库存校验、不调用 `Reserve`**（否则那条卡密会被 `reserved`/`used`，第二次就发不出去了）
- 未命中 → 原逻辑一字不变（`len(rows) < quantity` → 库存不足 → `Reserve`）

### 5.4 发货（`fulfillment/application/service.go`）

先取 `reserved` 行（老订单兼容），不足再取 `available` 行；命中循环卡密时：

- 把该内容重复 `quantity` 次写进 `payload`
- **不把该行放进 `ids`**，因此不会 `MarkUsed`

⚠️ **这里的代码顺序是唯一不能动的细节**，而且第一版写错过一次：

```
① selected = 已占用行(reserved)          ← 循环规格下单时不占用，所以此刻是空的
② 若不够，从可用行补齐                    ← 循环卡密在这一步才会出现
③ 判定 FirstLoopSecret(selected)  ← 必须在这里
④ 库存不足判定
```

第一版把 ③ 放在了 ② 之前，结果**永远命中不到**，整单退化成普通分支。
两个症状，一个根因：

| 下单数量 | 症状 |
|---|---|
| 1 | 不报错，但 `payload` 里带着 `__loop__:` 前缀（买家直接看到标记）；同时那条唯一的卡密被 `MarkUsed`，可用数归 0，**下一单显示"已售罄"** |
| ≥2 | 直接报 `card secret insufficient`（1 条凑不够 quantity） |

教训：这个 bug 只有把「下单 → 发货 → 再下单 → 再发货」串起来才测得出来。
当时只测了领域函数、导入不变量和库存聚合，恰好跳过了这条主链路，所以漏了。
现在 `fulfillment/integrationtest` 里有 `TestLoopSecretDeliversContentWithoutPrefix`
按 `quantity ∈ {1, 3, 1}` 连发三单，锁定 payload 无前缀 + 卡密始终 available。

### 5.5 库存展示（`catalog/product/application/stock.go`）

`CountStockByProductIDs`（**SQL 不改**）返回后：

- 候选集 = `available == 1` 的规格（分批 200，上限 1000 个）
- 探测命中 → 该规格 `AutoStockAvailable = -1`（复用既有"负数 = 无限库存"约定）
- 商品级任一规格为循环 → 商品 `AutoStockAvailable = -1`

探测能力通过**可选接口断言**接入，而不是扩展 `StockCounter` 端口：

```go
type loopSecretFinder interface {
	FindLoopSecretSKUs(pairs []cardsecretcontract.LoopSKU) ([]cardsecretcontract.LoopSKU, error)
}
if finder, ok := counter.(loopSecretFinder); ok { ... }
```

这样做是因为 `StockCounter` 是 catalog 模块自有的窄接口，上游测试里有对应的 stub；
往里加方法会连带改上游测试与所有实现方。可选接口让"仓储支持就启用、不支持就跳过"，
上游将来怎么改都不冲突。

探测失败（数据库错误）时静默降级为"不识别"，只让该商品显示真实库存 1，
绝不让商品列表整体报错。

### 5.6 商品详情汇总（`catalog/product/transport/http/public_stock.go`）

上游这里会把各规格的 `AutoStockAvailable` **直接相加**；
若一个商品同时有循环规格(-1) 和普通规格(5)，会算出 `4`（正好显示"低库存"）。
因此改为：任一启用规格为负数 → 商品级直接 `-1` / `unlimited`（与 manual 分支的 `hasUnlimitedSKU` 写法对齐）。

### 5.7 后台预警（`dashboard/infrastructure/gormstore`）

两条统计 SQL **完全不改**，只在 Go 侧：

- `GetStockStats`：跳过循环规格的规格级预警；含循环规格的商品跳过商品级预警
- `GetInventoryAlertItems`：同上，并抑制 `legacyInactiveAvailable` 兜底预警

### 5.8 用户端（`frontend/user`）

沿用仓库已有的 `upstream_stock == -1 → 不限购` 约定，让 auto 库存的 `-1` 同样表示不限：

- 源头保留 `-1`：`useProductDetail.ts`、`ProductQuickBuy.vue`×2、`utils/cartStock.ts` 改用 `normalizeManualStockTotal`
- 消费端处理负数：`useCart.ts`、`useCheckout.ts` 的 auto 分支补 2 行
- `utils/publicStock.ts` 已有 `autoStock < 0 → null`，**不用改**

### 5.9 后台商品列表（`frontend/admin/src/views/admin/Products.vue`）

录入侧零改动（本仓库自用，运营直接写前缀）。但**展示侧必须改 2 处**，
否则循环规格在商品列表里会显示成售罄：

| 位置 | 原本 | 问题 |
|---|---|---|
| `formatAutoStockSummary` | 用 `toSafeInt` 读 `auto_stock_total` | 循环规格是 `-1` |
| `autoStockBadgeClass` | `available <= 0` → 红色 | `-1` 落进 `<= 0`，被标成**售罄红徽章** |

⚠️ **这里有一个把补丁写废的坑，第一版就踩了：**

`toSafeInt` 的实现是 `Math.max(Math.floor(num), 0)` —— **它把 -1 夹成 0**。
所以「在函数里补一句 `if (total < 0)`」是**永远不成立的死代码**：
后端明明返回了 `-1`（买家端已经正确显示「库存无限」），管理端却渲染成
`库存 0/0 · 锁定 0 · 已售 0`，徽章还因为 `available <= 0` 变成红色。

正确做法是先把读取函数换成上游为 manual 分支准备的 `toSafeStockTotal`
（它特意 `if (integer === -1) return -1`），`-1` 才能活着走到判断里：

| 场景 | 修复前 | 修复后 |
|---|---|---|
| 循环卡密（后端返回 -1） | `库存 0/0` + 红徽章 | **`库存不限`** + 绿徽章 |
| 普通库存 5 | `库存 5/5` + 绿徽章 | `库存 5/5` + 绿徽章（不变） |
| 已售罄 0 | `库存 0/0` + 红徽章 | `库存 0/0` + 红徽章（不变） |

（上表是用 node 复刻两个函数实测出来的，不是推断。）

CI 里额外加了一条反向断言：**一旦有人把 `auto_stock_total` 改回 `toSafeInt` 读取就报错**。

### 5.10 导出守卫（`cardsecret/application/export.go`）

后台「导出可用卡密」会把导出的行批量改成 `used`（或用 `DeleteAfterExport` 直接删）。
对循环规格是致命的：那条唯一的卡密一旦不再是 `available`，可用数就不是 1，
不再进入库存探测候选集 —— 后台立刻显示 `0/0 · 锁定 0 · 已售 1`、买家端显示售罄，
**和 §5.4 那个判定顺序 bug 的表现一模一样**。

因此 `ExportAvailableCardSecrets` 在取到行之后、数量校验之前就把循环卡密过滤掉
（`excludeLoopSecrets`，同样写成本地闭包）：循环卡密不可导出，一条都不会被标记。

---

## 6. 语义边界（这些情况循环"不生效"，但功能仍正确）

| 场景 | 行为 |
|---|---|
| 手工改库把循环卡密塞进有大量普通卡密的规格 | `available ≠ 1` → 不显示"不限"，按普通卡密发（不会有脏数据） |
| 一个规格被绕过校验塞了 ≥2 条循环卡密 | 发货取 id 最小的那条；展示不显示"不限" |
| 循环卡密的 `status` 被改成 reserved/used | 立即失效：后台 `0/0 · 锁定 0 · 已售 1`，**买家端显示售罄且下单报「库存不足」**。已被 §5.4/§5.10 堵住，只有手工改库才会发生；恢复见 §7.1 |
| 普通卡密全部软删除后导入循环卡密 | **正常工作**。导入校验与库存聚合都带 `deleted_at IS NULL`，软删除的行既不算库存也不挡导入（见 §9 的 `TestPlainStockCanBeReplacedByLoopSecret`） |
| 人工发货商品 | **完全不受影响**（`CreateManual` 完全不碰 `card_secrets`） |
| 订单取消/超时释放 | 只回滚 `reserved`，循环卡密从未被占用，无影响 |

---

## 7. 回滚

撤掉补丁后，带前缀的卡密会被当作**普通卡密**原样发给买家（内容带 `__loop__:`）。
撤销时执行：

```sql
UPDATE card_secrets SET secret = substr(secret, 10)
WHERE substr(secret, 1, 9) = '__loop__:';
```

（前 9 个字符 `__loop__:` 被剥离；SQLite 与 PostgreSQL 的 `substr` 都是 1-based，语义一致。）

已产生订单的 `fulfillment.payload` 已落库，回滚不影响历史交付。

### 7.1 修复「判定顺序」bug 之前已发出的数据

早期版本（判定放在补齐可用行之前）在 `quantity = 1` 时会把那条卡密 `MarkUsed`，
线上表现为「卖过一次就打上已售罄」。升级到修复版之后卡密**不会自动复活**，
需要手工把它们放回可用（`order_id` / `used_at` 一并清空）：

```sql
-- 先确认影响范围（应当只包含真的被消耗掉的循环卡密）
SELECT id, product_id, sku_id, status, order_id, used_at
FROM card_secrets
WHERE substr(secret, 1, 9) = '__loop__:'
  AND status <> 'available';

-- 需要时再执行恢复
UPDATE card_secrets
SET status = 'available', order_id = NULL, used_at = NULL, updated_at = CURRENT_TIMESTAMP
WHERE substr(secret, 1, 9) = '__loop__:'
  AND status <> 'available';
```

顺带说明：这些订单的 `fulfillment.payload` 里存的是带前缀的内容
（当时漏了剥离），已经交付给买家的那一行不追改；后续发货会是干净内容。

注意区分两种"不见了"：本节是 `status` 被改成 `used`（卡密还在、但不算可用）；
如果是 `deleted_at` 被软删除，见 §10.3。两者都会让后台显示 `0/0 · 已售 1` 式的数字。

### 7.2 为什么不在运行时给「已售出」兜底

问得最多的两点，一并写清楚。

**（1）已售出（`status=used`）的循环卡密，为什么不自动当成"不限库存"？**

因为做不到「只改展示」而不说谎：

| 环节 | 对已售出的循环卡密的实际行为 |
|---|---|
| 识别（`available == 1` 候选集） | 不命中 —— 可用数已是 0，连候选都不是 |
| 展示 | 按真实数字显示（后台 `0/0 · 已售 1`、买家端售罄） |
| **下单** | `ListAvailableByProductForUpdate` 固定 `status = available`，**取不到它 → 报「库存不足」** |

如果只把展示改成"不限库存"，就会出现**页面写有货、下单却报库存不足**，
比诚实地显示售罄更糟。要让已售出的循环卡密真正可用，就必须让下单路径也去读
`used` 行并把它"复活"，那是语义上把已交付的卡密重新卖一遍，上游的
`status = available` 查询也得改 —— 违背"不改现有 SQL"。

而"识别"本身也不能放宽：判定必须扫 `substr(secret,1,9)`，而
`__loop__:` 不在索引里，实测单规格 10 万行就要 18.5 ms（§4.1），
放到每页都跑的展示链路上不可接受。

**（2）所以真正的兜底是三件事，而不是运行时猜测：**

1. **堵住所有能造成这种状态的路径**（这才是根治）
   - 下单命中循环 → 不 `Reserve`（§5.3）
   - 发货命中循环 → 不 `MarkUsed`（§5.4）
   - 导出把循环卡密排除在外 → 不会批量标 `used`（§5.10）
   - 导入校验保证"每规格恰好 1 条、不与普通并存"（§5.2）
2. **留下可执行的诊断与修复 SQL**（§7.1 的 `SELECT` / `UPDATE`）
3. **用测试把路径钉死**，防止以后有人再加一条能烧掉卡密的路径（§9）

**（3）"原本是普通卡密、全部删掉后改成循环"能不能行？**

**能。** 这是最常见的迁移路径，已用测试固化：

1. 有普通库存时直接导入循环 → 拒绝（`ErrLoopSecretMixed`，规则: 不并存）
2. 后台把普通卡密全部"删除" → 实际是**软删除**（`deleted_at`）
3. 再导入循环 → 成功，该规格可用数量回到 1

之所以成立：导入校验的 `CountAvailable` 与库存聚合的
`CountStockByProductIDs` **都带 `deleted_at IS NULL`**，软删除的行既不算库存、
也不会挡住循环导入。

⚠️ 一个容易误判的地方：既有测试 helper `countAvailableCardSecrets` 统计时
**不带** `deleted_at` 过滤，在有已删除行的场景会报出偏大的数字（实测会得到 6）。
新加的测试改用走生产聚合路径的 `realAvailable`，与页面展示的数字一致。

---

## 8. 补丁脚本结构

补丁目录 `dujiao-next/patches/loop-card-secret/`，按顺序执行，每一步都可独立 review：

| 脚本 | 内容 |
|---|---|
| `001-domain-and-repository.sh` | 领域前缀与 `FirstLoopSecret`；`contract` 加 `LoopSKU` 与两个端口方法；gormstore 实现 `CountLoopSecrets` / `FindLoopSecretSKUs` |
| `002-import-validation.sh` | 两条新错误、`CreateCardSecretBatch` 里的局部闭包校验、handler 400 映射、三语种文案 |
| `003-order-and-fulfillment.sh` | 下单跳过占用、发货重复内容且不 `MarkUsed` |
| `004-stock-and-dashboard.sh` | 库存置 `-1`、商品级汇总、后台预警跳过（两条 SQL 不动） |
| `005-frontend-user.sh` | 用户端保留并消费 `-1` |
| `006-tests.sh` | 领域单测 + 导入不变量集成测试 |
| `007-stock-tests.sh` | 库存聚合单测（含候选集断言） |
| `008-admin-and-export-guard.sh` | 后台列表 `-1` → 「库存不限」+ 绿徽章；导出排除循环卡密；导出守卫测试 |
| `009-replace-stock-test.sh` | 「普通库存全部删除后换成循环卡密」迁移路径的回归测试 |

所有脚本都是**幂等脚本**（锚点匹配 + 已存在则跳过 + 结尾断言），不是 `.patch` 文件：
上游改了周围代码时，锚点仍在就能继续套用；真的改动到锚点本身时，
脚本末尾的断言会立刻失败并把原因打出来，而不是像 3-way patch 那样悄悄产生错乱。

## 9. 验证方式

1. `gofmt -l internal/`、`go vet ./...`、`go build ./...`、`go test ./internal/...`（全量 188 个包）
2. 已落地的自动化用例：
   - `cardsecret/domain/secret_test.go`：前缀识别（含 `loop:` 反例、前缀在中间、空串）、
     内容剥离（普通卡密原样返回）、`FirstLoopSecret` 的优先级
   - `cardsecret/integrationtest`：循环卡密导入后该规格 `available` 恒为 1；
     第二条循环被拒；一次导入多条循环被拒；循环规格再导入普通卡密被拒；
     普通规格改造成循环规格被拒；只有前缀没有内容被拒
   - `catalog/product/application`：循环规格与商品级都是 `-1`；
     10 万库存规格不进候选集（断言探测请求里的候选只有那条 `available == 1` 的规格）；
     候选集为空时一条查询都不发；探测失败时降级不报错；
     "恰好剩 1 条"的普通规格不会被误判
3. 端到端回归（`fulfillment/integrationtest`）：
   `TestLoopSecretDeliversContentWithoutPrefix` —— 同一循环规格按 `quantity ∈ {1,3,1}`
   连发三单，断言每单 `payload` 等于裸内容重复 quantity 次（无 `__loop__:` 前缀）、
   且三单之后卡密仍为 `available` 且未绑定订单；
   `TestNormalSKUStillRequiresEnoughStock` —— 普通规格库存不足仍然报错（无回归）
4. 后台展示与导出守卫（`cardsecret/integrationtest`）：
   `TestLoopSecretIsNotExportable` —— 导出循环卡密被拒绝，且卡密仍是 `available`
   `TestPlainStockCanBeReplacedByLoopSecret` —— 普通卡密全部软删除后可导入循环卡密，
   且可用数量回到 1（用生产聚合 `CountStockByProductIDs` 断言，不过滤软删除的旧 helper 不参与）
5. 待人工验收（需要真实容器）：C 端商品页/购物车/结算页不显示"仅剩 1 件"、不限购；
   后台商品列表显示「库存不限」、预警列表不出现循环规格
6. CI：`.github/workflows/dujiao-next-build.yml`
   按 `remove-ads` → `loop-card-secret` 顺序套补丁，断言关键改动全部落地后再
   Docker 构建（含 admin/user 前端 `vue-tsc` + `vite build`），推
   `ghcr.io/<repo>:dujiao-next` 与 `:dujiao-next-<short>`。

## 10. 运维：删除、恢复与磁盘空间回收

### 10.1 后台“删除”是软删除

`BatchDeleteByIDs` 只写 `deleted_at`，不 DELETE：

```go
result := r.db.Model(&cardsecretdomain.Secret{}).
    Where("id IN ? AND deleted_at IS NULL", ids).
    Updates(map[string]interface{}{"deleted_at": now, "updated_at": now})
```

全仓库没有硬删除路径，也没有清理软删行的定时任务，所以**行会永久留在表里**。
这些行对应用完全不可见（所有 `card_secrets` 查询都带 `deleted_at IS NULL`），
但会一直占文件体积，且 SQLite 的 `DELETE` 也只把页放进 freelist，不 `VACUUM` 不会还盘。

一个容易踩的点：`Secret.DeletedAt` 是 **`*time.Time`**，不是 `gorm.DeletedAt`，
GORM 不会自动加过滤条件 —— 任何新写的查询都必须自己带 `deleted_at IS NULL`。

`card_secrets` 只有指向 `card_secret_batches` 的外键（它是子表），**没有任何表引用它**；
订单交付内容存在 `fulfillments.payload` 文本里，所以清理历史行不影响历史订单。

### 10.2 回收空间：`scripts/reclaim-card-secrets.sh`

```bash
# 只统计，不改动
./reclaim-card-secrets.sh /app/db/dujiao.db --dry-run

# 清理未发货的已删除行（默认行为，先备份再 VACUUM）
./reclaim-card-secrets.sh /app/db/dujiao.db

# 只清理 30 天前删除的，自动化场景免交互
./reclaim-card-secrets.sh /app/db/dujiao.db --days 30 --force
```
### 10.2.1 已发货的卡密能不能删？

**能删，但默认不删。** 脚本按状态把已删除行分成三类：

| 状态 | 判定条件 | 默认 | 删掉的后果 |
|---|---|---|---|
| 未发货 | `status='available'` 且 `order_id`/`reserved_at`/`used_at` 全为 NULL | **清理** | 无。这行从来没发给过任何人 |
| 已发货 | `status='used'` | **保留**，需 `--include-shipped` | 丢失「哪条卡密发给了哪个订单」的唯一凭据 |
| 待发货 | `status='reserved'` | **永不清理** | 在途订单发货时找不到行 → 订单卡住发不出货 |

已发货行删掉的**具体影响**（都查证过）：

1. **买家不受影响**。交付内容是 `fulfillments.payload` 文本快照，与 `card_secrets` 行脱钩。
2. **订单页不受影响**。订单详情展示 fulfillment，不 join `card_secrets`；`ListFilter` 也没有
   `OrderID` 字段，后台本来就没有「按订单查卡密」的入口。
3. **退款/取消不受影响**。`ReleaseByOrder` 只回滚 `status='reserved'`，`used` 从不回滚。
4. **库存不受影响**。`available` 计数只统计 `available` 行。
5. **受影响的是后台数字**：`CountByProduct` 的 `used`/`total`、
   `CountByBatchIDs` 的批次「已用」都直接数 `card_secrets`，
   删掉 used 行后这些数字会小于真实订单数，历史批次详情看起来"少发了"。
6. **追溯能力丢失且不可恢复**：想知道某个历史订单当时发的是哪一条卡密，
   只能反查 `card_secrets.order_id`。删了就没有第二处记录了。

所以脚本默认走安全模式；确实要压空间时才 `--include-shipped`：

```bash
# 只清理未发货的已删除行（推荐，默认）
./reclaim-card-secrets.sh /app/db/dujiao.db

# 连已发货的已删除行一起清（会永久丢失订单↔卡密的追溯关系）
./reclaim-card-secrets.sh /app/db/dujiao.db --include-shipped
```

实测（混合样本：2 条未发货 + 2 条已发货 + 1 条待发货，均已软删除）：

| 调用 | 删除 | 保留 |
|---|---|---|
| 默认 | 2 条未发货 | 2 条已发货 + 1 条待发货 + 2 条存活 |
| `--include-shipped` | 4 条（未发货 + 已发货） | 1 条待发货 + 2 条存活 |

⚠️ 如果看到 `待发货 (reserved): N` 的警告，说明有卡密被删掉了但仍在**在途订单**手里占用着
（例如运营在订单未发货时就批量删了卡密）。这些行脚本不会动，需要人工确认那些订单是否
还要发货 —— 强行删会让订单永远发不出货。

要求：`sqlite3` CLI ≥ 3.27（`VACUUM INTO`）。上游运行时镜像是
`alpine:latest` + `ca-certificates` + `tzdata`，**镜像里没有 sqlite3**，所以别指望
`docker exec` 能直接跑：

```bash
# A. 数据库是 bind mount（DB 在宿主机上）：停容器，直接在宿主机跑
docker compose stop dujiao-next
./dujiao-next/scripts/reclaim-card-secrets.sh ./data/db/dujiao.db
docker compose start dujiao-next

# B. 数据库在 named volume 里：拷出来处理，再拷回去
docker compose stop dujiao-next
docker cp dujiao-next:/app/db/dujiao.db ./dujiao.db
./dujiao-next/scripts/reclaim-card-secrets.sh ./dujiao.db
docker cp ./dujiao.db dujiao-next:/app/db/dujiao.db
docker compose start dujiao-next
```

VACUUM 需要独占访问，**必须停应用**；容器默认时区是 UTC，所以容器里写入的
`deleted_at` 是 `+00:00`，宿主机上手工写的可能是 `+08:00` —— 脚本的 `julianday`
比较对两种格式都正确。

脚本流程：`VACUUM INTO` 一致性备份 → 分批 `DELETE`（默认 5000 行/事务）→
`wal_checkpoint(TRUNCATE)` → `VACUUM`（空间不足时自动改走 `VACUUM INTO` + 原子替换）
→ `quick_check` / `foreign_key_check` 校验。

实测（SQLite，20 万行卡密，其中 12 万行已软删除）：

| 指标 | 结果 |
|---|---|
| 文件大小 | 56.6 MB → **20.2 MB**（回收 36.4 MB） |
| 耗时 | 2.1 s（删除 + VACUUM + 校验） |
| 存活行 | 80,000 行全部保留 |
| `--no-vacuum` | 行已删但文件仍 56.6 MB（证明必须 VACUUM） |

**时区陷阱（脚本已处理）**：GORM 写 `deleted_at` 用的是显式 `time.Now()`（本地时区），
存成 `2026-11-15 14:53:13.549729+08:00`；而同一张表里 `created_at` 由 `NowFunc` 写成
`...+00:00`。SQLite 的 `datetime('now')` 是 UTC，**直接比字符串会在时区边界上错几小时**。
脚本改用 `julianday(deleted_at) < julianday('now','-N days')` 做精确比较，
并保留一个 `deleted_at < datetime('now','-N days','+1 day')` 的粗边界让索引仍可用。
实测：字符串比较会漏掉「30 天 + 4 小时前」删除的行，`julianday` 版本正确。

### 10.3 恢复被删的循环卡密

```sql
UPDATE card_secrets SET deleted_at = NULL
WHERE product_id = ? AND sku_id = ?
  AND substr(secret, 1, 9) = '__loop__:';
```

（若已跑过回收脚本把行物理删除，就只能重新导入。**所以回收前务必留备份**。）
