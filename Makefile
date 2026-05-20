.PHONY: help up down db-up db-down db-migrate db-reset api-run api-run-local api-test api-test-unit api-test-int api-build flutter-run flutter-test flutter-analyze check smoke clean

API_DIR         := backend
MIGRATIONS_DIR  := migrations
FRONTEND        := frontend
PSQL_URL    ?= postgres://kamos:kamos@localhost:5432/kamos?sslmode=disable

help:
	@echo "KAMOS — common dev tasks"
	@echo ""
	@echo "  make up              Start postgres + api via docker-compose"
	@echo "  make down            Stop docker-compose services"
	@echo "  make db-up           Start postgres only"
	@echo "  make db-down         Stop postgres"
	@echo "  make db-migrate      Apply migrations to PSQL_URL"
	@echo "  make db-reset        Drop + recreate kamos database (DESTRUCTIVE)"
	@echo "  make api-run         Run Go API locally (requires running postgres)"
	@echo "  make api-run-local   Run Go API locally with local.env sourced"
	@echo "  make api-test        go test ./... (unit, no integration)"
	@echo "  make api-test-unit   alias for api-test"
	@echo "  make api-test-int    go test -tags=integration (real Postgres 18)"
	@echo "  make api-build       go build ./..."
	@echo "  make flutter-run     flutter run (mobile app)"
	@echo "  make flutter-test    flutter test"
	@echo "  make flutter-analyze flutter analyze"
	@echo "  make check           Build + unit-test backend, integration if INTEGRATION_DATABASE_URL set, then analyze + test frontend"
	@echo "  make smoke           Run scripts/smoke.sh end-to-end"

up:
	docker compose up -d --build

down:
	docker compose down

db-up:
	docker compose up -d postgres

db-down:
	docker compose stop postgres

db-migrate:
	@echo "Applying migrations to $(PSQL_URL)"
	@for f in $(MIGRATIONS_DIR)/*.sql; do \
		echo "→ $$f"; \
		psql "$(PSQL_URL)" -v ON_ERROR_STOP=1 -f "$$f" || exit 1; \
	done

db-reset:
	@echo "WARNING: this will DROP and recreate the kamos database."
	@read -p "Type 'yes' to continue: " ans; [ "$$ans" = "yes" ] || exit 1
	docker compose exec -T postgres psql -U kamos -d postgres -c "DROP DATABASE IF EXISTS kamos;"
	docker compose exec -T postgres psql -U kamos -d postgres -c "CREATE DATABASE kamos;"
	$(MAKE) db-migrate

api-run:
	cd $(API_DIR) && go run ./cmd/server

# Run the API against the local Postgres 18 using local.env at the repo root.
# local.env is auto-loaded by the binary in non-production via godotenv;
# we also source it explicitly so PSQL_URL etc. are available to subshells.
api-run-local:
	@set -a; [ -f local.env ] && . ./local.env; set +a; \
	cd $(API_DIR) && go run ./cmd/server

api-test:
	cd $(API_DIR) && go test ./...

api-test-unit: api-test

# Integration tests against a real Postgres. Sources local.env when present
# so INTEGRATION_DATABASE_URL is picked up. Requires Postgres 18 with the
# migrations applied.
api-test-int:
	@set -a; [ -f local.env ] && . ./local.env; set +a; \
	if [ -z "$$INTEGRATION_DATABASE_URL" ]; then \
		echo "INTEGRATION_DATABASE_URL is not set. Add it to local.env or export it."; \
		exit 1; \
	fi; \
	if [ -z "$$JWT_SECRET" ]; then \
		export JWT_SECRET=$$(openssl rand -base64 48); \
	fi; \
	export APP_ENV=test APP_BASE_URL=http://localhost:8080; \
	cd $(API_DIR) && go test -tags=integration -count=1 ./tests/integration/...

api-build:
	cd $(API_DIR) && go build ./...

flutter-run:
	cd $(FRONTEND) && flutter run

flutter-test:
	cd $(FRONTEND) && flutter test

flutter-analyze:
	cd $(FRONTEND) && flutter analyze

# Full pre-commit gate. Runs unit tests always; integration only when
# INTEGRATION_DATABASE_URL is present (so CI / local devs without Postgres
# can still call `make check`).
check: api-build api-test
	@set -a; [ -f local.env ] && . ./local.env; set +a; \
	if [ -n "$$INTEGRATION_DATABASE_URL" ]; then \
		$(MAKE) api-test-int; \
	else \
		echo "Skipping api-test-int (INTEGRATION_DATABASE_URL not set)"; \
	fi
	$(MAKE) flutter-analyze flutter-test
	@echo "All checks passed."

smoke:
	./scripts/smoke.sh

clean:
	cd $(API_DIR) && go clean ./...
	cd $(FRONTEND) && flutter clean
