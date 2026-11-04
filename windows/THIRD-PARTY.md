# Componentes distribuídos

- **.NET / Windows Desktop Runtime (Microsoft):** runtime incluído pela publicação self-contained. Licenças e avisos são copiados dos pacotes oficiais para `third-party-notices` no artefato.
- **llama.cpp / GGML:** revisão `cd959bae99ff4bed22bef2604f45241c09bbb8c8` (v0.9.0), licença MIT incluída em `LICENSE-llama.cpp.txt`. Motores CPU e Vulkan compilados a partir do código oficial.
- **Vulkan:** o SDK oficial LunarG é uma dependência de compilação; não é exigido do usuário nem redistribuído. O modo GPU depende do driver Vulkan da placa.
- **Modelos:** não são incluídos no ZIP. O catálogo aponta para conversões GGUF de `unsloth/Qwen3.5-0.8B-GGUF`, `unsloth/Qwen3.5-2B-GGUF` e `unsloth/Qwen3.5-9B-GGUF`, com revisão e SHA-256 fixados. Consulte as licenças e model cards no Hugging Face antes de redistribuir os pesos.

Fontes oficiais: https://github.com/dotnet/runtime · https://github.com/dotnet/wpf · https://github.com/ggml-org/llama.cpp · https://vulkan.lunarg.com/
