[CmdletBinding()]
param([string]$SiteRoot)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($SiteRoot)) {
    $SiteRoot = Split-Path -Parent $PSScriptRoot
}
$SiteRoot = [System.IO.Path]::GetFullPath($SiteRoot)
$ChineseRoot = Join-Path $SiteRoot 'content\zh'
$EnglishRoot = Join-Path $SiteRoot 'content\en'
$PublicRoot = Join-Path $SiteRoot 'public'
$BaseUrl = 'https://ai.alux.network'
$BasePath = '/daily'
$LegacyBaseUrl = 'https://ai-agent-daily.alux.network'
$ReportPattern = '^\d{8}_ALUX_AI智能体情报日报\.html$'

. (Join-Path $PSScriptRoot 'site-lib.ps1')

$requiredFiles = @(
    (Join-Path $PublicRoot 'index.html'),
    (Join-Path $PublicRoot 'en\index.html'),
    (Join-Path $PublicRoot 'latest\index.html'),
    (Join-Path $PublicRoot 'en\latest\index.html'),
    (Join-Path $PublicRoot 'archive.json'),
    (Join-Path $PublicRoot 'en\archive.json'),
    (Join-Path $PublicRoot 'sitemap.xml'),
    (Join-Path $PublicRoot 'robots.txt'),
    (Join-Path $PublicRoot '404.html'),
    (Join-Path $PublicRoot 'assets\report-site.css'),
    (Join-Path $PublicRoot 'assets\alux-mark.png'),
    (Join-Path $EnglishRoot 'translation-manifest.json'),
    (Join-Path $SiteRoot 'vercel.json')
)
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "缺少站点文件：$requiredFile"
    }
}

$chineseArchive = Get-Content -LiteralPath (Join-Path $PublicRoot 'archive.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$englishArchive = Get-Content -LiteralPath (Join-Path $PublicRoot 'en\archive.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$translationManifest = Get-Content -LiteralPath (Join-Path $EnglishRoot 'translation-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$chineseReports = @($chineseArchive.reports)
$englishReports = @($englishArchive.reports)
$translationEntries = @($translationManifest.reports)
$sourceFiles = @(
    Get-ChildItem -LiteralPath $ChineseRoot -File -Filter '*_ALUX_AI智能体情报日报.html' |
        Where-Object { $_.Name -match $ReportPattern }
)
$translationFiles = @(Get-ChildItem -LiteralPath $EnglishRoot -File -Filter '*.body.html')

foreach ($archive in @($chineseArchive, $englishArchive)) {
    if ([int]$archive.schemaVersion -ne 3 -or [string]$archive.baseUrl -ne $BaseUrl) {
        throw '归档清单必须使用 schemaVersion 3，并以新站 origin 作为 baseUrl。'
    }
    if (-not ([string]$archive.publicationPath).StartsWith($BasePath, [System.StringComparison]::Ordinal)) {
        throw '归档清单 publicationPath 未迁移到 /daily。'
    }
}

$counts = @(@($sourceFiles.Count, $translationFiles.Count, $translationEntries.Count, $chineseReports.Count, $englishReports.Count) | Select-Object -Unique)
if ($counts.Count -ne 1) {
    throw "中英内容数量不一致：中文=$($sourceFiles.Count) 英文=$($translationFiles.Count) 审核=$($translationEntries.Count) 中文归档=$($chineseReports.Count) 英文归档=$($englishReports.Count)"
}

if ([string]$chineseArchive.generatedAt -ne [string]$englishArchive.generatedAt) {
    throw '中英归档的原子发布时间不一致。'
}
$latestReviewedAt = @(
    $translationEntries | ForEach-Object {
        if ($_.status -ne 'reviewed' -or [string]::IsNullOrWhiteSpace([string]$_.reviewedAt)) {
            throw "$($_.date) 缺少有效的 reviewedAt。"
        }
        try {
            Convert-ToUtcDateTime -Value $_.reviewedAt
        } catch {
            throw "$($_.date) reviewedAt 不是有效的 ISO 8601 时间。"
        }
    } | Sort-Object -Descending
)[0]
$archiveGeneratedAt = Convert-ToUtcDateTime -Value $chineseArchive.generatedAt
if ($archiveGeneratedAt -ne $latestReviewedAt) {
    throw '首页、归档的最近更新时间没有与最新审核状态一起更新。'
}

$englishByDate = @{}
$translationByDate = @{}
foreach ($entry in $englishReports) {
    if ($englishByDate.ContainsKey([string]$entry.date)) { throw "英文归档日期重复：$($entry.date)" }
    $englishByDate[[string]$entry.date] = $entry
}
foreach ($entry in $translationEntries) {
    if ($translationByDate.ContainsKey([string]$entry.date)) { throw "翻译清单日期重复：$($entry.date)" }
    $translationByDate[[string]$entry.date] = $entry
}

$chineseIndex = Get-Content -LiteralPath (Join-Path $PublicRoot 'index.html') -Raw -Encoding UTF8
$englishIndex = Get-Content -LiteralPath (Join-Path $PublicRoot 'en\index.html') -Raw -Encoding UTF8
$sitemap = Get-Content -LiteralPath (Join-Path $PublicRoot 'sitemap.xml') -Raw -Encoding UTF8
$robots = Get-Content -LiteralPath (Join-Path $PublicRoot 'robots.txt') -Raw -Encoding UTF8
$notFound = Get-Content -LiteralPath (Join-Path $PublicRoot '404.html') -Raw -Encoding UTF8
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
        [datetime]::SpecifyKind($archiveGeneratedAt, [System.DateTimeKind]::Utc),
        $shanghaiTimeZone
    )
} else {
    [datetime]::SpecifyKind($archiveGeneratedAt, [System.DateTimeKind]::Utc).AddHours(8)
}
$generatedAtStamp = $generatedAtLocal.ToString('yyyy-MM-dd HH:mm')
if ($chineseIndex.IndexOf($generatedAtStamp, [System.StringComparison]::Ordinal) -lt 0 -or $englishIndex.IndexOf($generatedAtStamp, [System.StringComparison]::Ordinal) -lt 0) {
    throw '中英首页的最近更新时间没有与翻译审核清单同步。'
}
if ($chineseIndex -notmatch '<title>ALUX AI智能体情报日报</title>') { throw '中文首页站名不正确。' }
if ($englishIndex -notmatch '<title>ALUX AI Agent Intelligence Daily</title>') { throw '英文首页站名不正确。' }
foreach ($homeCheck in @(
    @{ html = $chineseIndex; url = $BaseUrl + $BasePath + '/' },
    @{ html = $englishIndex; url = $BaseUrl + $BasePath + '/en/' }
)) {
    if ($homeCheck.html.IndexOf('rel="canonical" href="' + $homeCheck.url + '"', [System.StringComparison]::OrdinalIgnoreCase) -lt 0 -or
        $homeCheck.html.IndexOf('property="og:url" content="' + $homeCheck.url + '"', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "首页 canonical 或 og:url 不正确：$($homeCheck.url)"
    }
}
foreach ($indexCheck in @(
    @{ html = $chineseIndex; required = @('href="/daily/en/"', 'hreflang="en"', '/daily/assets/alux-mark.png') },
    @{ html = $englishIndex; required = @('href="/daily/"', 'hreflang="zh-CN"', '/daily/assets/alux-mark.png') }
)) {
    foreach ($required in $indexCheck.required) {
        if ($indexCheck.html.IndexOf($required, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "首页缺少双语或品牌元素：$required"
        }
    }
}

$seenDates = @{}
$totalBytes = 0L
foreach ($chineseReport in $chineseReports) {
    $dateIso = [string]$chineseReport.date
    if ($seenDates.ContainsKey($dateIso)) { throw "中文归档日期重复：$dateIso" }
    $seenDates[$dateIso] = $true
    if (-not $englishByDate.ContainsKey($dateIso) -or -not $translationByDate.ContainsKey($dateIso)) {
        throw "$dateIso 缺少英文归档或翻译审核记录。"
    }
    $englishReport = $englishByDate[$dateIso]
    $translationEntry = $translationByDate[$dateIso]
    if ($translationEntry.status -ne 'reviewed') { throw "$dateIso 英文状态不是 reviewed。" }

    $sourcePath = Join-Path $ChineseRoot ([string]$chineseReport.sourceFile)
    $translationPath = Join-Path $EnglishRoot ([string]$translationEntry.translationFile)
    $chinesePublicPath = Join-Path $PublicRoot (([string]$chineseReport.publicPath) -replace '/', '\\')
    $englishPublicPath = Join-Path $PublicRoot (([string]$englishReport.publicPath) -replace '/', '\\')
    foreach ($path in @($sourcePath, $translationPath, $chinesePublicPath, $englishPublicPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$dateIso 缺少文件：$path" }
    }

    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $translationHash = (Get-FileHash -LiteralPath $translationPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $chinesePublicHash = (Get-FileHash -LiteralPath $chinesePublicPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $englishPublicHash = (Get-FileHash -LiteralPath $englishPublicPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -ne [string]$translationEntry.sourceSha256 -or $sourceHash -ne [string]$chineseReport.sha256) {
        throw "$dateIso 中文母稿哈希与审核清单或归档不一致。"
    }
    if ($translationHash -ne [string]$translationEntry.translationSha256 -or $translationHash -ne [string]$englishReport.sha256) {
        throw "$dateIso 英文母稿哈希与审核清单或归档不一致。"
    }
    if ($chinesePublicHash -ne [string]$chineseReport.publicSha256 -or $englishPublicHash -ne [string]$englishReport.publicSha256) {
        throw "$dateIso 公开页哈希与归档清单不一致。"
    }

    $sourceHtml = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
    $translationBody = Get-Content -LiteralPath $translationPath -Raw -Encoding UTF8
    Assert-EnglishBodyFragment -BodyFragment $translationBody -SourceHtml $sourceHtml -DateIso $dateIso
    $chineseHtml = Get-Content -LiteralPath $chinesePublicPath -Raw -Encoding UTF8
    $englishHtml = Get-Content -LiteralPath $englishPublicPath -Raw -Encoding UTF8
    foreach ($html in @($chineseHtml, $englishHtml)) {
        if ($html -match '(?i)(?:src|href)\s*=\s*[\x22\x27](?:file:|[a-z]:[\\/])') { throw "$dateIso 公开页含本地引用。" }
        foreach ($required in @('site:i18n-head:start', 'site:i18n-nav:start', 'site:issue-footer:start', '/daily/assets/alux-mark.png')) {
            if ($html.IndexOf($required, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { throw "$dateIso 公开页缺少：$required" }
        }
        if ($html.IndexOf($LegacyBaseUrl, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { throw "$dateIso 公开页仍把旧域名作为页面地址。" }
    }
    $expectedZhUrl = $BaseUrl + [string]$chineseReport.url
    $expectedEnUrl = $BaseUrl + [string]$englishReport.url
    if ($chineseHtml.IndexOf('lang="zh-CN"', [System.StringComparison]::OrdinalIgnoreCase) -lt 0 -or $englishHtml.IndexOf('lang="en-US"', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "$dateIso html lang 不正确。"
    }
    foreach ($pair in @(
        @{ html = $chineseHtml; canonical = $expectedZhUrl; alternate = [string]$englishReport.url },
        @{ html = $englishHtml; canonical = $expectedEnUrl; alternate = [string]$chineseReport.url }
    )) {
        if ($pair.html.IndexOf('rel="canonical" href="' + $pair.canonical + '"', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { throw "$dateIso canonical 不正确。" }
        if ($pair.html.IndexOf('href="' + $pair.alternate + '"', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { throw "$dateIso 语言切换未指向同一期。" }
    }
    $englishWithoutSwitcherLabel = $englishHtml.Replace('>中文<', '>ZH<')
    if ($englishWithoutSwitcherLabel -match '[\u3400-\u9fff]') { throw "$dateIso 公开英文页含非切换器中文。" }

    if ($chineseIndex.IndexOf([string]$chineseReport.url, [System.StringComparison]::Ordinal) -lt 0 -or $englishIndex.IndexOf([string]$englishReport.url, [System.StringComparison]::Ordinal) -lt 0) {
        throw "$dateIso 中英首页缺少日期链接。"
    }
    if ($sitemap.IndexOf($expectedZhUrl, [System.StringComparison]::Ordinal) -lt 0 -or $sitemap.IndexOf($expectedEnUrl, [System.StringComparison]::Ordinal) -lt 0) {
        throw "$dateIso sitemap 缺少中英 URL。"
    }
    $totalBytes += (Get-Item -LiteralPath $chinesePublicPath).Length + (Get-Item -LiteralPath $englishPublicPath).Length
}

if ($chineseArchive.latest.date -ne $englishArchive.latest.date) { throw '中英 latest 日期不一致。' }
$latestDate = [string]$chineseArchive.latest.date
$latestZh = $chineseReports | Where-Object { $_.date -eq $latestDate } | Select-Object -First 1
$latestEn = $englishReports | Where-Object { $_.date -eq $latestDate } | Select-Object -First 1
if (-not $latestZh -or -not $latestEn) { throw "latest 日期不在归档中：$latestDate" }
$latestZhHash = (Get-FileHash -LiteralPath (Join-Path $PublicRoot 'latest\index.html') -Algorithm SHA256).Hash.ToLowerInvariant()
$latestEnHash = (Get-FileHash -LiteralPath (Join-Path $PublicRoot 'en\latest\index.html') -Algorithm SHA256).Hash.ToLowerInvariant()
if ($latestZhHash -ne [string]$latestZh.publicSha256 -or $latestEnHash -ne [string]$latestEn.publicSha256) { throw '中英 latest 与最新日期页不一致。' }

$assetSourceHash = (Get-FileHash -LiteralPath (Join-Path $SiteRoot 'assets\alux-mark.png') -Algorithm SHA256).Hash
$assetPublicHash = (Get-FileHash -LiteralPath (Join-Path $PublicRoot 'assets\alux-mark.png') -Algorithm SHA256).Hash
if ($assetSourceHash -ne $assetPublicHash) { throw 'ALUX 品牌图标源文件与公开资产不一致。' }

if ($sitemap.IndexOf($BaseUrl + $BasePath + '/latest/', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
    throw 'sitemap 不应收录 canonical 指向日期页的 latest 别名。'
}
if ($robots.IndexOf('Sitemap: ' + $BaseUrl + $BasePath + '/sitemap.xml', [System.StringComparison]::OrdinalIgnoreCase) -lt 0 -or
    $notFound.IndexOf('href="' + $BasePath + '/"', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw 'robots 或 404 尚未迁移到 /daily 主路径。'
}
$legacyLeaks = @(
    Get-ChildItem -LiteralPath $PublicRoot -Recurse -File |
        Where-Object { $_.Extension -in @('.html', '.json', '.xml', '.txt', '.css') } |
        Select-String -SimpleMatch $LegacyBaseUrl
)
if ($legacyLeaks.Count -gt 0) {
    throw "公开成品仍含旧域名：$($legacyLeaks[0].Path):$($legacyLeaks[0].LineNumber)"
}
$unresolvedPlaceholders = @(
    Get-ChildItem -LiteralPath $PublicRoot -Recurse -File -Filter '*.html' |
        Select-String -SimpleMatch '{{BASE_PATH}}'
)
if ($unresolvedPlaceholders.Count -gt 0) {
    throw "公开成品仍含未替换的 BASE_PATH：$($unresolvedPlaceholders[0].Path)"
}

$vercelConfig = Get-Content -LiteralPath (Join-Path $SiteRoot 'vercel.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($vercelConfig.outputDirectory -ne 'public' -or $null -ne $vercelConfig.framework) {
    throw 'Vercel 配置必须以 public 为输出目录，并使用 Other（framework: null）。'
}
foreach ($spec in @(
    @{ source = '/'; destination = 'https://ai.alux.network/daily/' },
    @{ source = '/daily/(.*)'; destination = 'https://ai.alux.network/daily/$1' },
    @{ source = '/(.*)'; destination = 'https://ai.alux.network/daily/$1' }
)) {
    $matches = @($vercelConfig.redirects) | Where-Object {
        $_.source -eq $spec.source -and $_.destination -eq $spec.destination -and $_.permanent -eq $true -and
        @($_.has | Where-Object { $_.type -eq 'host' -and $_.value -eq 'ai-agent-daily.alux.network' }).Count -eq 1
    }
    if (@($matches).Count -ne 1) { throw "Vercel 缺少旧域名兼容规则：$($spec.source)" }
}
foreach ($spec in @(
    @{ source = '/daily/(.*)'; destination = '/$1' }
)) {
    $matches = @($vercelConfig.rewrites) | Where-Object { $_.source -eq $spec.source -and $_.destination -eq $spec.destination }
    if (@($matches).Count -ne 1) { throw "Vercel 缺少 /daily 内部映射：$($spec.source)" }
}

Write-Host ('验证通过：{0} 期中英双语日报，{1:N0} 字节，latest={2}' -f $chineseReports.Count, $totalBytes, $latestDate) -ForegroundColor Green
Write-Host '母稿、翻译审核、公开页哈希、结构、外链、语言切换、SEO 与 ALUX 图标全部一致。'
