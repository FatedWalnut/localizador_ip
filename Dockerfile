FROM alpine:latest

# Instala apenas o necessário
RUN apk add --no-cache bind-tools curl

# Copia o script
COPY check-ip.sh /check-ip.sh
RUN chmod +x /check-ip.sh

# Roda o script com domínio como argumento
ENTRYPOINT ["/check-ip.sh"]
