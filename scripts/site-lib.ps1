Set-StrictMode -Version Latest

function Convert-ToUtcDateTime {
    param([Parameter(Mandatory)] [object]$Value)

    if ($Value -is [datetimeoffset]) {
        return ([datetimeoffset]$Value).UtcDateTime
    }
    if ($Value -is [datetime]) {
        $dateTime = [datetime]$Value
        if ($dateTime.Kind -eq [System.DateTimeKind]::Unspecified) {
            return [datetime]::SpecifyKind($dateTime, [System.DateTimeKind]::Utc)
        }
        return $dateTime.ToUniversalTime()
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw '时间值不能为空。'
    }
    return ([datetimeoffset]::Parse(
        $text,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind
    )).UtcDateTime
}

function Convert-ToUtcIsoString {
    param([Parameter(Mandatory)] [object]$Value)
    return (Convert-ToUtcDateTime -Value $Value).ToString('o')
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Content
    )
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $normalizedContent = [regex]::Replace($Content, "`r`n?", "`n")
    [System.IO.File]::WriteAllText($Path, $normalizedContent, [System.Text.UTF8Encoding]::new($false))
}

function Encode-Html {
    param([AllowEmptyString()] [string]$Value)
    return [System.Net.WebUtility]::HtmlEncode($Value)
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
    $value = [regex]::Replace($value, '(?i)<br\s*/?>', ' ')
    $value = [regex]::Replace($value, '<[^>]+>', '')
    $value = [System.Net.WebUtility]::HtmlDecode($value)
    return ([regex]::Replace($value, '\s+', ' ')).Trim()
}

function Set-HtmlLanguage {
    param(
        [Parameter(Mandatory)] [string]$Html,
        [Parameter(Mandatory)] [ValidateSet('zh-CN', 'en-US')] [string]$Language
    )
    if ($Html -notmatch '(?i)<html\b') {
        throw '报告缺少 html 根元素。'
    }
    if ($Html -match '(?i)<html\b[^>]*\blang\s*=') {
        return [regex]::Replace(
            $Html,
            '(?i)(<html\b[^>]*\blang\s*=\s*)[\x22\x27][^\x22\x27]*[\x22\x27]',
            ('$1"' + $Language + '"'),
            1
        )
    }
    return [regex]::Replace($Html, '(?i)<html\b', ('<html lang="' + $Language + '"'), 1)
}

function Set-HtmlTitle {
    param(
        [Parameter(Mandatory)] [string]$Html,
        [Parameter(Mandatory)] [string]$Title
    )
    if ($Html -notmatch '(?is)<title>.*?</title>') {
        throw '报告缺少 title。'
    }
    return [regex]::Replace(
        $Html,
        '(?is)<title>.*?</title>',
        ('<title>' + (Encode-Html $Title) + '</title>'),
        1
    )
}

function Set-DocumentBody {
    param(
        [Parameter(Mandatory)] [string]$Html,
        [Parameter(Mandatory)] [string]$BodyFragment
    )
    if ($BodyFragment -notmatch '(?is)^\s*<main\b' -or $BodyFragment -notmatch '(?is)</main>\s*$') {
        throw '英文母稿必须是从 <main> 到 </main> 的完整 body 片段。'
    }
    if ($BodyFragment -match '(?is)<\/?(?:html|head|body|style|script)\b') {
        throw '英文母稿不得包含 html/head/body/style/script 标签。'
    }
    $pattern = '(?is)(?<open><body\b[^>]*>).*?(?<close></body>)'
    $match = [regex]::Match($Html, $pattern)
    if (-not $match.Success) {
        throw '报告缺少 body。'
    }
    return $Html.Substring(0, $match.Index) + $match.Groups['open'].Value + "`n" + $BodyFragment.Trim() + "`n" + $match.Groups['close'].Value + $Html.Substring($match.Index + $match.Length)
}

function Remove-SiteInjection {
    param([Parameter(Mandatory)] [string]$Html)
    foreach ($name in @('i18n-head', 'i18n-nav', 'issue-footer')) {
        $pattern = '(?is)\s*<!--\s*site:' + [regex]::Escape($name) + ':start\s*-->.*?<!--\s*site:' + [regex]::Escape($name) + ':end\s*-->\s*'
        $Html = [regex]::Replace($Html, $pattern, "`n")
    }
    return $Html
}

function Get-ReportExternalLinks {
    param([Parameter(Mandatory)] [string]$Html)
    return @(
        [regex]::Matches($Html, '(?is)\bhref\s*=\s*[\x22\x27](?<url>https?://[^\x22\x27]+)[\x22\x27]') |
            ForEach-Object { [System.Net.WebUtility]::HtmlDecode($_.Groups['url'].Value) } |
            Sort-Object -Unique
    )
}

function Get-ReportClassCount {
    param(
        [Parameter(Mandatory)] [string]$Html,
        [Parameter(Mandatory)] [string]$ClassName
    )
    return [regex]::Matches(
        $Html,
        '(?is)\bclass\s*=\s*[\x22\x27][^\x22\x27]*\b' + [regex]::Escape($ClassName) + '\b[^\x22\x27]*[\x22\x27]'
    ).Count
}

function Assert-EnglishBodyFragment {
    param(
        [Parameter(Mandatory)] [string]$BodyFragment,
        [Parameter(Mandatory)] [string]$SourceHtml,
        [Parameter(Mandatory)] [string]$DateIso
    )
    if ($BodyFragment -notmatch '(?is)^\s*<main\b' -or $BodyFragment -notmatch '(?is)</main>\s*$') {
        throw "$DateIso 英文母稿不是完整 main 片段。"
    }
    if ($BodyFragment -match '[\u3400-\u9fff]') {
        $sample = [regex]::Match($BodyFragment, '.{0,24}[\u3400-\u9fff].{0,24}', [System.Text.RegularExpressions.RegexOptions]::Singleline).Value
        throw "$DateIso 英文母稿仍含中文：$sample"
    }
    foreach ($className in @('hero', 'section', 'signal', 'sources')) {
        $sourceCount = Get-ReportClassCount -Html $SourceHtml -ClassName $className
        $translationCount = Get-ReportClassCount -Html $BodyFragment -ClassName $className
        if ($sourceCount -ne $translationCount) {
            throw "$DateIso 结构数量不一致：$className 中文=$sourceCount 英文=$translationCount"
        }
    }
    $sourceLinks = @(Get-ReportExternalLinks -Html $SourceHtml)
    $translationLinks = @(Get-ReportExternalLinks -Html $BodyFragment)
    if (($sourceLinks -join "`n") -ne ($translationLinks -join "`n")) {
        throw "$DateIso 中英文外部来源链接集合不一致。"
    }
    foreach ($required in @('target="_blank"', 'rel="noopener"')) {
        if ($translationLinks.Count -gt 0 -and $BodyFragment.IndexOf($required, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "$DateIso 英文母稿缺少外链安全属性：$required"
        }
    }
}

function Add-ReportSiteChrome {
    param(
        [Parameter(Mandatory)] [string]$Html,
        [Parameter(Mandatory)] [ValidateSet('zh-CN', 'en-US')] [string]$Language,
        [Parameter(Mandatory)] [string]$BaseUrl,
        [Parameter(Mandatory)] [string]$BasePath,
        [Parameter(Mandatory)] [string]$DateIso,
        [Parameter(Mandatory)] [string]$ChinesePath,
        [Parameter(Mandatory)] [string]$EnglishPath,
        [AllowEmptyString()] [string]$PreviousPath = '',
        [AllowEmptyString()] [string]$NextPath = ''
    )
    $Html = Remove-SiteInjection -Html $Html
    $Html = Set-HtmlLanguage -Html $Html -Language $Language
    $base = $BaseUrl.TrimEnd('/')
    $sitePath = '/' + $BasePath.Trim('/')
    $canonicalPath = if ($Language -eq 'zh-CN') { $ChinesePath } else { $EnglishPath }
    $canonicalUrl = $base + $canonicalPath
    $head = @"
<!-- site:i18n-head:start -->
<link rel="canonical" href="$(Encode-Html $canonicalUrl)">
<link rel="alternate" hreflang="zh-CN" href="$(Encode-Html ($base + $ChinesePath))">
<link rel="alternate" hreflang="en" href="$(Encode-Html ($base + $EnglishPath))">
<link rel="alternate" hreflang="x-default" href="$(Encode-Html ($base + $ChinesePath))">
<meta property="og:locale" content="$(if ($Language -eq 'zh-CN') { 'zh_CN' } else { 'en_US' })">
<meta property="og:url" content="$(Encode-Html $canonicalUrl)">
<link rel="icon" type="image/png" href="$sitePath/assets/alux-mark.png">
<link rel="apple-touch-icon" href="$sitePath/assets/alux-mark.png">
<link rel="stylesheet" href="$sitePath/assets/report-site.css">
<!-- site:i18n-head:end -->
"@
    if ($Html -notmatch '(?i)</head>') {
        throw "$DateIso 报告缺少 </head>。"
    }
    $Html = [regex]::Replace($Html, '(?i)</head>', ($head + "`n</head>"), 1)

    if ($Language -eq 'zh-CN') {
        $homePath = $sitePath + '/'
        $latestPath = $sitePath + '/latest/'
        $brand = 'ALUX AI智能体情报日报'
        $brandTagline = 'AI Agent Intelligence Daily'
        $latestLabel = '最新一期'
        $archiveLabel = '历史归档'
        $languageLabel = '语言切换'
        $chineseCurrent = ' aria-current="page"'
        $englishCurrent = ''
        $previousLabel = '← 上一期'
        $nextLabel = '下一期 →'
        $footerBrand = 'ALUX AI智能体情报日报'
    } else {
        $homePath = $sitePath + '/en/'
        $latestPath = $sitePath + '/en/latest/'
        $brand = 'ALUX AI Agent Intelligence Daily'
        $brandTagline = 'Signals for Agent Infrastructure'
        $latestLabel = 'Latest'
        $archiveLabel = 'Archive'
        $languageLabel = 'Language switcher'
        $chineseCurrent = ''
        $englishCurrent = ' aria-current="page"'
        $previousLabel = '← Previous Issue'
        $nextLabel = 'Next Issue →'
        $footerBrand = 'ALUX AI Agent Intelligence Daily'
    }

    $nav = @"
<!-- site:i18n-nav:start -->
<header class="report-sitebar">
  <a class="report-sitebrand" href="$homePath"><span class="report-sitebrand-copy"><span>$(Encode-Html $brand)</span><small>$(Encode-Html $brandTagline)</small></span></a>
  <nav class="report-sitenav" aria-label="$(Encode-Html $archiveLabel)">
    <a href="$latestPath">$(Encode-Html $latestLabel)</a>
    <a href="$homePath#archive">$(Encode-Html $archiveLabel)</a>
    <span class="language-switch" aria-label="$(Encode-Html $languageLabel)">
      <a href="$ChinesePath" lang="zh-CN"$chineseCurrent>中文</a>
      <a href="$EnglishPath" lang="en"$englishCurrent>EN</a>
    </span>
  </nav>
</header>
<!-- site:i18n-nav:end -->
"@
    if ($Html -notmatch '(?i)<body\b[^>]*>') {
        throw "$DateIso 报告缺少 body。"
    }
    $Html = [regex]::Replace($Html, '(?i)<body\b[^>]*>', { param($m) $m.Value + "`n" + $nav }, 1)

    $previousMarkup = if ($PreviousPath) {
        '<a rel="prev" href="' + (Encode-Html $PreviousPath) + '">' + (Encode-Html $previousLabel) + '</a>'
    } else {
        '<span>' + (Encode-Html $previousLabel) + '</span>'
    }
    $nextMarkup = if ($NextPath) {
        '<a rel="next" href="' + (Encode-Html $NextPath) + '">' + (Encode-Html $nextLabel) + '</a>'
    } else {
        '<span>' + (Encode-Html $nextLabel) + '</span>'
    }
    $footer = @"
<!-- site:issue-footer:start -->
<footer class="report-sitefooter">
  <nav class="issue-nav" aria-label="$(Encode-Html $archiveLabel)">$previousMarkup$nextMarkup</nav>
  <a href="$homePath">$(Encode-Html $footerBrand) · $DateIso</a>
</footer>
<!-- site:issue-footer:end -->
"@
    if ($Html -notmatch '(?i)</body>') {
        throw "$DateIso 报告缺少 </body>。"
    }
    return [regex]::Replace($Html, '(?i)</body>', ($footer + "`n</body>"), 1)
}
