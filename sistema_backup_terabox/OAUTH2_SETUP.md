# 🔐 Configuração OAuth2 para Terabox

## 🚨 **IMPORTANTE: Configuração Obrigatória**

Para usar o Terabox, você **DEVE** configurar suas credenciais OAuth2. O sistema não funcionará sem isso.

## 📋 **Passos para Configuração**

### 1. **Registrar Aplicação no Baidu Developer Console**

1. Acesse: https://developer.baidu.com/
2. Faça login com sua conta Baidu/Terabox
3. Vá para **"Console"** → **"Criar Aplicação"**
4. Preencha os dados:
   - **Nome da Aplicação**: BackupMaster
   - **Tipo**: Aplicação Web
   - **Descrição**: Sistema de backup automatizado
   - **URL de Callback**: `http://localhost:8080/callback`

### 2. **Obter Credenciais**

Após criar a aplicação, você receberá:
- **Client ID** (App ID)
- **Client Secret** (App Secret)

### 3. **Configurar no Código**

Abra o arquivo: `lib/services/terabox_service.dart`

Encontre estas linhas:
```dart
static const String _clientId = 'YOUR_CLIENT_ID';
static const String _clientSecret = 'YOUR_CLIENT_SECRET';
```

Substitua pelos seus valores reais:
```dart
static const String _clientId = 'seu_client_id_aqui';
static const String _clientSecret = 'seu_client_secret_aqui';
```

### 4. **Configurar Permissões**

No console do Baidu, configure as seguintes permissões:
- **basic**: Informações básicas da conta
- **netdisk**: Acesso ao armazenamento em nuvem

## 🔧 **URLs Importantes**

| Serviço | URL |
|---------|-----|
| **Developer Console** | https://developer.baidu.com/ |
| **API Documentation** | https://pan.baidu.com/union/doc/ |
| **OAuth2 Guide** | https://developer.baidu.com/wiki/index.php?title=docs/oauth |

## ⚡ **Fluxo OAuth2 Implementado**

O sistema implementa o fluxo OAuth2 completo:

1. **Autorização**: Abre navegador para login
2. **Callback**: Captura código de autorização
3. **Token**: Troca código por access token
4. **API**: Usa token para chamadas da API

## 🧪 **Como Testar**

1. Configure as credenciais no código
2. Abra o BackupMaster
3. Vá para **Settings** → **Terabox**
4. Digite seu email
5. Clique em **"Autenticar"**
6. Autorize no navegador
7. Verifique se a quota aparece

## 🚨 **Problemas Comuns**

### ❌ "Credenciais OAuth2 não configuradas"
- **Causa**: Client ID/Secret não substituídos no código
- **Solução**: Configure as credenciais conforme passo 3

### ❌ "Autorização cancelada pelo usuário"
- **Causa**: Usuário fechou navegador sem autorizar
- **Solução**: Tente novamente e complete a autorização

### ❌ "Erro de rede ou timeout"
- **Causa**: Problemas de conectividade
- **Solução**: Verifique internet e tente novamente

### ❌ "Invalid client"
- **Causa**: Client ID/Secret incorretos
- **Solução**: Verifique credenciais no console Baidu

## 📊 **Status Após Configuração**

Quando configurado corretamente:
- ✅ **Autenticação**: OAuth2 funcional
- ✅ **Upload**: Arquivos enviados para Terabox
- ✅ **Quota**: Informações reais de espaço
- ✅ **Links**: URLs de compartilhamento reais

## 🔒 **Segurança**

- **Client Secret**: Mantenha seguro, não compartilhe
- **Access Token**: Renovado automaticamente
- **Callback**: Apenas localhost (seguro)
- **Permissões**: Apenas necessárias (basic + netdisk)

---

**🎯 Após configurar, o Terabox funcionará 100% real, sem simulações!**