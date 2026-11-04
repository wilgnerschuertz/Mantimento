# Reuse only artifacts from successful push runs on this repository's main branch.
# PR artifacts are deliberately excluded. Every engine file is rehashed before use.
$ErrorActionPreference = 'Stop'
if (-not $env:GITHUB_TOKEN -or -not $env:GITHUB_REPOSITORY) { exit 0 }
$api = "https://api.github.com/repos/$env:GITHUB_REPOSITORY"
$headers = @{ Authorization = "Bearer $env:GITHUB_TOKEN"; Accept = 'application/vnd.github+json' }
try {
 $runs = Invoke-RestMethod "$api/actions/workflows/windows.yml/runs?event=push&branch=main&status=success&per_page=1" -Headers $headers
 if (-not $runs.workflow_runs.Count) { exit 0 }
 $run = $runs.workflow_runs[0]
 if ($run.head_repository.full_name -ne $env:GITHUB_REPOSITORY) { exit 0 }
 $artifacts = Invoke-RestMethod "$api/actions/runs/$($run.id)/artifacts" -Headers $headers
 $artifact = $artifacts.artifacts | Where-Object { $_.name -eq 'Mantimento-Windows-x64-preview' -and -not $_.expired } | Select-Object -First 1
 if (-not $artifact) { exit 0 }
 $temporary = Join-Path $env:RUNNER_TEMP ('mantimento-native-' + [guid]::NewGuid())
 New-Item $temporary -ItemType Directory | Out-Null
 Invoke-WebRequest "$api/actions/artifacts/$($artifact.id)/zip" -Headers $headers -OutFile "$temporary/artifact.zip"
 Expand-Archive "$temporary/artifact.zip" "$temporary/artifact"
 $zip = Get-ChildItem "$temporary/artifact" -Recurse -Filter 'Mantimento-0.3.0-preview.1-Windows-x64.zip' | Select-Object -First 1
 if (-not $zip) { exit 0 }
 $expected = ((Get-Content ($zip.FullName + '.sha256') -Raw).Trim() -split '\s+')[0]
 if ((Get-FileHash $zip.FullName -Algorithm SHA256).Hash -ne $expected) { throw 'Checksum do pacote anterior não confere.' }
 Expand-Archive $zip.FullName "$temporary/package"
 $package = "$temporary/package/Mantimento-0.3.0-preview.1-Windows-x64"
 $info = Get-Content "$package/build-info.json" -Raw | ConvertFrom-Json
 if ($info.engineCommit -ne 'cd959bae99ff4bed22bef2604f45241c09bbb8c8' -or $info.platform -ne 'Windows-x64' -or $info.cpu -ne 'SSE2 baseline, sem exigir AVX/AVX2') { exit 0 }
 foreach ($backend in @('cpu','vulkan')) {
  $folder = "$package/engine/$backend"
  $manifest = Get-Content "$folder/manifest.json" -Raw | ConvertFrom-Json -AsHashtable
  if (-not $manifest.ContainsKey('llama-server.exe')) { throw 'Manifesto incompleto.' }
  foreach ($file in $manifest.Keys) {
   if ([IO.Path]::GetFileName($file) -ne $file -or (Get-FileHash "$folder/$file" -Algorithm SHA256).Hash -ne $manifest[$file]) { throw 'Integridade do motor anterior inválida.' }
  }
 }
 $output = Join-Path $env:GITHUB_WORKSPACE 'dist/windows/Mantimento-0.3.0-preview.1-Windows-x64'
 New-Item $output -ItemType Directory -Force | Out-Null
 Copy-Item "$package/engine" "$output/engine" -Recurse -Force
 "reused=true" >> $env:GITHUB_OUTPUT
 Write-Output "Motores verificados reaproveitados do run $($run.id). A aplicação e os testes serão recompilados."
} catch {
 Write-Warning "Reutilização indisponível; compilando motores a partir do código oficial. $($_.Exception.Message)"
}
