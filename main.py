from fastapi import FastAPI
from pydantic import BaseModel
import socket
import requests
import logging
import json

from prometheus_fastapi_instrumentator import Instrumentator

from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

# Importa o LokiLoggerHandler
from loki_logger_handler.loki_logger_handler import LokiLoggerHandler

# Inicializa o app FastAPI
app = FastAPI()

# --------- Setup Prometheus Metrics ----------- 
instrumentator = Instrumentator()
instrumentator.instrument(app).expose(app, "/metrics")  # Expondo as métricas para o Prometheus

# --------- Setup OpenTelemetry Traces ----------
resource = Resource(attributes={
    "service.name": "ip-checker-api"
})

# Configuração do OTLP Span Exporter sem usar 'insecure=True'
# Para conexões sem SSL, remova o 'https://' e use o 'http://'
# Caso você tenha SSL no coletor, use 'https://' no lugar de 'http://'
provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint="http://localhost:4318"))
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

FastAPIInstrumentor.instrument_app(app)

# --------- Setup de Logger configurado para Loki ---------
logger = logging.getLogger("uvicorn")
logger.setLevel(logging.INFO)

# Configura o Loki Handler
loki_handler = LokiLoggerHandler(
    url="http://localhost:3100/loki/api/v1/push",  # URL onde o Loki está escutando
    labels={"app": "ip-checker-api", "env": "dev", "job": "fastapi"}  # Ajuste aqui
)

# Adiciona o Loki Handler ao logger
logger.addHandler(loki_handler)

# Função para enviar logs para o Loki
def log_json(message: str, extra: dict = {}):
    log_entry = {"message": message}
    log_entry.update(extra)
    logger.info(log_entry)  # Envia o log como JSON para o Loki

# --------- Modelo do Body ----------
class UrlRequest(BaseModel):
    url: str

# --------- Rota principal ----------
@app.post("/info_url")
def info_url(request: UrlRequest):
    url = request.url

    # Extrai domínio da URL
    domain = url.split("//")[-1].split("/")[0]

    try:
        # Resolve o IP do domínio
        ip = socket.gethostbyname(domain)
    except socket.gaierror:
        log_json("Erro ao resolver domínio", {"domain": domain})
        return {"error": f"Não foi possível resolver o domínio {domain}"}

    # Faz requisição ao IPInfo
    ip_info_response = requests.get(f"https://ipinfo.io/{ip}/json", timeout=5)

    if ip_info_response.status_code != 200:
        log_json("Erro ao buscar IP Info", {"ip": ip})
        return {"error": "Erro ao buscar informações do IP"}

    ip_info = ip_info_response.json()

    # Log de sucesso
    log_json("IP Info coletado", {"url": url, "ip": ip})

    return {
        "original_url": url,
        "domain": domain,
        "ip": ip,
        "ip_info": ip_info
    }
