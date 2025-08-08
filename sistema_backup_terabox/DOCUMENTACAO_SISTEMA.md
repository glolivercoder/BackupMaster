# 📚 Documentação do Sistema BackupMaster

## 🎯 **Visão Geral**

O BackupMaster é um sistema completo de backup automatizado que integra com Terabox e Gmail, desenvolvido em Flutter para Windows. O sistema cria arquivos ZIP protegidos por senha, faz upload para a nuvem e envia relatórios detalhados por email.

---

## 🏗️ **Arquitetura do Sistema**

### **Padrão MVVM (Model-View-ViewModel)**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   View Layer    │◄──►│  ViewModel      │◄──►│   Model Layer   │
│ (Flutter UI)    │    │  (Provider)     │    │ (Services/Data) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Estrutura de Diretórios**

```
lib/
├── main.dart                 # Ponto de entrada da aplicação
├── models/                   # Modelos de dados (gerados pelo Drift)
├── views/                    # Interfaces de usuário (Pages)
│   ├── home_page.dart       # Dashboard principal
│   ├── search_page.dart     # Busca interativa de backups
│   ├── history_page.dart    # Histórico de backups
│   └── settings_page.dart   # Configurações do sistema
├── viewmodels/              # Lógica de apresentação
│   ├── backup_viewmodel.dart
│   ├── search_viewmodel.dart
│   └── history_viewmodel.dart
├── services/                # Serviços de negócio
│   ├── backup_service.dart  # Criação e gerenciamento de backups
│   ├── terabox_service.dart # Integração com Terabox (OAuth2)
│   ├── gmail_service.dart   # Envio de emails
│   ├── password_manager.dart # Gerenciamento seguro de senhas
│   └── database.dart        # Banco de dados local (Drift/SQLite)
└── utils/                   # Utilitários
    └── app_theme.dart       # Tema escuro e paleta de cores
```

---

## 🎨 **Design System**

### **Paleta de Cores**

| Cor | Código | Uso |
|-----|--------|-----|
| **Verde** | `#4CAF50` | Ações principais, sucesso |
| **Azul** | `#2196F3` | Ações secundárias, informações |
| **Laranja** | `#FF9800` | Alertas, senhas |
| **Ciano** | `#00BCD4` | Destaques, tamanhos |
| **Vermelho** | `#F44336` | Erros, exclusões |

### **Tema Escuro**

- **Background**: `#121212`
- **Surface**: `#1E1E1E`
- **Cards**: `#2C2C2C`
- **Texto Primário**: `#FFFFFF`
- **Texto Secundário**: `#B0B0B0`

---

## 🔧 **Funcionalidades Principais**

### **1. Criação de Backups**

- **Seleção de Diretório**: Interface moderna com file_picker
- **Compactação ZIP**: Usando package `archive`
- **Proteção por Senha**: Senhas de 12+ caracteres alfanuméricos
- **Nomenclatura Automática**: `nome_diretorio_DD-MM-AAAA_HH-MM-SS.zip`
- **Validação de Integridade**: Checksum MD5

### **2. Integração com Terabox (OAuth2)**

- **Autenticação Real**: OAuth2 completo implementado
- **Upload Automático**: Arquivos enviados para a nuvem
- **Sistema de Retry**: 3 tentativas em caso de falha
- **Gerenciamento de Quota**: Verificação de espaço disponível

### **3. Sistema de Email (Gmail)**

- **Autenticação por Senha de App**: Segurança aprimorada
- **Relatórios HTML**: Templates responsivos
- **Lista de Backups**: Inclui senhas e metadados
- **Sistema de Retry**: 2 tentativas para envio

### **4. Busca Interativa**

- **Busca em Tempo Real**: Resultados instantâneos
- **Autocompletar**: Sugestões baseadas em backups existentes
- **Histórico de Buscas**: Últimas 10 buscas salvas
- **Filtros Rápidos**: Por data (hoje, semana, mês) e tamanho
- **Cópia de Senha**: Um clique para copiar para clipboard

### **5. Gerenciamento de Senhas**

- **Geração Segura**: Algoritmo criptograficamente seguro
- **Criptografia AES**: Armazenamento protegido
- **Backup Automático**: Arquivo separado para recuperação
- **Limpeza de Clipboard**: Remoção automática após 30s

---

## 🗄️ **Banco de Dados**

### **Esquema SQLite (Drift)**

#### **Tabela: backups**
```sql
CREATE TABLE backups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    original_path TEXT NOT NULL,
    zip_path TEXT,
    terabox_url TEXT,
    password_hash TEXT NOT NULL,
    file_size INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'creating',
    checksum TEXT
);
```

#### **Tabela: email_logs**
```sql
CREATE TABLE email_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_id TEXT,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    recipient TEXT,
    status TEXT,
    error_message TEXT
);
```

#### **Tabela: password_logs**
```sql
CREATE TABLE password_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_id TEXT,
    password_generated TEXT,
    password_hash TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    test_result TEXT,
    validation_status TEXT DEFAULT 'pending'
);
```

---

## 🔐 **Segurança**

### **Criptografia de Senhas**

- **Algoritmo**: AES-256-GCM
- **Chave**: Derivada usando PBKDF2
- **Salt**: Único para cada senha
- **Verificação**: Hash SHA-256 para validação

### **Proteção de Dados**

- **Senhas ZIP**: Nunca armazenadas em texto plano
- **Clipboard**: Limpeza automática após uso
- **Logs**: Informações sensíveis mascaradas
- **OAuth2**: Tokens seguros com refresh automático

---

## 📱 **Interface do Usuário**

### **Página Principal (Home)**

- **Dashboard**: Estatísticas de backups
- **Ações Rápidas**: Botões para funcionalidades principais
- **Status do Sistema**: Indicadores de conectividade
- **Últimos Backups**: Lista dos 5 mais recentes

### **Página de Busca**

- **SearchBar Interativa**: 
  - Busca em tempo real
  - Autocompletar com sugestões
  - Histórico de buscas recentes
  - Contador de resultados
- **Filtros Rápidos**:
  - Por data (hoje, semana, mês)
  - Por tamanho (arquivos grandes >100MB)
- **Resultados**:
  - Cards modernos com informações completas
  - Cópia de senha com um clique
  - Abertura de pasta original
  - Abertura do ZIP com senha

### **Página de Histórico**

- **Lista Cronológica**: Backups em ordem decrescente
- **Formatação Brasileira**: DD/MM/AAAA HH:MM:SS
- **Informações Detalhadas**: Nome, tamanho, status, senha
- **Ações Rápidas**: Abrir, copiar senha, excluir

### **Página de Configurações**

- **Seção Terabox**: Configuração OAuth2
- **Seção Gmail**: Configuração de senha de app
- **Testes de Conectividade**: Validação em tempo real
- **Logs do Sistema**: Visualização de atividades
- **Manual de Autenticação**: Guia passo a passo

---

## 🔄 **Fluxo de Backup**

### **Processo Completo**

1. **Seleção**: Usuário escolhe diretório
2. **Validação**: Sistema verifica permissões e espaço
3. **Compactação**: Criação do arquivo ZIP com senha
4. **Armazenamento**: Salvamento local temporário
5. **Upload**: Envio para Terabox via OAuth2
6. **Registro**: Inserção no banco de dados
7. **Email**: Envio de relatório via Gmail
8. **Limpeza**: Remoção de arquivos temporários

### **Estados do Backup**

- `creating`: Criando arquivo ZIP
- `uploading`: Enviando para Terabox
- `completed`: Processo concluído com sucesso
- `failed`: Falha em alguma etapa
- `deleted`: Backup removido pelo usuário

---

## 🧪 **Sistema de Testes**

### **Testes de Senha**

- **Geração**: Validação de complexidade
- **Criptografia**: Teste de encrypt/decrypt
- **Integridade**: Verificação de hashes
- **Performance**: Tempo de processamento

### **Testes de Integração**

- **Terabox**: Upload e download de arquivos
- **Gmail**: Envio e formatação de emails
- **Banco de Dados**: CRUD operations
- **Interface**: Navegação e interações

---

## 📊 **Monitoramento e Logs**

### **Sistema de Logging**

- **Níveis**: DEBUG, INFO, WARNING, ERROR
- **Formato**: Timestamp, classe, nível, mensagem
- **Armazenamento**: Arquivo local rotativo
- **Visualização**: Interface na página Settings

### **Métricas**

- **Backups Criados**: Contador total
- **Taxa de Sucesso**: Percentual de uploads bem-sucedidos
- **Tempo Médio**: Duração do processo completo
- **Uso de Espaço**: Terabox e armazenamento local

---

## 🚀 **Instalação e Configuração**

### **Pré-requisitos**

- **Flutter SDK**: 3.0+
- **Dart SDK**: 3.0+
- **Windows**: 10/11
- **Conta Google**: Para Gmail e Terabox
- **Baidu Developer Account**: Para OAuth2 do Terabox

### **Configuração Inicial**

1. **Clone o repositório**
2. **Execute `flutter pub get`**
3. **Configure credenciais OAuth2** (veja OAUTH2_SETUP.md)
4. **Configure senha de app Gmail** (veja ManualdeAutenticacao.md)
5. **Execute `flutter run`**

---

## 🔧 **Manutenção**

### **Backup do Banco de Dados**

- **Automático**: A cada 100 operações
- **Manual**: Botão na página Settings
- **Localização**: Pasta Documents/BackupMaster/db_backups/

### **Limpeza de Arquivos**

- **Temporários**: Removidos após cada backup
- **Logs**: Rotação a cada 10MB
- **Cache**: Limpeza semanal automática

### **Atualizações**

- **Verificação**: Automática na inicialização
- **Download**: Manual pelo usuário
- **Migração**: Banco de dados versionado

---

## 🐛 **Troubleshooting**

### **Problemas Comuns**

#### **Erro de Autenticação Terabox**
- **Causa**: Credenciais OAuth2 inválidas
- **Solução**: Reconfigurar no Baidu Developer Console

#### **Email não enviado**
- **Causa**: Senha de app incorreta
- **Solução**: Gerar nova senha no Google Account

#### **Backup falha**
- **Causa**: Permissões de arquivo ou espaço insuficiente
- **Solução**: Verificar permissões e espaço em disco

### **Logs de Diagnóstico**

- **Localização**: Settings → Logs do Sistema
- **Filtros**: Por nível e data
- **Exportação**: Arquivo .txt para suporte

---

## 📈 **Roadmap**

### **Versão Atual (1.0)**
- ✅ Backup ZIP com senha
- ✅ Integração Terabox OAuth2
- ✅ Envio de emails Gmail
- ✅ Busca interativa
- ✅ Interface moderna

### **Próximas Versões**

#### **v1.1**
- 🔄 Backup incremental
- 🔄 Agendamento automático
- 🔄 Múltiplos destinos de nuvem

#### **v1.2**
- 🔄 Sincronização entre dispositivos
- 🔄 API REST para integração
- 🔄 Dashboard web

#### **v2.0**
- 🔄 Suporte Linux/macOS
- 🔄 Backup de bancos de dados
- 🔄 Criptografia end-to-end

---

## 📞 **Suporte**

### **Documentação Adicional**

- **Manual de Autenticação**: `ManualdeAutenticacao.md`
- **Configuração OAuth2**: `OAUTH2_SETUP.md`
- **Configuração Gmail**: `CONFIGURACAO_GMAIL_TERABOX.md`

### **Contato**

- **Issues**: GitHub Issues
- **Email**: suporte@backupmaster.com
- **Documentação**: Wiki do projeto

---

*Documentação atualizada em Janeiro 2025 - BackupMaster v1.0*