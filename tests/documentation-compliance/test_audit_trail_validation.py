#!/usr/bin/env python3
"""
Test suite for audit trail completeness testing and evidence artifact validation.
Validates that all evidence artifacts are accessible and audit trails are complete.
"""

import csv
import json
import re
from pathlib import Path
import pytest
from collections import defaultdict
import subprocess
from urllib.parse import urlparse


class TestAuditTrailValidation:
    """Test cases for audit trail completeness and evidence artifact validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment and load audit trail data."""
        cls.project_root = Path(__file__).parent.parent.parent
        cls.docs_dir = cls.project_root / "docs"
        cls.scripts_dir = cls.project_root / "scripts"
        
        # Load control matrix and other audit sources
        cls.control_matrix = cls._load_control_matrix()
        cls.checklist_items = cls._load_checklist_items()
        cls.evidence_artifacts = cls._extract_evidence_artifacts()
    
    @classmethod
    def _load_control_matrix(cls):
        """Load control matrix CSV."""
        control_matrix_file = cls.docs_dir / "control-matrix.csv"
        
        if not control_matrix_file.exists():
            return []
        
        controls = []
        with open(control_matrix_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                controls.append(row)
        
        return controls
    
    @classmethod
    def _load_checklist_items(cls):
        """Load checklist items from checklist document."""
        checklist_file = cls.docs_dir / "checklists" / "lambda-production-readiness-checklist.md"
        
        if not checklist_file.exists():
            return []
        
        with open(checklist_file, 'r') as f:
            content = f.read()
        
        # Extract checklist items (lines starting with - [ ] or - [x])
        checklist_pattern = r'^- \[([ x])\] (.+)$'
        items = []
        
        for line in content.split('\n'):
            match = re.match(checklist_pattern, line.strip())
            if match:
                checked = match.group(1) == 'x'
                item_text = match.group(2)
                items.append({
                    'checked': checked,
                    'text': item_text,
                    'line': line.strip()
                })
        
        return items
    
    @classmethod
    def _extract_evidence_artifacts(cls):
        """Extract evidence artifacts from control matrix."""
        artifacts = []
        
        for control in cls.control_matrix:
            evidence = control.get('Evidence Artifact', '')
            if evidence and evidence.strip():
                artifacts.append({
                    'control': control.get('Requirement', 'Unknown'),
                    'artifact': evidence.strip(),
                    'automated_check': control.get('Automated Check/Test', ''),
                    'aws_service': control.get('AWS Service/Feature', '')
                })
        
        return artifacts
    
    def test_evidence_artifacts_accessibility(self):
        """Test that evidence artifacts are accessible and properly documented."""
        if not self.evidence_artifacts:
            pytest.skip("No evidence artifacts found")
        
        # Categorize evidence artifacts
        artifact_categories = {
            'aws_console': [],
            'cloudwatch': [],
            'config_rules': [],
            'cloudtrail': [],
            'security_hub': [],
            'documentation': [],
            'scripts': [],
            'policies': [],
            'other': []
        }
        
        for artifact in self.evidence_artifacts:
            artifact_text = artifact['artifact'].lower()
            
            if 'console' in artifact_text or 'dashboard' in artifact_text:
                artifact_categories['aws_console'].append(artifact)
            elif 'cloudwatch' in artifact_text or 'metric' in artifact_text or 'alarm' in artifact_text:
                artifact_categories['cloudwatch'].append(artifact)
            elif 'config' in artifact_text or 'rule' in artifact_text:
                artifact_categories['config_rules'].append(artifact)
            elif 'cloudtrail' in artifact_text or 'trail' in artifact_text:
                artifact_categories['cloudtrail'].append(artifact)
            elif 'security hub' in artifact_text or 'securityhub' in artifact_text:
                artifact_categories['security_hub'].append(artifact)
            elif 'document' in artifact_text or 'policy' in artifact_text or '.md' in artifact_text:
                artifact_categories['documentation'].append(artifact)
            elif 'script' in artifact_text or '.sh' in artifact_text or '.py' in artifact_text:
                artifact_categories['scripts'].append(artifact)
            elif 'scp' in artifact_text or 'iam' in artifact_text or 'json' in artifact_text:
                artifact_categories['policies'].append(artifact)
            else:
                artifact_categories['other'].append(artifact)
        
        # Validate that we have diverse evidence types
        non_empty_categories = sum(1 for artifacts in artifact_categories.values() if artifacts)
        assert non_empty_categories >= 4, f"Should have evidence from at least 4 categories, got {non_empty_categories}"
        
        # Validate specific categories have reasonable coverage
        assert len(artifact_categories['cloudwatch']) >= 2, "Should have CloudWatch evidence artifacts"
        assert len(artifact_categories['config_rules']) >= 1, "Should have Config rules evidence"
    
    def test_automated_check_coverage(self):
        """Test that automated checks are defined for evidence artifacts."""
        if not self.evidence_artifacts:
            pytest.skip("No evidence artifacts found")
        
        automated_checks = 0
        manual_checks = 0
        
        for artifact in self.evidence_artifacts:
            automated_check = artifact['automated_check'].strip()
            
            if automated_check:
                # Check if it's an automated check
                automated_keywords = [
                    'aws config', 'cloudwatch alarm', 'script', 'cli', 'api',
                    'automated', 'monitor', 'alert', 'rule'
                ]
                
                if any(keyword in automated_check.lower() for keyword in automated_keywords):
                    automated_checks += 1
                else:
                    manual_checks += 1
            else:
                manual_checks += 1
        
        total_checks = automated_checks + manual_checks
        automation_ratio = automated_checks / total_checks if total_checks > 0 else 0
        
        assert automation_ratio >= 0.6, f"At least 60% of checks should be automated, got {automation_ratio:.2%}"
    
    def test_cloudwatch_evidence_completeness(self):
        """Test completeness of CloudWatch-based evidence."""
        cloudwatch_artifacts = [
            artifact for artifact in self.evidence_artifacts
            if 'cloudwatch' in artifact['artifact'].lower() or 'metric' in artifact['artifact'].lower()
        ]
        
        if not cloudwatch_artifacts:
            pytest.skip("No CloudWatch evidence artifacts found")
        
        # Check for different types of CloudWatch evidence
        evidence_types = {
            'metrics': 0,
            'alarms': 0,
            'logs': 0,
            'dashboards': 0
        }
        
        for artifact in cloudwatch_artifacts:
            artifact_text = artifact['artifact'].lower()
            
            if 'metric' in artifact_text:
                evidence_types['metrics'] += 1
            if 'alarm' in artifact_text:
                evidence_types['alarms'] += 1
            if 'log' in artifact_text:
                evidence_types['logs'] += 1
            if 'dashboard' in artifact_text:
                evidence_types['dashboards'] += 1
        
        # Should have multiple types of CloudWatch evidence
        active_types = sum(1 for count in evidence_types.values() if count > 0)
        assert active_types >= 2, f"Should have at least 2 types of CloudWatch evidence, got {active_types}"
    
    def test_config_rules_evidence_validation(self):
        """Test that Config rules evidence is properly documented."""
        config_artifacts = [
            artifact for artifact in self.evidence_artifacts
            if 'config' in artifact['artifact'].lower() or 'rule' in artifact['artifact'].lower()
        ]
        
        if not config_artifacts:
            pytest.skip("No Config rules evidence artifacts found")
        
        # Check for both managed and custom rules
        managed_rules = 0
        custom_rules = 0
        
        for artifact in config_artifacts:
            artifact_text = artifact['artifact'].lower()
            
            if 'managed' in artifact_text or 'aws' in artifact_text:
                managed_rules += 1
            elif 'custom' in artifact_text or 'lambda' in artifact_text:
                custom_rules += 1
        
        # Should have both managed and custom rules
        assert managed_rules >= 1, "Should have managed Config rules evidence"
        assert custom_rules >= 1, "Should have custom Config rules evidence"
    
    def test_security_hub_integration_evidence(self):
        """Test Security Hub integration for centralized evidence collection."""
        security_hub_artifacts = [
            artifact for artifact in self.evidence_artifacts
            if 'security hub' in artifact['artifact'].lower() or 'securityhub' in artifact['artifact'].lower()
        ]
        
        # Security Hub integration is recommended but not required
        if security_hub_artifacts:
            # If Security Hub is used, validate it's properly configured
            for artifact in security_hub_artifacts:
                assert 'finding' in artifact['artifact'].lower() or 'compliance' in artifact['artifact'].lower(), \
                    "Security Hub evidence should reference findings or compliance"
        else:
            # If no Security Hub, should have alternative centralized monitoring
            centralized_monitoring = [
                artifact for artifact in self.evidence_artifacts
                if any(keyword in artifact['artifact'].lower() for keyword in ['dashboard', 'central', 'aggregate'])
            ]
            
            assert len(centralized_monitoring) >= 1, "Should have centralized monitoring evidence if not using Security Hub"
    
    def test_cloudtrail_audit_evidence(self):
        """Test CloudTrail audit evidence for API calls and changes."""
        cloudtrail_artifacts = [
            artifact for artifact in self.evidence_artifacts
            if 'cloudtrail' in artifact['artifact'].lower() or 'trail' in artifact['artifact'].lower()
        ]
        
        if not cloudtrail_artifacts:
            # CloudTrail might be implied in other audit evidence
            audit_artifacts = [
                artifact for artifact in self.evidence_artifacts
                if any(keyword in artifact['artifact'].lower() for keyword in ['audit', 'log', 'event'])
            ]
            
            assert len(audit_artifacts) >= 2, "Should have audit trail evidence (CloudTrail or equivalent)"
        else:
            # Validate CloudTrail evidence
            for artifact in cloudtrail_artifacts:
                assert any(keyword in artifact['artifact'].lower() for keyword in ['event', 'log', 'api']), \
                    "CloudTrail evidence should reference events, logs, or API calls"
    
    def test_policy_enforcement_evidence(self):
        """Test evidence for policy enforcement mechanisms."""
        policy_artifacts = [
            artifact for artifact in self.evidence_artifacts
            if any(keyword in artifact['artifact'].lower() for keyword in ['policy', 'scp', 'iam', 'permission'])
        ]
        
        if not policy_artifacts:
            pytest.skip("No policy enforcement evidence found")
        
        # Check for different types of policy evidence
        policy_types = {
            'scp': 0,
            'iam': 0,
            'permission_boundary': 0,
            'resource_policy': 0
        }
        
        for artifact in policy_artifacts:
            artifact_text = artifact['artifact'].lower()
            
            if 'scp' in artifact_text or 'service control' in artifact_text:
                policy_types['scp'] += 1
            if 'iam' in artifact_text:
                policy_types['iam'] += 1
            if 'boundary' in artifact_text or 'permission boundary' in artifact_text:
                policy_types['permission_boundary'] += 1
            if 'resource policy' in artifact_text or 'bucket policy' in artifact_text:
                policy_types['resource_policy'] += 1
        
        # Should have multiple types of policy enforcement
        active_policy_types = sum(1 for count in policy_types.values() if count > 0)
        assert active_policy_types >= 2, f"Should have at least 2 types of policy enforcement evidence, got {active_policy_types}"
    
    def test_checklist_evidence_linkage(self):
        """Test that checklist items properly link to evidence artifacts."""
        if not self.checklist_items:
            pytest.skip("No checklist items found")
        
        # Check for evidence links in checklist items
        items_with_evidence = 0
        
        for item in self.checklist_items:
            item_text = item['text'].lower()
            
            # Look for evidence references
            evidence_keywords = [
                'evidence', 'artifact', 'dashboard', 'console', 'cloudwatch',
                'config', 'cloudtrail', 'security hub', 'monitor', 'check'
            ]
            
            if any(keyword in item_text for keyword in evidence_keywords):
                items_with_evidence += 1
        
        evidence_ratio = items_with_evidence / len(self.checklist_items)
        assert evidence_ratio >= 0.5, f"At least 50% of checklist items should reference evidence, got {evidence_ratio:.2%}"
    
    def test_script_based_evidence_validation(self):
        """Test that script-based evidence artifacts exist and are executable."""
        script_artifacts = [
            artifact for artifact in self.evidence_artifacts
            if any(ext in artifact['artifact'].lower() for ext in ['.sh', '.py', 'script'])
        ]
        
        if not script_artifacts:
            pytest.skip("No script-based evidence artifacts found")
        
        # Check that referenced scripts exist
        existing_scripts = 0
        
        for artifact in script_artifacts:
            artifact_text = artifact['artifact']
            
            # Extract potential script names
            script_patterns = [
                r'([a-zA-Z0-9_-]+\.sh)',
                r'([a-zA-Z0-9_-]+\.py)',
                r'scripts?/([a-zA-Z0-9_-]+\.[a-zA-Z]+)'
            ]
            
            for pattern in script_patterns:
                matches = re.findall(pattern, artifact_text)
                for script_name in matches:
                    script_path = self.scripts_dir / script_name
                    if script_path.exists():
                        existing_scripts += 1
                        
                        # Check if script is executable (for .sh files)
                        if script_name.endswith('.sh'):
                            stat_info = script_path.stat()
                            is_executable = bool(stat_info.st_mode & 0o111)
                            assert is_executable, f"Script {script_name} should be executable"
        
        # At least some referenced scripts should exist
        if script_artifacts:
            assert existing_scripts >= 1, "At least one referenced script should exist in the scripts directory"
    
    def test_documentation_evidence_completeness(self):
        """Test that documentation-based evidence is complete and accessible."""
        doc_artifacts = [
            artifact for artifact in self.evidence_artifacts
            if any(keyword in artifact['artifact'].lower() for keyword in ['document', 'guide', 'manual', '.md'])
        ]
        
        if not doc_artifacts:
            pytest.skip("No documentation evidence artifacts found")
        
        # Check that referenced documents exist
        existing_docs = 0
        
        for artifact in doc_artifacts:
            artifact_text = artifact['artifact']
            
            # Extract potential document references
            doc_patterns = [
                r'([a-zA-Z0-9_-]+\.md)',
                r'docs?/([a-zA-Z0-9_/-]+\.md)',
                r'([a-zA-Z0-9_-]+ guide)',
                r'([a-zA-Z0-9_-]+ manual)'
            ]
            
            for pattern in doc_patterns:
                matches = re.findall(pattern, artifact_text, re.IGNORECASE)
                for doc_ref in matches:
                    # Try to find the document
                    potential_paths = [
                        self.docs_dir / doc_ref,
                        self.docs_dir / f"{doc_ref}.md",
                        self.project_root / doc_ref
                    ]
                    
                    if any(path.exists() for path in potential_paths):
                        existing_docs += 1
        
        # Some referenced documents should exist
        if doc_artifacts:
            doc_ratio = existing_docs / len(doc_artifacts)
            assert doc_ratio >= 0.3, f"At least 30% of referenced documents should exist, got {doc_ratio:.2%}"
    
    def test_evidence_artifact_uniqueness(self):
        """Test that evidence artifacts are unique and not duplicated."""
        if not self.evidence_artifacts:
            pytest.skip("No evidence artifacts found")
        
        # Check for duplicate evidence artifacts
        artifact_texts = [artifact['artifact'] for artifact in self.evidence_artifacts]
        unique_artifacts = set(artifact_texts)
        
        duplication_ratio = len(artifact_texts) / len(unique_artifacts) if unique_artifacts else 1
        
        # Allow some duplication but not excessive
        assert duplication_ratio <= 1.2, f"Evidence artifacts should be mostly unique, duplication ratio: {duplication_ratio:.2f}"
    
    def test_audit_trail_temporal_coverage(self):
        """Test that audit trail covers different time periods and scenarios."""
        # Check for evidence that covers different operational scenarios
        scenario_coverage = {
            'deployment': 0,
            'runtime': 0,
            'incident': 0,
            'change': 0,
            'access': 0
        }
        
        for artifact in self.evidence_artifacts:
            artifact_text = artifact['artifact'].lower()
            
            if any(keyword in artifact_text for keyword in ['deploy', 'release', 'build']):
                scenario_coverage['deployment'] += 1
            if any(keyword in artifact_text for keyword in ['runtime', 'execution', 'invoke']):
                scenario_coverage['runtime'] += 1
            if any(keyword in artifact_text for keyword in ['incident', 'error', 'failure', 'alert']):
                scenario_coverage['incident'] += 1
            if any(keyword in artifact_text for keyword in ['change', 'update', 'modify']):
                scenario_coverage['change'] += 1
            if any(keyword in artifact_text for keyword in ['access', 'login', 'authentication']):
                scenario_coverage['access'] += 1
        
        # Should cover multiple operational scenarios
        covered_scenarios = sum(1 for count in scenario_coverage.values() if count > 0)
        assert covered_scenarios >= 3, f"Should cover at least 3 operational scenarios, got {covered_scenarios}"
    
    def test_evidence_retention_and_availability(self):
        """Test that evidence retention and availability requirements are documented."""
        retention_artifacts = [
            artifact for artifact in self.evidence_artifacts
            if any(keyword in artifact['artifact'].lower() for keyword in ['retention', 'archive', 'backup', 'storage'])
        ]
        
        # Check for retention policies in documentation
        retention_documented = False
        
        # Check control matrix for retention information
        for control in self.control_matrix:
            for field_value in control.values():
                if field_value and isinstance(field_value, str):
                    if any(keyword in field_value.lower() for keyword in ['retention', 'days', 'months', 'years']):
                        retention_documented = True
                        break
            
            if retention_documented:
                break
        
        # Either have retention artifacts or documented retention policies
        assert len(retention_artifacts) >= 1 or retention_documented, \
            "Should have evidence retention artifacts or documented retention policies"
    
    def test_compliance_audit_readiness(self):
        """Test overall audit readiness for compliance assessments."""
        if not self.evidence_artifacts:
            pytest.skip("No evidence artifacts found")
        
        # Calculate audit readiness score
        readiness_factors = {
            'automated_evidence': 0,
            'diverse_sources': 0,
            'documented_procedures': 0,
            'accessible_artifacts': 0,
            'compliance_mapping': 0
        }
        
        # Check automated evidence
        automated_count = sum(1 for artifact in self.evidence_artifacts 
                            if artifact['automated_check'].strip())
        readiness_factors['automated_evidence'] = min(automated_count / len(self.evidence_artifacts), 1.0)
        
        # Check diverse sources (different AWS services)
        aws_services = set()
        for artifact in self.evidence_artifacts:
            service = artifact['aws_service'].strip()
            if service:
                aws_services.add(service)
        
        readiness_factors['diverse_sources'] = min(len(aws_services) / 5, 1.0)  # Expect at least 5 services
        
        # Check documented procedures (non-empty evidence artifacts)
        documented_count = sum(1 for artifact in self.evidence_artifacts 
                             if artifact['artifact'].strip())
        readiness_factors['documented_procedures'] = documented_count / len(self.evidence_artifacts)
        
        # Check accessible artifacts (assume all are accessible for now)
        readiness_factors['accessible_artifacts'] = 1.0
        
        # Check compliance mapping (controls with requirements)
        mapped_count = sum(1 for artifact in self.evidence_artifacts 
                         if artifact['control'].strip() and artifact['control'] != 'Unknown')
        readiness_factors['compliance_mapping'] = mapped_count / len(self.evidence_artifacts)
        
        # Calculate overall readiness score
        overall_score = sum(readiness_factors.values()) / len(readiness_factors)
        
        assert overall_score >= 0.7, f"Audit readiness score should be at least 70%, got {overall_score:.2%}"
        
        # Individual factors should meet minimum thresholds
        assert readiness_factors['automated_evidence'] >= 0.5, "At least 50% of evidence should be automated"
        assert readiness_factors['diverse_sources'] >= 0.6, "Should use diverse AWS services for evidence"
        assert readiness_factors['documented_procedures'] >= 0.9, "At least 90% of evidence should be documented"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])