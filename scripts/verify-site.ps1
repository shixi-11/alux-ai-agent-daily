[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$SiteRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($SiteRoot)) {
    $SiteRoot = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Split-Path -Parent $SiteRoot
}

$SiteRoot = [System.IO.Path]::GetFullPath($SiteRoot)
$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$PublicRoot = Join-Path $SiteRoot 'public'
$manifestPath = Join-Path $PublicRoot 'archive.json'
$indexPath = Join-Path $PublicRoot 'index.html'
$reportPattern = '^\d{8}_ALUX_AI智能体情报日报\.html$'

foreach ($requiredPath in @($manifestPath, $indexPath, (Join-Path $PublicRoot 'latest\index.html'), (Join-Path $SiteRoot 'vercel.json'))) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "缺少站点文件：$requiredPath"
    }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$reports = @($manifest.reports)
$sourceFiles = @(
    Get-ChildItem -LiteralPath $SourceRoot -File -Filter '*_ALUX_AI智能体情报日报.html' |
        Where-Object { $_.Name -match $reportPattern }
)

if ($reports.Count -ne $sourceFiles.Count) {
    throw "归档数量与源文件不一致：清单 $($reports.Count)，源文件 $($sourceFiles.Count)。"
}

$indexHtml = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
$seenDates = @{}
$totalBytes = 0L

foreach ($report in $reports) {
    if ($seenDates.ContainsKey($report.date)) {
        throw "归档清单含重复日期：$($report.date)"
    }
    $seenDates[$report.date] = $true

    $sourcePath = Join-Path $SourceRoot $report.sourceFile
    $publicPath = Join-Path $PublicRoot ($report.publicPath -replace '/', '\')
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "清单中的源文件不存在：$sourcePath"
    }
    if (-not (Test-Path -LiteralPath $publicPath -PathType Leaf)) {
        throw "日期归档不存在：$publicPath"
    }

    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $publicHash = (Get-FileHash -LiteralPath $publicPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -ne $report.sha256 -or $publicHash -ne $sourceHash) {
        throw "源文件、清单与日期归档哈希不一致：$($report.date)"
    }

    $reportHtml = Get-Content -LiteralPath $publicPath -Raw -Encoding UTF8
    if ($reportHtml -match '(?i)(?:src|href)\s*=\s*[\x22\x27](?:file:|[a-z]:[\\/])') {
        throw "日期归档含本地文件引用：$($report.date)"
    }
    if ($indexHtml.IndexOf([string]$report.url, [System.StringComparison]::Ordinal) -lt 0) {
        throw "首页缺少日期归档链接：$($report.url)"
    }
    $totalBytes += (Get-Item -LiteralPath $publicPath).Length
}

$latestReport = $reports | Where-Object { $_.date -eq $manifest.latest.date } | Select-Object -First 1
if (-not $latestReport) {
    throw "latest 指向的日期不在清单中：$($manifest.latest.date)"
}
$latestHash = (Get-FileHash -LiteralPath (Join-Path $PublicRoot 'latest\index.html') -Algorithm SHA256).Hash.ToLowerInvariant()
if ($latestHash -ne $latestReport.sha256) {
    throw 'latest 页面与最新日期归档不一致。'
}

$vercelConfig = Get-Content -LiteralPath (Join-Path $SiteRoot 'vercel.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($vercelConfig.outputDirectory -ne 'public' -or $null -ne $vercelConfig.framework) {
    throw 'Vercel 配置必须以 public 为输出目录，并使用 Other（framework: null）。'
}

Write-Host ('验证通过：{0} 期日报，{1:N0} 字节，latest={2}' -f $reports.Count, $totalBytes, $manifest.latest.date) -ForegroundColor Green
Write-Host '源文件、日期归档与 archive.json 的 SHA-256 全部一致。'
