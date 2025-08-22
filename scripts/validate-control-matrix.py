#!/usr/bin/env python3
"""
Control Matrix Validation Framework

This script validates the control matrix against the PRR document to ensure:
1. All requirements are mapped to controls
2. Control matrix schema compliance
3. Cross-reference integrity
4. Evidence artifact accessibility
"""

import re
import csv
import json
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Set, Tuple
from dataclasses import dataclass
from urllib.parse import urlparse

@dataclass
class ControlMatrixEntry:
    """Data structure for control matrix entry"""
    requirement_id: str
    requirement_description: str
    aws_service: str
    enforcement_method: str
    automated_check: str
    evidence_artifact: str
    compliance_mapping: str = ""

@dataclass
class ValidationResult:
    """Validation result with errors and warnings"""
    is_valid: bool
    errors: List[str]
    warnings: List[str]
    coverage_stats: Dict[str, int]

class ControlMatrixValidator:
    """Validates control matrix against PRR requirements"""
    
    def __init__(self, prr_file: Path, control_matrix_file: Path):
        self.prr_file = prr_file
        self.control_matrix_file = control_matrix_file
        self.prr_requirements = set()
        self.control_entries = []
        
        # Valid AWS services for validation
        self.valid_aws_services = {
            'IAM', 'Lambda', 'API Gateway', 'CloudWatch', 'X-Ray', 'KMS',
            'Secrets Manager', 'Parameter Store', 'S3', 'DynamoDB', 'SQS',
            'SNS', 'EventBridge', 'CodeDeploy', 'CodeSigner', 'Config',
            'CloudTrail', 'Security Hub', 'GuardDuty', 'VPC', 'WAF',
            'Certificate Manager', 'Systems Manager'
        }
        
        # Compliance frameworks
        self.valid_compliance_frameworks = {
            'ISO 27001', 'SOC 2', 'NIST CSF', 'PCI DSS', 'GDPR'
        }
    
    def extract_requirements_from_prr(self) -> Set[str]:
        """Extract requirement IDs from PRR document"""
        requirements = set()
        
        try:
            with open(self.prr_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Pattern to match requirement IDs (e.g., SEC-001.1, NFR-002.3)
            pattern = r'([A-Z]{2,4}-\d{3}\.\d+)'
            matches = re.findall(pattern, content)
            
            for match in matches:
                requirements.add(match)
            
            print(f"Extracted {len(requirements)} requirements from PRR document")
            return requirements
            
        except FileNotFoundError:
            print(f"Error: PRR file not found: {self.prr_file}")
            return set()
        except Exception as e:
            print(f"Error reading PRR file: {e}")
            return set()
    
    def load_control_matrix(self) -> List[ControlMatrixEntry]:
        """Load control matrix from CSV file"""
        entries = []
        
        try:
            with open(self.control_matrix_file, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                for row_num, row in enumerate(reader, start=2):
                    try:
                        entry = ControlMatrixEntry(
                            requirement_id=row.get('Requirement ID', '').strip(),
                            requirement_description=row.get('Requirement Description', '').strip(),
                            aws_service=row.get('AWS Service/Feature', '').strip(),
                            enforcement_method=row.get('How Enforced/Configured', '').strip(),
                            automated_check=row.get('Automated Check/Test', '').strip(),
                            evidence_artifact=row.get('Evidence Artifact', '').strip(),
                            compliance_mapping=row.get('Compliance Mapping', '').strip()
                        )
                        entries.append(entry)
                    except Exception as e:
                        print(f"Error parsing row {row_num}: {e}")
            
            print(f"Loaded {len(entries)} control matrix entries")
            return entries
            
        except FileNotFoundError:
            print(f"Error: Control matrix file not found: {self.control_matrix_file}")
            return []
        except Exception as e:
            print(f"Error reading control matrix file: {e}")
            return []
    
    def validate_schema(self, entries: List[ControlMatrixEntry]) -> Tuple[List[str], List[str]]:
        """Validate control matrix schema compliance"""
        errors = []
        warnings = []
        
        for i, entry in enumerate(entries, start=1):
            # Required field validation
            if not entry.requirement_id:
                errors.append(f"Row {i}: Missing Requirement ID")
            elif not re.match(r'^[A-Z]{2,4}-\d{3}\.\d+$', entry.requirement_id):
                errors.append(f"Row {i}: Invalid Requirement ID format: {entry.requirement_id}")
            
            if not entry.requirement_description:
                errors.append(f"Row {i}: Missing Requirement Description")
            
            if not entry.aws_service:
                errors.append(f"Row {i}: Missing AWS Service/Feature")
            elif entry.aws_service not in self.valid_aws_services:
                warnings.append(f"Row {i}: Unknown AWS service: {entry.aws_service}")
            
            if not entry.enforcement_method:
                errors.append(f"Row {i}: Missing How Enforced/Configured")
            
            if not entry.automated_check:
                errors.append(f"Row {i}: Missing Automated Check/Test")
            
            if not entry.evidence_artifact:
                errors.append(f"Row {i}: Missing Evidence Artifact")
            
            # Compliance mapping validation
            if entry.compliance_mapping:
                frameworks = [f.strip() for f in entry.compliance_mapping.split(',')]
                for framework in frameworks:
                    if framework not in self.valid_compliance_frameworks:
                        warnings.append(f"Row {i}: Unknown compliance framework: {framework}")
        
        return errors, warnings
    
    def validate_cross_references(self, prr_requirements: Set[str], 
                                 control_entries: List[ControlMatrixEntry]) -> Tuple[List[str], List[str]]:
        """Validate cross-references between PRR and control matrix"""
        errors = []
        warnings = []
        
        # Get requirement IDs from control matrix
        matrix_requirements = {entry.requirement_id for entry in control_entries if entry.requirement_id}
        
        # Check for unmapped PRR requirements
        unmapped_requirements = prr_requirements - matrix_requirements
        if unmapped_requirements:
            errors.extend([f"PRR requirement not mapped in control matrix: {req}" 
                          for req in sorted(unmapped_requirements)])
        
        # Check for invalid requirement references in matrix
        invalid_references = matrix_requirements - prr_requirements
        if invalid_references:
            errors.extend([f"Control matrix references non-existent requirement: {req}" 
                          for req in sorted(invalid_references)])
        
        # Check for duplicate mappings
        requirement_counts = {}
        for entry in control_entries:
            if entry.requirement_id:
                requirement_counts[entry.requirement_id] = requirement_counts.get(entry.requirement_id, 0) + 1
        
        duplicates = {req: count for req, count in requirement_counts.items() if count > 1}
        if duplicates:
            warnings.extend([f"Requirement {req} mapped {count} times" 
                           for req, count in duplicates.items()])
        
        return errors, warnings
    
    def validate_evidence_artifacts(self, control_entries: List[ControlMatrixEntry]) -> Tuple[List[str], List[str]]:
        """Validate evidence artifact accessibility and format"""
        errors = []
        warnings = []
        
        for i, entry in enumerate(control_entries, start=1):
            if not entry.evidence_artifact:
                continue
            
            artifact = entry.evidence_artifact.strip()
            
            # Check for valid URL format
            if artifact.startswith('http'):
                parsed = urlparse(artifact)
                if not parsed.netloc:
                    errors.append(f"Row {i}: Invalid URL format in evidence artifact: {artifact}")
            
            # Check for AWS ARN format
            elif artifact.startswith('arn:aws:'):
                if not re.match(r'^arn:aws:[a-z0-9-]+:[a-z0-9-]*:\d*:.+$', artifact):
                    errors.append(f"Row {i}: Invalid ARN format in evidence artifact: {artifact}")
            
            # Check for CloudWatch dashboard format
            elif 'cloudwatch' in artifact.lower() and 'dashboard' in artifact.lower():
                if not re.match(r'.+dashboard.+', artifact, re.IGNORECASE):
                    warnings.append(f"Row {i}: Evidence artifact may not be a valid dashboard reference: {artifact}")
            
            # Check for file path format
            elif '/' in artifact:
                if not artifact.startswith('/') and not artifact.startswith('./'):
                    warnings.append(f"Row {i}: Evidence artifact path format unclear: {artifact}")
        
        return errors, warnings
    
    def generate_coverage_stats(self, prr_requirements: Set[str], 
                               control_entries: List[ControlMatrixEntry]) -> Dict[str, int]:
        """Generate coverage statistics"""
        matrix_requirements = {entry.requirement_id for entry in control_entries if entry.requirement_id}
        
        stats = {
            'total_prr_requirements': len(prr_requirements),
            'mapped_requirements': len(matrix_requirements & prr_requirements),
            'unmapped_requirements': len(prr_requirements - matrix_requirements),
            'invalid_references': len(matrix_requirements - prr_requirements),
            'total_control_entries': len(control_entries),
            'coverage_percentage': round((len(matrix_requirements & prr_requirements) / len(prr_requirements)) * 100, 2) if prr_requirements else 0
        }
        
        return stats
    
    def validate(self) -> ValidationResult:
        """Perform complete validation of control matrix"""
        print("Starting control matrix validation...")
        
        # Load data
        prr_requirements = self.extract_requirements_from_prr()
        control_entries = self.load_control_matrix()
        
        if not prr_requirements or not control_entries:
            return ValidationResult(
                is_valid=False,
                errors=["Failed to load PRR requirements or control matrix"],
                warnings=[],
                coverage_stats={}
            )
        
        all_errors = []
        all_warnings = []
        
        # Schema validation
        schema_errors, schema_warnings = self.validate_schema(control_entries)
        all_errors.extend(schema_errors)
        all_warnings.extend(schema_warnings)
        
        # Cross-reference validation
        xref_errors, xref_warnings = self.validate_cross_references(prr_requirements, control_entries)
        all_errors.extend(xref_errors)
        all_warnings.extend(xref_warnings)
        
        # Evidence artifact validation
        evidence_errors, evidence_warnings = self.validate_evidence_artifacts(control_entries)
        all_errors.extend(evidence_errors)
        all_warnings.extend(evidence_warnings)
        
        # Generate coverage statistics
        coverage_stats = self.generate_coverage_stats(prr_requirements, control_entries)
        
        is_valid = len(all_errors) == 0
        
        return ValidationResult(
            is_valid=is_valid,
            errors=all_errors,
            warnings=all_warnings,
            coverage_stats=coverage_stats
        )

def main():
    """Main function for command-line usage"""
    parser = argparse.ArgumentParser(description='Validate control matrix against PRR requirements')
    parser.add_argument('--prr', required=True, help='Path to PRR document')
    parser.add_argument('--matrix', required=True, help='Path to control matrix CSV file')
    parser.add_argument('--output', help='Output file for validation report (JSON format)')
    
    args = parser.parse_args()
    
    # Validate file paths
    prr_path = Path(args.prr)
    matrix_path = Path(args.matrix)
    
    if not prr_path.exists():
        print(f"Error: PRR file not found: {prr_path}")
        sys.exit(1)
    
    if not matrix_path.exists():
        print(f"Error: Control matrix file not found: {matrix_path}")
        sys.exit(1)
    
    # Run validation
    validator = ControlMatrixValidator(prr_path, matrix_path)
    result = validator.validate()
    
    # Print results
    print("\n" + "="*60)
    print("CONTROL MATRIX VALIDATION RESULTS")
    print("="*60)
    
    print(f"\nValidation Status: {'PASSED' if result.is_valid else 'FAILED'}")
    
    if result.coverage_stats:
        print(f"\nCoverage Statistics:")
        for key, value in result.coverage_stats.items():
            print(f"  {key.replace('_', ' ').title()}: {value}")
    
    if result.errors:
        print(f"\nErrors ({len(result.errors)}):")
        for error in result.errors:
            print(f"  ❌ {error}")
    
    if result.warnings:
        print(f"\nWarnings ({len(result.warnings)}):")
        for warning in result.warnings:
            print(f"  ⚠️  {warning}")
    
    if not result.errors and not result.warnings:
        print("\n✅ No issues found!")
    
    # Save results to file if requested
    if args.output:
        output_data = {
            'validation_status': 'PASSED' if result.is_valid else 'FAILED',
            'coverage_stats': result.coverage_stats,
            'errors': result.errors,
            'warnings': result.warnings,
            'timestamp': str(Path().cwd())
        }
        
        with open(args.output, 'w') as f:
            json.dump(output_data, f, indent=2)
        
        print(f"\nValidation report saved to: {args.output}")
    
    # Exit with appropriate code
    sys.exit(0 if result.is_valid else 1)

if __name__ == '__main__':
    main()