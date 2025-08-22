#!/usr/bin/env python3
"""
Pytest configuration and fixtures for documentation and compliance testing.
"""

import pytest
import csv
import json
from pathlib import Path
from collections import defaultdict
import re


@pytest.fixture(scope="session")
def project_root():
    """Fixture providing path to project root directory."""
    return Path(__file__).parent.parent.parent


@pytest.fixture(scope="session")
def docs_dir(project_root):
    """Fixture providing path to docs directory."""
    return project_root / "docs"


@pytest.fixture(scope="session")
def specs_dir(project_root):
    """Fixture providing path to specs directory."""
    return project_root / ".kiro" / "specs" / "lambda-production-readiness-requirements"


@pytest.fixture(scope="session")
def control_matrix(docs_dir):
    """Fixture providing control matrix data."""
    control_matrix_file = docs_dir / "control-matrix.csv"
    
    if not control_matrix_file.exists():
        return []
    
    controls = []
    with open(control_matrix_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            controls.append(row)
    
    return controls


@pytest.fixture(scope="session")
def all_documents(project_root, docs_dir, specs_dir):
    """Fixture providing all documentation content."""
    documents = {}
    
    # Load PRR document
    prr_file = docs_dir / "prr" / "lambda-production-readiness-requirements.md"
    if prr_file.exists():
        with open(prr_file, 'r') as f:
            documents['prr'] = f.read()
    
    # Load spec documents
    for spec_file in ['requirements.md', 'design.md', 'tasks.md']:
        spec_path = specs_dir / spec_file
        if spec_path.exists():
            with open(spec_path, 'r') as f:
                documents[f'spec_{spec_file.replace(".md", "")}'] = f.read()
    
    # Load checklist
    checklist_file = docs_dir / "checklists" / "lambda-production-readiness-checklist.md"
    if checklist_file.exists():
        with open(checklist_file, 'r') as f:
            documents['checklist'] = f.read()
    
    # Load runbooks
    runbooks_dir = docs_dir / "runbooks"
    if runbooks_dir.exists():
        for runbook_file in runbooks_dir.glob("*.md"):
            with open(runbook_file, 'r') as f:
                documents[f'runbook_{runbook_file.stem}'] = f.read()
    
    # Load deployment guide
    deployment_guide = docs_dir / "deployment-guide.md"
    if deployment_guide.exists():
        with open(deployment_guide, 'r') as f:
            documents['deployment_guide'] = f.read()
    
    return documents


@pytest.fixture(scope="session")
def compliance_frameworks():
    """Fixture providing compliance framework definitions."""
    return {
        'ISO27001': {
            'name': 'ISO/IEC 27001:2013',
            'description': 'Information Security Management Systems',
            'control_pattern': r'A\.\d+\.\d+\.\d+',
            'critical_controls': [
                'A.9.1.1', 'A.9.2.4', 'A.10.1.1', 'A.12.1.2',
                'A.12.4.1', 'A.12.6.1', 'A.13.1.1', 'A.14.2.1'
            ]
        },
        'SOC2': {
            'name': 'SOC 2 Type II',
            'description': 'Service Organization Control 2',
            'control_pattern': r'CC\d+\.\d+|A\d+\.\d+|PI\d+\.\d+',
            'critical_controls': [
                'CC6.1', 'CC6.2', 'CC6.3', 'CC7.1', 'CC7.4', 'CC8.1'
            ]
        },
        'NISTCSF': {
            'name': 'NIST Cybersecurity Framework',
            'description': 'Framework for Improving Critical Infrastructure Cybersecurity',
            'control_pattern': r'[A-Z]{2}\.[A-Z]{2}-\d+',
            'critical_controls': [
                'PR.AC-1', 'PR.AC-4', 'PR.DS-1', 'PR.DS-2',
                'PR.IP-2', 'PR.PT-1', 'DE.CM-1', 'RS.RP-1'
            ]
        }
    }


@pytest.fixture
def document_analyzer():
    """Fixture providing document analysis utilities."""
    
    class DocumentAnalyzer:
        """Helper class for analyzing document content."""
        
        @staticmethod
        def extract_requirements(content):
            """Extract requirement IDs from document content."""
            patterns = [
                r'REQ-(\d+\.\d+)',
                r'(?:^|\s)(\d+\.\d+)(?:\s|$)',
                r'Requirement\s+(\d+)',
            ]
            
            requirements = set()
            for pattern in patterns:
                matches = re.findall(pattern, content, re.MULTILINE)
                requirements.update(matches)
            
            return requirements
        
        @staticmethod
        def extract_cross_references(content):
            """Extract cross-references from document content."""
            patterns = [
                r'\[([^\]]+)\]\(([^)]+)\)',  # Markdown links
                r'see\s+([^.]+\.md)',
                r'refer\s+to\s+([^.]+\.md)',
                r'section\s+(\d+\.\d+)',
            ]
            
            references = []
            for pattern in patterns:
                matches = re.findall(pattern, content, re.IGNORECASE)
                references.extend(matches)
            
            return references
        
        @staticmethod
        def extract_compliance_mappings(content, framework_patterns):
            """Extract compliance framework mappings from content."""
            mappings = defaultdict(list)
            
            for framework, pattern in framework_patterns.items():
                matches = re.findall(pattern, content)
                mappings[framework].extend(matches)
            
            return dict(mappings)
        
        @staticmethod
        def validate_markdown_syntax(content):
            """Basic markdown syntax validation."""
            issues = []
            
            lines = content.split('\n')
            for i, line in enumerate(lines, 1):
                # Check for unmatched brackets
                if line.count('[') != line.count(']'):
                    issues.append(f"Line {i}: Unmatched square brackets")
                
                if line.count('(') != line.count(')'):
                    issues.append(f"Line {i}: Unmatched parentheses")
                
                # Check for malformed links
                if '[' in line and ']' in line and '(' in line:
                    link_pattern = r'\[([^\]]*)\]\(([^)]*)\)'
                    if not re.search(link_pattern, line):
                        issues.append(f"Line {i}: Malformed markdown link")
            
            return issues
        
        @staticmethod
        def count_words(content):
            """Count words in content."""
            # Remove markdown syntax for more accurate count
            clean_content = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', content)
            clean_content = re.sub(r'[#*`_]', '', clean_content)
            
            words = clean_content.split()
            return len(words)
        
        @staticmethod
        def extract_code_blocks(content):
            """Extract code blocks from markdown content."""
            code_blocks = []
            
            # Fenced code blocks
            fenced_pattern = r'```(\w+)?\n(.*?)\n```'
            matches = re.findall(fenced_pattern, content, re.DOTALL)
            
            for language, code in matches:
                code_blocks.append({
                    'type': 'fenced',
                    'language': language,
                    'content': code
                })
            
            # Inline code
            inline_pattern = r'`([^`]+)`'
            inline_matches = re.findall(inline_pattern, content)
            
            for code in inline_matches:
                code_blocks.append({
                    'type': 'inline',
                    'language': '',
                    'content': code
                })
            
            return code_blocks
    
    return DocumentAnalyzer()


@pytest.fixture
def evidence_validator():
    """Fixture providing evidence validation utilities."""
    
    class EvidenceValidator:
        """Helper class for validating evidence artifacts."""
        
        def __init__(self, project_root):
            self.project_root = project_root
            self.docs_dir = project_root / "docs"
            self.scripts_dir = project_root / "scripts"
        
        def validate_file_reference(self, file_reference):
            """Validate that a file reference exists."""
            potential_paths = [
                self.project_root / file_reference,
                self.docs_dir / file_reference,
                self.scripts_dir / file_reference
            ]
            
            return any(path.exists() for path in potential_paths)
        
        def validate_url_format(self, url):
            """Validate URL format."""
            url_pattern = r'^https?://[^\s/$.?#].[^\s]*$'
            return re.match(url_pattern, url) is not None
        
        def categorize_evidence_type(self, evidence_text):
            """Categorize evidence artifact by type."""
            evidence_lower = evidence_text.lower()
            
            if 'cloudwatch' in evidence_lower or 'metric' in evidence_lower:
                return 'cloudwatch'
            elif 'config' in evidence_lower or 'rule' in evidence_lower:
                return 'config'
            elif 'cloudtrail' in evidence_lower:
                return 'cloudtrail'
            elif 'security hub' in evidence_lower:
                return 'security_hub'
            elif 'console' in evidence_lower or 'dashboard' in evidence_lower:
                return 'aws_console'
            elif 'script' in evidence_lower or '.sh' in evidence_lower or '.py' in evidence_lower:
                return 'script'
            elif 'document' in evidence_lower or '.md' in evidence_lower:
                return 'documentation'
            elif 'policy' in evidence_lower or 'scp' in evidence_lower:
                return 'policy'
            else:
                return 'other'
        
        def validate_aws_service_reference(self, service_name):
            """Validate AWS service name."""
            valid_services = [
                'Lambda', 'CloudWatch', 'Config', 'CloudTrail', 'IAM',
                'Organizations', 'Security Hub', 'CodeDeploy', 'X-Ray',
                'Secrets Manager', 'Parameter Store', 'API Gateway',
                'EventBridge', 'SQS', 'SNS', 'S3', 'KMS', 'Signer'
            ]
            
            return service_name in valid_services
    
    return EvidenceValidator(project_root)


@pytest.fixture
def compliance_mapper():
    """Fixture providing compliance mapping utilities."""
    
    class ComplianceMapper:
        """Helper class for compliance framework mapping."""
        
        def __init__(self, frameworks):
            self.frameworks = frameworks
        
        def extract_framework_controls(self, content):
            """Extract controls for all frameworks from content."""
            mappings = {}
            
            for framework_name, framework_info in self.frameworks.items():
                pattern = framework_info['control_pattern']
                matches = re.findall(pattern, content)
                mappings[framework_name] = list(set(matches))
            
            return mappings
        
        def validate_control_format(self, control_id, framework):
            """Validate control ID format for specific framework."""
            if framework not in self.frameworks:
                return False
            
            pattern = self.frameworks[framework]['control_pattern']
            return re.match(pattern, control_id) is not None
        
        def get_critical_controls(self, framework):
            """Get critical controls for a framework."""
            if framework not in self.frameworks:
                return []
            
            return self.frameworks[framework]['critical_controls']
        
        def calculate_coverage(self, mapped_controls, framework):
            """Calculate coverage of critical controls."""
            critical_controls = self.get_critical_controls(framework)
            if not critical_controls:
                return 1.0
            
            mapped_critical = set(mapped_controls) & set(critical_controls)
            return len(mapped_critical) / len(critical_controls)
    
    return ComplianceMapper(compliance_frameworks)


@pytest.fixture
def audit_trail_analyzer():
    """Fixture providing audit trail analysis utilities."""
    
    class AuditTrailAnalyzer:
        """Helper class for analyzing audit trails."""
        
        @staticmethod
        def categorize_audit_evidence(evidence_list):
            """Categorize audit evidence by type."""
            categories = defaultdict(list)
            
            for evidence in evidence_list:
                evidence_text = evidence.get('artifact', '').lower()
                
                if 'cloudwatch' in evidence_text:
                    categories['monitoring'].append(evidence)
                elif 'config' in evidence_text:
                    categories['compliance'].append(evidence)
                elif 'cloudtrail' in evidence_text:
                    categories['audit_log'].append(evidence)
                elif 'security hub' in evidence_text:
                    categories['security'].append(evidence)
                elif 'policy' in evidence_text or 'scp' in evidence_text:
                    categories['governance'].append(evidence)
                else:
                    categories['other'].append(evidence)
            
            return dict(categories)
        
        @staticmethod
        def validate_evidence_completeness(evidence_categories):
            """Validate that audit evidence covers all necessary categories."""
            required_categories = ['monitoring', 'compliance', 'audit_log', 'security']
            
            coverage = {}
            for category in required_categories:
                coverage[category] = len(evidence_categories.get(category, []))
            
            return coverage
        
        @staticmethod
        def calculate_automation_ratio(evidence_list):
            """Calculate ratio of automated vs manual evidence."""
            automated = 0
            manual = 0
            
            for evidence in evidence_list:
                automated_check = evidence.get('automated_check', '').strip()
                
                if automated_check and any(keyword in automated_check.lower() 
                                         for keyword in ['aws', 'cli', 'api', 'automated', 'script']):
                    automated += 1
                else:
                    manual += 1
            
            total = automated + manual
            return automated / total if total > 0 else 0
    
    return AuditTrailAnalyzer()