# Makefile for Documentation and Compliance Testing

.PHONY: help install test test-cross-ref test-compliance test-audit clean lint format validate-structure quality-check

# Default target
help:
	@echo "Documentation and Compliance Testing Commands:"
	@echo ""
	@echo "  install            Install testing dependencies"
	@echo "  test               Run all documentation and compliance tests"
	@echo "  test-cross-ref     Run cross-reference validation tests only"
	@echo "  test-compliance    Run compliance mapping tests only"
	@echo "  test-audit         Run audit trail validation tests only"
	@echo "  validate-structure Validate that all required documents exist"
	@echo "  quality-check      Run documentation quality check"
	@echo "  lint               Run code linting"
	@echo "  format             Format code with black"
	@echo "  clean              Clean up test artifacts"
	@echo ""

# Install dependencies
install:
	@echo "📦 Installing testing dependencies..."
	pip install -r requirements.txt

# Run all tests
test:
	@echo "📚 Running all documentation and compliance tests..."
	python test_runner.py

# Run cross-reference validation tests only
test-cross-ref:
	@echo "📚 Running cross-reference validation tests..."
	python test_runner.py --test test_cross_reference_validation.py

# Run compliance mapping tests only
test-compliance:
	@echo "📚 Running compliance mapping tests..."
	python test_runner.py --test test_compliance_mapping.py

# Run audit trail validation tests only
test-audit:
	@echo "📚 Running audit trail validation tests..."
	python test_runner.py --test test_audit_trail_validation.py

# Validate documentation structure
validate-structure:
	@echo "📋 Validating documentation structure..."
	python test_runner.py --validate-structure

# Run documentation quality check
quality-check:
	@echo "📝 Running documentation quality check..."
	python test_runner.py --quality-check

# Run tests with coverage
test-coverage:
	@echo "📚 Running tests with coverage..."
	pytest --cov=. --cov-report=html --cov-report=term

# Run tests in parallel
test-parallel:
	@echo "📚 Running tests in parallel..."
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

# Run quick validation (structure + quality)
quick-check: validate-structure quality-check
	@echo "✅ Quick validation complete"

# Run comprehensive test suite
comprehensive: install test test-coverage
	@echo "✅ Comprehensive testing complete"

# CI/CD pipeline target
ci: validate-structure quality-check lint test
	@echo "✅ CI pipeline tests complete"

# Generate compliance report
compliance-report: test
	@echo "📊 Generating compliance report..."
	@if [ -f "results/documentation_compliance_report.md" ]; then \
		echo "✅ Compliance report generated: results/documentation_compliance_report.md"; \
	else \
		echo "❌ Compliance report not found. Run 'make test' first."; \
	fi

# Validate markdown files
validate-markdown:
	@echo "📝 Validating markdown files..."
	@for file in ../../docs/**/*.md; do \
		if [ -f "$$file" ]; then \
			echo "Checking $$file..."; \
			python -c "import markdown; markdown.markdown(open('$$file').read())" 2>/dev/null || echo "❌ Syntax error in $$file"; \
		fi \
	done
	@echo "✅ Markdown validation complete"

# Check document word counts
word-count:
	@echo "📊 Checking document word counts..."
	@for file in ../../docs/**/*.md; do \
		if [ -f "$$file" ]; then \
			words=$$(wc -w < "$$file"); \
			echo "$$(basename $$file): $$words words"; \
		fi \
	done

# Validate control matrix
validate-control-matrix:
	@echo "📋 Validating control matrix..."
	@if [ -f "../../docs/control-matrix.csv" ]; then \
		python -c "import csv; list(csv.DictReader(open('../../docs/control-matrix.csv')))" && \
		echo "✅ Control matrix CSV is valid" || \
		echo "❌ Control matrix CSV has syntax errors"; \
	else \
		echo "❌ Control matrix not found"; \
	fi

# Check for broken links (basic)
check-links:
	@echo "🔗 Checking for basic link issues..."
	@grep -r "](http" ../../docs/ | head -10 || echo "No external links found"
	@grep -r "]\(./" ../../docs/ | head -10 || echo "No relative links found"
	@echo "✅ Basic link check complete"

# Generate documentation metrics
metrics:
	@echo "📊 Generating documentation metrics..."
	@echo "=== Document Count ==="
	@find ../../docs -name "*.md" | wc -l | xargs echo "Markdown files:"
	@find ../../docs -name "*.csv" | wc -l | xargs echo "CSV files:"
	@find ../../docs -name "*.json" | wc -l | xargs echo "JSON files:"
	@find ../../docs -name "*.yaml" -o -name "*.yml" | wc -l | xargs echo "YAML files:"
	@echo ""
	@echo "=== Total Word Count ==="
	@find ../../docs -name "*.md" -exec wc -w {} + | tail -1 | awk '{print $$1 " total words"}'
	@echo ""
	@echo "=== Directory Structure ==="
	@tree ../../docs 2>/dev/null || find ../../docs -type d | sort