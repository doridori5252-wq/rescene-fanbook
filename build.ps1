# data.json 내용을 화면 틀(src/template.html)에 넣어 웹용 index.html 과 앱용 app/www/index.html 을 만듭니다.
# 정보만 바꿀 때는 data.json 만 고치고 push 하면 설치된 앱도 다음 실행 때 새 정보를 받아옵니다.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$u = New-Object Text.UTF8Encoding $false
$tpl  = [IO.File]::ReadAllText("$root\src\template.html", $u)
$data = [IO.File]::ReadAllText("$root\data.json", $u)
$null = $data | ConvertFrom-Json   # JSON 형식이 틀리면 여기서 멈춥니다
$body = $tpl.Replace("__SEED__", $data.Trim())
$head = @"
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#191b2a">
<link rel="icon" href="ICON">
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>
</head>
<body>

"@
$tail = "`n</body>`n</html>`n"
[IO.File]::WriteAllText("$root\index.html", $head.Replace("ICON","app/res/icon.png") + $body + $tail, $u)
New-Item -ItemType Directory -Force "$root\app\www" | Out-Null
[IO.File]::WriteAllText("$root\app\www\index.html", $head.Replace("ICON","icon.png") + $body + $tail, $u)
Copy-Item "$root\app\res\icon.png" "$root\app\www\icon.png" -Force
Copy-Item "$root\data.json" "$root\app\www\data.json" -Force
# 미리보기·게시용 (문서 틀 없이 본문만)
[IO.File]::WriteAllText("$root\dist-body.html", $body, $u)
Write-Output "built"
