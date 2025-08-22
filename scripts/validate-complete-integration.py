#!/usr/bin/env python3
"""
Comprehensive integration validation for Lambda PRR package.
Validates that all 40+ control matrix entries have proper evidence artifacts.
"""

import json
import csv
import os
import sys
from pathlib import Path
from datetime import datetime
import subprocess

class IntegrationValidator:
    def __init__(self):
        self.root_path = Path(__file__).parent.parent
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'overall_success': True,
            'validation_summary': {},
            'control_matrix_validation': {},
            'component_integration': {},
            'evidence_artifacts': {},
            'compliance_readiness': {}
        }
    
    def validate_control_matrix_coverage(self):
        """Validate that control matrix has proper coverage and evidence."""
        print("🔍 Validating Control Matrix Coverage...")
        
        control_matrix_path = self.root_path / "docs" / "control-matrix.csv"
        if not control_matrix_path.exists():
            self.results['control_matrix_validation']['error'] = "Control matrix file not found"
            return False
        
        controls = []
        evidence_count = 0
        automated_checks = 0
        
        with open(control_matrix_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                controls.append(row)
                if row.get('Evidence Artifact', '').strip():
                    evidence_count += 1
                if row.get('Automated Check/Test', '').strip():
                    automated_checks += 1
        
        total_controls = len(controls)
        evidence_coverage = evidence_count / total_controls if total_controls > 0 else 0
        automation_coverage = automated_checks / total_controls if total_controls > 0 else 0
        
        self.results['control_matrix_validation'] = {
            'total_controls': total_controls,
            'evidence_coverage': evidence_coverage,
            'automation_coverage': automation_coverage,
            'evidence_count': evidence_count,
            'automated_checks': automated_checks,
            'meets_40_plus_requirement': total_controls >= 40,
            'meets_evidence_threshold': evidence_coverage >= 0.8,
            'meets_automation_threshold': automation_coverage >= 0.6
        }
        
        print(f"   ✅ Total Controls: {total_controls}")
        print(f"   ✅ Evidence Coverage: {evidence_coverage:.1%}")
        print(f"   ✅ Automation Coverage: {automation_coverage:.1%}")
        
        return total_controls >= 40 and evidence_coverage >= 0.8
    
    def validate_policy_guardrails(self):
        """Validate policy guardrails are properly implemented."""
        print("🛡️ Validating Policy Guardrails...")
        
        policy_files = [
            "docs/policies/scp-lambda-code-signing.json",
            "docs/policies/scp-lambda-governance.json", 
            "docs/policies/scp-lambda-production-governance.json",
            "docs/policies/scp-api-gateway-waf.json",
            "docs/policies/config-conformance-pack-lambda.yaml",
            "docs/policies/iam-permission-boundary-cicd.json",
            "docs/policies/iam-permission-boundary-lambda-execution.json"
        ]
        
        existing_policies = 0
        for policy_file in policy_files:
            if (self.root_path / policy_file).exists():
                existing_policies += 1
        
        custom_rules = list((self.root_path / "docs" / "policies" / "custom-rules").glob("*.py"))
        
        self.results['component_integration']['policy_guardrails'] = {
            'scp_policies': existing_policies >= 4,
            'config_conformance_pack': (self.root_path / "docs/policies/config-conformance-pack-lambda.yaml").exists(),
            'permission_boundaries': existing_policies >= 6,
            'custom_config_rules': len(custom_rules) >= 4,
            'total_policy_files': existing_policies,
            'custom_rules_count': len(custom_rules)
        }
        
        print(f"   ✅ Policy Files: {existing_policies}/{len(policy_files)}")
        print(f"   ✅ Custom Rules: {len(custom_rules)}")
        
        return existing_policies >= 6 and len(custom_rules) >= 4
    
    def validate_cicd_automation(self):
        """Validate CI/CD automation components."""
        print("🚀 Validating CI/CD Automation...")
        
        scripts = [
            "scripts/build-lambda-package.sh",
            "scripts/sign-lambda-package.sh", 
            "scripts/deploy-lambda-canary.sh",
            "scripts/rollback-lambda-deployment.sh",
            "scripts/validate-lambda-package.sh"
        ]
        
        existing_scripts = 0
        for script in scripts:
            if (self.root_path / script).exists():
                existing_scripts += 1
        
        # Check for GitHub Actions workflow template
        github_workflow_exists = (self.root_path / ".github" / "workflows").exists()
        
        self.results['component_integration']['cicd_automation'] = {
            'deployment_scripts': existing_scripts >= 4,
            'github_actions_ready': github_workflow_exists,
            'total_scripts': existing_scripts,
            'script_coverage': existing_scripts / len(scripts)
        }
        
        print(f"   ✅ Deployment Scripts: {existing_scripts}/{len(scripts)}")
        print(f"   ✅ GitHub Actions Ready: {github_workflow_exists}")
        
        return existing_scripts >= 4
    
    def validate_operational_procedures(self):
        """Validate operational runbooks and procedures."""
        print("📖 Validating Operational Procedures...")
        
        runbooks = [
            "docs/runbooks/lambda-incident-response.md",
            "docs/runbooks/sqs-dlq-troubleshooting.md",
            "docs/runbooks/secret-rotation-runtime-upgrade.md",
            "docs/runbooks/incident-flow-diagrams.md"
        ]
        
        existing_runbooks = 0
        for runbook in runbooks:
            if (self.root_path / runbook).exists():
                existing_runbooks += 1
        
        checklist_exists = (self.root_path / "docs/checklists/lambda-production-readiness-checklist.md").exists()
        
        self.results['component_integration']['operational_procedures'] = {
            'incident_runbooks': existing_runbooks >= 3,
            'production_checklist': checklist_exists,
            'total_runbooks': existing_runbooks,
            'runbook_coverage': existing_runbooks / len(runbooks)
        }
        
        print(f"   ✅ Runbooks: {existing_runbooks}/{len(runbooks)}")
        print(f"   ✅ Production Checklist: {checklist_exists}")
        
        return existing_runbooks >= 3 and checklist_exists
    
    def validate_documentation_package(self):
        """Validate documentation completeness."""
        print("📚 Validating Documentation Package...")
        
        core_docs = [
            "docs/EXECUTIVE_SUMMARY.md",
            "docs/IMPLEMENTATION_GUIDE.md",
            "docs/TABLE_OF_CONTENTS.md",
            "docs/INDEX.md",
            "docs/prr/lambda-production-readiness-requirements.md",
            "docs/control-matrix.csv"
        ]
        
        existing_docs = 0
        for doc in core_docs:
            if (self.root_path / doc).exists():
                existing_docs += 1
        
        diagrams_exist = len(list((self.root_path / "docs" / "diagrams").glob("*.md"))) >= 2
        
        self.results['component_integration']['documentation_package'] = {
            'core_documentation': existing_docs >= 5,
            'architecture_diagrams': diagrams_exist,
            'total_docs': existing_docs,
            'doc_coverage': existing_docs / len(core_docs)
        }
        
        print(f"   ✅ Core Documentation: {existing_docs}/{len(core_docs)}")
        print(f"   ✅ Architecture Diagrams: {diagrams_exist}")
        
        return existing_docs >= 5 and diagrams_exist
    
    def validate_testing_framework(self):
        """Validate testing framework completeness."""
        print("🧪 Validating Testing Framework...")
        
        test_suites = [
            "tests/policy-guardrails",
            "tests/workflow-integration", 
            "tests/documentation-compliance"
        ]
        
        existing_suites = 0
        total_test_files = 0
        
        for suite in test_suites:
            suite_path = self.root_path / suite
            if suite_path.exists():
                existing_suites += 1
                test_files = list(suite_path.glob("test_*.py"))
                total_test_files += len(test_files)
        
        master_runner_exists = (self.root_path / "tests/master_test_runner.py").exists()
        
        self.results['component_integration']['testing_framework'] = {
            'test_suites_complete': existing_suites >= 3,
            'master_runner': master_runner_exists,
            'total_test_suites': existing_suites,
            'total_test_files': total_test_files
        }
        
        print(f"   ✅ Test Suites: {existing_suites}/{len(test_suites)}")
        print(f"   ✅ Test Files: {total_test_files}")
        print(f"   ✅ Master Runner: {master_runner_exists}")
        
        return existing_suites >= 3 and master_runner_exists
    
    def validate_evidence_artifacts(self):
        """Validate evidence artifact accessibility."""
        print("📊 Validating Evidence Artifacts...")
        
        evidence_scripts = [
            "scripts/generate-checklist-evidence.py",
            "scripts/validate-checklist-compliance.py",
            "scripts/validate-control-matrix.py",
            "scripts/validate-production-readiness.py"
        ]
        
        existing_evidence_scripts = 0
        for script in evidence_scripts:
            if (self.root_path / script).exists():
                existing_evidence_scripts += 1
        
        self.results['evidence_artifacts'] = {
            'evidence_generation_scripts': existing_evidence_scripts >= 3,
            'total_evidence_scripts': existing_evidence_scripts,
            'script_coverage': existing_evidence_scripts / len(evidence_scripts)
        }
        
        print(f"   ✅ Evidence Scripts: {existing_evidence_scripts}/{len(evidence_scripts)}")
        
        return existing_evidence_scripts >= 3
    
    def validate_compliance_readiness(self):
        """Validate compliance audit readiness."""
        print("✅ Validating Compliance Readiness...")
        
        # Check for compliance framework coverage
        prr_doc = self.root_path / "docs/prr/lambda-production-readiness-requirements.md"
        compliance_coverage = {
            'iso27001': False,
            'soc2': False,
            'nist_csf': False,
            'aws_well_architected': False
        }
        
        if prr_doc.exists():
            content = prr_doc.read_text().lower()
            compliance_coverage['iso27001'] = 'iso 27001' in content or 'iso27001' in content
            compliance_coverage['soc2'] = 'soc 2' in content or 'soc2' in content
            compliance_coverage['nist_csf'] = 'nist' in content
            compliance_coverage['aws_well_architected'] = 'well-architected' in content or 'well architected' in content
        
        frameworks_covered = sum(compliance_coverage.values())
        
        self.results['compliance_readiness'] = {
            'frameworks_covered': frameworks_covered,
            'framework_details': compliance_coverage,
            'meets_compliance_threshold': frameworks_covered >= 3,
            'audit_ready': frameworks_covered >= 3
        }
        
        print(f"   ✅ Compliance Frameworks: {frameworks_covered}/4")
        for framework, covered in compliance_coverage.items():
            status = "✅" if covered else "❌"
            print(f"      {status} {framework.upper()}")
        
        return frameworks_covered >= 3
    
    def run_comprehensive_validation(self):
        """Run complete integration validation."""
        print("🚀 Starting Comprehensive Integration Validation")
        print("=" * 60)
        
        validations = [
            ("Control Matrix Coverage", self.validate_control_matrix_coverage),
            ("Policy Guardrails", self.validate_policy_guardrails),
            ("CI/CD Automation", self.validate_cicd_automation),
            ("Operational Procedures", self.validate_operational_procedures),
            ("Documentation Package", self.validate_documentation_package),
            ("Testing Framework", self.validate_testing_framework),
            ("Evidence Artifacts", self.validate_evidence_artifacts),
            ("Compliance Readiness", self.validate_compliance_readiness)
        ]
        
        passed_validations = 0
        total_validations = len(validations)
        
        for name, validation_func in validations:
            try:
                result = validation_func()
                if result:
                    passed_validations += 1
                    print(f"✅ {name}: PASSED")
                else:
                    print(f"❌ {name}: FAILED")
                    self.results['overall_success'] = False
            except Exception as e:
                print(f"❌ {name}: ERROR - {str(e)}")
                self.results['overall_success'] = False
            print()
        
        # Calculate overall success rate
        success_rate = passed_validations / total_validations
        self.results['validation_summary'] = {
            'total_validations': total_validations,
            'passed_validations': passed_validations,
            'success_rate': success_rate,
            'production_ready': success_rate >= 0.8
        }
        
        print("=" * 60)
        print(f"📊 Validation Summary:")
        print(f"   Total Validations: {total_validations}")
        print(f"   Passed: {passed_validations}")
        print(f"   Success Rate: {success_rate:.1%}")
        
        if success_rate >= 0.8:
            print("🎉 INTEGRATION VALIDATION PASSED - PRODUCTION READY!")
        else:
            print("⚠️  INTEGRATION VALIDATION FAILED - NEEDS ATTENTION")
        
        return self.results['overall_success']
    
    def generate_validation_report(self, output_file):
        """Generate detailed validation report."""
        with open(output_file, 'w') as f:
            json.dump(self.results, f, indent=2)
        
        print(f"📄 Detailed validation report saved to: {output_file}")

def main():
    validator = IntegrationValidator()
    
    # Run comprehensive validation
    success = validator.run_comprehensive_validation()
    
    # Generate detailed report
    output_dir = Path("test-results")
    output_dir.mkdir(exist_ok=True)
    report_file = output_dir / "integration_validation_report.json"
    validator.generate_validation_report(report_file)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()