# Vérifie la syntaxe des blocs <script> inline de index.html (node --check).
# Usage : .\check.ps1   (code de sortie = nombre de blocs en erreur)
$h = Get-Content -Raw -Encoding utf8 "$PSScriptRoot\index.html"
$ms = [regex]::Matches($h, '(?s)<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>')
$dir = Join-Path $env:TEMP 'flux-check'
New-Item -ItemType Directory -Force $dir | Out-Null
$fail = 0
for ($i = 0; $i -lt $ms.Count; $i++) {
  $f = Join-Path $dir "bloc$i.js"
  Set-Content -Encoding utf8 $f $ms[$i].Groups[1].Value
  node --check $f
  if ($LASTEXITCODE -ne 0) { $fail++; "bloc $i : ERREUR" } else { "bloc $i : OK" }
}
exit $fail
