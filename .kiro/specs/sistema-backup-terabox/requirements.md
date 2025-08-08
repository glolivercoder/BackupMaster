# Requirements Document

## Introduction

Este documento define os requisitos para um sistema de backup automatizado integrado ao Terabox. O sistema deve criar arquivos ZIP protegidos por senha, gerenciar essas senhas internamente, enviar notificações por email via Gmail com listas atualizadas de backups, e fornecer funcionalidades de busca e histórico com formatação brasileira de data/hora.

## Requirements

### Requirement 1

**User Story:** Como usuário, eu quero que o sistema crie backups automaticamente em formato ZIP com senha, para que meus dados estejam protegidos e compactados.

#### Acceptance Criteria

1. WHEN o usuário solicita um backup THEN o sistema SHALL criar um arquivo ZIP do diretório especificado
2. WHEN o arquivo ZIP é criado THEN o sistema SHALL protegê-lo com uma senha gerada automaticamente
3. WHEN o backup é criado THEN o sistema SHALL nomear o arquivo no formato "nome_do_diretorio_DD-MM-AAAA_HH-MM-SS.zip"
4. WHEN a senha é gerada THEN o sistema SHALL armazenar a senha de forma segura na aplicação

### Requirement 2

**User Story:** Como usuário, eu quero que o sistema se integre ao Terabox, para que meus backups sejam armazenados na nuvem automaticamente.

#### Acceptance Criteria

1. WHEN um backup ZIP é criado THEN o sistema SHALL fazer upload do arquivo para o Terabox
2. WHEN o upload é concluído THEN o sistema SHALL confirmar o armazenamento bem-sucedido
3. IF o upload falhar THEN o sistema SHALL tentar novamente até 3 vezes
4. WHEN o upload falha definitivamente THEN o sistema SHALL notificar o usuário do erro

### Requirement 3

**User Story:** Como usuário, eu quero receber emails com a lista atualizada de backups e suas senhas, para que eu tenha controle sobre meus backups.

#### Acceptance Criteria

1. WHEN um novo backup é criado THEN o sistema SHALL enviar um email via Gmail
2. WHEN o email é enviado THEN o sistema SHALL incluir a lista completa de backups existentes
3. WHEN o email é enviado THEN o sistema SHALL incluir as respectivas senhas de cada backup
4. WHEN o email é enviado THEN o sistema SHALL usar formatação clara e organizada
5. IF o envio de email falhar THEN o sistema SHALL tentar reenviar até 2 vezes

### Requirement 4

**User Story:** Como usuário, eu quero buscar backups específicos, para que eu possa encontrar rapidamente o backup que preciso.

#### Acceptance Criteria

1. WHEN o usuário digita um termo de busca THEN o sistema SHALL procurar por nome do backup
2. WHEN o usuário digita um termo de busca THEN o sistema SHALL procurar por data de criação
3. WHEN resultados são encontrados THEN o sistema SHALL exibir nome, data/hora e senha do backup
4. WHEN nenhum resultado é encontrado THEN o sistema SHALL informar "Nenhum backup encontrado"
5. WHEN o usuário busca por data THEN o sistema SHALL aceitar formato DD/MM/AAAA ou DD-MM-AAAA

### Requirement 5

**User Story:** Como usuário, eu quero visualizar o histórico completo de backups com data e hora em formato brasileiro, para que eu tenha controle cronológico dos meus backups.

#### Acceptance Criteria

1. WHEN o usuário acessa o histórico THEN o sistema SHALL exibir todos os backups em ordem cronológica decrescente
2. WHEN o histórico é exibido THEN o sistema SHALL mostrar data e hora no formato DD/MM/AAAA HH:MM:SS
3. WHEN o histórico é exibido THEN o sistema SHALL mostrar nome do backup, tamanho do arquivo e status
4. WHEN o usuário clica em um backup THEN o sistema SHALL exibir detalhes incluindo a senha
5. WHEN o histórico está vazio THEN o sistema SHALL exibir "Nenhum backup encontrado"

### Requirement 6

**User Story:** Como usuário, eu quero que o sistema gerencie senhas de forma segura, para que minhas senhas de backup estejam protegidas.

#### Acceptance Criteria

1. WHEN uma senha é gerada THEN o sistema SHALL usar pelo menos 12 caracteres alfanuméricos
2. WHEN uma senha é armazenada THEN o sistema SHALL criptografá-la antes do armazenamento
3. WHEN uma senha é recuperada THEN o sistema SHALL descriptografá-la apenas quando necessário
4. WHEN o sistema é reiniciado THEN o sistema SHALL manter todas as senhas armazenadas
5. IF o banco de senhas for corrompido THEN o sistema SHALL criar backup das senhas em arquivo separado

### Requirement 7

**User Story:** Como usuário, eu quero que o sistema tenha uma interface intuitiva, para que eu possa usar todas as funcionalidades facilmente.

#### Acceptance Criteria

1. WHEN o usuário abre a aplicação THEN o sistema SHALL exibir menu principal com todas as opções
2. WHEN o usuário seleciona "Criar Backup" THEN o sistema SHALL permitir seleção de diretório
3. WHEN o usuário seleciona "Buscar Backup" THEN o sistema SHALL exibir campo de busca
4. WHEN o usuário seleciona "Histórico" THEN o sistema SHALL exibir lista de backups
5. WHEN uma operação está em andamento THEN o sistema SHALL exibir barra de progresso
6. WHEN uma operação é concluída THEN o sistema SHALL exibir mensagem de confirmação