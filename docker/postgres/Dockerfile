# PostGIS 16 + pgvector for CrimeaTrip (facts in PostGIS, narrative RAG in pgvector).
# Build:
#   docker build -t crimeatrip/postgis-pgvector:16-3.4 tourism-platform/docker/postgres
# Deploy VPS is linux/amd64. On Apple Silicon Docker may emulate amd64 if the
# base postgis tag resolves to amd64-only locally.
FROM postgis/postgis:16-3.4

USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends postgresql-16-pgvector; \
    rm -rf /var/lib/apt/lists/*

USER postgres
