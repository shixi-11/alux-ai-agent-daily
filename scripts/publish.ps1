[CmdletBinding()]
param(
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$siteRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot 'sync-reports.ps1') -SiteRoot $siteRoot
& (Join-Path $PSScriptRoot 'verify-site.ps1') -SiteRoot $siteRoot

git -C $siteRoot rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    throw '日报站点还没有初始化为 Git 仓库。'
}

$remote = git -C $siteRoot remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($remote -join ''))) {
    throw '日报站点还没有连接 GitHub origin。'
}

git -C $siteRoot add -- public
if ($LASTEXITCODE -ne 0) {
    throw '无法暂存生成后的站点文件。'
}

git -C $siteRoot diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host '站点已经是最新状态，没有需要发布的变更。' -ForegroundColor Yellow
    exit 0
}

$manifest = Get-Content -LiteralPath (Join-Path $siteRoot 'public\archive.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$commitMessage = '发布 {0} 日报' -f $manifest.latest.date
git -C $siteRoot commit -m $commitMessage
if ($LASTEXITCODE -ne 0) {
    throw 'Git 提交失败。'
}

if (-not $NoPush) {
    git -C $siteRoot push origin HEAD
    if ($LASTEXITCODE -ne 0) {
        throw 'GitHub 推送失败。'
    }
    Write-Host ('已推送：{0}' -f $commitMessage) -ForegroundColor Green
    Write-Host 'Vercel 会从 GitHub main 分支自动部署。'
}
