# Makefile for Policy and Guardrail Testing

.PHONY: help install test test-scp test-config test-boundaries clean lint format validate-files

# Default target
help:
	@echo "Policy and Guardrail Testing Commands:"
	@echo ""
	@echo "  install          Install testing dependencies"
	@echo "  test             Run all policy and guardrail tests"
	@echo "  test-scp         Run Service Control Policy tests only"
	@echo "  test-config      Run AWS Config rules tests only"
	@echo "  test-boundaries  Run permission boundary tests only"
	@echo "  validate-files   Validate that all required policy files exist"
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
	@echo "🔒 Running all policy and guardrail tests..."
	python test_runner.py

# Run SCP tests only
test-scp:
	@echo "🔒 Running Service Control Policy tests..."
	python test_runner.py --test test_scp_enforcement.py

# Run Config rules tests only
test-config:
	@echo "🔒 Running AWS Config rules tests..."
	python test_runner.py --test test_config_rules.py

# Run permission boundary tests only
test-boundaries:
	@echo "🔒 Running permission boundary tests..."
	python test_runner.py --test test_permission_boundaries.py

# Validate policy files exist
validate-files:
	@echo "📋 Validating policy files..."
	python test_runner.py --validate-files

# Run tests with coverage
test-coverage:
	@echo "🔒 Running tests with coverage..."
	pytest --cov=. --cov-report=html --cov-report=term

# Run tests in parallel
test-parallel:
	@echo "🔒 Running tests in parallel..."
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

# Run quick validation (files + syntax)
quick-check: validate-files lint
	@echo "✅ Quick validation complete"

# Run comprehensive test suite
comprehensive: install test test-coverage
	@echo "✅ Comprehensive testing complete"

# CI/CD pipeline target
ci: validate-files lint test
	@echo "✅ CI pipeline tests complete"