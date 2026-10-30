# 长沙游工作台 V5 / Changsha Travel Desk

一个可部署到 GitHub Pages 的手机优先 PWA，使用 Supabase Auth + PostgreSQL 保存个人旅行数据。**无需购买域名**，但需要自己配置 GitHub 与 Supabase。

## 现状与限制

- ✅ 可在浏览器操作三天行程、预约、交通估算、美食、地点、记账、笔记。
- ✅ 旧版 V1–V4 JSON 备份安全合并导入，合并前自动下载当前备份；不会静默覆盖已有记录。
- ✅ Supabase 邮箱魔法链接登录；按登录用户隔离数据（RLS + RPC），跨设备读取和写入。
- ✅ PostgreSQL 修订号冲突检测，避免旧设备悄悄覆盖云端新数据。
- ✅ PWA 主屏幕快捷方式及应用外壳离线缓存；离线时记录保存在本机。
- ⚠️ 云端同步依赖网络。离线记录不会自动与另一设备的不同更改合并；遇到冲突必须导出备份、手动核对合并。
- ⚠️ 预约和交通数据为建议值，不是官方实时查询；天气在 V5 里暂未连接实时天气 API。手机导航会打开高德搜索，不是自动换乘计算。
- ⚠️ 不要保存身份证、银行卡、账号密码等个人敏感信息。
- ⚠️ GitHub Pages 公开仓库意味着**网页源代码公开**，但个人内容存储于具有用户隔离权限的 Supabase，不在 GitHub 仓库内。仍需自行管理账号权限。

## 1. Supabase 配置

1. 创建 Supabase 项目（建议区域靠近主要使用地）。
2. 打开 **SQL Editor**，执行 `supabase/schema.sql` 全部内容。
3. Authentication → Providers → Email：开启 Email / OTP 登录。
4. Authentication → URL Configuration：在 **Site URL** 及 **Redirect URLs** 中添加部署后的 GitHub Pages 地址，示例 `https://YOURNAME.github.io/changsha-v5/`。
5. Project Settings / API Keys 复制 **Project URL** 和 **publishable/anon key**（不是 service_role/secret），填写 `config.js`。
6. 不要将 Supabase service_role/secret、数据库口令、邮箱登录链接提交到 GitHub。

> Supabase 的邮箱发信能力、免费套餐配额和验证策略以实际后台为准。

## 2. GitHub Pages 发布

1. 在 GitHub 建立新仓库，例如 `changsha-v5`，将本 ZIP 解压后**所有文件（含隐藏的 .github 文件夹）**上传到仓库根目录；默认分支 `main`。
2. GitHub 仓库 → Settings → Pages → Build and deployment → Source 选择 **GitHub Actions**。
3. 推送代码后查看 Actions 工作流 `Publish GitHub Pages`。部署成功后访问 GitHub Pages 给出的地址。
4. 把此 URL 添加到 Supabase Auth 的允许重定向网址（见上一步），否则邮箱登录可能失败。
5. 手机 Safari（iPhone）选 **分享 → 添加到主屏幕**；安卓 Chrome 选 **安装应用/添加到主屏幕**。

GitHub Pages 需要 GitHub 账户权限，Supabase 数据库需要账户授权；本 ZIP 本身不能自动完成这两项创建或发布。

## 3. 从旧 HTML 导入数据：关键步骤

1. 在**原设备、原浏览器**打开你已记录数据的旧版 HTML（V4）；在「数据与备份」点击「导出全部数据 JSON」。
2. 不要直接删除旧 HTML 或清理浏览器缓存。把备份 JSON 留存一份。
3. 在 V5 → 数据 →「旧版数据迁移」选择该 JSON；查看行程、地点、消费、笔记数量，确认安全合并。
4. V5 会先下载合并前备份。核对行程、记账、笔记、预约和交通是否完整。
5. 配置好云端并登录后：如云端是空白，点击「将当前副本保存到云端」；如云端已经存在数据，先备份当前数据、读取云端，之后再用先前导出的 JSON 合并，不可直接覆盖。
6. 在第二台设备登录同一账户，点击「从云端读取」，核对记录。仅在所有设备核对成功后再考虑不再使用 V4。

合并策略：消费按 ID、日期、名称、金额、类别避免重复；地点按名称+区域；行程按 ID+日期+时间+名称；备注保留冲突内容。不保证可自动解决不同设备同时编辑同一条记录的冲突。请备份并人工核对。

## 4. 更新工作台而不清空数据

更新 HTML/CSS/JavaScript 后 GitHub Pages 自动发布新版本。个人云端数据与代码部署独立，不会因部署自动重置。默认行程种子存放在 `seed.json`，只用于首次初始化；不会自动覆盖已有行程。将来更改数据库表结构需编写 SQL 迁移脚本并先备份数据。

## 5. 本地开发预览

静态站点运行需要 HTTP 服务，**不要直接双击 `index.html` 通过 file:// 打开**（JSON modules 和服务工作线程需 Web 服务器）。

```bash
cd changsha-v5
python -m http.server 8080
```

浏览器访问 `http://localhost:8080/`。本地模式可不填写 `config.js`，但云端登录与跨设备同步不可用。跨设备/主屏幕安装必须使用 HTTPS 托管站点。

## 6. 数据与备份设计

- `trip_documents`：每名登录用户一行 JSONB 文档、修订号、更新时间。由 RLS 限制读取；写入走 `save_trip(expected_revision,new_payload)`。
- `save_trip` 用行锁和修订号校验进行原子更新；检测到冲突时客户端拒绝静默覆盖，保留本地数据供导出。
- 本地 `localStorage` key 为 `changsha-trip-v5-local`，用于离线草稿和刷新恢复；不作为跨设备同步源。
- GitHub 仓库中不包含用户数据；不要上传备份 JSON 到公开仓库。
- `config.js` 仅含公开项目 URL 和公开密钥，可随前端部署。**绝不放入服务端特权密钥**。

## 7. 旅行规划默认约束

11月11日12:00到长沙南站、住开福区乐古道巷5号；11月13日15:31长沙南站返回广州，出门携带全部行李不返回酒店。包含湖南博物院、杜甫江阁夜景、IFS、7mall、五一广场、太平老街、潮宗街、开福寺、梅溪湖艺术博物馆、中国结步行桥、麦垛艺术空间、东茅街茶馆、黄兴路步行街、零食王国等。岳麓山、橘子洲不安排。

部分地点的营业时间、门票及天气应在出发前按官方更新核查。
