# Design Document

## Overview

O sistema de backup integrado ao Terabox será desenvolvido como uma aplicação desktop usando Flutter para Windows. A arquitetura seguirá o padrão MVVM (Model-View-ViewModel) com Provider para gerenciamento de estado. A interface terá design moderno com tema escuro e paleta de cores vibrantes (verde, azul, laranja, ciano). O sistema utilizará packages especializados para compactação ZIP, criptografia, integração com APIs de nuvem e envio de emails.

## Architecture

### Arquitetura MVVM Flutter
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   View Layer    │    │  ViewModel      │    │   Model Layer   │
│ (Flutter Widgets│◄──►│  (Provider/     │◄──►│   (Data &       │
│  + Dark Theme)  │    │   Notifier)     │    │   Services)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Flutter Widgets │    │   ViewModels    │    │   Services      │
│ - HomePage      │    │ - BackupVM      │    │ - BackupService │
│ - BackupPage    │    │ - SearchVM      │    │ - TeraboxAPI    │
│ - SearchPage    │    │ - HistoryVM     │    │ - EmailService  │
│ - HistoryPage   │    │ - SettingsVM    │    │ - CryptoService │
│ - SettingsPage  │    │                 │    │ - DatabaseSvc   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Fluxo de Dados Principal
1. **Interface do Usuário** → Captura ações do usuário
2. **Controller** → Processa lógica de negócio
3. **Services** → Executam operações específicas
4. **External APIs** → Integram com serviços externos
5. **Database** → Persiste dados e metadados

## Components and Interfaces

### 1. View Layer (Interface Flutter)

#### Tema Escuro Moderno
```dart
class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.green,
    scaffoldBackgroundColor: Color(0xFF121212),
    cardColor: Color(0xFF1E1E1E),
    colorScheme: ColorScheme.dark(
      primary: Colors.green,      // Verde para ações principais
      secondary: Colors.blue,     // Azul para ações secundárias  
      tertiary: Colors.orange,    // Laranja para alertas
      surface: Colors.cyan,       // Ciano para destaques
    ),
  );
}
```

#### Páginas Principais
- **HomePage**: Dashboard com estatísticas e ações rápidas
- **BackupPage**: Criação de backup com seletor de pasta moderno
- **SearchPage**: Busca avançada com filtros visuais
- **HistoryPage**: Lista de backups com cards modernos
- **SettingsPage**: Configurações de Terabox, Gmail e preferências

#### Widgets Customizados
- **ModernCard**: Cards com elevação e bordas arredondadas
- **ColoredButton**: Botões com cores da paleta (verde, azul, laranja, ciano)
- **ProgressIndicator**: Indicador de progresso com animações
- **SearchBar**: Campo de busca com ícones e sugestões
- **BackupListItem**: Item de lista com informações detalhadas

#### Design System - Paleta de Cores
```dart
class AppColors {
  // Cores principais
  static const Color primary = Color(0xFF4CAF50);      // Verde
  static const Color secondary = Color(0xFF2196F3);    // Azul
  static const Color accent = Color(0xFFFF9800);       // Laranja
  static const Color highlight = Color(0xFF00BCD4);    // Ciano
  
  // Tema escuro
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color cardColor = Color(0xFF2C2C2C);
  
  // Texto
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textDisabled = Color(0xFF757575);
}
```

#### Componentes de Interface Moderna
- **Dashboard Cards**: Cards com ícones coloridos e estatísticas
- **Floating Action Button**: FAB verde para criar novo backup
- **Bottom Navigation**: Navegação inferior com ícones coloridos
- **Snackbars**: Notificações com cores contextuais
- **Modal Dialogs**: Diálogos modernos com bordas arredondadas
- **Progress Cards**: Cards de progresso com animações fluidas

### 2. ViewModel Layer (Gerenciamento de Estado)

#### BackupViewModel
```dart
class BackupViewModel extends ChangeNotifier {
  Future<void> createBackup(String directoryPath);
  Future<void> uploadToTerabox(String filePath);
  void updateProgress(double progress);
  void setStatus(BackupStatus status);
}
```

#### SearchViewModel
```dart
class SearchViewModel extends ChangeNotifier {
  List<BackupRecord> searchResults = [];
  Future<void> searchBackups(String query, SearchFilters filters);
  void clearSearch();
  void applyFilters(SearchFilters filters);
}
```

#### HistoryViewModel
```dart
class HistoryViewModel extends ChangeNotifier {
  List<BackupRecord> backupHistory = [];
  Future<void> loadHistory();
  Future<void> deleteBackup(String backupId);
  void sortByDate(bool ascending);
}
```

#### SettingsViewModel
```dart
class SettingsViewModel extends ChangeNotifier {
  AppSettings settings;
  Future<void> saveTeraboxCredentials(TeraboxConfig config);
  Future<void> saveEmailSettings(EmailConfig config);
  Future<void> testConnections();
}
```

### 3. Model Layer (Dados e Serviços)

#### BackupService
```dart
class BackupService {
  Future<String> createZipWithPassword(String sourceDir, String outputPath, String password);
  Future<String> uploadToTerabox(String filePath);
  String generateBackupName(String directoryName);
  Future<bool> validateBackupIntegrity(String backupPath);
}
```

#### PasswordManager
```dart
class PasswordManager {
  String generateSecurePassword({int length = 12});
  Future<String> encryptPassword(String password);
  Future<String> decryptPassword(String encryptedPassword);
  Future<void> storePassword(String backupId, String password);
  Future<String> retrievePassword(String backupId);
}
```

#### DatabaseService
```dart
class DatabaseService {
  Future<void> initDatabase();
  Future<void> insertBackupRecord(BackupRecord backup);
  Future<List<BackupRecord>> searchBackups(String query, DateTimeRange? dateRange);
  Future<List<BackupRecord>> getBackupHistory();
  Future<void> updateBackupStatus(String backupId, BackupStatus status);
}
```

#### TeraboxAPI
```dart
class TeraboxAPI {
  Future<String> authenticate(String username, String password);
  Future<String> uploadFile(String filePath, String fileName);
  Future<List<CloudFile>> listFiles();
  Future<bool> deleteFile(String fileId);
}
```

## Data Models

### BackupRecord Model
```dart
class BackupRecord {
  final String id;
  final String name;
  final String originalPath;
  final String zipPath;
  final String teraboxUrl;
  final String passwordHash;
  final int fileSize;
  final DateTime createdAt;
  final BackupStatus status;
  final String checksum;
  
  BackupRecord({
    required this.id,
    required this.name,
    required this.originalPath,
    required this.zipPath,
    required this.teraboxUrl,
    required this.passwordHash,
    required this.fileSize,
    required this.createdAt,
    required this.status,
    required this.checksum,
  });
  
  factory BackupRecord.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### BackupStatus Enum
```dart
enum BackupStatus {
  creating('Criando'),
  uploading('Enviando'),
  completed('Concluído'),
  failed('Falhou'),
  deleted('Deletado');
  
  const BackupStatus(this.displayName);
  final String displayName;
}
```

### Configurações
```dart
class AppSettings {
  final TeraboxConfig teraboxConfig;
  final EmailConfig emailConfig;
  final UIPreferences uiPreferences;
  
  AppSettings({
    required this.teraboxConfig,
    required this.emailConfig,
    required this.uiPreferences,
  });
}

class TeraboxConfig {
  final String username;
  final String password;
  final String apiKey;
  
  TeraboxConfig({
    required this.username,
    required this.password,
    required this.apiKey,
  });
}

class EmailConfig {
  final String smtpServer;
  final int smtpPort;
  final String senderEmail;
  final String senderPassword;
  final String recipientEmail;
  
  EmailConfig({
    this.smtpServer = 'smtp.gmail.com',
    this.smtpPort = 587,
    required this.senderEmail,
    required this.senderPassword,
    required this.recipientEmail,
  });
}
```

## Database Schema

### Tabela: backups
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

### Tabela: email_logs
```sql
CREATE TABLE email_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_id TEXT,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    recipient TEXT,
    status TEXT,
    error_message TEXT,
    FOREIGN KEY (backup_id) REFERENCES backups (id)
);
```

## Error Handling

### Estratégia de Tratamento de Erros

#### 1. Erros de Criação de Backup
- **FileNotFoundError**: Diretório não existe
- **PermissionError**: Sem permissão de leitura
- **DiskSpaceError**: Espaço insuficiente
- **Ação**: Log do erro, notificação ao usuário, limpeza de arquivos temporários

#### 2. Erros de Upload (Terabox)
- **NetworkError**: Sem conexão com internet
- **AuthenticationError**: Credenciais inválidas
- **QuotaExceededError**: Cota de armazenamento excedida
- **Ação**: Retry automático (3 tentativas), fallback para armazenamento local

#### 3. Erros de Email
- **SMTPAuthenticationError**: Credenciais Gmail inválidas
- **SMTPConnectError**: Falha na conexão SMTP
- **Ação**: Retry (2 tentativas), log do erro, continuar operação

#### 4. Erros de Banco de Dados
- **DatabaseCorruptionError**: Banco corrompido
- **Ação**: Backup automático, recriação do banco, recuperação de dados

### Sistema de Logging
```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('backup_system.log'),
        logging.StreamHandler()
    ]
)
```

## Testing Strategy

### 1. Testes Unitários
- **BackupService**: Criação de ZIP, geração de senhas, validação
- **PasswordManager**: Criptografia/descriptografia, armazenamento
- **DatabaseManager**: CRUD operations, queries de busca
- **EmailController**: Formatação de emails, configuração SMTP

### 2. Testes de Integração
- **Fluxo completo**: Criação → Upload → Email → Armazenamento
- **API Terabox**: Upload, autenticação, tratamento de erros
- **Gmail API**: Envio de emails, autenticação OAuth2

### 3. Testes de Interface
- **Tkinter UI**: Navegação entre telas, validação de inputs
- **Responsividade**: Operações longas não bloqueiam UI
- **Tratamento de erros**: Mensagens claras para o usuário

### 4. Testes de Performance
- **Backup de arquivos grandes**: >1GB
- **Múltiplos backups simultâneos**: Gerenciamento de recursos
- **Busca em histórico grande**: >1000 registros

### 5. Testes de Segurança
- **Criptografia de senhas**: Validação de algoritmos
- **Armazenamento seguro**: Proteção contra acesso não autorizado
- **Validação de inputs**: Prevenção de injection attacks

### Framework de Testes Flutter
```dart
// Estrutura de testes
test/
├── unit/
│   ├── backup_service_test.dart
│   ├── password_manager_test.dart
│   └── database_service_test.dart
├── widget/
│   ├── backup_page_test.dart
│   ├── search_page_test.dart
│   └── history_page_test.dart
├── integration/
│   ├── terabox_integration_test.dart
│   └── email_integration_test.dart
└── golden/
    └── ui_golden_tests.dart
```

### Packages Flutter Necessários
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.5           # Gerenciamento de estado
  sqflite: ^2.3.0           # Banco de dados local
  archive: ^3.4.9           # Criação de arquivos ZIP
  crypto: ^3.0.3            # Criptografia
  http: ^1.1.0              # Requisições HTTP
  file_picker: ^6.1.1       # Seleção de arquivos/pastas
  mailer: ^6.0.1            # Envio de emails
  shared_preferences: ^2.2.2 # Armazenamento de configurações
  intl: ^0.18.1             # Formatação de datas (pt-BR)
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.2           # Mocks para testes
  golden_toolkit: ^0.15.0   # Testes de UI
```

### Configuração de Ambiente de Teste
- **Mock APIs**: Simulação de Terabox e Gmail usando mockito
- **Banco de teste**: SQLite em memória para testes rápidos
- **Golden Tests**: Validação visual da interface
- **Widget Tests**: Testes de componentes individuais
- **Integration Tests**: Testes de fluxo completo