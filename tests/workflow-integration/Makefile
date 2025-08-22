# Makefile for Workflow and Integration Testing

.PHONY: help install test test-cicd test-signing test-canary clean lint format validate-files smoke-test

# Default target
help:
	@echo "Workflow and Integration Testing Commands:"
	@echo ""
	@echo "  install          Install testing dependencies"
	@echo "  test             Run all workflow and integration tests"
	@echo "  test-cicd        Run CI/CD pipeline tests only"
	@echo "  test-signing     Run code signing tests only"
	@echo "  test-canary      Run canary deployment tests only"
	@echo "  validate-files   Validate that all required workflow files exist"
	@echo "  smoke-test       Run quick integration smoke test"
	@echo "  lint             Run code linting"
	@echo "  format           Format code with black"
	@echo "  clean            Clean up test artifacts"
	@echo ""

# Install dependencies
install:
	@echo "📦 Installing testing dependencies..."
	pip install -r requirements.txt

# Run all tests
test:
	@echo "🚀 Running all workflow and integration tests..."
	python test_runner.py

# Run CI/CD pipeline tests only
test-cicd:
	@echo "🚀 Running CI/CD pipeline tests..."
	python test_runner.py --test test_cicd_pipeline.py

# Run code signing tests only
test-signing:
	@echo "🚀 Running code signing tests..."
	python test_runner.py --test test_code_signing.py

# Run canary deployment tests only
test-canary:
	@echo "🚀 Running canary deployment tests..."
	python test_runner.py --test test_canary_deployment.py

# Validate workflow files exist
validate-files:
	@echo "📋 Validating workflow files..."
	python test_runner.py --validate-files

# Run integration smoke test
smoke-test:
	@echo "🔥 Running integration smoke test..."
	python test_runner.py --smoke-test

# Run tests with coverage
test-coverage:
	@echo "🚀 Running tests with coverage..."
	pytest --cov=. --cov-report=html --cov-report=term

# Run tests in parallel
test-parallel:
	@echo "🚀 Running tests in parallel..."
	pytest -n auto

# Lint code
lint:
	@echo "🔍 Running code linting..."
	flake8 *.py
	mypy *.py --ignore-missing-imports

# Format code
format:
	@echo "🎨 Formatting code..."
	black *.py

# Clean up test artifacts
clean:
	@echo "🧹 Cleaning up test artifacts..."
	rm -rf results/
	rm -rf __pycache__/
	rm -rf .pytest_cache/
	rm -rf htmlcov/
	rm -rf .coverage
	find . -name "*.pyc" -delete
	find . -name "*.pyo" -delete

# Run quick validation (files + smoke test)
quick-check: validate-files smoke-test
	@echo "✅ Quick validation complete"

# Run comprehensive test suite
comprehensive: install test test-coverage
	@echo "✅ Comprehensive testing complete"

# CI/CD pipeline target
ci: validate-files smoke-test lint test
	@echo "✅ CI pipeline tests complete"

# Integration test with real AWS (requires credentials)
integration-real:
	@echo "🔗 Running integration tests with real AWS services..."
	@echo "⚠️  Warning: This will use real AWS resources"
	AWS_INTEGRATION_TEST=true python test_runner.py

# Validate GitHub Actions workflows
validate-workflows:
	@echo "📋 Validating GitHub Actions workflows..."
	@for file in ../../.github/workflows/*.yml ../../.github/workflows/*.yaml; do \
		if [ -f "$$file" ]; then \
			echo "Validating $$file..."; \
			python -c "import yaml; yaml.safe_load(open('$$file'))" || exit 1; \
		fi \
	done
	@echo "✅ All workflows valid"

# Check script permissions
check-scripts:
	@echo "🔍 Checking script permissions..."
	@for script in ../../scripts/*.sh; do \
		if [ -f "$$script" ]; then \
			if [ -x "$$script" ]; then \
				echo "✅ $$script is executable"; \
			else \
				echo "❌ $$script is not executable"; \
			fi \
		fi \
	done