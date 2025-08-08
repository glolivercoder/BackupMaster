# 📚 Manual de Autenticação - BackupMaster

## 🎯 **Objetivo**
Este manual fornece instruções detalhadas para configurar a autenticação OAuth2 do Terabox e a autenticação por senha de app do Gmail no BackupMaster.

---

## 🔐 **PARTE 1: Configuração do Terabox (OAuth2)**

### 📋 **Pré-requisitos**
- Conta Google/Gmail ativa
- Acesso ao Terabox (pode usar a mesma conta Google)
- Navegador web atualizado

### 🚀 **Passo 1: Criar Conta no Baidu (se necessário)**

1. **Acesse o site do Baidu:**
   - URL: https://passport.baidu.com/
   - Clique em "注册" (Registrar) se não tiver conta

2. **Registrar nova conta:**
   - Escolha "海外手机号" (Número internacional)
   - Digite seu número de telefone com código do país (+55 para Brasil)
   - Preencha o código de verificação recebido por SMS
   - Crie uma senha forte
   - Complete o cadastro

3. **Verificar acesso ao Terabox:**
   - Acesse: https://www.terabox.com/
   - Faça login com sua conta Baidu
   - Confirme que consegue acessar o painel

### 🛠️ **Passo 2: Registrar Aplicação no Baidu Developer Console**

1. **Acessar o Developer Console:**
   - URL: https://developer.baidu.com/
   - Faça login com sua conta Baidu
   - Clique em "控制台" (Console) no canto superior direito

2. **Criar Nova Aplicação:**
   - Clique em "创建应用" (Criar Aplicação)
   - Preencha os dados:
     - **应用名称** (Nome): `BackupMaster`
     - **应用描述** (Descrição): `Sistema de backup automatizado`
     - **应用类型** (Tipo): Selecione "网页应用" (Aplicação Web)
     - **网站地址** (URL do Site): `http://localhost:8080`
     - **授权回调页** (URL de Callback): `http://localhost:8080/callback`

3. **Configurar Permissões:**
   - Na seção "接口权限" (Permissões de Interface)
   - Ative as seguintes permissões:
     - ✅ **basic** - Informações básicas do usuário
     - ✅ **netdisk** - Acesso ao armazenamento em nuvem
   - Clique em "保存" (Salvar)

4. **Obter Credenciais:**
   - Após criar a aplicação, você verá:
     - **App ID** (Client ID): Copie este valor
     - **App Secret** (Client Secret): Copie este valor
   - ⚠️ **IMPORTANTE**: Guarde essas credenciais em local seguro!

### 📱 **Passo 3: Configurar no BackupMaster**

1. **Abrir BackupMaster:**
   - Execute o aplicativo
   - Vá para a aba **Settings**
   - Localize a seção **"Configurações do Terabox (OAuth2)"**

2. **Preencher os Campos:**
   - **Email da Conta Terabox**: Seu email Baidu/Google
   - **Client ID**: Cole o App ID obtido no passo anterior
   - **Client Secret**: Cole o App Secret obtido no passo anterior

3. **Salvar e Testar:**
   - Clique em **"Salvar"**
   - Clique em **"Autenticar"**
   - O navegador abrirá automaticamente
   - Autorize a aplicação no Baidu
   - Retorne ao BackupMaster para confirmar sucesso

---

## 📧 **PARTE 2: Configuração do Gmail (Senha de App)**

### 📋 **Pré-requisitos**
- Conta Gmail ativa
- Verificação em duas etapas habilitada
- Acesso às configurações de segurança do Google

### 🔒 **Passo 1: Habilitar Verificação em Duas Etapas**

1. **Acessar Configurações de Segurança:**
   - URL: https://myaccount.google.com/security
   - Faça login na sua conta Google
   - Localize a seção "Como fazer login no Google"

2. **Ativar Verificação em Duas Etapas:**
   - Clique em "Verificação em duas etapas"
   - Siga o assistente de configuração:
     - Confirme seu número de telefone
     - Escolha método de verificação (SMS ou app)
     - Complete a configuração

3. **Confirmar Ativação:**
   - Verifique se aparece "Ativada" na verificação em duas etapas
   - Teste fazendo logout e login novamente

### 🔑 **Passo 2: Gerar Senha de App**

1. **Acessar Senhas de App:**
   - Ainda em https://myaccount.google.com/security
   - Role até encontrar "Senhas de app"
   - Clique em "Senhas de app"

2. **Criar Nova Senha:**
   - No campo "Selecionar app", escolha **"Email"**
   - No campo "Selecionar dispositivo", escolha **"Outro (nome personalizado)"**
   - Digite: `BackupMaster`
   - Clique em **"Gerar"**

3. **Copiar a Senha:**
   - Uma senha de 16 caracteres será exibida
   - Formato: `abcd efgh ijkl mnop`
   - ⚠️ **COPIE IMEDIATAMENTE** - não será mostrada novamente
   - Guarde em local seguro

### 📱 **Passo 3: Configurar no BackupMaster**

1. **Abrir Configurações:**
   - No BackupMaster, vá para **Settings**
   - Localize **"Configurações do Gmail"**

2. **Preencher Campos:**
   - **Email Remetente**: Seu email Gmail completo
   - **Senha do App**: Cole a senha de 16 caracteres (SEM espaços)
   - **Email Destinatário**: Email que receberá os relatórios

3. **Testar Configuração:**
   - Clique em **"Salvar"**
   - Clique em **"Testar"**
   - Verifique se recebeu o email de teste

---

## 🔧 **PARTE 3: Troubleshooting**

### ❌ **Problemas Comuns - Terabox**

#### **Erro: "Credenciais OAuth2 não configuradas"**
- **Causa**: Client ID ou Secret vazios
- **Solução**: Verifique se copiou corretamente do Baidu Console

#### **Erro: "Invalid client"**
- **Causa**: Client ID incorreto
- **Solução**: 
  - Confirme o App ID no Baidu Console
  - Recrie a aplicação se necessário

#### **Erro: "Unauthorized redirect_uri"**
- **Causa**: URL de callback incorreta
- **Solução**: 
  - No Baidu Console, configure: `http://localhost:8080/callback`
  - Certifique-se de usar HTTP (não HTTPS)

#### **Navegador não abre**
- **Causa**: Problemas com url_launcher
- **Solução**:
  - Copie a URL manualmente do log
  - Abra no navegador
  - Complete a autorização

### ❌ **Problemas Comuns - Gmail**

#### **Erro: "Authentication failed"**
- **Causa**: Senha de app incorreta
- **Solução**:
  - Gere nova senha de app
  - Certifique-se de copiar sem espaços
  - Use apenas a senha de app, nunca a senha normal

#### **Erro: "Less secure app access"**
- **Causa**: Configuração de segurança
- **Solução**:
  - Use APENAS senhas de app
  - Nunca ative "apps menos seguros"
  - Mantenha verificação em duas etapas

#### **Email não chega**
- **Causa**: Filtros de spam ou configuração
- **Solução**:
  - Verifique pasta de spam
  - Confirme email destinatário
  - Teste com outro email

### 🔍 **Logs e Diagnóstico**

#### **Verificar Logs do Sistema**
1. No BackupMaster, vá para **Settings**
2. Role até **"Output dos Testes"**
3. Execute os testes e analise as mensagens
4. Procure por códigos de erro específicos

#### **Códigos de Erro Comuns**
- **400**: Parâmetros inválidos
- **401**: Não autorizado (credenciais incorretas)
- **403**: Acesso negado (permissões insuficientes)
- **404**: Endpoint não encontrado
- **500**: Erro interno do servidor

---

## 📞 **PARTE 4: Suporte e Recursos**

### 🌐 **Links Úteis**

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **Baidu Developer** | https://developer.baidu.com/ | Console de desenvolvimento |
| **Terabox** | https://www.terabox.com/ | Serviço de armazenamento |
| **Google Security** | https://myaccount.google.com/security | Configurações de segurança |
| **Gmail App Passwords** | https://support.google.com/accounts/answer/185833 | Guia oficial |

### 📋 **Checklist de Configuração**

#### **Terabox OAuth2:**
- [ ] Conta Baidu criada e verificada
- [ ] Aplicação registrada no Developer Console
- [ ] Permissões basic e netdisk ativadas
- [ ] Client ID e Secret copiados
- [ ] Campos preenchidos no BackupMaster
- [ ] Teste de autenticação bem-sucedido

#### **Gmail:**
- [ ] Verificação em duas etapas ativada
- [ ] Senha de app gerada
- [ ] Campos preenchidos no BackupMaster
- [ ] Email de teste recebido
- [ ] Destinatário configurado corretamente

### 🆘 **Quando Pedir Ajuda**

Se após seguir este manual você ainda tiver problemas:

1. **Colete Informações:**
   - Screenshots dos erros
   - Logs do sistema (aba Settings)
   - Passos já realizados

2. **Verifique Novamente:**
   - Todas as URLs estão corretas
   - Credenciais foram copiadas sem espaços
   - Permissões estão ativadas

3. **Recursos de Suporte:**
   - Documentação oficial do Baidu
   - Suporte do Google para senhas de app
   - Logs detalhados no BackupMaster

---

## ✅ **PARTE 5: Verificação Final**

### 🧪 **Teste Completo do Sistema**

1. **Criar Backup de Teste:**
   - Selecione uma pasta pequena
   - Execute o backup completo
   - Verifique se o ZIP foi criado

2. **Verificar Upload Terabox:**
   - Confirme se o arquivo aparece no Terabox
   - Teste o download do link gerado

3. **Verificar Email:**
   - Confirme recebimento do relatório
   - Verifique se a senha está incluída
   - Teste abertura do ZIP com a senha

### 🎉 **Configuração Concluída**

Se todos os testes passaram, sua configuração está completa! O BackupMaster agora pode:

- ✅ Criar backups ZIP com senhas seguras
- ✅ Fazer upload automático para Terabox
- ✅ Enviar relatórios detalhados por email
- ✅ Gerenciar credenciais de forma segura

**Parabéns! Seu sistema de backup está totalmente funcional! 🚀**

---

*Manual criado para BackupMaster v1.0 - Janeiro 2025*