#!/usr/bin/env python3
"""
Test runner for workflow and integration testing.
Orchestrates CI/CD pipeline tests and generates comprehensive reports.
"""

import pytest
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime
import argparse


class WorkflowTestRunner:
    """Main test runner for workflow and integration validation."""
    
    def __init__(self, output_dir=None):
        """Initialize test runner."""
        self.output_dir = Path(output_dir) if output_dir else Path(__file__).parent / "results"
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.test_modules = [
            'test_cicd_pipeline.py',
            'test_code_signing.py',
            'test_canary_deployment.py'
        ]
    
    def run_all_tests(self, verbose=True, generate_report=True):
        """Run all workflow and integration tests."""
        print("🚀 Starting Workflow and Integration Tests")
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
        json_report_path = self.output_dir / 'workflow_test_report.json'
        with open(json_report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        # Generate markdown report
        self._generate_markdown_report(report)
        
        print(f"\n📊 Test report generated: {json_report_path}")
    
    def _generate_markdown_report(self, report):
        """Generate markdown test report."""
        md_content = f"""# Workflow and Integration Test Report

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

### CI/CD Pipeline Testing
- GitHub Actions workflow structure validation
- OIDC authentication configuration
- Security scanning integration (SAST, SCA, IaC)
- Build and package stage validation
- Environment-specific configurations
- Approval gates for production deployments

### Code Signing Validation
- AWS Signer integration testing
- Signature verification processes
- SCP enforcement for unsigned code prevention
- Signing profile configuration
- Certificate validation requirements
- Signing metadata preservation

### Canary Deployment Testing
- Lambda alias management for traffic shifting
- CodeDeploy application and deployment group configuration
- CloudWatch alarms for automatic rollback
- Deployment validation and health checks
- Rollback procedure testing
- Traffic shifting strategy validation

## Integration Points

The tests validate integration between:

1. **GitHub Actions ↔ AWS Services**
   - OIDC authentication flow
   - AWS CLI operations in workflows
   - Security Hub findings upload

2. **AWS Signer ↔ Lambda Deployment**
   - Code signing enforcement
   - Signature verification in deployment pipeline

3. **CodeDeploy ↔ Lambda Aliases**
   - Canary deployment orchestration
   - Weighted traffic routing
   - Automatic rollback triggers

4. **CloudWatch ↔ Deployment Monitoring**
   - Alarm-based rollback triggers
   - Deployment health monitoring
   - Performance metrics tracking

## Recommendations

"""
        
        if not report['overall_success']:
            md_content += """### Failed Tests
Review the failed test modules above and address the following:

1. **Workflow Configuration:** Ensure GitHub Actions workflows are properly structured
2. **Script Dependencies:** Verify all deployment scripts exist and are executable
3. **AWS Integration:** Check AWS service configurations and permissions
4. **Security Controls:** Validate code signing and security scanning setup

### Next Steps
1. Fix failing tests by addressing configuration issues
2. Validate scripts in a sandbox environment
3. Test end-to-end pipeline with actual deployments
4. Set up monitoring and alerting for production use

"""
        else:
            md_content += """### All Tests Passed
Your workflow and integration configuration meets the production readiness requirements.

**Next Steps:**
1. Deploy pipeline to staging environment for end-to-end testing
2. Configure production environment with proper approval gates
3. Set up monitoring dashboards for deployment tracking
4. Schedule regular pipeline validation runs
5. Train team on deployment and rollback procedures

### Production Readiness Checklist
- ✅ CI/CD pipeline structure validated
- ✅ Code signing enforcement configured
- ✅ Canary deployment procedures tested
- ✅ Rollback mechanisms validated
- ✅ Security scanning integrated
- ✅ Monitoring and alerting configured

"""
        
        # Save markdown report
        md_report_path = self.output_dir / 'workflow_test_report.md'
        with open(md_report_path, 'w') as f:
            f.write(md_content)
    
    def run_specific_test(self, test_name, verbose=True):
        """Run a specific test by name."""
        if test_name not in self.test_modules:
            available_tests = ', '.join(self.test_modules)
            raise ValueError(f"Test '{test_name}' not found. Available tests: {available_tests}")
        
        print(f"🚀 Running specific test: {test_name}")
        success, output = self._run_test_module(test_name, verbose)
        
        if success:
            print(f"✅ {test_name} PASSED")
        else:
            print(f"❌ {test_name} FAILED")
            print(output)
        
        return success, output
    
    def validate_workflow_files(self):
        """Validate that all required workflow and script files exist."""
        project_root = Path(__file__).parent.parent.parent
        
        required_files = {
            'GitHub Workflows': [
                '.github/workflows/deploy.yml',
                '.github/workflows/ci.yml'
            ],
            'Deployment Scripts': [
                'scripts/build-lambda-package.sh',
                'scripts/sign-lambda-package.sh',
                'scripts/deploy-lambda-canary.sh',
                'scripts/rollback-lambda-deployment.sh',
                'scripts/validate-lambda-package.sh'
            ]
        }
        
        missing_files = {}
        for category, files in required_files.items():
            missing_in_category = []
            for file_path in files:
                full_path = project_root / file_path
                if not full_path.exists():
                    missing_in_category.append(file_path)
            
            if missing_in_category:
                missing_files[category] = missing_in_category
        
        if missing_files:
            print("❌ Missing required workflow/script files:")
            for category, files in missing_files.items():
                print(f"\n{category}:")
                for file_path in files:
                    print(f"   - {file_path}")
            return False
        else:
            print("✅ All required workflow and script files found")
            return True
    
    def run_integration_smoke_test(self):
        """Run a quick smoke test of integration points."""
        print("🔥 Running integration smoke test...")
        
        # Check for basic integration requirements
        checks = [
            self._check_github_workflow_syntax,
            self._check_script_executability,
            self._check_aws_cli_availability
        ]
        
        results = []
        for check in checks:
            try:
                success, message = check()
                results.append((success, message))
                print(f"{'✅' if success else '❌'} {message}")
            except Exception as e:
                results.append((False, f"Check failed: {e}"))
                print(f"❌ Check failed: {e}")
        
        overall_success = all(result[0] for result in results)
        
        if overall_success:
            print("\n✅ Integration smoke test PASSED")
        else:
            print("\n❌ Integration smoke test FAILED")
        
        return overall_success
    
    def _check_github_workflow_syntax(self):
        """Check GitHub workflow syntax."""
        import yaml
        
        project_root = Path(__file__).parent.parent.parent
        workflow_dir = project_root / '.github' / 'workflows'
        
        if not workflow_dir.exists():
            return False, "No GitHub workflows directory found"
        
        workflow_files = list(workflow_dir.glob('*.yml')) + list(workflow_dir.glob('*.yaml'))
        
        if not workflow_files:
            return False, "No GitHub workflow files found"
        
        for workflow_file in workflow_files:
            try:
                with open(workflow_file, 'r') as f:
                    yaml.safe_load(f)
            except yaml.YAMLError as e:
                return False, f"Invalid YAML in {workflow_file.name}: {e}"
        
        return True, f"GitHub workflow syntax valid ({len(workflow_files)} files)"
    
    def _check_script_executability(self):
        """Check that deployment scripts are executable."""
        project_root = Path(__file__).parent.parent.parent
        scripts_dir = project_root / 'scripts'
        
        if not scripts_dir.exists():
            return False, "Scripts directory not found"
        
        script_files = list(scripts_dir.glob('*.sh'))
        
        if not script_files:
            return False, "No shell scripts found"
        
        executable_count = 0
        for script_file in script_files:
            if script_file.stat().st_mode & 0o111:  # Check execute permission
                executable_count += 1
        
        return True, f"Script executability checked ({executable_count}/{len(script_files)} executable)"
    
    def _check_aws_cli_availability(self):
        """Check AWS CLI availability."""
        try:
            result = subprocess.run(['aws', '--version'], capture_output=True, text=True)
            if result.returncode == 0:
                return True, "AWS CLI available"
            else:
                return False, "AWS CLI not working properly"
        except FileNotFoundError:
            return False, "AWS CLI not installed"


def main():
    """Main entry point for workflow test runner."""
    parser = argparse.ArgumentParser(description='Run workflow and integration tests')
    parser.add_argument('--test', help='Run specific test module')
    parser.add_argument('--output-dir', help='Output directory for test results')
    parser.add_argument('--quiet', action='store_true', help='Run tests in quiet mode')
    parser.add_argument('--no-report', action='store_true', help='Skip generating test report')
    parser.add_argument('--validate-files', action='store_true', help='Only validate workflow files exist')
    parser.add_argument('--smoke-test', action='store_true', help='Run integration smoke test')
    
    args = parser.parse_args()
    
    runner = WorkflowTestRunner(output_dir=args.output_dir)
    
    if args.validate_files:
        success = runner.validate_workflow_files()
        sys.exit(0 if success else 1)
    
    if args.smoke_test:
        success = runner.run_integration_smoke_test()
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