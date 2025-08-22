# Master Makefile for Comprehensive Testing and Validation

.PHONY: help install test test-all test-policies test-workflows test-docs clean setup validate-env

# Default target
help:
	@echo "Lambda Production Readiness Validation Suite"
	@echo "============================================="
	@echo ""
	@echo "Comprehensive Commands:"
	@echo "  install        Install all testing dependencies"
	@echo "  test           Run complete validation suite"
	@echo "  test-parallel  Run validation suite in parallel"
	@echo "  validate-env   Validate test environment setup"
	@echo ""
	@echo "Individual Test Suites:"
	@echo "  test-policies  Run policy and guardrail tests"
	@echo "  test-workflows Run workflow and integration tests"
	@echo "  test-docs      Run documentation and compliance tests"
	@echo ""
	@echo "Setup and Maintenance:"
	@echo "  setup          Complete environment setup"
	@echo "  clean          Clean all test artifacts"
	@echo "  clean-all      Deep clean including dependencies"
	@echo ""
	@echo "Quality Assurance:"
	@echo "  lint           Run linting on all test code"
	@echo "  format         Format all test code"
	@echo "  coverage       Run tests with coverage reporting"
	@echo ""

# Install all dependencies
install:
	@echo "📦 Installing all testing dependencies..."
	@echo "Installing policy guardrail dependencies..."
	@cd policy-guardrails && pip install -r requirements.txt
	@echo "Installing workflow integration dependencies..."
	@cd workflow-integration && pip install -r requirements.txt
	@echo "Installing documentation compliance dependencies..."
	@cd documentation-compliance && pip install -r requirements.txt
	@echo "✅ All dependencies installed"

# Complete environment setup
setup: install validate-env
	@echo "🔧 Setting up test environment..."
	@mkdir -p results
	@echo "✅ Test environment setup complete"

# Validate test environment
validate-env:
	@echo "🔧 Validating test environment..."
	python master_test_runner.py --validate-env

# Run complete validation suite
test:
	@echo "🚀 Running complete Lambda production readiness validation..."
	python master_test_runner.py

# Run validation suite in parallel
test-parallel:
	@echo "🚀 Running validation suite in parallel..."
	python master_test_runner.py --parallel

# Run policy and guardrail tests only
test-policies:
	@echo "🔒 Running policy and guardrail validation..."
	python master_test_runner.py --suite policy-guardrails

# Run workflow and integration tests only
test-workflows:
	@echo "🚀 Running workflow and integration validation..."
	python master_test_runner.py --suite workflow-integration

# Run documentation and compliance tests only
test-docs:
	@echo "📚 Running documentation and compliance validation..."
	python master_test_runner.py --suite documentation-compliance

# Run tests with coverage
coverage:
	@echo "📊 Running tests with coverage reporting..."
	@cd policy-guardrails && make test-coverage
	@cd workflow-integration && make test-coverage
	@cd documentation-compliance && make test-coverage

# Lint all test code
lint:
	@echo "🔍 Running linting on all test code..."
	@cd policy-guardrails && make lint
	@cd workflow-integration && make lint
	@cd documentation-compliance && make lint
	@echo "Linting master test runner..."
	@flake8 master_test_runner.py
	@mypy master_test_runner.py --ignore-missing-imports

# Format all test code
format:
	@echo "🎨 Formatting all test code..."
	@cd policy-guardrails && make format
	@cd workflow-integration && make format
	@cd documentation-compliance && make format
	@black master_test_runner.py

# Clean test artifacts
clean:
	@echo "🧹 Cleaning test artifacts..."
	@rm -rf results/
	@cd policy-guardrails && make clean
	@cd workflow-integration && make clean
	@cd documentation-compliance && make clean
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@find . -name ".pytest_cache" -type d -exec rm -rf {} + 2>/dev/null || true

# Deep clean including dependencies
clean-all: clean
	@echo "🧹 Deep cleaning including dependencies..."
	@pip freeze | grep -E "(pytest|moto|boto3)" | xargs pip uninstall -y 2>/dev/null || true

# Quick validation (fast checks)
quick:
	@echo "⚡ Running quick validation checks..."
	@cd policy-guardrails && make validate-files
	@cd workflow-integration && make validate-files
	@cd documentation-compliance && make validate-structure

# Comprehensive validation (all tests + coverage + lint)
comprehensive: setup lint test coverage
	@echo "✅ Comprehensive validation complete"

# CI/CD pipeline target
ci: validate-env quick test
	@echo "✅ CI pipeline validation complete"

# Generate validation report
report:
	@echo "📊 Generating validation report..."
	@if [ -f "results/master_validation_report.md" ]; then \
		echo "✅ Master validation report: results/master_validation_report.md"; \
		echo "📋 Policy report: results/policy-guardrails/policy_test_report.md"; \
		echo "🚀 Workflow report: results/workflow-integration/workflow_test_report.md"; \
		echo "📚 Documentation report: results/documentation-compliance/documentation_compliance_report.md"; \
	else \
		echo "❌ No validation report found. Run 'make test' first."; \
	fi

# Show test statistics
stats:
	@echo "📊 Test Suite Statistics"
	@echo "======================="
	@echo "Policy Guardrail Tests:"
	@find policy-guardrails -name "test_*.py" -exec wc -l {} + | tail -1 | awk '{print "  Lines of test code: " $$1}'
	@find policy-guardrails -name "test_*.py" | wc -l | awk '{print "  Test files: " $$1}'
	@echo ""
	@echo "Workflow Integration Tests:"
	@find workflow-integration -name "test_*.py" -exec wc -l {} + | tail -1 | awk '{print "  Lines of test code: " $$1}'
	@find workflow-integration -name "test_*.py" | wc -l | awk '{print "  Test files: " $$1}'
	@echo ""
	@echo "Documentation Compliance Tests:"
	@find documentation-compliance -name "test_*.py" -exec wc -l {} + | tail -1 | awk '{print "  Lines of test code: " $$1}'
	@find documentation-compliance -name "test_*.py" | wc -l | awk '{print "  Test files: " $$1}'

# Check dependencies
check-deps:
	@echo "🔍 Checking dependencies..."
	@python -c "import pytest; print('✅ pytest available')" 2>/dev/null || echo "❌ pytest not available"
	@python -c "import boto3; print('✅ boto3 available')" 2>/dev/null || echo "❌ boto3 not available"
	@python -c "import moto; print('✅ moto available')" 2>/dev/null || echo "❌ moto not available"
	@python -c "import yaml; print('✅ pyyaml available')" 2>/dev/null || echo "❌ pyyaml not available"

# Show help for individual test suites
help-suites:
	@echo "Individual Test Suite Commands:"
	@echo "=============================="
	@echo ""
	@echo "Policy Guardrails:"
	@cd policy-guardrails && make help
	@echo ""
	@echo "Workflow Integration:"
	@cd workflow-integration && make help
	@echo ""
	@echo "Documentation Compliance:"
	@cd documentation-compliance && make help

# Development workflow
dev: setup quick lint
	@echo "✅ Development environment ready"

# Production validation workflow
prod: setup test report
	@echo "✅ Production validation complete"