# 域名路由、迁移记录与 Agent 接班说明

本文件是日报专用 Agent 在任何电脑上处理发布、域名与线上故障时的权威说明。根目录 `AGENTS.md`、`AUTOMATION.md`、`automation/task-contract.json` 与本文件必须保持一致。

## 当前正式地址

- 正式主地址：<https://ai.alux.network/daily/>
- 英文首页：<https://ai.alux.network/daily/en/>
- 中文日期页：`https://ai.alux.network/daily/YYYY/MM/DD/`
- 英文日期页：`https://ai.alux.network/daily/en/YYYY/MM/DD/`
- 永久兼容入口：<https://ai-agent-daily.alux.network/>

所有新生成页面、canonical、hreflang、sitemap、二维码、分享卡、公告和 Telegram 文案只使用新主地址。旧域名只用于兼容已经发出的链接，不再作为品牌主地址。

## 2026-07-16 迁移记录

### DNS

`ai.alux.network` 已完成 DNS 与部署平台绑定。正常日报发布不得添加、删除或修改 DNS；日报专用 Agent 不需要持有域名服务商账号。

公开仓库不复制域名服务商控制台的具体记录值、所有权验证信息、账号、验证码、截图或凭据。DNS 目标可能由平台调整；只有域名失效且项目所有者明确授权排障时，才应实时查询权威 DNS，并与部署平台当时给出的目标核对。

### Vercel 路由合同

仓库 `vercel.json` 实现以下行为：

| 请求 | 预期结果 |
| --- | --- |
| `https://ai.alux.network/` | 临时 `307` 到 `/daily/` |
| `https://ai.alux.network/daily/` | 中文首页 `200` |
| `https://ai.alux.network/daily/en/` | 英文首页 `200` |
| `https://ai-agent-daily.alux.network/` | 永久 `308` 到新中文首页 |
| 旧域名 `/en/`、`/latest/`、`/en/latest/`、中英日期页 | 单次 `308` 到新主地址下的同路径内容 |
| 旧域名 `/daily/...` | 单次 `308` 到新主地址 `/daily/...`，不得出现 `/daily/daily/...` |

旧链接的查询参数必须保留。旧入口不得形成跳转链，也不得返回 404。

Vercel 在外部以 `/daily/...` 提供页面，内部再 rewrite 到 `public/` 的对应成品。不要为迁移复制第二套 `public/daily/`，也不要直接编辑 `public/`。

## 其他电脑上的日报专用 Agent 应如何工作

1. 拉取正式仓库 `main`，完整阅读 `AGENTS.md`、`AUTOMATION.md`、本文件与 `automation/OPENCLAW_DAILY_TASK.md`。
2. 如果自动化正文没有 `[ALUX_DAILY_CONTRACT_VERSION: 2.4.0]`，保留原任务 ID、执行时间、时区和凭据，只替换任务正文并完成一次 dry run；不得新建重复任务。
3. 生成中文母稿、完成美式英语精译与独立审校、更新翻译清单。
4. 运行构建、结构验证、响应式渲染、公开边界和发布白名单检查。
5. 由 `scripts/publish.ps1` 直接提交并推送正式仓库 `main`；Vercel 会自动部署。
6. 部署后运行 `node scripts/verify-official-deployment.cjs YYYY-MM-DD`。该门禁必须同时通过：
   - 新主地址中英首页、最新页和日期页为 `200`，且字节哈希与本地 `public/` 一致；
   - 旧域名对应路径只经过一次 `308`，`Location` 精确指向新主地址；
   - 旧 `/daily/` 不会叠加成 `/daily/daily/`；
   - 带查询参数的旧链接仍保留查询参数。
7. 只有正式部署验证全部通过后，才可以发送日报附件与固定链接消息。

## 不得做的事

- 不把新日报只发布到旧域名或 Vercel 预览域名。
- 不把旧域名写进 canonical、hreflang、sitemap、二维码或新公告。
- 不手工维护两套站点，也不在 `public/daily/` 复制成品。
- 不为了让验证通过而降低 308、哈希、双语一致性或响应式门槛。
- 不在 GitHub 中记录域名或部署服务商的登录信息、验证码、令牌、Cookie、私密接收者或本机凭据。

## 故障定位顺序

1. `ai.alux.network` 无法解析：实时查询权威 DNS，并与部署平台当前给出的目标核对；不要依赖旧截图或旧记录值。
2. `/daily/` 返回 404：检查最新 `main` 是否已部署、`vercel.json` 的 rewrites 是否生效。
3. 旧域名不跳转或出现两次跳转：检查旧 Host 的特定 `/daily/:path*` 规则是否位于通配 `/:path*` 规则之前。
4. 页面能打开但内容不是最新一期：重新运行构建，检查翻译清单哈希，再核对 Vercel 正式部署与 Git 提交。
5. DNS 正常但 HTTPS 未就绪：等待 Vercel 证书签发并检查项目域名绑定；不要用关闭安全校验的方式绕过。

本记录只描述公开域名与稳定路由合同，不保存域名服务商的私密运维数据。后续如修改域名合同，必须在同一次维护提交中更新本文件、自动化合同、验证脚本和 `vercel.json`。
