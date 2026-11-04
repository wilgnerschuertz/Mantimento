# Windows x64 · CPU e GPU

Aplicação Windows nativa em WPF/.NET 10, com núcleo separado e motores llama.cpp CPU/Vulkan. A versão Mac SwiftUI/MLX permanece independente.

Veja [LEIA-ME-WINDOWS.md](LEIA-ME-WINDOWS.md) para instalação, requisitos, dados e limitações.

## Desenvolvimento

Requer .NET SDK 10, Visual Studio Build Tools para C++ e CMake no Windows x64. Para o motor GPU, instale o SDK Vulkan e defina `VULKAN_SDK`.

```powershell
dotnet run --project windows/Mantimento.Tests -c Release
./windows/scripts/build.ps1
```

O script gera `dist/windows/Mantimento-0.3.0-preview.1-Windows-x64.zip` e SHA-256. O pacote é self-contained: quem baixa não instala o SDK nem o runtime .NET separadamente.

O workflow `.github/workflows/windows.yml` compila a partir de uma revisão fixa do llama.cpp, gera motores sem AVX/AVX2, testa o núcleo, renderiza a interface e verifica inferência com um modelo real. GPU física não está disponível no runner hospedado; o modo Automático também verifica o caminho de fallback. Os artefatos só são enviados se os testes passarem.

O núcleo e a compilação Windows podem ser verificados a partir de um Mac com o SDK .NET; a aplicação WPF e o executável x64 precisam de Windows para rodar. Não use uma compilação cruzada como evidência de funcionamento na máquina final.
