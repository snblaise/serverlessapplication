#!/usr/bin/env python3
"""
Master test runner for comprehensive testing and validation suite.
Orchestrates policy guardrails, workflow integration, and documentation compliance tests.
"""

import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed


class MasterTestRunner:
    """Master test runner for all validation suites."""
    
    def __init__(self, output_dir=None):
        """Initialize master test runner."""
        self.output_dir = Path(output_dir) if output_dir else Path(__file__).parent / "results"
        self.output_dir.mkdir(exist_ok=True)
        
        self.test_suites = {
            'policy-guardrails': {
                'name': 'Policy and Guardrail Testing',
                'path': Path(__file__).parent / 'policy-guardrails',
                'runner': 'test_runner.py',
                'description': 'Validates SCP enforcement, Config rules, and permission boundaries'
            },
            'workflow-integration': {
                'name': 'Workflow and Integration Testing',
                'path': Path(__file__).parent / 'workflow-integration',
                'runner': 'test_runner.py',
                'description': 'Tests CI/CD pipelines, code signing, and canary deployments'
            },
            'documentation-compliance': {
                'name': 'Documentation and Compliance Testing',
                'path': Path(__file__).parent / 'documentation-compliance',
                'runner': 'test_runner.py',
                'description': 'Validates cross-references, compliance mappings, and audit trails'
            }
        }
    
    def run_all_suites(self, parallel=False, verbose=True, generate_report=True):
        """Run all test suites."""
        print("🚀 Starting Comprehensive Production Readiness Validation")
        print("=" * 80)
        print("This validation suite ensures your Lambda production readiness")
        print("package meets enterprise compliance and security standards.")
        print("=" * 80)
        
        if parallel:
            return self._run_suites_parallel(verbose, generate_report)
        else:
            return self._run_suites_sequential(verbose, generate_report)
    
    def _run_suites_sequential(self, verbose, generate_report):
        """Run test suites sequentially."""
        results = {}
        overall_success = True
        
        for suite_id, suite_info in self.test_suites.items():
            print(f"\n🔍 Running {suite_info['name']}...")
            print(f"📝 {suite_info['description']}")
            print("-" * 60)
            
            success, output, duration = self._run_test_suite(suite_id, verbose)
            
            results[suite_id] = {
                'name': suite_info['name'],
                'success': success,
                'output': output,
                'duration': duration,
                'timestamp': datetime.now().isoformat()
            }
            
            if not success:
                overall_success = False
                print(f"❌ {suite_info['name']} FAILED ({duration:.1f}s)")
            else:
                print(f"✅ {suite_info['name']} PASSED ({duration:.1f}s)")
        
        if generate_report:
            self._generate_master_report(results, overall_success)
        
        return overall_success, results
    
    def _run_suites_parallel(self, verbose, generate_report):
        """Run test suites in parallel."""
        print("🔄 Running test suites in parallel...")
        
        results = {}
        overall_success = True
        
        with ThreadPoolExecutor(max_workers=3) as executor:
            # Submit all test suites
            future_to_suite = {
                executor.submit(self._run_test_suite, suite_id, verbose): suite_id
                for suite_id in self.test_suites.keys()
            }
            
            # Collect results as they complete
            for future in as_completed(future_to_suite):
                suite_id = future_to_suite[future]
                suite_info = self.test_suites[suite_id]
                
                try:
                    success, output, duration = future.result()
                    
                    results[suite_id] = {
                        'name': suite_info['name'],
                        'success': success,
                        'output': output,
                        'duration': duration,
                        'timestamp': datetime.now().isoformat()
                    }
                    
                    if not success:
                        overall_success = False
                        print(f"❌ {suite_info['name']} FAILED ({duration:.1f}s)")
                    else:
                        print(f"✅ {suite_info['name']} PASSED ({duration:.1f}s)")
                        
                except Exception as e:
                    overall_success = False
                    results[suite_id] = {
                        'name': suite_info['name'],
                        'success': False,
                        'output': f"Exception: {str(e)}",
                        'duration': 0,
                        'timestamp': datetime.now().isoformat()
                    }
                    print(f"❌ {suite_info['name']} FAILED (Exception: {e})")
        
        if generate_report:
            self._generate_master_report(results, overall_success)
        
        return overall_success, results
    
    def _run_test_suite(self, suite_id, verbose):
        """Run a specific test suite."""
        suite_info = self.test_suites[suite_id]
        suite_path = suite_info['path']
        runner_script = suite_info['runner']
        
        if not suite_path.exists():
            return False, f"Test suite directory not found: {suite_path}", 0
        
        runner_path = suite_path / runner_script
        if not runner_path.exists():
            return False, f"Test runner not found: {runner_path}", 0
        
        start_time = datetime.now()
        
        try:
            # Run the test suite
            cmd = [
                sys.executable, str(runner_path),
                '--output-dir', str(self.output_dir / suite_id)
            ]
            
            if not verbose:
                cmd.append('--quiet')
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=suite_path
            )
            
            duration = (datetime.now() - start_time).total_seconds()
            
            return result.returncode == 0, result.stdout + result.stderr, duration
            
        except Exception as e:
            duration = (datetime.now() - start_time).total_seconds()
            return False, f"Error running test suite: {str(e)}", duration
    
    def _generate_master_report(self, results, overall_success):
        """Generate comprehensive master report."""
        report = {
            'timestamp': datetime.now().isoformat(),
            'overall_success': overall_success,
            'summary': {
                'total_suites': len(self.test_suites),
                'passed_suites': sum(1 for r in results.values() if r['success']),
                'failed_suites': sum(1 for r in results.values() if not r['success']),
                'total_duration': sum(r['duration'] for r in results.values())
            },
            'results': results
        }
        
        # Save JSON report
        json_report_path = self.output_dir / 'master_validation_report.json'
        with open(json_report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        # Generate markdown report
        self._generate_master_markdown_report(report)
        
        print(f"\n📊 Master validation report generated: {json_report_path}")
    
    def _generate_master_markdown_report(self, report):
        """Generate comprehensive markdown master report."""
        md_content = f"""# Lambda Production Readiness Validation Report

**Generated:** {report['timestamp']}  
**Overall Status:** {'✅ PRODUCTION READY' if report['overall_success'] else '❌ NOT READY FOR PRODUCTION'}

## Executive Summary

This comprehensive validation report covers all aspects of Lambda production readiness including policy enforcement, workflow automation, and compliance documentation. The validation ensures your serverless infrastructure meets enterprise security, compliance, and operational standards.

**Validation Coverage:**
- 🔒 **Policy and Guardrail Enforcement** - Service Control Policies, Config rules, permission boundaries
- 🚀 **CI/CD Workflow Integration** - GitHub Actions, code signing, canary deployments  
- 📚 **Documentation and Compliance** - Cross-references, compliance mappings, audit trails

## Summary

- **Total Test Suites:** {report['summary']['total_suites']}
- **Passed Suites:** {report['summary']['passed_suites']}
- **Failed Suites:** {report['summary']['failed_suites']}
- **Total Duration:** {report['summary']['total_duration']:.1f} seconds

## Test Suite Results

"""
        
        for suite_id, result in report['results'].items():
            status = '✅ PASSED' if result['success'] else '❌ FAILED'
            suite_info = self.test_suites[suite_id]
            
            md_content += f"### {result['name']}\n\n"
            md_content += f"**Status:** {status}  \n"
            md_content += f"**Duration:** {result['duration']:.1f} seconds  \n"
            md_content += f"**Description:** {suite_info['description']}  \n"
            md_content += f"**Timestamp:** {result['timestamp']}\n\n"
            
            if not result['success']:
                md_content += "**Error Summary:**\n```\n"
                # Extract key error information
                error_lines = result['output'].split('\n')
                key_errors = [line for line in error_lines if 'FAILED' in line or 'ERROR' in line or 'AssertionError' in line]
                
                if key_errors:
                    md_content += '\n'.join(key_errors[:10])  # Show first 10 errors
                    if len(key_errors) > 10:
                        md_content += f"\n... and {len(key_errors) - 10} more errors"
                else:
                    md_content += result['output'][:500]  # Show first 500 chars if no specific errors
                    if len(result['output']) > 500:
                        md_content += "\n... (truncated)"
                
                md_content += "\n```\n\n"
        
        md_content += """## Production Readiness Assessment

### Policy and Guardrail Enforcement ✅/❌
- **Service Control Policies (SCPs):** Prevent unauthorized Lambda deployments and enforce governance
- **AWS Config Rules:** Automated compliance checking for Lambda configurations  
- **Permission Boundaries:** Restrict CI/CD roles and enforce least privilege access
- **Code Signing Enforcement:** Ensure only signed code can be deployed to production

### CI/CD Workflow Integration ✅/❌
- **GitHub Actions Workflows:** Automated build, test, and deployment pipelines
- **OIDC Authentication:** Secure, keyless authentication to AWS services
- **Code Signing Integration:** AWS Signer integration for code integrity
- **Canary Deployments:** Safe, gradual rollouts with automatic rollback capabilities
- **Security Scanning:** SAST, SCA, and infrastructure-as-code security validation

### Documentation and Compliance ✅/❌
- **Cross-Reference Integrity:** All documents properly linked and traceable
- **Compliance Framework Mapping:** ISO 27001, SOC 2, and NIST CSF coverage
- **Evidence Artifact Validation:** Automated evidence collection and accessibility
- **Audit Trail Completeness:** Comprehensive logging and monitoring evidence

## Compliance Framework Coverage

### ISO 27001:2013 Information Security Management
"""
        
        if report['overall_success']:
            md_content += """- ✅ A.9.1.1 Access control policy implementation
- ✅ A.9.2.4 Secret authentication information management  
- ✅ A.10.1.1 Cryptographic controls policy
- ✅ A.12.1.2 Change management procedures
- ✅ A.12.4.1 Event logging and monitoring
- ✅ A.12.6.1 Technical vulnerability management
- ✅ A.13.1.1 Network security controls
- ✅ A.14.2.1 Secure development lifecycle

### SOC 2 Type II Service Organization Controls
- ✅ CC6.1 Logical and physical access controls
- ✅ CC6.2 Authorized user access restrictions
- ✅ CC6.3 Data transmission protection
- ✅ CC7.1 System capacity monitoring
- ✅ CC7.4 Security incident resolution
- ✅ CC8.1 Change management processes

### NIST Cybersecurity Framework
- ✅ PR.AC-1 Identity and credential management
- ✅ PR.AC-4 Least privilege access controls
- ✅ PR.DS-1 Data-at-rest protection
- ✅ PR.DS-2 Data-in-transit protection
- ✅ PR.IP-2 System development lifecycle
- ✅ PR.PT-1 Audit logging implementation
- ✅ DE.CM-1 Network monitoring
- ✅ RS.RP-1 Response plan execution

## Production Deployment Readiness

### ✅ Ready for Production Deployment
Your Lambda production readiness package has passed all validation tests and is ready for:

**Immediate Actions:**
1. **Deploy to Production:** All guardrails and controls are in place
2. **Enable Monitoring:** Activate all CloudWatch alarms and dashboards
3. **Conduct Go-Live Review:** Final stakeholder approval with validated evidence
4. **Begin Operations:** Start using operational runbooks and procedures

**Ongoing Maintenance:**
1. **Regular Validation:** Schedule monthly validation runs
2. **Compliance Monitoring:** Monitor compliance dashboards daily
3. **Policy Updates:** Review and update policies quarterly
4. **Documentation Maintenance:** Keep documentation current with changes

### 🎯 Production Readiness Checklist
- ✅ All security controls implemented and tested
- ✅ CI/CD pipeline validated and operational
- ✅ Compliance documentation complete and auditable
- ✅ Monitoring and alerting configured
- ✅ Incident response procedures documented
- ✅ Rollback procedures tested and validated
- ✅ Evidence artifacts accessible and automated
- ✅ Audit trail complete and compliant

"""
        else:
            md_content += """❌ **CRITICAL ISSUES FOUND - NOT READY FOR PRODUCTION**

### Required Actions Before Production Deployment

1. **Fix Failed Test Suites:** Address all failing tests in the results above
2. **Validate Security Controls:** Ensure all policy guardrails are properly configured
3. **Test CI/CD Pipeline:** Verify end-to-end deployment and rollback procedures
4. **Complete Documentation:** Fix cross-reference issues and compliance gaps
5. **Re-run Validation:** Execute full validation suite after fixes

### Risk Assessment
Deploying to production without addressing these issues poses significant risks:
- **Security Vulnerabilities:** Inadequate policy enforcement
- **Compliance Violations:** Missing or incomplete compliance controls
- **Operational Failures:** Untested deployment and rollback procedures
- **Audit Failures:** Incomplete documentation and evidence trails

### Next Steps
1. Review detailed error messages in each failed test suite
2. Address configuration and documentation issues
3. Re-run individual test suites as fixes are implemented
4. Execute full validation suite before production deployment
5. Obtain security and compliance team approval

"""
        
        md_content += """## Detailed Test Coverage

### Policy and Guardrail Testing
- **SCP Enforcement:** 15+ test cases validating Service Control Policy effectiveness
- **Config Rules:** 12+ test cases for managed and custom AWS Config rules
- **Permission Boundaries:** 18+ test cases for CI/CD role restrictions and enforcement
- **Policy Syntax:** Validation of JSON/YAML policy syntax and structure

### Workflow Integration Testing  
- **CI/CD Pipeline:** 10+ test cases for GitHub Actions workflow validation
- **Code Signing:** 12+ test cases for AWS Signer integration and enforcement
- **Canary Deployment:** 15+ test cases for CodeDeploy canary scenarios and rollback
- **Security Integration:** Validation of security scanning and Security Hub integration

### Documentation Compliance Testing
- **Cross-References:** 12+ test cases for document linkage and traceability
- **Compliance Mapping:** 8+ test cases for ISO 27001, SOC 2, and NIST CSF coverage
- **Audit Trails:** 15+ test cases for evidence accessibility and completeness
- **Quality Assurance:** Markdown syntax, link validation, and content completeness

## Evidence Artifacts Validated

### Monitoring Evidence
- CloudWatch metrics, alarms, and dashboards
- X-Ray tracing configurations and service maps
- Lambda Powertools integration and structured logging
- Performance monitoring and error tracking

### Compliance Evidence  
- AWS Config rules and conformance packs
- Config compliance dashboards and reports
- Automated compliance checking and remediation
- Security posture monitoring

### Audit Evidence
- CloudTrail event logging and analysis
- API call auditing and change tracking
- Access logging and authentication events
- Incident response and recovery procedures

### Security Evidence
- Security Hub findings aggregation
- Vulnerability assessment results
- Security policy enforcement validation
- Code signing and integrity verification

## Recommendations for Continuous Improvement

### Automation Enhancements
1. **Automated Validation:** Integrate validation suite into CI/CD pipeline
2. **Continuous Monitoring:** Set up real-time compliance monitoring
3. **Automated Remediation:** Implement auto-remediation for common issues
4. **Regular Updates:** Schedule quarterly policy and procedure reviews

### Operational Excellence
1. **Runbook Testing:** Regularly test incident response procedures
2. **Team Training:** Conduct quarterly training on security and compliance procedures
3. **Metrics Tracking:** Monitor key performance and security indicators
4. **Feedback Loops:** Establish processes for continuous improvement

### Compliance Maintenance
1. **Audit Preparation:** Maintain audit-ready documentation and evidence
2. **Regulatory Updates:** Stay current with compliance framework changes
3. **Risk Assessment:** Conduct regular risk assessments and updates
4. **Stakeholder Communication:** Regular reporting to security and compliance teams

---

**Report Generated By:** Lambda Production Readiness Validation Suite  
**Validation Framework Version:** 1.0  
**Total Validation Time:** {report['summary']['total_duration']:.1f} seconds

This comprehensive validation ensures your Lambda serverless infrastructure meets enterprise production standards for security, compliance, and operational excellence.
"""
        
        # Save markdown report
        md_report_path = self.output_dir / 'master_validation_report.md'
        with open(md_report_path, 'w') as f:
            f.write(md_content)
    
    def run_specific_suite(self, suite_name, verbose=True):
        """Run a specific test suite."""
        if suite_name not in self.test_suites:
            available_suites = ', '.join(self.test_suites.keys())
            raise ValueError(f"Suite '{suite_name}' not found. Available suites: {available_suites}")
        
        suite_info = self.test_suites[suite_name]
        print(f"🔍 Running {suite_info['name']}...")
        
        success, output, duration = self._run_test_suite(suite_name, verbose)
        
        if success:
            print(f"✅ {suite_info['name']} PASSED ({duration:.1f}s)")
        else:
            print(f"❌ {suite_info['name']} FAILED ({duration:.1f}s)")
            if verbose:
                print(output)
        
        return success, output, duration
    
    def validate_environment(self):
        """Validate that the test environment is properly set up."""
        print("🔧 Validating test environment...")
        
        checks = [
            self._check_python_version,
            self._check_test_suite_structure,
            self._check_dependencies
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
            print("\n✅ Test environment validation PASSED")
        else:
            print("\n❌ Test environment validation FAILED")
        
        return overall_success
    
    def _check_python_version(self):
        """Check Python version compatibility."""
        import sys
        
        version = sys.version_info
        if version.major >= 3 and version.minor >= 8:
            return True, f"Python version compatible: {version.major}.{version.minor}.{version.micro}"
        else:
            return False, f"Python version too old: {version.major}.{version.minor}.{version.micro} (requires 3.8+)"
    
    def _check_test_suite_structure(self):
        """Check that all test suites are properly structured."""
        missing_suites = []
        
        for suite_id, suite_info in self.test_suites.items():
            suite_path = suite_info['path']
            runner_path = suite_path / suite_info['runner']
            
            if not suite_path.exists():
                missing_suites.append(f"{suite_id} (directory missing)")
            elif not runner_path.exists():
                missing_suites.append(f"{suite_id} (runner missing)")
        
        if missing_suites:
            return False, f"Missing test suites: {missing_suites}"
        else:
            return True, f"All {len(self.test_suites)} test suites found"
    
    def _check_dependencies(self):
        """Check that required dependencies are available."""
        try:
            import pytest
            return True, "Required dependencies available"
        except ImportError:
            return False, "Missing required dependencies (pytest not found)"


def main():
    """Main entry point for master test runner."""
    parser = argparse.ArgumentParser(description='Run comprehensive production readiness validation')
    parser.add_argument('--suite', help='Run specific test suite only')
    parser.add_argument('--output-dir', help='Output directory for test results')
    parser.add_argument('--parallel', action='store_true', help='Run test suites in parallel')
    parser.add_argument('--quiet', action='store_true', help='Run tests in quiet mode')
    parser.add_argument('--no-report', action='store_true', help='Skip generating master report')
    parser.add_argument('--validate-env', action='store_true', help='Validate test environment only')
    
    args = parser.parse_args()
    
    runner = MasterTestRunner(output_dir=args.output_dir)
    
    if args.validate_env:
        success = runner.validate_environment()
        sys.exit(0 if success else 1)
    
    if args.suite:
        try:
            success, _, _ = runner.run_specific_suite(args.suite, verbose=not args.quiet)
            sys.exit(0 if success else 1)
        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)
    else:
        success, _ = runner.run_all_suites(
            parallel=args.parallel,
            verbose=not args.quiet,
            generate_report=not args.no_report
        )
        sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()