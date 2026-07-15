[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$SiteRoot,
    [string]$BaseUrl = 'https://report.alux.network'
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
$TemplateRoot = Join-Path $SiteRoot 'templates'
$ReportNamePattern = '^(?<date>\d{8})_ALUX_AI智能体情报日报\.html$'

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Content
    )
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-HtmlText {
    param(
        [Parameter(Mandatory)] [string]$Html,
        [Parameter(Mandatory)] [string]$Pattern
    )
    $match = [regex]::Match(
        $Html,
        $Pattern,
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $match.Success) {
        return ''
    }
    $value = $match.Groups['value'].Value
    $value = [regex]::Replace($value, '<[^>]+>', ' ')
    $value = [System.Net.WebUtility]::HtmlDecode($value)
    return ([regex]::Replace($value, '\s+', ' ')).Trim()
}

function Encode-Html {
    param([AllowEmptyString()] [string]$Value)
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "日报源目录不存在：$SourceRoot"
}
if (-not (Test-Path -LiteralPath $TemplateRoot -PathType Container)) {
    throw "模板目录不存在：$TemplateRoot"
}
if (-not (Test-Path -LiteralPath $PublicRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $PublicRoot | Out-Null
}

$sourceFiles = @(
    Get-ChildItem -LiteralPath $SourceRoot -File -Filter '*_ALUX_AI智能体情报日报.html' |
        Where-Object { $_.Name -match $ReportNamePattern } |
        Sort-Object Name
)

if ($sourceFiles.Count -eq 0) {
    throw "没有找到符合命名规则的日报：$SourceRoot"
}

$reports = New-Object System.Collections.Generic.List[object]
$seenDates = @{}

foreach ($file in $sourceFiles) {
    if ($file.Name -notmatch $ReportNamePattern) {
        continue
    }

    $dateToken = $Matches['date']
    $date = [datetime]::ParseExact(
        $dateToken,
        'yyyyMMdd',
        [System.Globalization.CultureInfo]::InvariantCulture
    )
    $dateIso = $date.ToString('yyyy-MM-dd')

    if ($seenDates.ContainsKey($dateIso)) {
        throw "同一日期出现多份日报：$dateIso"
    }
    $seenDates[$dateIso] = $true

    $html = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    foreach ($required in @('<!doctype html', '<html', '<meta', '<title>', '<h1')) {
        if ($html.IndexOf($required, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "$($file.Name) 缺少必要 HTML 结构：$required"
        }
    }
    if ($html -notmatch '(?i)<meta[^>]+name\s*=\s*[\x22\x27]viewport[\x22\x27]') {
        throw "$($file.Name) 缺少移动端 viewport。"
    }
    if ($html -match '(?i)(?:src|href)\s*=\s*[\x22\x27](?:file:|[a-z]:[\\/])') {
        throw "$($file.Name) 含有本地文件引用，无法安全部署。"
    }

    $titleEn = Get-HtmlText -Html $html -Pattern '<span[^>]+class\s*=\s*[\x22\x27][^\x22\x27]*title-en[^\x22\x27]*[\x22\x27][^>]*>(?<value>.*?)</span>'
    $titleCn = Get-HtmlText -Html $html -Pattern '<span[^>]+class\s*=\s*[\x22\x27][^\x22\x27]*title-cn[^\x22\x27]*[\x22\x27][^>]*>(?<value>.*?)</span>'
    if (-not $titleEn -and -not $titleCn) {
        $titleCn = Get-HtmlText -Html $html -Pattern '<h1[^>]*>(?<value>.*?)</h1>'
    }
    if ($titleEn -and $titleCn -and $titleEn.EndsWith('Agent') -and $titleCn.StartsWith('Agent ')) {
        $titleCn = $titleCn.Substring(6).TrimStart()
    }
    $displayTitle = (@($titleEn, $titleCn) | Where-Object { $_ }) -join ' '
    if (-not $displayTitle) {
        $displayTitle = 'ALUX AI 智能体情报日报'
    }

    $lead = Get-HtmlText -Html $html -Pattern '<p[^>]+class\s*=\s*[\x22\x27][^\x22\x27]*lead[^\x22\x27]*[\x22\x27][^>]*>(?<value>.*?)</p>'
    if (-not $lead) {
        $lead = '聚焦 AI Agent 运行时、可靠执行、安全边界与产业信号。'
    }

    $relativeDirectory = Join-Path (Join-Path $date.ToString('yyyy') $date.ToString('MM')) $date.ToString('dd')
    $destinationDirectory = Join-Path $PublicRoot $relativeDirectory
    if (-not (Test-Path -LiteralPath $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory | Out-Null
    }
    $destinationPath = Join-Path $destinationDirectory 'index.html'
    Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force

    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $url = '/' + ($relativeDirectory -replace '\\', '/') + '/'
    $publicPath = (($relativeDirectory -replace '\\', '/') + '/index.html')

    $reports.Add([pscustomobject][ordered]@{
        date = $date
        dateIso = $dateIso
        dateZh = $date.ToString('yyyy年M月d日')
        sourceLastWriteUtc = $file.LastWriteTimeUtc
        sourceFile = $file.Name
        title = $displayTitle
        lead = $lead
        url = $url
        publicPath = $publicPath
        sha256 = $hash
    })
}

$reportsDescending = @($reports | Sort-Object date -Descending)
$latest = $reportsDescending[0]
$earliest = @($reports | Sort-Object date)[0]
$generatedAtUtc = @($reports | Sort-Object sourceLastWriteUtc -Descending)[0].sourceLastWriteUtc
$generatedAtLocal = $generatedAtUtc.ToLocalTime()

$latestDirectory = Join-Path $PublicRoot 'latest'
if (-not (Test-Path -LiteralPath $latestDirectory)) {
    New-Item -ItemType Directory -Path $latestDirectory | Out-Null
}
Copy-Item -LiteralPath (Join-Path $SourceRoot $latest.sourceFile) -Destination (Join-Path $latestDirectory 'index.html') -Force

$archiveBuilder = [System.Text.StringBuilder]::new()
$monthGroups = $reportsDescending | Group-Object { $_.date.ToString('yyyy-MM') }
foreach ($group in $monthGroups) {
    $monthDate = [datetime]::ParseExact($group.Name + '-01', 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    $null = $archiveBuilder.AppendLine('<section class="archive-group" aria-labelledby="month-' + $group.Name + '">')
    $null = $archiveBuilder.AppendLine('  <div class="month-strip">')
    $null = $archiveBuilder.AppendLine('    <h3 id="month-' + $group.Name + '">' + (Encode-Html $monthDate.ToString('yyyy年M月')) + '</h3>')
    $null = $archiveBuilder.AppendLine('    <span>' + $group.Count + ' 期</span>')
    $null = $archiveBuilder.AppendLine('  </div>')
    $null = $archiveBuilder.AppendLine('  <div class="report-list">')

    foreach ($report in @($group.Group | Sort-Object date -Descending)) {
        $latestClass = if ($report.dateIso -eq $latest.dateIso) { ' is-latest' } else { '' }
        $latestLabel = if ($report.dateIso -eq $latest.dateIso) { '<span class="latest-pill">最新</span>' } else { '' }
        $null = $archiveBuilder.AppendLine('    <a class="report-row' + $latestClass + '" href="' + (Encode-Html $report.url) + '">')
        $null = $archiveBuilder.AppendLine('      <time datetime="' + $report.dateIso + '"><b>' + $report.date.ToString('dd') + '</b><span>' + $report.date.ToString('MM月') + '</span></time>')
        $null = $archiveBuilder.AppendLine('      <div class="report-copy">' + $latestLabel + '<strong>' + (Encode-Html $report.title) + '</strong><p>' + (Encode-Html $report.lead) + '</p></div>')
        $null = $archiveBuilder.AppendLine('      <span class="report-arrow" aria-hidden="true">↗</span>')
        $null = $archiveBuilder.AppendLine('    </a>')
    }

    $null = $archiveBuilder.AppendLine('  </div>')
    $null = $archiveBuilder.AppendLine('</section>')
}

$indexTemplatePath = Join-Path $TemplateRoot 'index.template.html'
$indexTemplate = Get-Content -LiteralPath $indexTemplatePath -Raw -Encoding UTF8
$replacementMap = [ordered]@{
    '{{BASE_URL}}' = $BaseUrl.TrimEnd('/')
    '{{LATEST_DATE_ISO}}' = $latest.dateIso
    '{{LATEST_DATE_ZH}}' = $latest.dateZh
    '{{LATEST_URL}}' = $latest.url
    '{{LATEST_TITLE}}' = Encode-Html $latest.title
    '{{LATEST_LEAD}}' = Encode-Html $latest.lead
    '{{REPORT_COUNT}}' = [string]$reports.Count
    '{{DATE_RANGE}}' = (Encode-Html ($earliest.date.ToString('M月d日') + '—' + $latest.date.ToString('M月d日')))
    '{{MONTH_COUNT}}' = [string]$monthGroups.Count
    '{{ARCHIVE_GROUPS}}' = $archiveBuilder.ToString().Trim()
    '{{GENERATED_AT}}' = $generatedAtLocal.ToString('yyyy-MM-dd HH:mm')
}
foreach ($entry in $replacementMap.GetEnumerator()) {
    $indexTemplate = $indexTemplate.Replace($entry.Key, [string]$entry.Value)
}
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'index.html') -Content $indexTemplate

$archivePayload = [ordered]@{
    schemaVersion = 1
    generatedAt = $generatedAtUtc.ToString('o')
    baseUrl = $BaseUrl.TrimEnd('/')
    latest = [ordered]@{
        date = $latest.dateIso
        url = $latest.url
        latestUrl = '/latest/'
    }
    reports = @(
        $reportsDescending | ForEach-Object {
            [ordered]@{
                date = $_.dateIso
                title = $_.title
                lead = $_.lead
                url = $_.url
                publicPath = $_.publicPath
                sourceFile = $_.sourceFile
                sha256 = $_.sha256
            }
        }
    )
}
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'archive.json') -Content ($archivePayload | ConvertTo-Json -Depth 6)

$base = $BaseUrl.TrimEnd('/')
$sitemapUrls = @($base + '/', $base + '/latest/') + @($reportsDescending | ForEach-Object { $base + $_.url })
$sitemapItems = $sitemapUrls | ForEach-Object {
    '  <url><loc>' + [System.Security.SecurityElement]::Escape($_) + '</loc></url>'
}
$sitemap = @(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
    $sitemapItems
    '</urlset>'
) -join "`n"
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'sitemap.xml') -Content $sitemap
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'robots.txt') -Content ("User-agent: *`nAllow: /`nSitemap: $base/sitemap.xml`n")

$notFoundTemplate = Get-Content -LiteralPath (Join-Path $TemplateRoot '404.template.html') -Raw -Encoding UTF8
Write-Utf8NoBom -Path (Join-Path $PublicRoot '404.html') -Content $notFoundTemplate

Write-Host ('已同步 {0} 期日报：{1} 至 {2}' -f $reports.Count, $earliest.dateIso, $latest.dateIso) -ForegroundColor Green
Write-Host ('最新固定归档：{0}' -f $latest.url)
Write-Host '最新入口：/latest/'
