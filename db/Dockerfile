FROM flyio/postgres-flex:18

ARG PG_BIGM_TAG=v1.2-20250903

USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        postgresql-server-dev-18 \
        build-essential \
        ca-certificates \
        git; \
    git clone --depth 1 --branch "${PG_BIGM_TAG}" https://github.com/pgbigm/pg_bigm.git /tmp/pg_bigm; \
    make -C /tmp/pg_bigm USE_PGXS=1; \
    make -C /tmp/pg_bigm USE_PGXS=1 install; \
    rm -rf /tmp/pg_bigm; \
    apt-get purge -y --auto-remove \
        postgresql-server-dev-18 \
        build-essential \
        git; \
    rm -rf /var/lib/apt/lists/*
