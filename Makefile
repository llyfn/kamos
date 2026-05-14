.PHONY: help up down db-up db-down db-migrate db-reset api-run api-test api-build flutter-run flutter-test flutter-analyze check clean

API_DIR     := _workspace/02_backend/api
DB_DIR      := _workspace/02_backend/db
FRONTEND    := _workspace/03_frontend
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
	@echo "  make api-test        go test ./..."
	@echo "  make api-build       go build ./..."
	@echo "  make flutter-run     flutter run (mobile app)"
	@echo "  make flutter-test    flutter test"
	@echo "  make flutter-analyze flutter analyze"
	@echo "  make check           Run api-build + api-test + flutter-analyze + flutter-test"

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
	@for f in $(DB_DIR)/migrations/*.sql; do \
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

api-test:
	cd $(API_DIR) && go test ./...

api-build:
	cd $(API_DIR) && go build ./...

flutter-run:
	cd $(FRONTEND) && flutter run

flutter-test:
	cd $(FRONTEND) && flutter test

flutter-analyze:
	cd $(FRONTEND) && flutter analyze

check: api-build api-test flutter-analyze flutter-test
	@echo "All checks passed."

clean:
	cd $(API_DIR) && go clean ./...
	cd $(FRONTEND) && flutter clean
