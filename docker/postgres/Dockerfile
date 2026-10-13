# PostgreSQL 16 with PostGIS and pgvector for CrimeaTrip: facts in PostGIS,
# narrative RAG in pgvector (ADR-008).
#
# The same base as the backend's CI database (tourism-backend
# docker/ci-postgres), so local, CI and a future production rebuild run one
# database (BACKEND-45, BACKEND-49).
#
# It used to be postgis/postgis:16-3.4 plus apt-installed pgvector. That image
# is Debian bullseye, whose PostgreSQL package repository was removed on
# 2026-10-07, so it no longer builds. Production still runs the old image
# built in August under the tag 16-3.4; this one is tagged 16-bookworm so the
# two never get mixed up. Moving production is a separate, planned step:
# docs/postgres-image-upgrade.md.
#
# Build:
#   docker build -t crimeatrip/postgis-pgvector:16-bookworm docker/postgres
FROM pgvector/pgvector:pg16

RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-16-postgis-3 \
    && rm -rf /var/lib/apt/lists/*
