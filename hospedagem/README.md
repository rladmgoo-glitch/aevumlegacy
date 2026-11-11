# Hospedagem do site — aevumlegacy.com.br

**No ar desde 2026-10-22**, servido do Mac mini do dono (Mac16,10, ligado na tomada, sem suspender).
Mesmo padrão dos outros sites desta máquina (energystake, istar-fiscal): servidor local + túnel Cloudflare.

```
visitante ──HTTPS──▶ Cloudflare (DNS, certificado, proxy)
                         │  túnel "aevum" (cloudflared abre a conexão de dentro para fora)
                         ▼
                 Caddy em 127.0.0.1:8090 ──▶ ~/aevumlegacy/public/
```

Nenhuma porta aberta no roteador e o IP de casa não aparece. O Caddy só escuta em `127.0.0.1`.

## Deploy (atualizar o site)

1. Editar a fonte: [`marca/aevumlegacy-site.html`](../aevumlegacy-site.html).
2. Rodar:

   ```bash
   ~/aevumlegacy/publicar.sh
   ```

É só isso. O Caddy serve os arquivos novos na hora, sem reiniciar. O navegador guarda o HTML por até
5 min; as fotos têm nome por hash e podem ficar em cache para sempre.

O publicador lê o arquivo **da cópia de trabalho do repo, no branch que estiver aberto**. Ele:
- extrai as fotos embutidas (`data:image/...;base64`) para `public/img/<hash>.jpg`, com
  `width`/`height` e `decoding="async"` — a página cai de ~1,4 MB para ~45 KB e cada foto só baixa
  quando aparece na tela;
- grava `public/index.html` e copia `marca/og.jpg` (prévia de link no WhatsApp/redes);
- apaga fotos antigas que a página não usa mais.

**Nada mais de `marca/` é servido** (PDFs com sigilo, comercial, playbook): só a página, as fotos e o `og.jpg`.

## Onde está cada coisa

| O quê | Na máquina (cópia viva) | Neste diretório |
|---|---|---|
| Fonte da página (fotos embutidas) | — | [`../aevumlegacy-site.html`](../aevumlegacy-site.html) |
| Pasta servida (gerada — não editar) | `~/aevumlegacy/public/` | — |
| Publicador | `~/aevumlegacy/publicar.sh` | [`publicar.sh`](publicar.sh) |
| Servidor web | `~/aevumlegacy/Caddyfile` | [`Caddyfile`](Caddyfile) |
| Serviço do servidor | `~/Library/LaunchAgents/com.aevum.site.web.plist` | [`com.aevum.site.web.plist`](com.aevum.site.web.plist) |
| Serviço do túnel | `~/Library/LaunchAgents/com.aevum.site.tunnel.plist` | [`com.aevum.site.tunnel.plist`](com.aevum.site.tunnel.plist) |
| Config do túnel | `~/.cloudflared/aevum.yml` | [`cloudflared-aevum.yml`](cloudflared-aevum.yml) |
| Credencial do túnel | `~/.cloudflared/f9f5e67a-8fa4-4935-ad4a-55b4bad2e8b3.json` | **nunca versionar** |
| Credencial de DNS da zona | `~/.cloudflared/cert-aevum.pem` | **nunca versionar** |
| Logs | `~/aevumlegacy/logs/` (`web.*.log`, `tunnel.*.log`) | — |

As cópias daqui são **espelho para reinstalar**; quem roda é a cópia da máquina. Elas ficam fora do repo
de propósito: trocar de branch não muda o site no ar. **Se alterar uma, alterar a outra.**

## Operação

```bash
# os dois serviços estão de pé?
launchctl print gui/$(id -u)/com.aevum.site.web | grep state
launchctl print gui/$(id -u)/com.aevum.site.tunnel | grep state
cloudflared tunnel list | grep aevum          # conexões ativas do túnel

# reiniciar um serviço (ex.: depois de mudar o Caddyfile)
launchctl kickstart -k gui/$(id -u)/com.aevum.site.web

# teste de fora
curl -sI https://aevumlegacy.com.br/
```

- **Depois de reiniciar a máquina** os dois serviços sobem sozinhos (`RunAtLoad` + `KeepAlive`). Como são
  LaunchAgents, dependem do login automático do usuário, que já está ligado (o energystake usa o mesmo).
- Não use `cloudflared tunnel info aevum`: o `~/.cloudflared/config.yml` padrão é do istar-fiscal e confunde
  o comando. Use `tunnel list`.
- **Limite:** se o Mac mini desligar ou a internet cair, o site sai do ar até voltar.

## DNS — zona `aevumlegacy.com.br` na Cloudflare

- Registro no registro.br via **GoDaddy**. Nameservers trocados para `felicity`/`paris.ns.cloudflare.com`
  em 2026-10-22. Mesma conta Cloudflare dos túneis.
- `aevumlegacy.com.br` e `www` → CNAME `f9f5e67a-8fa4-4935-ad4a-55b4bad2e8b3.cfargotunnel.com`, com proxy.
  Os registros A de estacionamento da GoDaddy foram apagados.
- Mantidos sem mexer: `_domainconnect` (GoDaddy) e `_dmarc` (TXT).
- Para mexer no DNS pela linha de comando, use a credencial desta zona (o `cert.pem` padrão só alcança
  `unsupervisedthinking.com`):

  ```bash
  cloudflared --origincert ~/.cloudflared/cert-aevum.pem tunnel route dns --overwrite-dns aevum <host>
  ```

## Segurança — decisões que não devem ser desfeitas sem testar

- **`Cache-Control: no-transform` é obrigatório.** Sem ele, o "Email Obfuscation" da Cloudflare reescreve
  o `mailto` e injeta um script externo que a CSP bloqueia: o e-mail aparece como "[email protected]" e o
  link quebra. Com ele, a página sai da Cloudflare idêntica ao arquivo.
- **CSP rígida**, porque a página é autocontida (fonte e scripts embutidos, nada de terceiros):
  `default-src 'none'`, scripts e estilos só inline, fontes `data:`, imagens do próprio site ou `data:`,
  sem formulário enviado a servidor e sem ser embutida em outro site. Se um dia entrar script, fonte ou
  imagem de fora, ajustar a CSP no `Caddyfile` e **testar o e-mail de novo**.
- HSTS, `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`.
- O Caddy redireciona `http`→`https` (pelo `X-Forwarded-Proto` que a Cloudflare manda) e `www`→domínio sem www.
- **Sem log de acesso** — não guardamos IP de visitante (LGPD). A Cloudflare já tem as estatísticas.
- O formulário de contato **não envia nada ao servidor**: abre o app de e-mail do visitante com a mensagem pronta.

## O que está no ar (conteúdo)

- **Versão:** a de fotos + documento com tarjas (Artifact "AEVUM · Private Legacy Office", 2026-10-12),
  com a revisão do escritório **`ANÁLISE ESQUELETO SITE.docx`** (iCloud, `Desktop/`) aplicada em 2026-10-23.
  Antes de mexer no texto, procurar esse documento — o iCloud do Mac pode estar atrás do celular.
- **Contatos:** e-mail `contato@dawrahecarmona.com.br`, WhatsApp **+55 11 99876-0777**, Instagram **@dawrahecarmona**.
- **CNPJ e endereço: fora da página por decisão do dono (2026-10-23), por enquanto.** Atenção: o CNPJ do
  registro do domínio (50.320.782/0001-14) é da **RP Serviços e Negócios Ltda**, não da Dawrah, Carmona &
  Associados — não usar como se fosse da banca.
- **Contato:** o documento traz duas opções; está no ar a 1ª ("Agende uma conversa reservada"). A 2ª
  ("Agende uma conversa privada") está no documento.
- Prévia de link: `og.jpg` + título/descrição do cartão de visitas anterior (sem o trio "ache, prove e receba").

## Reinstalar em outra máquina

Os caminhos estão fixos em `/Users/raphaelpiovezan`; se o usuário mudar, ajustar nos arquivos.

```bash
brew install caddy cloudflared
mkdir -p ~/aevumlegacy/public ~/aevumlegacy/logs
cp marca/hospedagem/Caddyfile marca/hospedagem/publicar.sh ~/aevumlegacy/
cp marca/hospedagem/cloudflared-aevum.yml ~/.cloudflared/aevum.yml
cp marca/hospedagem/com.aevum.site.*.plist ~/Library/LaunchAgents/
```

Depois:
1. Trazer a credencial do túnel (`~/.cloudflared/f9f5e67a-….json`) da máquina antiga. Sem ela, criar um
   túnel novo (`cloudflared tunnel create aevum`), trocar o id no `aevum.yml` e apontar o DNS (seção acima).
2. Para mexer no DNS: `cloudflared tunnel login` com `HOME` apontando para uma pasta temporária, escolher
   `aevumlegacy.com.br` e salvar o `cert.pem` gerado como `~/.cloudflared/cert-aevum.pem`, sem sobrescrever
   o `cert.pem` dos outros sites.
3. Subir os serviços e publicar:

   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.aevum.site.web.plist
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.aevum.site.tunnel.plist
   ~/aevumlegacy/publicar.sh
   ```
