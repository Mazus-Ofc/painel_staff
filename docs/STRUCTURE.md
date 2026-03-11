# MZ Staff Panel — estrutura modular

## Pastas principais

- `config/` → configuração central do painel.
- `client/core/` → estado compartilhado do client.
- `client/modules/` → lógica separada por tema (UI, spectate, visual, jogador, veículo, noclip).
- `client/commands/` → comandos/recursos específicos do client, como wall.
- `server/main.lua` → núcleo do servidor e roteamento principal das ações.
- `server/commands/` → comandos separados por categoria.
- `sql/` → instalação e preparação do banco.
- `html/js/` → NUI separada por estado, utilitários, renderização e formulários/eventos.

## Ordem sugerida para editar

1. `config/config.lua`
2. `server/commands/` ou `client/modules/`
3. `server/main.lua` apenas quando a mudança afetar regras centrais
4. `html/js/` para NUI
5. `sql/install.sql` para banco

## Observação

Essa versão prioriza **segurança na reorganização**: a lógica sensível do servidor foi mantida no núcleo, enquanto client/NUI/comandos foram separados para facilitar manutenção sem quebrar o painel.
