param([string]$Output = "dist/windows", [switch]$SkipEngine)
$ErrorActionPreference = 'Stop'
$Project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Project
$Output = [IO.Path]::GetFullPath($Output)
$Package = Join-Path $Output 'Mantimento-0.3.0-preview.1-Windows-x64'
$EngineCommit = 'cd959bae99ff4bed22bef2604f45241c09bbb8c8'
$Build = Join-Path $env:TEMP 'mantimento-engine-build'
$Source = Join-Path $Build 'llama.cpp'
function Checked([scriptblock]$Command) { & $Command; if ($LASTEXITCODE -ne 0) { throw "Comando falhou: $Command" } }
New-Item $Package -ItemType Directory -Force | Out-Null
Checked { dotnet publish windows/Mantimento.Windows/Mantimento.Windows.csproj -c Release -r win-x64 --self-contained true -o $Package --nologo }
if (-not $SkipEngine) {
 New-Item $Build -ItemType Directory -Force | Out-Null
 if (-not (Test-Path "$Source/.git")) { Checked { git clone --filter=blob:none --no-checkout https://github.com/ggml-org/llama.cpp.git $Source } }
 Checked { git -C $Source fetch --depth 1 origin $EngineCommit }
 Checked { git -C $Source checkout --detach $EngineCommit }
 $actual = (git -C $Source rev-parse HEAD).Trim()
 if ($actual -ne $EngineCommit) { throw 'Revisão do motor não confere.' }
 foreach ($backend in @('cpu','vulkan')) {
  if ($backend -eq 'vulkan' -and -not $env:VULKAN_SDK) { throw 'Defina VULKAN_SDK para compilar a opção GPU.' }
  $NativeBuild = Join-Path $Build $backend
  $Vulkan = if ($backend -eq 'vulkan') { 'ON' } else { 'OFF' }
  Checked { cmake -S $Source -B $NativeBuild -A x64 `
   -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded -DBUILD_SHARED_LIBS=OFF `
   -DGGML_NATIVE=OFF -DGGML_AVX=OFF -DGGML_AVX2=OFF -DGGML_AVX512=OFF `
   -DGGML_AVX_VNNI=OFF -DGGML_BMI2=OFF -DGGML_FMA=OFF -DGGML_F16C=OFF -DGGML_SSE42=OFF `
   -DGGML_CPU_ALL_VARIANTS=OFF -DGGML_BACKEND_DL=OFF -DGGML_OPENMP=OFF -DGGML_VULKAN=$Vulkan `
   -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_APP=OFF `
   -DLLAMA_BUILD_UI=OFF -DLLAMA_USE_PREBUILT_UI=OFF -DLLAMA_OPENSSL=OFF -DLLAMA_BUILD_SERVER=ON }
  Checked { cmake --build $NativeBuild --config Release --target llama-server --parallel 2 }
  $Destination = Join-Path $Package "engine/$backend"
  New-Item $Destination -ItemType Directory -Force | Out-Null
  Copy-Item "$NativeBuild/bin/Release/llama-server.exe" $Destination -Force
  Get-ChildItem "$NativeBuild/bin/Release" -Filter *.dll | Copy-Item -Destination $Destination -Force
  $hashes = [ordered]@{}
  Get-ChildItem $Destination -File | Where-Object { $_.Extension -in @('.exe','.dll') } | ForEach-Object { $hashes[$_.Name] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
  $hashes | ConvertTo-Json | Set-Content "$Destination/manifest.json" -Encoding utf8
  Copy-Item "$Source/LICENSE" "$Destination/LICENSE-llama.cpp.txt"
 }
}
Copy-Item windows/LEIA-ME-WINDOWS.md "$Package/LEIA-ME.md" -Force
Copy-Item windows/THIRD-PARTY.md "$Package/THIRD-PARTY.md" -Force
Copy-Item "$Package/engine/cpu/LICENSE-llama.cpp.txt" "$Package/LICENSE-llama.cpp.txt" -Force
$manifest = [ordered]@{ version='0.3.0-preview.1'; platform='Windows-x64'; engine='llama.cpp'; engineCommit=$EngineCommit; cpu='SSE2 baseline, sem exigir AVX/AVX2'; gpu='Vulkan experimental' }
$manifest | ConvertTo-Json | Set-Content "$Package/build-info.json" -Encoding utf8
$notices = Join-Path $Package 'third-party-notices'
New-Item $notices -ItemType Directory -Force | Out-Null
$nuget = if ($env:NUGET_PACKAGES) { $env:NUGET_PACKAGES } else { Join-Path $env:USERPROFILE '.nuget/packages' }
foreach ($name in @('microsoft.netcore.app.runtime.win-x64','microsoft.windowsdesktop.app.runtime.win-x64')) {
 $installed = Get-ChildItem (Join-Path $nuget $name) -Directory | Sort-Object Name -Descending | Select-Object -First 1
 if (-not $installed) { throw "Licenças do runtime ausentes: $name" }
 $destination = Join-Path $notices $name
 New-Item $destination -ItemType Directory -Force | Out-Null
 Get-ChildItem $installed.FullName -File | Where-Object { $_.Name -match '(?i)license|third.party|notice' } | Copy-Item -Destination $destination -Force
 if (-not (Get-ChildItem $destination -File)) { throw "Avisos legais do runtime ausentes: $name" }
}
$Archive = "$Package.zip"
Compress-Archive -Path $Package -DestinationPath $Archive -Force
$sha = (Get-FileHash $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$sha  $([IO.Path]::GetFileName($Archive))" | Set-Content "$Archive.sha256" -Encoding ascii
Write-Output "Pacote: $Archive"
