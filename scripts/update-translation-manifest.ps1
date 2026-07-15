[CmdletBinding(DefaultParameterSetName = 'Single')]
param(
    [Parameter(ParameterSetName = 'Single', Mandatory)] [string]$Date,
    [Parameter(ParameterSetName = 'All', Mandatory)] [switch]$All,
    [switch]$MarkReviewed,
    [string]$SiteRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($SiteRoot)) {
    $SiteRoot = Split-Path -Parent $PSScriptRoot
}
$SiteRoot = [System.IO.Path]::GetFullPath($SiteRoot)
$ChineseRoot = Join-Path $SiteRoot 'content\zh'
$EnglishRoot = Join-Path $SiteRoot 'content\en'
$ManifestPath = Join-Path $EnglishRoot 'translation-manifest.json'
$ReportPattern = '^(?<date>\d{8})_ALUX_AI智能体情报日报\.html$'

. (Join-Path $PSScriptRoot 'site-lib.ps1')

if (-not (Test-Path -LiteralPath $ChineseRoot -PathType Container)) {
    throw "中文母稿目录不存在：$ChineseRoot"
}
if (-not (Test-Path -LiteralPath $EnglishRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $EnglishRoot -Force | Out-Null
}

$existingByDate = @{}
if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
    $existingManifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($entry in @($existingManifest.reports)) {
        $existingByDate[[string]$entry.date] = $entry
    }
}

$sourceFiles = @(
    Get-ChildItem -LiteralPath $ChineseRoot -File -Filter '*_ALUX_AI智能体情报日报.html' |
        Where-Object { $_.Name -match $ReportPattern } |
        Sort-Object Name
)
if (-not $All) {
    try {
        $parsedDate = [datetime]::ParseExact($Date, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
        throw "Date 必须使用 YYYY-MM-DD：$Date"
    }
    $dateToken = $parsedDate.ToString('yyyyMMdd')
    $sourceFiles = @($sourceFiles | Where-Object { $_.Name.StartsWith($dateToken + '_', [System.StringComparison]::Ordinal) })
    if ($sourceFiles.Count -ne 1) {
        throw "$Date 对应的中文母稿数量不是 1。"
    }
}
if ($sourceFiles.Count -eq 0) {
    throw '没有可更新的中文母稿。'
}

$updatedDates = @{}
foreach ($sourceFile in $sourceFiles) {
    if ($sourceFile.Name -notmatch $ReportPattern) {
        continue
    }
    $dateToken = $Matches['date']
    $dateIso = [datetime]::ParseExact($dateToken, 'yyyyMMdd', [System.Globalization.CultureInfo]::InvariantCulture).ToString('yyyy-MM-dd')
    $translationFile = Join-Path $EnglishRoot ($dateToken + '.body.html')
    if (-not (Test-Path -LiteralPath $translationFile -PathType Leaf)) {
        throw "$dateIso 缺少英文母稿：$translationFile"
    }
    $sourceHtml = Get-Content -LiteralPath $sourceFile.FullName -Raw -Encoding UTF8
    $translationBody = Get-Content -LiteralPath $translationFile -Raw -Encoding UTF8
    Assert-EnglishBodyFragment -BodyFragment $translationBody -SourceHtml $sourceHtml -DateIso $dateIso
    $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $translationHash = (Get-FileHash -LiteralPath $translationFile -Algorithm SHA256).Hash.ToLowerInvariant()

    $old = if ($existingByDate.ContainsKey($dateIso)) { $existingByDate[$dateIso] } else { $null }
    $status = if ($MarkReviewed) { 'reviewed' } else { 'draft' }
    $reviewedAt = $null
    if ($MarkReviewed) {
        $sameReviewed = $old -and $old.status -eq 'reviewed' -and [string]$old.sourceSha256 -eq $sourceHash -and [string]$old.translationSha256 -eq $translationHash
        $reviewedAt = if ($sameReviewed) { [string]$old.reviewedAt } else { [datetime]::UtcNow.ToString('o') }
    }
    $existingByDate[$dateIso] = [pscustomobject][ordered]@{
        date = $dateIso
        sourceFile = $sourceFile.Name
        translationFile = Split-Path -Leaf $translationFile
        sourceSha256 = $sourceHash
        translationSha256 = $translationHash
        status = $status
        reviewedAt = $reviewedAt
    }
    $updatedDates[$dateIso] = $true
}

$reports = @(
    $existingByDate.GetEnumerator() |
        Sort-Object Name |
        ForEach-Object { $_.Value }
)
$payload = [ordered]@{
    schemaVersion = 1
    locale = 'en-US'
    reports = $reports
}
Write-Utf8NoBom -Path $ManifestPath -Content ($payload | ConvertTo-Json -Depth 5)

$mode = if ($MarkReviewed) { 'reviewed' } else { 'draft' }
Write-Host ('翻译清单已更新：{0} 期，本次 {1} 期，状态={2}' -f $reports.Count, $updatedDates.Count, $mode) -ForegroundColor Green
