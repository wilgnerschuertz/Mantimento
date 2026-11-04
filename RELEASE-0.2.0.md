# Mantimento 0.2.0 — catálogo e kit offline

Candidata a testes; não substitui a 0.1.1 publicada até a próxima publicação.

- Catálogo com Qwen3.5 2B/4B/9B, Llama 3.2 3B e Phi-4 Mini em MLX 4 bits.
- Busca por nome/finalidade, filtro de família, tamanho aproximado, RAM sugerida e estado de validação.
- Download fixado na revisão consultada, verificação de espaço, bytes presentes no cache e possibilidade de tentar novamente aproveitando o cache do Hugging Face.
- Remoção recuperável pela Lixeira. O cache compartilhado do Hugging Face pode manter blobs; o aplicativo não limpa dados de outros modelos.
- Templates de bugs e sugestões no GitHub e roteiro TESTES-BETA.md.
- Kit offline com aplicativo, Python gerenciado, wheels e modelos baixados. Restauração cria um ambiente novo em vez de copiar venv com caminhos antigos.

## Kit offline

Em Modelos e ajustes, execute **Preparar pacotes (internet)** e depois **Exportar kit** com o servidor desligado. Escolha uma pasta fora dos dados do Mantimento e com espaço para vários GB. O kit é uma pasta, não um ZIP.

Conversas e documentos internos ficam excluídos por padrão. A opção de incluir dados pessoais copia conversations.json, history.json e Workspaces. Documentos de pastas externas ficam de fora. Caminhos de conversas importadas podem exigir selecionar a pasta novamente. O kit não é criptografado.

No Mac de destino Apple Silicon, execute no Terminal `bash restaurar.sh` dentro do kit. O destino padrão é `~/Library/Application Support/Mantimento` e deve estar ausente; para testes, passe uma pasta nova como argumento. O script recusa sobrescrever um destino existente, confere hashes e usa somente pacotes locais. Copie Mantimento.app para Aplicativos.

Não distribua modelos sem observar suas licenças. Assinatura ad hoc, sem notarização. Não há suporte Intel, Windows, Linux ou iOS nesta versão. Testes em outro Mac e macOS 14/15 continuam necessários.
