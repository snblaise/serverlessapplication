#!/usr/bin/env python3
"""
Test runner for policy and guardrail validation.
Orchestrates all policy-related tests and generates comprehensive reports.
"""

import pytest
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime
import argparse


class PolicyTestRunner:
    """Main test runner for policy and guardrail validation."""
    
    def __init__(self, output_dir=None):
        """Initialize test runner."""
        self.output_dir = Path(output_dir) if output_dir else Path(__file__).parent / "results"
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.test_modules = [
            'test_scp_enforcement.py',
            'test_config_rules.py',
            'test_permission_boundaries.py'
        ]
    
    def run_all_tests(self, verbose=True, generate_report=True):
        """Run all policy and guardrail tests."""
        print("🔒 Starting Policy and Guardrail Validation Tests")
        print("=" * 60)
        
        results = {}
        overall_success = True
        
        for test_module in self.test_modules:
            print(f"\n📋 Running {test_module}...")
            
            success, output = self._run_test_module(test_module, verbose)
            results[test_module] = {
                'success': success,
                'output': output,
                'timestamp': datetime.now().isoformat()
            }
            
            if not success:
                overall_success = False
                print(f"❌ {test_module} FAILED")
            else:
                print(f"✅ {test_module} PASSED")
        
        if generate_report:
            self._generate_test_report(results, overall_success)
        
        return overall_success, results
    
    def _run_test_module(self, test_module, verbose=True):
        """Run a specific test module."""
        test_path = Path(__file__).parent / test_module
        
        if not test_path.exists():
            return False, f"Test module {test_module} not found"
        
        try:
            # Run pytest with appropriate flags
            cmd = [
                sys.executable, '-m', 'pytest',
                str(test_path),
                '-v' if verbose else '-q',
                '--tb=short',
                '--no-header',
                '--json-report',
                f'--json-report-file={self.output_dir / f"{test_module}.json"}'
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=Path(__file__).parent
            )
            
            return result.returncode == 0, result.stdout + result.stderr
            
        except Exception as e:
            return False, f"Error running {test_module}: {str(e)}"
    
    def _generate_test_report(self, results, overall_success):
        """Generate comprehensive test report."""
        report = {
            'timestamp': datetime.now().isoformat(),
            'overall_success': overall_success,
            'summary': {
                'total_modules': len(self.test_modules),
                'passed_modules': sum(1 for r in results.values() if r['success']),
                'failed_modules': sum(1 for r in results.values() if not r['success'])
            },
            'results': results
        }
        
        # Save JSON report
        json_report_path = self.output_dir / 'policy_test_report.json'
        with open(json_report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        # Generate markdown report
        self._generate_markdown_report(report)
        
        print(f"\n📊 Test report generated: {json_report_path}")
    
    def _generate_markdown_report(self, report):
        """Generate markdown test report."""
        md_content = f"""# Policy and Guardrail Validation Report

**Generated:** {report['timestamp']}  
**Overall Status:** {'✅ PASSED' if report['overall_success'] else '❌ FAILED'}

## Summary

- **Total Test Modules:** {report['summary']['total_modules']}
- **Passed Modules:** {report['summary']['passed_modules']}
- **Failed Modules:** {report['summary']['failed_modules']}

## Test Results

"""
        
        for module, result in report['results'].items():
            status = '✅ PASSED' if result['success'] else '❌ FAILED'
            md_content += f"### {module}\n\n"
            md_content += f"**Status:** {status}  \n"
            md_content += f"**Timestamp:** {result['timestamp']}\n\n"
            
            if not result['success']:
                md_content += "**Error Output:**\n```\n"
                md_content += result['output'][:1000]  # Truncate long output
                if len(result['output']) > 1000:
                    md_content += "\n... (truncated)"
                md_content += "\n```\n\n"
        
        md_content += """## Test Coverage

This validation suite covers:

### Service Control Policies (SCPs)
- Lambda governance policies
- Code signing enforcement
- API Gateway WAF requirements
- Region restrictions
- Mandatory tagging

### AWS Config Rules
- Managed Config rules for Lambda settings
- Custom Config rules for security controls
- Conformance pack deployment
- Rule parameter validation

### Permission Boundaries
- CI/CD role restrictions
- Lambda execution role boundaries
- Wildcard action denial
- Production access controls
- Encryption enforcement

## Recommendations

"""
        
        if not report['overall_success']:
            md_content += """### Failed Tests
Review the failed test modules above and address the following:

1. **Policy Syntax:** Ensure all policies have valid JSON syntax
2. **Required Controls:** Verify all mandatory security controls are present
3. **Configuration:** Check that policy parameters match requirements
4. **Dependencies:** Ensure all required policy files exist

"""
        else:
            md_content += """### All Tests Passed
Your policy and guardrail configuration meets the production readiness requirements.

**Next Steps:**
1. Deploy policies to sandbox environment for integration testing
2. Validate policies with actual AWS resources
3. Set up monitoring for policy compliance
4. Schedule regular policy validation runs

"""
        
        # Save markdown report
        md_report_path = self.output_dir / 'policy_test_report.md'
        with open(md_report_path, 'w') as f:
            f.write(md_content)
    
    def run_specific_test(self, test_name, verbose=True):
        """Run a specific test by name."""
        if test_name not in self.test_modules:
            available_tests = ', '.join(self.test_modules)
            raise ValueError(f"Test '{test_name}' not found. Available tests: {available_tests}")
        
        print(f"🔒 Running specific test: {test_name}")
        success, output = self._run_test_module(test_name, verbose)
        
        if success:
            print(f"✅ {test_name} PASSED")
        else:
            print(f"❌ {test_name} FAILED")
            print(output)
        
        return success, output
    
    def validate_policy_files(self):
        """Validate that all required policy files exist."""
        policies_dir = Path(__file__).parent.parent.parent / "docs" / "policies"
        
        required_files = [
            "scp-lambda-governance.json",
            "scp-lambda-code-signing.json",
            "scp-api-gateway-waf.json",
            "config-conformance-pack-lambda.yaml",
            "iam-permission-boundary-cicd.json",
            "iam-permission-boundary-lambda-execution.json"
        ]
        
        missing_files = []
        for file_name in required_files:
            file_path = policies_dir / file_name
            if not file_path.exists():
                missing_files.append(file_name)
        
        if missing_files:
            print("❌ Missing required policy files:")
            for file_name in missing_files:
                print(f"   - {file_name}")
            return False
        else:
            print("✅ All required policy files found")
            return True


def main():
    """Main entry point for policy test runner."""
    parser = argparse.ArgumentParser(description='Run policy and guardrail validation tests')
    parser.add_argument('--test', help='Run specific test module')
    parser.add_argument('--output-dir', help='Output directory for test results')
    parser.add_argument('--quiet', action='store_true', help='Run tests in quiet mode')
    parser.add_argument('--no-report', action='store_true', help='Skip generating test report')
    parser.add_argument('--validate-files', action='store_true', help='Only validate policy files exist')
    
    args = parser.parse_args()
    
    runner = PolicyTestRunner(output_dir=args.output_dir)
    
    if args.validate_files:
        success = runner.validate_policy_files()
        sys.exit(0 if success else 1)
    
    if args.test:
        try:
            success, _ = runner.run_specific_test(args.test, verbose=not args.quiet)
            sys.exit(0 if success else 1)
        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)
    else:
        success, _ = runner.run_all_tests(
            verbose=not args.quiet,
            generate_report=not args.no_report
        )
        sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()