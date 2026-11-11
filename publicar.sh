#!/bin/zsh
# Publica o site: pega a versão atual do repo e coloca na pasta servida.
# Só saem a página, as fotos dela e o og.jpg — o resto de marca/ (PDFs, comercial,
# playbook) nunca é servido.
# As fotos vêm embutidas no HTML (data:); aqui viram arquivos em img/ com nome por
# hash, para a página abrir leve e cada foto só baixar quando aparecer na tela.
set -euo pipefail
# A fonte mora neste repositório — antes vinha de `acervo-seguro/marca/`, e o
# script quebrava sempre que aquele checkout trocava de branch.
REPO="${REPO:-$(cd "$(dirname "$0")" && pwd)}"
DEST="${DEST:-$REPO/public}"

mkdir -p "$DEST/img"
/opt/homebrew/bin/python3 -I - "$REPO/aevumlegacy-site.html" "$DEST" <<'PY'
import base64, hashlib, os, re, sys
src, dest = sys.argv[1], sys.argv[2]
html = open(src, encoding="utf-8").read()
usadas = set()

def jpeg_wh(raw):
    i = 2
    while i < len(raw) - 9:
        if raw[i] != 0xFF:
            i += 1; continue
        mk = raw[i + 1]
        if mk in (0xC0, 0xC1, 0xC2):
            return int.from_bytes(raw[i + 7:i + 9], "big"), int.from_bytes(raw[i + 5:i + 7], "big")
        i += 2 + int.from_bytes(raw[i + 2:i + 4], "big")
    return None

def troca(m):
    ext = {"jpeg": "jpg", "png": "png", "webp": "webp"}.get(m.group(2))
    if not ext:
        return m.group(0)
    raw = base64.b64decode(m.group(3))
    nome = hashlib.sha256(raw).hexdigest()[:12] + "." + ext
    caminho = os.path.join(dest, "img", nome)
    if not os.path.exists(caminho):
        with open(caminho + ".tmp", "wb") as f:
            f.write(raw)
        os.replace(caminho + ".tmp", caminho)
    usadas.add(nome)
    antes, depois = m.group(1), m.group(4)
    extra = ""
    wh = jpeg_wh(raw) if ext == "jpg" else None
    if wh and "width=" not in antes + depois:
        extra += f' width="{wh[0]}" height="{wh[1]}"'
    if "decoding=" not in antes + depois:
        extra += ' decoding="async"'
    return f'<img{antes}src="img/{nome}"{depois}{extra}>'

html = re.sub(r'<img\b([^>]*?)src="data:image/(\w+);base64,([A-Za-z0-9+/=]+)"([^>]*)>', troca, html)
with open(os.path.join(dest, "index.html.tmp"), "w", encoding="utf-8") as f:
    f.write(html)
os.replace(os.path.join(dest, "index.html.tmp"), os.path.join(dest, "index.html"))
for velha in os.listdir(os.path.join(dest, "img")):
    if velha not in usadas:
        os.remove(os.path.join(dest, "img", velha))
print(f"fotos: {len(usadas)} · página: {len(html) // 1024} KB")
PY
install -m 644 "$REPO/og.jpg" "$DEST/og.jpg.new" && mv "$DEST/og.jpg.new" "$DEST/og.jpg"
chmod 644 "$DEST"/index.html "$DEST"/img/*
echo "publicado: $(shasum -a 256 "$DEST/index.html" | cut -c1-12)  $(date '+%Y-%m-%d %H:%M')"
