#!/bin/sh

# Lista de encurtadores comuns
ENCURTADORES="bit.ly encurtador.com.br tinyurl.com is.gd goo.gl ow.ly t.co shorturl.at"

RAW_INPUT=$1

if [ -z "$RAW_INPUT" ]; then
  echo "Uso: docker run <container> <url ou domínio>"
  exit 1
fi

# Extrai domínio original
ORIGINAL_DOMAIN=$(echo "$RAW_INPUT" | sed -E 's~^(https?://)?([^/]+).*~\2~' | cut -d':' -f1)

# Detecta se é encurtador
IS_ENCURTADOR=$(echo "$ENCURTADORES" | grep -o "$ORIGINAL_DOMAIN")

# Se for encurtador, resolve URL final
if [ -n "$IS_ENCURTADOR" ]; then
  echo "🔗 Link encurtado detectado. Resolvendo redirecionamento..."
  
  # Adiciona o cookie aqui (substitua com os cookies reais)
  COOKIES="cookie_name1=value1; cookie_name2=value2; cookie_name3=value3"

  FINAL_URL=$(curl -Ls --max-time 10 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" --cookie "$COOKIES" -o /dev/null -w "%{url_effective}" "$RAW_INPUT")

  if [ -z "$FINAL_URL" ]; then
    echo "❌ Não foi possível resolver o link encurtado."
    exit 1
  fi

  echo "✅ URL final resolvida: $FINAL_URL"
  DOMAIN=$(echo "$FINAL_URL" | sed -E 's~^(https?://)?([^/]+).*~\2~' | cut -d':' -f1)
else
  DOMAIN=$ORIGINAL_DOMAIN
  FINAL_URL=$RAW_INPUT
fi

# Resolve o IP com segurança
IPS=$(dig +short "$DOMAIN" | grep '^[0-9]')

if [ -z "$IPS" ]; then
  echo "❌ Não foi possível resolver o IP de $DOMAIN"
  exit 1
fi

FIRST_IP=$(echo "$IPS" | head -n 1)

echo "🌐 URL original: $RAW_INPUT"
[ "$FINAL_URL" != "$RAW_INPUT" ] && echo "➡️  URL final: $FINAL_URL"
echo "🌍 Domínio final: $DOMAIN"
echo "🔎 IP(s):"
echo "$IPS"

echo ""
echo "📍 Localização do primeiro IP ($FIRST_IP):"
echo "{\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"domain\":\"$DOMAIN\",\"final_url\":\"$FINAL_URL\",\"first_ip\":\"$FIRST_IP\",\"ips\":\"$(echo $IPS | tr '\n' ',' | sed 's/,$//')\"}"

curl -s --max-time 5 https://ipinfo.io/$FIRST_IP