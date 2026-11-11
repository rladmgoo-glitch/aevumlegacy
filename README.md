# aevumlegacy.com.br — site da AEVUM

O site **no ar** de AEVUM — Private Legacy Office, e a receita completa da
máquina que o serve. Antes a fonte vivia em `acervo-seguro/marca/` e o
`publicar.sh` apontava para aquele checkout: o script quebrava sempre que o
monorepo trocava de branch. Aqui a fonte e a publicação moram juntas.

## Como funciona

A página é **autocontida**: uma fonte única, com o CSS, o script e as fotos
embutidos (`data:`). O `publicar.sh` extrai as fotos para `public/img/` com nome
por hash — assim a página abre leve e cada foto só baixa quando aparece na tela —
e grava `public/index.html` por substituição atômica.

Quem serve é o **Caddy**, preso a `127.0.0.1:8090`; a internet chega por um
**túnel Cloudflare** (`aevum`). **Nenhuma porta aberta no roteador.** Os dois
sobem por LaunchAgent no boot.

```
aevumlegacy-site.html   a fonte (edite aqui)
og.html / og.jpg        o cartão de compartilhamento e o gerador dele
publicar.sh             fonte -> public/ (idempotente; roda quantas vezes quiser)
Caddyfile               o servidor, como está rodando
public/privacidade/     política de privacidade hospedada (exigida pelas lojas)
public/suporte/         página de suporte hospedada (exigida pelas lojas)
hospedagem/             manual da máquina: plists, túnel, DNS, recuperação
```

`public/index.html`, `public/og.jpg` e `public/img/` **não são versionados** —
são saída do `publicar.sh`. As pastas `privacidade/` e `suporte/` são escritas à
mão e **são** versionadas: são o endereço público que as fichas da App Store e do
Play apontam.

## Publicar

```bash
./publicar.sh
```

Imprime o sha256 do que ficou no ar. É idempotente: mesma fonte, mesma saída.
Para ensaiar sem mexer no que está no ar, publique noutro lugar:

```bash
DEST=/tmp/ensaio ./publicar.sh && diff /tmp/ensaio/index.html public/index.html
```

## A máquina

Mac mini desta casa. Caddy e `cloudflared` sob LaunchAgent:

```bash
launchctl list | grep com.aevum.site          # os dois serviços
curl -sI http://127.0.0.1:8090 | head -1      # o Caddy responde?
curl -sI https://aevumlegacy.com.br | head -1 # o túnel responde?
tail -f logs/web.err.log logs/tunnel.err.log
```

Os plists e o `cloudflared-aevum.yml` versionados em `hospedagem/` são **cópias
de referência**; os que valem estão em `~/Library/LaunchAgents/` e
`~/.cloudflared/`. As **credenciais do túnel** (o JSON com o UUID do tunnel)
ficam só em `~/.cloudflared/` e **nunca** entram aqui.

O DNS é da Cloudflare, apontando para o túnel — não para um IP desta casa.
Detalhe, recuperação e o passo-a-passo de montar isto de novo: `hospedagem/README.md`.

## Decisões que não são bug

- **CNPJ e endereço ficam fora** da página, por decisão do dono.
- O conteúdo do site está **aprovado**; mudança de marca aqui é **só cor e
  fonte**.
- O verde (*Forest*) **não** é acento desta marca — o navy do escritório é.
