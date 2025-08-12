# 🔐 Configuração Google OAuth2 para Terabox

## 🎯 **Visão Geral**

Esta é a forma **MAIS FÁCIL** de configurar o Terabox no BackupMaster! Se você criou sua conta Terabox usando login do Google, pode usar este método simplificado que não requer VPN ou configurações complexas do Baidu.

---

## ✅ **Vantagens do Google OAuth2**

- ✅ **Mais simples**: Não precisa criar conta no Baidu Developer Console
- ✅ **Sem VPN**: Funciona de qualquer país
- ✅ **Seguro**: Usa o sistema de autenticação do Google
- ✅ **Rápido**: Configuração em poucos minutos
- ✅ **Confiável**: Protocolo OAuth2 padrão da indústria

---

## 📋 **Pré-requisitos**

1. **Conta Google** ativa
2. **Conta Terabox** criada via login Google
3. **Google Cloud Console** (gratuito)
4. **Navegador** atualizado

---

## 🚀 **Passo a Passo**

### **1. Criar Projeto no Google Cloud Console**

1. **Acesse o Google Cloud Console:**
   - URL: https://console.cloud.google.com/
   - Faça login com sua conta Google

2. **Criar Novo Projeto:**
   - Clique em "Selecionar projeto" no topo
   - Clique em "Novo Projeto"
   - Nome: `BackupMaster`
   - Clique em "Criar"

3. **Selecionar o Projeto:**
   - Aguarde a criação
   - Selecione o projeto criado

### **2. Ativar APIs Necessárias**

1. **Ir para APIs e Serviços:**
   - Menu lateral → "APIs e serviços" → "Biblioteca"

2. **Ativar Google Drive API:**
   - Pesquise por "Google Drive API"
   - Clique na API
   - Clique em "Ativar"

3. **Ativar Google OAuth2 API:**
   - Pesquise por "Google+ API" (se disponível)
   - Ative também

### **3. Configurar Tela de Consentimento**

1. **Acessar OAuth consent screen:**
   - Menu lateral → "APIs e serviços" → "Tela de consentimento OAuth"

2. **Configurar:**
   - **Tipo de usuário**: Externo
   - **Nome do aplicativo**: BackupMaster
   - **Email de suporte**: Seu email
   - **Domínios autorizados**: (deixe vazio)
   - **Email do desenvolvedor**: Seu email

3. **Escopos:**
   - Adicione: `https://www.googleapis.com/auth/drive.file`

4. **Usuários de teste:**
   - Adicione seu próprio email

### **4. Criar Credenciais OAuth2**

1. **Ir para Credenciais:**
   - Menu lateral → "APIs e serviços" → "Credenciais"

2. **Criar Credenciais:**
   - Clique em "Criar credenciais"
   - Selecione "ID do cliente OAuth 2.0"

3. **Configurar:**
   - **Tipo de aplicativo**: Aplicativo para computador
   - **Nome**: BackupMaster Desktop
   - **URIs de redirecionamento autorizados**: 
     - `http://localhost:8080/callback`

4. **Obter Credenciais:**
   - Após criar, você receberá:
     - **Client ID**: `xxxxx.apps.googleusercontent.com`
     - **Client Secret**: `xxxxx`
   - **COPIE E GUARDE** essas informações!

### **5. Configurar no BackupMaster**

1. **Abrir o arquivo:**
   - `lib/services/google_oauth_service.dart`

2. **Substituir as credenciais:**
   ```dart
   static const String _clientId = 'SEU_CLIENT_ID_AQUI.apps.googleusercontent.com';
   static const String _clientSecret = 'SEU_CLIENT_SECRET_AQUI';
   ```

3. **Salvar o arquivo**

### **6. Testar a Configuração**

1. **Abrir BackupMaster**
2. **Ir para Settings**
3. **Seção "Configurações do Terabox"**
4. **Selecionar "Google Account"**
5. **Clicar em "Autenticar com Google"**
6. **Autorizar no navegador**
7. **Verificar sucesso**

---

## 🔧 **Exemplo de Configuração**

### **Arquivo: `lib/services/google_oauth_service.dart`**

```dart
// ANTES (configuração padrão)
static const String _clientId = 'YOUR_GOOGLE_CLIENT_ID';
static const String _clientSecret = 'YOUR_GOOGLE_CLIENT_SECRET';

// DEPOIS (suas credenciais)
static const String _clientId = '123456789-abcdefghijklmnop.apps.googleusercontent.com';
static const String _clientSecret = 'GOCSPX-abcdefghijklmnopqrstuvwxyz';
```

---

## 🧪 **Como Testar**

### **Teste Básico:**
1. Execute o BackupMaster
2. Vá para Settings
3. Selecione "Google Account" 
4. Clique "Autenticar com Google"
5. Autorize no navegador
6. Verifique se apareceu informações da conta

### **Teste de Upload:**
1. Após autenticar
2. Crie um backup pequeno
3. Verifique se foi enviado para Google Drive
4. Confirme acesso via Terabox (conta Google)

---

## ❌ **Troubleshooting**

### **Erro: "Credenciais não configuradas"**
- **Causa**: Client ID/Secret não substituídos
- **Solução**: Configure as credenciais no arquivo

### **Erro: "redirect_uri_mismatch"**
- **Causa**: URI de callback incorreta
- **Solução**: Configure `http://localhost:8080/callback` no Google Console

### **Erro: "access_denied"**
- **Causa**: Usuário cancelou autorização
- **Solução**: Tente novamente e autorize completamente

### **Erro: "invalid_client"**
- **Causa**: Client ID incorreto
- **Solução**: Verifique se copiou corretamente do Google Console

### **Navegador não abre**
- **Causa**: Problema com url_launcher
- **Solução**: Copie a URL do log e abra manualmente

---

## 🔒 **Segurança**

### **Boas Práticas:**
- ✅ Mantenha Client Secret seguro
- ✅ Use apenas localhost para callback
- ✅ Não compartilhe credenciais
- ✅ Revogue acesso se necessário

### **Revogar Acesso:**
1. Acesse: https://myaccount.google.com/permissions
2. Encontre "BackupMaster"
3. Clique em "Remover acesso"

---

## 🌐 **Links Úteis**

| Recurso | URL |
|---------|-----|
| **Google Cloud Console** | https://console.cloud.google.com/ |
| **Google Drive API** | https://developers.google.com/drive |
| **OAuth2 Playground** | https://developers.google.com/oauthplayground |
| **Gerenciar Permissões** | https://myaccount.google.com/permissions |

---

## 📊 **Comparação: Google vs Baidu**

| Aspecto | Google OAuth2 | Baidu OAuth2 |
|---------|---------------|--------------|
| **Facilidade** | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Velocidade** | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Disponibilidade** | 🌍 Global | 🇨🇳 China |
| **VPN Necessária** | ❌ Não | ✅ Sim |
| **Documentação** | 📚 Excelente | 📖 Limitada |
| **Suporte** | 💬 Ativo | 💬 Limitado |

---

## 🎉 **Resultado Final**

Após configurar corretamente:

- ✅ **Login automático** via Google
- ✅ **Upload direto** para Google Drive
- ✅ **Acesso via Terabox** (conta Google)
- ✅ **Sincronização** entre dispositivos
- ✅ **Backup seguro** na nuvem

---

## 💡 **Dicas Extras**

### **Para Desenvolvedores:**
- Use ambiente de desenvolvimento separado
- Configure quotas adequadas
- Monitore uso da API
- Implemente refresh token

### **Para Usuários:**
- Mantenha conta Google segura
- Verifique espaço disponível
- Faça backup das credenciais
- Teste regularmente

---

*Guia criado para BackupMaster v1.0 - Janeiro 2025*
*Método recomendado para usuários com conta Terabox via Google*