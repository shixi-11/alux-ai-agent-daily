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
    throw '项目根目录还没有初始化为 Git 仓库。'
}

$remote = git -C $siteRoot remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($remote -join ''))) {
    throw '项目根目录还没有连接 GitHub origin。'
}
$remoteUrl = ($remote -join '').Trim()
if ($remoteUrl -notmatch 'github\.com[/:]shixi-11/alux-ai-agent-daily(?:\.git)?$') {
    throw "origin 不是 ALUX 日报正式仓库：$remoteUrl"
}

$branch = (git -C $siteRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') {
    throw "日报只能从 main 分支发布；当前分支为 $branch。"
}

$manifest = Get-Content -LiteralPath (Join-Path $siteRoot 'public\archive.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$releaseDate = [string]$manifest.latest.date
$dateCompact = $releaseDate.Replace('-', '')
$chineseRelative = "content/zh/${dateCompact}_ALUX_AI智能体情报日报.html"
$englishRelative = "content/en/${dateCompact}.body.html"
$translationManifestRelative = 'content/en/translation-manifest.json'
$requiredReleaseFiles = @($chineseRelative, $englishRelative, $translationManifestRelative)
foreach ($relativePath in $requiredReleaseFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $siteRoot $relativePath) -PathType Leaf)) {
        throw "缺少当期正式发布文件：$relativePath"
    }
}

function Test-AllowedDailyReleasePath {
    param([Parameter(Mandatory)] [string]$Name)
    $normalized = $Name.Replace('\', '/')
    return $normalized -in $requiredReleaseFiles -or $normalized.StartsWith('public/')
}

$changedNames = @()
$changedNames += @(git -c core.quotepath=false -C $siteRoot diff --name-only)
$changedNames += @(git -c core.quotepath=false -C $siteRoot diff --cached --name-only)
$changedNames += @(git -c core.quotepath=false -C $siteRoot ls-files --others --exclude-standard)
$changedNames = @($changedNames | Where-Object { $_ } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
$unexpectedNames = @($changedNames | Where-Object { -not (Test-AllowedDailyReleasePath $_) })
if ($unexpectedNames.Count -gt 0) {
    throw "检测到日报发布白名单之外的改动，已停止提交：$($unexpectedNames -join ', ')"
}

git -C $siteRoot add -- $chineseRelative $englishRelative $translationManifestRelative public
if ($LASTEXITCODE -ne 0) {
    throw '无法暂存当期中英母稿、翻译清单与 public 发布成品。'
}

$stagedNames = @(git -c core.quotepath=false -C $siteRoot diff --cached --name-only)
$unexpectedStagedNames = @($stagedNames | Where-Object { -not (Test-AllowedDailyReleasePath $_) })
if ($unexpectedStagedNames.Count -gt 0) {
    throw "暂存区包含非正式发布文件，已停止提交：$($unexpectedStagedNames -join ', ')"
}

git -C $siteRoot diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    $commitMessage = '发布 {0} 中英双语日报' -f $releaseDate
    git -C $siteRoot commit -m $commitMessage
    if ($LASTEXITCODE -ne 0) {
        throw 'Git 提交失败。'
    }
} else {
    $commitMessage = '站点已经是最新状态'
    Write-Host $commitMessage -ForegroundColor Yellow
}

if (-not $NoPush) {
    git -C $siteRoot push origin main
    if ($LASTEXITCODE -ne 0) {
        throw 'GitHub 推送失败。'
    }
    Write-Host ('已推送：{0}' -f $commitMessage) -ForegroundColor Green
    & $nodeExecutable (Join-Path $PSScriptRoot 'verify-official-deployment.cjs') $releaseDate
    if ($LASTEXITCODE -ne 0) {
        throw 'Vercel 正式域名尚未部署当前中英版本；已停止 Telegram 交付。'
    }
    Write-Host '正式域名已部署并通过中英首页、最新页、日期页与内容哈希验收。' -ForegroundColor Green
}
