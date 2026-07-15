[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$SiteRoot,
    [string]$TranslationRoot,
    [string]$BaseUrl = 'https://ai-agent-daily.alux.network'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($SiteRoot)) {
    $SiteRoot = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $SiteRoot 'content\zh'
}
if ([string]::IsNullOrWhiteSpace($TranslationRoot)) {
    $TranslationRoot = Join-Path $SiteRoot 'content\en'
}

$SiteRoot = [System.IO.Path]::GetFullPath($SiteRoot)
$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$TranslationRoot = [System.IO.Path]::GetFullPath($TranslationRoot)
$PublicRoot = Join-Path $SiteRoot 'public'
$TemplateRoot = Join-Path $SiteRoot 'templates'
$AssetRoot = Join-Path $SiteRoot 'assets'
$ManifestPath = Join-Path $TranslationRoot 'translation-manifest.json'
$ReportNamePattern = '^(?<date>\d{8})_ALUX_AI智能体情报日报\.html$'
$EnglishCulture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')

. (Join-Path $PSScriptRoot 'site-lib.ps1')

foreach ($requiredDirectory in @($SourceRoot, $TemplateRoot, $AssetRoot, $TranslationRoot)) {
    if (-not (Test-Path -LiteralPath $requiredDirectory -PathType Container)) {
        throw "缺少必要目录：$requiredDirectory"
    }
}
foreach ($requiredFile in @(
    (Join-Path $TemplateRoot 'index.template.html'),
    (Join-Path $TemplateRoot 'index.en.template.html'),
    (Join-Path $TemplateRoot '404.template.html'),
    (Join-Path $AssetRoot 'report-site.css'),
    $ManifestPath
)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "缺少必要文件：$requiredFile"
    }
}
if (-not (Test-Path -LiteralPath $PublicRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $PublicRoot -Force | Out-Null
}

$translationManifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($translationManifest.locale -ne 'en-US') {
    throw '翻译清单 locale 必须是 en-US。'
}
$translationManifestByDate = @{}
foreach ($entry in @($translationManifest.reports)) {
    if ($translationManifestByDate.ContainsKey([string]$entry.date)) {
        throw "翻译清单含重复日期：$($entry.date)"
    }
    $translationManifestByDate[[string]$entry.date] = $entry
}

$sourceFiles = @(
    Get-ChildItem -LiteralPath $SourceRoot -File -Filter '*_ALUX_AI智能体情报日报.html' |
        Where-Object { $_.Name -match $ReportNamePattern } |
        Sort-Object Name
)
if ($sourceFiles.Count -eq 0) {
    throw "没有找到符合命名规则的日报：$SourceRoot"
}
if ($translationManifestByDate.Count -ne $sourceFiles.Count) {
    throw "翻译清单与中文日报数量不一致：清单 $($translationManifestByDate.Count)，中文 $($sourceFiles.Count)。"
}

$reports = New-Object System.Collections.Generic.List[object]
$seenDates = @{}

foreach ($file in $sourceFiles) {
    if ($file.Name -notmatch $ReportNamePattern) {
        continue
    }
    $dateToken = $Matches['date']
    $date = [datetime]::ParseExact($dateToken, 'yyyyMMdd', [System.Globalization.CultureInfo]::InvariantCulture)
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

    $translationPath = Join-Path $TranslationRoot ($dateToken + '.body.html')
    if (-not (Test-Path -LiteralPath $translationPath -PathType Leaf)) {
        throw "$dateIso 缺少英文母稿：$translationPath"
    }
    $englishBody = Get-Content -LiteralPath $translationPath -Raw -Encoding UTF8
    Assert-EnglishBodyFragment -BodyFragment $englishBody -SourceHtml $html -DateIso $dateIso

    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $translationHash = (Get-FileHash -LiteralPath $translationPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $translationManifestByDate.ContainsKey($dateIso)) {
        throw "$dateIso 未进入翻译审核清单。"
    }
    $translationEntry = $translationManifestByDate[$dateIso]
    if ($translationEntry.status -ne 'reviewed') {
        throw "$dateIso 英文母稿未通过审核：status=$($translationEntry.status)"
    }
    if ([string]$translationEntry.sourceSha256 -ne $sourceHash) {
        throw "$dateIso 中文源文已改动，英文翻译需重新审核。"
    }
    if ([string]$translationEntry.translationSha256 -ne $translationHash) {
        throw "$dateIso 英文母稿已改动，请重新标记 reviewed。"
    }
    if ([string]::IsNullOrWhiteSpace([string]$translationEntry.reviewedAt)) {
        throw "$dateIso 英文母稿缺少 reviewedAt，不能确定原子发布时间。"
    }
    try {
        $reviewedAtUtc = Convert-ToUtcDateTime -Value $translationEntry.reviewedAt
    } catch {
        throw "$dateIso reviewedAt 不是有效的 ISO 8601 时间：$($translationEntry.reviewedAt)"
    }

    $titleEn = Get-HtmlText -Html $html -Pattern '<span[^>]+class\s*=\s*[\x22\x27][^\x22\x27]*title-en[^\x22\x27]*[\x22\x27][^>]*>(?<value>.*?)</span>'
    $titleCn = Get-HtmlText -Html $html -Pattern '<span[^>]+class\s*=\s*[\x22\x27][^\x22\x27]*title-cn[^\x22\x27]*[\x22\x27][^>]*>(?<value>.*?)</span>'
    if (-not $titleEn -and -not $titleCn) {
        $titleCn = Get-HtmlText -Html $html -Pattern '<h1[^>]*>(?<value>.*?)</h1>'
    }
    if ($titleEn -and $titleCn -and $titleEn.EndsWith('Agent') -and $titleCn.StartsWith('Agent ')) {
        $titleCn = $titleCn.Substring(6).TrimStart()
    }
    $displayTitle = (@($titleEn, $titleCn) | Where-Object { $_ }) -join ''
    if (-not $displayTitle) {
        $displayTitle = 'ALUX AI智能体情报日报'
    }
    $lead = Get-HtmlText -Html $html -Pattern '<p[^>]+class\s*=\s*[\x22\x27][^\x22\x27]*lead[^\x22\x27]*[\x22\x27][^>]*>(?<value>.*?)</p>'
    if (-not $lead) {
        $lead = '聚焦 AI Agent 运行时、可靠执行、安全边界与产业信号。'
    }

    $englishTitleMain = Get-HtmlText -Html $englishBody -Pattern '<span[^>]+class\s*=\s*[\x22\x27][^\x22\x27]*title-en[^\x22\x27]*[\x22\x27][^>]*>(?<value>.*?)</span>'
    $englishTitleSubject = Get-HtmlText -Html $englishBody -Pattern '<span[^>]+class\s*=\s*[\x22\x27][^\x22\x27]*title-cn[^\x22\x27]*[\x22\x27][^>]*>(?<value>.*?)</span>'
    if ($englishTitleMain -and $englishTitleSubject) {
        $englishDisplayTitle = $englishTitleMain + ' — ' + $englishTitleSubject
    } elseif ($englishTitleMain -or $englishTitleSubject) {
        $englishDisplayTitle = @($englishTitleMain, $englishTitleSubject) | Where-Object { $_ } | Select-Object -First 1
    } else {
        $englishDisplayTitle = Get-HtmlText -Html $englishBody -Pattern '<h1[^>]*>(?<value>.*?)</h1>'
    }
    if (-not $englishDisplayTitle) {
        throw "$dateIso 英文母稿缺少标题。"
    }
    $englishLead = Get-HtmlText -Html $englishBody -Pattern '<p[^>]+class\s*=\s*[\x22\x27][^\x22\x27]*lead[^\x22\x27]*[\x22\x27][^>]*>(?<value>.*?)</p>'
    if (-not $englishLead) {
        throw "$dateIso 英文母稿缺少 lead。"
    }

    $relativeDirectory = Join-Path (Join-Path $date.ToString('yyyy') $date.ToString('MM')) $date.ToString('dd')
    $url = '/' + ($relativeDirectory -replace '\\', '/') + '/'
    $englishUrl = '/en' + $url
    $reports.Add([pscustomobject][ordered]@{
        date = $date
        dateIso = $dateIso
        dateZh = $date.ToString('yyyy年M月d日')
        dateEn = $date.ToString('MMMM d, yyyy', $EnglishCulture)
        sourceLastWriteUtc = $file.LastWriteTimeUtc
        translationLastWriteUtc = (Get-Item -LiteralPath $translationPath).LastWriteTimeUtc
        reviewedAtUtc = $reviewedAtUtc
        sourceFile = $file.Name
        translationFile = Split-Path -Leaf $translationPath
        sourceHtml = $html
        englishBody = $englishBody
        title = $displayTitle
        lead = $lead
        titleEn = [string]$englishDisplayTitle
        leadEn = $englishLead
        url = $url
        englishUrl = $englishUrl
        publicPath = (($relativeDirectory -replace '\\', '/') + '/index.html')
        englishPublicPath = ('en/' + ($relativeDirectory -replace '\\', '/') + '/index.html')
        sourceSha256 = $sourceHash
        translationSha256 = $translationHash
        publicSha256 = ''
        englishPublicSha256 = ''
    })
}

$reportsAscending = @($reports | Sort-Object date)
for ($index = 0; $index -lt $reportsAscending.Count; $index++) {
    $report = $reportsAscending[$index]
    $previousZh = if ($index -gt 0) { $reportsAscending[$index - 1].url } else { '' }
    $nextZh = if ($index -lt ($reportsAscending.Count - 1)) { $reportsAscending[$index + 1].url } else { '' }
    $previousEn = if ($previousZh) { '/en' + $previousZh } else { '' }
    $nextEn = if ($nextZh) { '/en' + $nextZh } else { '' }

    $chinesePage = Add-ReportSiteChrome -Html $report.sourceHtml -Language 'zh-CN' -BaseUrl $BaseUrl -DateIso $report.dateIso -ChinesePath $report.url -EnglishPath $report.englishUrl -PreviousPath $previousZh -NextPath $nextZh
    $englishPage = Set-DocumentBody -Html $report.sourceHtml -BodyFragment $report.englishBody
    $englishPage = Set-HtmlTitle -Html $englishPage -Title ($report.dateIso + ' ALUX AI Agent Intelligence Daily')
    $englishPage = Add-ReportSiteChrome -Html $englishPage -Language 'en-US' -BaseUrl $BaseUrl -DateIso $report.dateIso -ChinesePath $report.url -EnglishPath $report.englishUrl -PreviousPath $previousEn -NextPath $nextEn

    $chineseDestination = Join-Path $PublicRoot ($report.publicPath -replace '/', '\\')
    $englishDestination = Join-Path $PublicRoot ($report.englishPublicPath -replace '/', '\\')
    Write-Utf8NoBom -Path $chineseDestination -Content $chinesePage
    Write-Utf8NoBom -Path $englishDestination -Content $englishPage
    $report.publicSha256 = (Get-FileHash -LiteralPath $chineseDestination -Algorithm SHA256).Hash.ToLowerInvariant()
    $report.englishPublicSha256 = (Get-FileHash -LiteralPath $englishDestination -Algorithm SHA256).Hash.ToLowerInvariant()
}

$reportsDescending = @($reports | Sort-Object date -Descending)
$latest = $reportsDescending[0]
$earliest = $reportsAscending[0]
$generatedAtUtc = @($reports | ForEach-Object { $_.reviewedAtUtc } | Sort-Object -Descending)[0]
$shanghaiTimeZone = $null
foreach ($timeZoneId in @('China Standard Time', 'Asia/Shanghai')) {
    try {
        $shanghaiTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById($timeZoneId)
        break
    } catch {
        continue
    }
}
$generatedAtLocal = if ($shanghaiTimeZone) {
    [System.TimeZoneInfo]::ConvertTimeFromUtc(
        [datetime]::SpecifyKind($generatedAtUtc, [System.DateTimeKind]::Utc),
        $shanghaiTimeZone
    )
} else {
    [datetime]::SpecifyKind($generatedAtUtc, [System.DateTimeKind]::Utc).AddHours(8)
}

Write-Utf8NoBom -Path (Join-Path $PublicRoot 'latest\index.html') -Content (Get-Content -LiteralPath (Join-Path $PublicRoot ($latest.publicPath -replace '/', '\\')) -Raw -Encoding UTF8)
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'en\latest\index.html') -Content (Get-Content -LiteralPath (Join-Path $PublicRoot ($latest.englishPublicPath -replace '/', '\\')) -Raw -Encoding UTF8)
$publicAssetRoot = Join-Path $PublicRoot 'assets'
if (-not (Test-Path -LiteralPath $publicAssetRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $publicAssetRoot -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $AssetRoot 'report-site.css') -Destination (Join-Path $PublicRoot 'assets\report-site.css') -Force
Copy-Item -LiteralPath (Join-Path $AssetRoot 'alux-mark.png') -Destination (Join-Path $PublicRoot 'assets\alux-mark.png') -Force

function New-ArchiveMarkup {
    param(
        [Parameter(Mandatory)] [object[]]$Items,
        [Parameter(Mandatory)] [ValidateSet('zh-CN', 'en-US')] [string]$Language,
        [Parameter(Mandatory)] [string]$LatestDateIso
    )
    $builder = [System.Text.StringBuilder]::new()
    $monthGroups = $Items | Group-Object { $_.date.ToString('yyyy-MM') } | Sort-Object Name -Descending
    foreach ($group in $monthGroups) {
        $monthDate = [datetime]::ParseExact($group.Name + '-01', 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
        $monthLabel = if ($Language -eq 'zh-CN') { $monthDate.ToString('yyyy年M月') } else { $monthDate.ToString('MMMM yyyy', $EnglishCulture) }
        $issueCountLabel = if ($Language -eq 'zh-CN') { $group.Count.ToString() + '期' } elseif ($group.Count -eq 1) { '1 Issue' } else { $group.Count.ToString() + ' Issues' }
        $null = $builder.AppendLine('<section class="archive-group" aria-labelledby="month-' + $Language + '-' + $group.Name + '">')
        $null = $builder.AppendLine('  <div class="month-strip">')
        $null = $builder.AppendLine('    <h3 id="month-' + $Language + '-' + $group.Name + '">' + (Encode-Html $monthLabel) + '</h3>')
        $null = $builder.AppendLine('    <span>' + (Encode-Html $issueCountLabel) + '</span>')
        $null = $builder.AppendLine('  </div>')
        $null = $builder.AppendLine('  <div class="report-list">')
        foreach ($report in @($group.Group | Sort-Object date -Descending)) {
            $isLatest = $report.dateIso -eq $LatestDateIso
            $latestClass = if ($isLatest) { ' is-latest' } else { '' }
            $latestLabel = if ($isLatest -and $Language -eq 'zh-CN') { '<span class="latest-pill">最新</span>' } elseif ($isLatest) { '<span class="latest-pill">Latest</span>' } else { '' }
            $url = if ($Language -eq 'zh-CN') { $report.url } else { $report.englishUrl }
            $title = if ($Language -eq 'zh-CN') { $report.title } else { $report.titleEn }
            $lead = if ($Language -eq 'zh-CN') { $report.lead } else { $report.leadEn }
            $monthShort = if ($Language -eq 'zh-CN') { $report.date.ToString('M月') } else { $report.date.ToString('MMM', $EnglishCulture).ToUpperInvariant() }
            $null = $builder.AppendLine('    <a class="report-row' + $latestClass + '" href="' + (Encode-Html $url) + '">')
            $null = $builder.AppendLine('      <time datetime="' + $report.dateIso + '"><b>' + $report.date.ToString('dd') + '</b><span>' + (Encode-Html $monthShort) + '</span></time>')
            $null = $builder.AppendLine('      <div class="report-copy">' + $latestLabel + '<strong>' + (Encode-Html $title) + '</strong><p>' + (Encode-Html $lead) + '</p></div>')
            $null = $builder.AppendLine('      <span class="report-arrow" aria-hidden="true">↗</span>')
            $null = $builder.AppendLine('    </a>')
        }
        $null = $builder.AppendLine('  </div>')
        $null = $builder.AppendLine('</section>')
    }
    return $builder.ToString().Trim()
}

$chineseArchiveMarkup = New-ArchiveMarkup -Items $reportsDescending -Language 'zh-CN' -LatestDateIso $latest.dateIso
$englishArchiveMarkup = New-ArchiveMarkup -Items $reportsDescending -Language 'en-US' -LatestDateIso $latest.dateIso
$monthGroups = $reportsDescending | Group-Object { $_.date.ToString('yyyy-MM') }

$chineseIndex = Get-Content -LiteralPath (Join-Path $TemplateRoot 'index.template.html') -Raw -Encoding UTF8
$chineseReplacementMap = [ordered]@{
    '{{BASE_URL}}' = $BaseUrl.TrimEnd('/')
    '{{LATEST_DATE_ISO}}' = $latest.dateIso
    '{{LATEST_DATE_ZH}}' = $latest.dateZh
    '{{LATEST_URL}}' = $latest.url
    '{{LATEST_TITLE}}' = Encode-Html $latest.title
    '{{LATEST_LEAD}}' = Encode-Html $latest.lead
    '{{REPORT_COUNT}}' = [string]$reports.Count
    '{{DATE_RANGE}}' = Encode-Html ($earliest.date.ToString('M月d日') + '—' + $latest.date.ToString('M月d日'))
    '{{MONTH_COUNT}}' = [string]$monthGroups.Count
    '{{ARCHIVE_GROUPS}}' = $chineseArchiveMarkup
    '{{GENERATED_AT}}' = $generatedAtLocal.ToString('yyyy-MM-dd HH:mm')
}
foreach ($entry in $chineseReplacementMap.GetEnumerator()) {
    $chineseIndex = $chineseIndex.Replace($entry.Key, [string]$entry.Value)
}
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'index.html') -Content $chineseIndex

$englishIndex = Get-Content -LiteralPath (Join-Path $TemplateRoot 'index.en.template.html') -Raw -Encoding UTF8
$englishReplacementMap = [ordered]@{
    '{{BASE_URL}}' = $BaseUrl.TrimEnd('/')
    '{{LATEST_DATE_ISO}}' = $latest.dateIso
    '{{LATEST_DATE_EN}}' = $latest.dateEn
    '{{LATEST_URL}}' = $latest.englishUrl
    '{{LATEST_TITLE}}' = Encode-Html $latest.titleEn
    '{{LATEST_LEAD}}' = Encode-Html $latest.leadEn
    '{{REPORT_COUNT}}' = [string]$reports.Count
    '{{DATE_RANGE}}' = Encode-Html ($earliest.date.ToString('MMM d', $EnglishCulture) + '—' + $latest.date.ToString('MMM d', $EnglishCulture))
    '{{MONTH_COUNT}}' = [string]$monthGroups.Count
    '{{ARCHIVE_GROUPS}}' = $englishArchiveMarkup
    '{{GENERATED_AT}}' = $generatedAtLocal.ToString('yyyy-MM-dd HH:mm')
}
foreach ($entry in $englishReplacementMap.GetEnumerator()) {
    $englishIndex = $englishIndex.Replace($entry.Key, [string]$entry.Value)
}
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'en\index.html') -Content $englishIndex

$chineseArchivePayload = [ordered]@{
    schemaVersion = 2
    locale = 'zh-CN'
    generatedAt = $generatedAtUtc.ToString('o')
    baseUrl = $BaseUrl.TrimEnd('/')
    latest = [ordered]@{ date = $latest.dateIso; url = $latest.url; latestUrl = '/latest/'; alternateUrl = $latest.englishUrl }
    reports = @($reportsDescending | ForEach-Object {
        [ordered]@{
            date = $_.dateIso; title = $_.title; lead = $_.lead; url = $_.url; alternateUrl = $_.englishUrl
            publicPath = $_.publicPath; sourceFile = $_.sourceFile; sha256 = $_.sourceSha256; publicSha256 = $_.publicSha256
        }
    })
}
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'archive.json') -Content ($chineseArchivePayload | ConvertTo-Json -Depth 6)

$englishArchivePayload = [ordered]@{
    schemaVersion = 2
    locale = 'en-US'
    generatedAt = $generatedAtUtc.ToString('o')
    baseUrl = $BaseUrl.TrimEnd('/') + '/en'
    latest = [ordered]@{ date = $latest.dateIso; url = $latest.englishUrl; latestUrl = '/en/latest/'; alternateUrl = $latest.url }
    reports = @($reportsDescending | ForEach-Object {
        [ordered]@{
            date = $_.dateIso; title = $_.titleEn; lead = $_.leadEn; url = $_.englishUrl; alternateUrl = $_.url
            publicPath = $_.englishPublicPath; sourceFile = $_.translationFile; sha256 = $_.translationSha256; publicSha256 = $_.englishPublicSha256
        }
    })
}
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'en\archive.json') -Content ($englishArchivePayload | ConvertTo-Json -Depth 6)

$base = $BaseUrl.TrimEnd('/')
$sitemapPairs = New-Object System.Collections.Generic.List[object]
$sitemapPairs.Add([pscustomobject]@{ zh = $base + '/'; en = $base + '/en/' })
$sitemapPairs.Add([pscustomobject]@{ zh = $base + '/latest/'; en = $base + '/en/latest/' })
foreach ($report in $reportsDescending) {
    $sitemapPairs.Add([pscustomobject]@{ zh = $base + $report.url; en = $base + $report.englishUrl })
}
$sitemapItems = New-Object System.Collections.Generic.List[string]
foreach ($pair in $sitemapPairs) {
    foreach ($primary in @($pair.zh, $pair.en)) {
        $sitemapItems.Add('  <url>')
        $sitemapItems.Add('    <loc>' + [System.Security.SecurityElement]::Escape($primary) + '</loc>')
        $sitemapItems.Add('    <xhtml:link rel="alternate" hreflang="zh-CN" href="' + [System.Security.SecurityElement]::Escape($pair.zh) + '" />')
        $sitemapItems.Add('    <xhtml:link rel="alternate" hreflang="en" href="' + [System.Security.SecurityElement]::Escape($pair.en) + '" />')
        $sitemapItems.Add('    <xhtml:link rel="alternate" hreflang="x-default" href="' + [System.Security.SecurityElement]::Escape($pair.zh) + '" />')
        $sitemapItems.Add('  </url>')
    }
}
$sitemap = @(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">'
    $sitemapItems
    '</urlset>'
) -join "`n"
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'sitemap.xml') -Content $sitemap
Write-Utf8NoBom -Path (Join-Path $PublicRoot 'robots.txt') -Content ("User-agent: *`nAllow: /`nSitemap: $base/sitemap.xml`n")

$notFoundTemplate = Get-Content -LiteralPath (Join-Path $TemplateRoot '404.template.html') -Raw -Encoding UTF8
Write-Utf8NoBom -Path (Join-Path $PublicRoot '404.html') -Content $notFoundTemplate

Write-Host ('已同步 {0} 期中英双语日报：{1} 至 {2}' -f $reports.Count, $earliest.dateIso, $latest.dateIso) -ForegroundColor Green
Write-Host ('最新固定归档：{0} / {1}' -f $latest.url, $latest.englishUrl)
Write-Host '最新入口：/latest/ / /en/latest/'
