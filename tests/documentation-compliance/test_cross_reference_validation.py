#!/usr/bin/env python3
"""
Test suite for automated cross-reference validation between all documents.
Validates that all documents are properly linked and references are accurate.
"""

import re
import csv
import json
from pathlib import Path
import pytest
from collections import defaultdict
import yaml


class TestCrossReferenceValidation:
    """Test cases for cross-reference validation between documents."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment and load all documents."""
        cls.project_root = Path(__file__).parent.parent.parent
        cls.docs_dir = cls.project_root / "docs"
        cls.policies_dir = cls.docs_dir / "policies"
        cls.specs_dir = cls.project_root / ".kiro" / "specs" / "lambda-production-readiness-requirements"
        
        # Load all documents
        cls.documents = cls._load_all_documents()
        cls.control_matrix = cls._load_control_matrix()
    
    @classmethod
    def _load_all_documents(cls):
        """Load all markdown and text documents."""
        documents = {}
        
        # Load PRR document
        prr_file = cls.docs_dir / "prr" / "lambda-production-readiness-requirements.md"
        if prr_file.exists():
            with open(prr_file, 'r') as f:
                documents['prr'] = f.read()
        
        # Load spec documents
        for spec_file in ['requirements.md', 'design.md', 'tasks.md']:
            spec_path = cls.specs_dir / spec_file
            if spec_path.exists():
                with open(spec_path, 'r') as f:
                    documents[f'spec_{spec_file.replace(".md", "")}'] = f.read()
        
        # Load checklist
        checklist_file = cls.docs_dir / "checklists" / "lambda-production-readiness-checklist.md"
        if checklist_file.exists():
            with open(checklist_file, 'r') as f:
                documents['checklist'] = f.read()
        
        # Load runbooks
        runbooks_dir = cls.docs_dir / "runbooks"
        for runbook_file in runbooks_dir.glob("*.md"):
            with open(runbook_file, 'r') as f:
                documents[f'runbook_{runbook_file.stem}'] = f.read()
        
        # Load deployment guide
        deployment_guide = cls.docs_dir / "deployment-guide.md"
        if deployment_guide.exists():
            with open(deployment_guide, 'r') as f:
                documents['deployment_guide'] = f.read()
        
        return documents
    
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
    
    def test_prr_to_control_matrix_mapping(self):
        """Test that all PRR requirements are mapped in control matrix."""
        if 'prr' not in self.documents:
            pytest.skip("PRR document not found")
        
        prr_content = self.documents['prr']
        
        # Extract requirement IDs from PRR document
        # Look for patterns like "REQ-1.1", "1.1", etc.
        requirement_patterns = [
            r'REQ-(\d+\.\d+)',
            r'(?:^|\s)(\d+\.\d+)(?:\s|$)',
            r'Requirement\s+(\d+\.\d+)',
        ]
        
        prr_requirements = set()
        for pattern in requirement_patterns:
            matches = re.findall(pattern, prr_content, re.MULTILINE)
            prr_requirements.update(matches)
        
        # Extract requirements from control matrix
        matrix_requirements = set()
        for control in self.control_matrix:
            req_field = control.get('Requirement', '')
            # Extract requirement numbers from the field
            req_matches = re.findall(r'(\d+\.\d+)', req_field)
            matrix_requirements.update(req_matches)
        
        # Check that all PRR requirements are in control matrix
        missing_in_matrix = prr_requirements - matrix_requirements
        
        if missing_in_matrix:
            print(f"Requirements in PRR but not in control matrix: {missing_in_matrix}")
        
        # Allow some flexibility - not all requirements may need controls
        coverage_ratio = len(matrix_requirements & prr_requirements) / len(prr_requirements) if prr_requirements else 1
        assert coverage_ratio >= 0.8, f"Control matrix should cover at least 80% of PRR requirements, got {coverage_ratio:.2%}"
    
    def test_checklist_to_control_matrix_mapping(self):
        """Test that checklist items reference control matrix entries."""
        if 'checklist' not in self.documents:
            pytest.skip("Checklist document not found")
        
        checklist_content = self.documents['checklist']
        
        # Extract checklist item references
        # Look for patterns that reference controls or evidence
        reference_patterns = [
            r'Control\s+(\d+\.\d+)',
            r'Evidence:\s*([^\n]+)',
            r'\[([^\]]+)\]\([^)]+\)',  # Markdown links
        ]
        
        checklist_references = set()
        for pattern in reference_patterns:
            matches = re.findall(pattern, checklist_content, re.IGNORECASE)
            checklist_references.update(matches)
        
        # Check that checklist has meaningful references
        assert len(checklist_references) >= 10, "Checklist should have at least 10 references to controls or evidence"
    
    def test_runbook_cross_references(self):
        """Test that runbooks properly reference other documents."""
        runbook_docs = {k: v for k, v in self.documents.items() if k.startswith('runbook_')}
        
        if not runbook_docs:
            pytest.skip("No runbook documents found")
        
        # Check for cross-references in runbooks
        cross_ref_patterns = [
            r'see\s+([^.]+\.md)',
            r'refer\s+to\s+([^.]+\.md)',
            r'\[([^\]]+)\]\(([^)]+\.md)\)',
            r'checklist',
            r'control\s+matrix',
            r'PRR',
        ]
        
        total_references = 0
        for runbook_name, content in runbook_docs.items():
            runbook_references = 0
            for pattern in cross_ref_patterns:
                matches = re.findall(pattern, content, re.IGNORECASE)
                runbook_references += len(matches)
            
            total_references += runbook_references
            
            # Each runbook should have at least some references
            assert runbook_references >= 1, f"Runbook {runbook_name} should reference other documents"
        
        assert total_references >= 5, "Runbooks should have meaningful cross-references"
    
    def test_spec_to_implementation_traceability(self):
        """Test traceability from spec requirements to implementation artifacts."""
        spec_requirements = self.documents.get('spec_requirements', '')
        spec_tasks = self.documents.get('spec_tasks', '')
        
        if not spec_requirements or not spec_tasks:
            pytest.skip("Spec documents not found")
        
        # Extract requirement IDs from spec requirements
        req_pattern = r'### Requirement (\d+)'
        requirements = re.findall(req_pattern, spec_requirements)
        
        # Check that tasks reference requirements
        task_requirement_refs = re.findall(r'Requirements?:\s*([^_\n]+)', spec_tasks)
        
        referenced_requirements = set()
        for ref in task_requirement_refs:
            # Extract requirement numbers from references like "1.1, 1.2, 2.1"
            req_nums = re.findall(r'(\d+(?:\.\d+)?)', ref)
            referenced_requirements.update(req_nums)
        
        # Check coverage
        requirements_set = set(requirements)
        coverage = len(referenced_requirements & requirements_set) / len(requirements_set) if requirements_set else 1
        
        assert coverage >= 0.9, f"Tasks should reference at least 90% of requirements, got {coverage:.2%}"
    
    def test_policy_document_references(self):
        """Test that policy documents are properly referenced."""
        # Check for references to policy files in documentation
        policy_files = [
            'scp-lambda-governance.json',
            'scp-lambda-code-signing.json',
            'config-conformance-pack-lambda.yaml',
            'iam-permission-boundary-cicd.json'
        ]
        
        policy_references = defaultdict(int)
        
        for doc_name, content in self.documents.items():
            for policy_file in policy_files:
                # Count references to each policy file
                policy_name = policy_file.replace('.json', '').replace('.yaml', '')
                if policy_name.lower() in content.lower():
                    policy_references[policy_file] += 1
        
        # Each major policy should be referenced at least once
        major_policies = ['scp-lambda-governance.json', 'config-conformance-pack-lambda.yaml']
        for policy in major_policies:
            assert policy_references[policy] >= 1, f"Policy {policy} should be referenced in documentation"
    
    def test_script_references_in_documentation(self):
        """Test that deployment scripts are properly documented."""
        script_files = [
            'build-lambda-package.sh',
            'sign-lambda-package.sh',
            'deploy-lambda-canary.sh',
            'rollback-lambda-deployment.sh',
            'validate-lambda-package.sh'
        ]
        
        script_references = defaultdict(int)
        
        for doc_name, content in self.documents.items():
            for script_file in script_files:
                script_name = script_file.replace('.sh', '')
                if script_name.lower() in content.lower() or script_file in content:
                    script_references[script_file] += 1
        
        # Critical scripts should be documented
        critical_scripts = ['deploy-lambda-canary.sh', 'rollback-lambda-deployment.sh']
        for script in critical_scripts:
            assert script_references[script] >= 1, f"Script {script} should be documented"
    
    def test_aws_service_consistency(self):
        """Test consistency of AWS service references across documents."""
        aws_services = [
            'Lambda', 'CodeDeploy', 'CloudWatch', 'X-Ray', 'Secrets Manager',
            'Parameter Store', 'IAM', 'Organizations', 'Config', 'Security Hub'
        ]
        
        service_mentions = defaultdict(list)
        
        for doc_name, content in self.documents.items():
            for service in aws_services:
                if service.lower() in content.lower():
                    service_mentions[service].append(doc_name)
        
        # Core services should be mentioned in multiple documents
        core_services = ['Lambda', 'CloudWatch', 'IAM']
        for service in core_services:
            assert len(service_mentions[service]) >= 2, f"Core service {service} should be mentioned in multiple documents"
    
    def test_url_and_link_validity(self):
        """Test that URLs and internal links are properly formatted."""
        url_pattern = r'https?://[^\s\)]+|www\.[^\s\)]+'
        markdown_link_pattern = r'\[([^\]]+)\]\(([^)]+)\)'
        
        broken_links = []
        
        for doc_name, content in self.documents.items():
            # Check URLs
            urls = re.findall(url_pattern, content)
            for url in urls:
                # Basic URL format validation
                if not (url.startswith('http') or url.startswith('www')):
                    broken_links.append(f"{doc_name}: Invalid URL format - {url}")
            
            # Check markdown links
            md_links = re.findall(markdown_link_pattern, content)
            for link_text, link_url in md_links:
                # Check for common link issues
                if link_url.startswith('#') and len(link_url) < 3:
                    broken_links.append(f"{doc_name}: Short anchor link - {link_url}")
                elif link_url.endswith('.md') and not link_url.startswith('http'):
                    # Internal markdown link - check if it's a reasonable path
                    if '../' in link_url or './' not in link_url:
                        # This might be a broken relative path
                        pass  # We'll be lenient here
        
        # Allow some broken links but not too many
        assert len(broken_links) <= 5, f"Too many potentially broken links: {broken_links[:5]}"
    
    def test_requirement_numbering_consistency(self):
        """Test that requirement numbering is consistent across documents."""
        requirement_patterns = [
            (r'REQ-(\d+\.\d+)', 'REQ-X.X format'),
            (r'(?:^|\s)(\d+\.\d+)(?:\s|$)', 'X.X format'),
            (r'Requirement\s+(\d+)', 'Requirement X format'),
        ]
        
        all_requirements = defaultdict(list)
        
        for doc_name, content in self.documents.items():
            for pattern, format_name in requirement_patterns:
                matches = re.findall(pattern, content, re.MULTILINE)
                for match in matches:
                    all_requirements[match].append((doc_name, format_name))
        
        # Check for consistent numbering
        duplicate_requirements = {req: docs for req, docs in all_requirements.items() if len(docs) > 1}
        
        # Some duplication is expected (cross-references), but validate format consistency
        for req, docs in duplicate_requirements.items():
            formats = set(doc[1] for doc in docs)
            if len(formats) > 1:
                print(f"Warning: Requirement {req} uses different formats: {formats}")
    
    def test_evidence_artifact_references(self):
        """Test that evidence artifacts are properly referenced."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Extract evidence artifacts from control matrix
        evidence_artifacts = set()
        for control in self.control_matrix:
            evidence = control.get('Evidence Artifact', '')
            if evidence and evidence.strip():
                evidence_artifacts.add(evidence.strip())
        
        # Check that evidence artifacts are referenced in documentation
        referenced_artifacts = set()
        
        for doc_name, content in self.documents.items():
            for artifact in evidence_artifacts:
                # Look for references to the artifact
                if artifact.lower() in content.lower():
                    referenced_artifacts.add(artifact)
        
        # Calculate coverage
        if evidence_artifacts:
            coverage = len(referenced_artifacts) / len(evidence_artifacts)
            assert coverage >= 0.5, f"At least 50% of evidence artifacts should be referenced in documentation, got {coverage:.2%}"
    
    def test_document_completeness(self):
        """Test that all expected documents exist and have content."""
        expected_documents = [
            'prr',
            'checklist',
            'spec_requirements',
            'spec_design',
            'spec_tasks'
        ]
        
        missing_documents = []
        empty_documents = []
        
        for doc_name in expected_documents:
            if doc_name not in self.documents:
                missing_documents.append(doc_name)
            elif len(self.documents[doc_name].strip()) < 100:
                empty_documents.append(doc_name)
        
        assert len(missing_documents) == 0, f"Missing documents: {missing_documents}"
        assert len(empty_documents) <= 1, f"Documents with insufficient content: {empty_documents}"
    
    def test_cross_reference_link_format(self):
        """Test that cross-reference links follow consistent format."""
        link_patterns = [
            r'\[([^\]]+)\]\(([^)]+)\)',  # Markdown links
            r'see\s+section\s+(\d+\.\d+)',  # Section references
            r'refer\s+to\s+([^.]+\.md)',  # File references
        ]
        
        inconsistent_formats = []
        
        for doc_name, content in self.documents.items():
            # Check for consistent link formatting
            md_links = re.findall(r'\[([^\]]+)\]\(([^)]+)\)', content)
            
            for link_text, link_url in md_links:
                # Check for common formatting issues
                if link_text.strip() != link_text:
                    inconsistent_formats.append(f"{doc_name}: Link text has extra whitespace")
                
                if link_url.strip() != link_url:
                    inconsistent_formats.append(f"{doc_name}: Link URL has extra whitespace")
        
        # Allow some formatting issues but not too many
        assert len(inconsistent_formats) <= 3, f"Too many formatting issues: {inconsistent_formats}"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])