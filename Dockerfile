FROM python:3.11-alpine

# Instala dependências
RUN pip install fastapi uvicorn prometheus-fastapi-instrumentator opentelemetry-api opentelemetry-sdk opentelemetry-instrumentation-fastapi opentelemetry-exporter-otlp requests

# Cria e configura a app
COPY . /app
WORKDIR /app

# Comando para rodar a aplicação
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
