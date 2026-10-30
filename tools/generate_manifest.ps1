# Generates data/json/videos.json — the media manifest used by the app's
# downloader (stream URLs, download-all, update-check, verification).
#
# Output shape (flat — the dictionary has no lesson grouping):
# {
#   "version": "<generatedAt UTC>",
#   "totalFiles": N, "totalBytes": N,
#   "videos": [ {"n":"12345B","size":123,"sha256":"..."} ]
# }
#
# JSON is built with StringBuilder (ConvertTo-Json misbehaves on PS5.1 with
# nested generic lists) and written UTF-8 WITHOUT BOM, which would otherwise
# break Flutter's jsonDecode.
Set-Location $PSScriptRoot\..

$files = Get-ChildItem 'data\videos\*.mp4' | Sort-Object Name
if (-not $files) { throw 'no videos found' }

$totalBytes = [long]0
$entries = New-Object System.Collections.Generic.List[string]

foreach ($f in $files) {
  $sha = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLower()
  $n = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $totalBytes += [long]$f.Length
  $entries.Add('{"n":"' + $n + '","size":' + [long]$f.Length + ',"sha256":"' + $sha + '"}') | Out-Null
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('{"version":"')
[void]$sb.Append((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))
[void]$sb.Append('","totalFiles":'); [void]$sb.Append($entries.Count)
[void]$sb.Append(',"totalBytes":'); [void]$sb.Append($totalBytes)
[void]$sb.Append(',"videos":[')
[void]$sb.Append([string]::Join(',', $entries))
[void]$sb.Append(']}')

[IO.File]::WriteAllText("$PWD\data\json\videos.json", $sb.ToString(), [Text.UTF8Encoding]::new($false))
"videos.json written: $($entries.Count) files, $([long]($totalBytes/1MB)) MB"
