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

$nodeExecutable = $null
if ($env:NODE_EXE -and (Test-Path -LiteralPath $env:NODE_EXE -PathType Leaf)) {
    $nodeExecutable = $env:NODE_EXE
} else {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCommand) {
        $nodeExecutable = $nodeCommand.Source
    } elseif ($env:LOCALAPPDATA) {
        $bundledNode = Join-Path $env:LOCALAPPDATA 'codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
        if (Test-Path -LiteralPath $bundledNode -PathType Leaf) {
            $nodeExecutable = $bundledNode
            $bundledModules = Join-Path $env:LOCALAPPDATA 'codex-runtimes\codex-primary-runtime\dependencies\node\node_modules'
            $pnpmModules = Join-Path $bundledModules '.pnpm\node_modules'
            $env:NODE_PATH = @($bundledModules, $pnpmModules) -join ';'
        }
    }
}
if (-not $nodeExecutable) {
    throw '没有找到 Node.js。请先安装 Node.js 并在仓库根目录执行 npm install。'
}
& $nodeExecutable (Join-Path $PSScriptRoot 'render-check.cjs')
if ($LASTEXITCODE -ne 0) {
    throw '桌面、平板或手机渲染验收失败，已停止发布。'
}

git -C $siteRoot rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    throw '日报站点还没有初始化为 Git 仓库。'
}

$remote = git -C $siteRoot remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($remote -join ''))) {
    throw '日报站点还没有连接 GitHub origin。'
}

git -C $siteRoot add --all
if ($LASTEXITCODE -ne 0) {
    throw '无法暂存中英母稿、工作配置与生成后的站点文件。'
}

$stagedNames = @(git -C $siteRoot diff --cached --name-only)
if ($stagedNames | Where-Object { $_ -match '(^|/)(\.env|\.vercel)(/|$)' }) {
    throw '检测到本地凭据或 Vercel 设备状态被暂存，已停止提交。'
}

git -C $siteRoot diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host '站点已经是最新状态，没有需要发布的变更。' -ForegroundColor Yellow
    exit 0
}

$manifest = Get-Content -LiteralPath (Join-Path $siteRoot 'public\archive.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$commitMessage = '发布 {0} 中英双语日报' -f $manifest.latest.date
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
    Write-Host 'Vercel 会从 GitHub main 分支自动部署。部署完成后请在 https://ai-agent-daily.alux.network/ 验收中英首页与最新入口。'
}
