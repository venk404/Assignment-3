.ONESHELL:

# Variables
VENV := venv

include .env

# SQL query to check for the schema_migrations table
CHECK_MIGRATIONS_QUERY := "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'students') THEN 'Schema exists' ELSE 'Schema does not exist' END AS schema_status;"

all: Run_all_containers

Run_all_containers:
	docker-compose up -d

Start_DB:
	@echo "Waiting for PostgreSQL to start..."
	docker-compose up $(POSTGRES_HOST) -d
	@echo "PostgreSQL started successfully."

run-migrations:
	@echo "Running migrations..."
	docker-compose up $(MIGRATION_SERVICE) -d	
	@echo "Migrations completed successfully."


docker_build-api:
	@echo "Building Docker image for API..."
	docker build -t $(IMAGE_NAME) .
	@echo "Docker image $(IMAGE_NAME) built successfully."

docker_run-api:
	@echo "Running Docker container for API..."
	docker run -d \
		--name $(CONTAINER_NAME) \
		--network $(DOCKER_NETWORK) \
		-p $(APP_PORT):$(APP_PORT) \
		$(IMAGE_NAME):$(IMAGE_VERSION)
	@echo "Docker container $(CONTAINER_NAME) is running."



check-db:
ifeq ($(OS),Windows_NT)
	@powershell -Command "if (docker-compose ps -q $(POSTGRES_HOST)) { Write-Host 'yes DB is running' } else { Write-Host 'DB is not running' }"
else
	@if [ "$$(docker-compose ps -q $(POSTGRES_HOST))" ]; then echo "yes running"; else echo "not running"; fi
endif

check-migrations:
	@echo "Checking database status..."
ifeq ($(OS),Windows_NT)
	@powershell -Command "$$status = docker-compose ps -q $(POSTGRES_HOST); if (-not $$status) { Write-Host 'Database is not running. Please run ''make Start_DB'' first.' } else { Write-Host 'Database is running. Checking schema...'; docker-compose exec $(POSTGRES_HOST) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -t -c \"$(CHECK_MIGRATIONS_QUERY)\" }"
else
    @if [ -z "$$(docker-compose ps -q $(POSTGRES_HOST))" ]; then \
        echo "Database is not running. Please run 'make Start_DB' first."; \
    else \
        echo "Database is running. Checking schema..."; \
        docker-compose exec $(POSTGRES_HOST) psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -t -c "$(CHECK_MIGRATIONS_QUERY)"; \
    fi
endif

down:
	docker-compose down

# Define a clean step
clean:
ifeq ($(OS),Windows_NT)
	@powershell -Command "Get-ChildItem -Recurse -Directory -Filter '__pycache__' | Remove-Item -Recurse -Force"
	@powershell -Command "Get-ChildItem -Recurse -Directory -Filter 'data' | Remove-Item -Recurse -Force"
else
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name "data" -exec rm -rf {} +
endif


.PHONY: all clean Run_all_containers check-db check-migrations Start_DB down run-migrations Build-api docker_build-api docker_run-api
