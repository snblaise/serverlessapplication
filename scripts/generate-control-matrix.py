#!/usr/bin/env python3
"""
Control Matrix Generator

This script automatically generates a control matrix template from the PRR document
by extracting requirements and creating placeholder entries for manual completion.
"""

import re
import csv
import argparse
from pathlib import Path
from typing import List, Dict, Tuple
from dataclasses import dataclass

@dataclass
class RequirementEntry:
    """Data structure for extracted requirement"""
    requirement_id: str
    title: str
    description: str
    category: str

class ControlMatrixGenerator:
    """Generates control matrix template from PRR document"""
    
    def __init__(self, prr_file: Path):
        self.prr_file = prr_file
        self.requirements = []
        
        # AWS service mapping based on requirement categories
        self.service_mapping = {
            'SEC': {
                'identity': 'IAM',
                'secrets': 'Secrets Manager',
                'encryption': 'KMS',
                'code': 'Lambda',
                'network': 'VPC',
                'api': 'API Gateway'
            },
            'NFR': {
                'availability': 'Lambda',
                'performance': 'CloudWatch',
                'disaster': 'S3',
                'cost': 'CloudWatch'
            },
            'LRR': {
                'version': 'Lambda',
                'concurrency': 'Lambda',
                'error': 'SQS',
                'performance': 'CloudWatch'
            },
            'ESA': {
                'api': 'API Gateway',
                'event': 'EventBridge',
                'queue': 'SQS',
                'notification': 'SNS'
            },
            'OBS': {
                'logging': 'CloudWatch',
                'tracing': 'X-Ray',
                'monitoring': 'CloudWatch',
                'alerting': 'SNS'
            }
        }
        
        # Compliance framework mapping
        self.compliance_mapping = {
            'identity': 'ISO 27001 A.9.2.3',
            'access': 'ISO 27001 A.9.4.2',
            'encryption': 'ISO 27001 A.10.1.2',
            'logging': 'ISO 27001 A.12.4.1',
            'monitoring': 'ISO 27001 A.12.4.1',
            'backup': 'ISO 27001 A.12.3.1',
            'network': 'ISO 27001 A.13.1.1'
        }
    
    def extract_requirements(self) -> List[RequirementEntry]:
        """Extract requirements from PRR document"""
        requirements = []
        
        try:
            with open(self.prr_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Find all requirement patterns with their descriptions
            # Pattern matches: #### SEC-001.1 Title followed by requirement text
            requirement_pattern = r'#### ([A-Z]{2,4}-\d{3}\.\d+)\s+(.+?)\n- \*\*Requirement\*\*:\s*(.+?)(?=\n- \*\*|#### [A-Z]{2,4}-\d{3}\.\d+|## [A-Z]|$)'
            matches = re.finditer(requirement_pattern, content, re.DOTALL)
            
            for match in matches:
                req_id = match.group(1)
                title = match.group(2).strip()
                description = match.group(3).strip()
                
                # Clean up description
                description = re.sub(r'\n+', ' ', description)
                description = re.sub(r'\s+', ' ', description)
                description = description.replace('- **Implementation**:', '').strip()
                
                # Take first sentence or first 200 characters
                if '.' in description:
                    description = description.split('.')[0] + '.'
                elif len(description) > 200:
                    description = description[:200] + '...'
                
                # Determine category from requirement ID
                category = req_id.split('-')[0]
                
                requirements.append(RequirementEntry(
                    requirement_id=req_id,
                    title=title,
                    description=description,
                    category=category
                ))
            
            # If no matches found with the detailed pattern, try simpler pattern
            if not requirements:
                simple_pattern = r'#### ([A-Z]{2,4}-\d{3}\.\d+)\s+(.+?)(?=#### [A-Z]{2,4}-\d{3}\.\d+|## [A-Z]|$)'
                matches = re.finditer(simple_pattern, content, re.DOTALL)
                
                for match in matches:
                    req_id = match.group(1)
                    content_block = match.group(2).strip()
                    
                    # Extract title (first line)
                    lines = content_block.split('\n')
                    title = lines[0].strip()
                    
                    # Extract description from requirement section
                    desc_match = re.search(r'\*\*Requirement\*\*:\s*(.+?)(?=\n- \*\*|$)', content_block, re.DOTALL)
                    if desc_match:
                        description = desc_match.group(1).strip()
                        description = re.sub(r'\n+', ' ', description)
                        description = re.sub(r'\s+', ' ', description)
                    else:
                        description = title
                    
                    category = req_id.split('-')[0]
                    
                    requirements.append(RequirementEntry(
                        requirement_id=req_id,
                        title=title,
                        description=description,
                        category=category
                    ))
            
            print(f"Extracted {len(requirements)} requirements from PRR document")
            return requirements
            
        except FileNotFoundError:
            print(f"Error: PRR file not found: {self.prr_file}")
            return []
        except Exception as e:
            print(f"Error reading PRR file: {e}")
            return []
    
    def suggest_aws_service(self, requirement: RequirementEntry) -> str:
        """Suggest AWS service based on requirement content"""
        content = (requirement.description + " " + requirement.title).lower()
        
        # Service keyword mapping
        service_keywords = {
            'IAM': ['iam', 'role', 'policy', 'permission', 'access', 'identity'],
            'Lambda': ['lambda', 'function', 'execution', 'runtime', 'concurrency'],
            'API Gateway': ['api', 'gateway', 'endpoint', 'rest', 'http'],
            'CloudWatch': ['cloudwatch', 'log', 'metric', 'alarm', 'monitoring'],
            'KMS': ['kms', 'encryption', 'key', 'encrypt'],
            'Secrets Manager': ['secret', 'credential', 'password'],
            'Parameter Store': ['parameter', 'configuration', 'config'],
            'VPC': ['vpc', 'network', 'security group', 'subnet'],
            'S3': ['s3', 'bucket', 'storage', 'backup'],
            'DynamoDB': ['dynamodb', 'database', 'table'],
            'SQS': ['sqs', 'queue', 'message'],
            'SNS': ['sns', 'notification', 'topic'],
            'EventBridge': ['eventbridge', 'event', 'rule'],
            'X-Ray': ['xray', 'x-ray', 'tracing', 'trace'],
            'CodeDeploy': ['codedeploy', 'deployment', 'canary'],
            'Config': ['config', 'compliance', 'rule'],
            'Security Hub': ['security hub', 'security', 'finding'],
            'WAF': ['waf', 'web application firewall']
        }
        
        # Score each service based on keyword matches
        service_scores = {}
        for service, keywords in service_keywords.items():
            score = sum(1 for keyword in keywords if keyword in content)
            if score > 0:
                service_scores[service] = score
        
        # Return highest scoring service or default based on category
        if service_scores:
            return max(service_scores, key=service_scores.get)
        
        # Fallback to category-based mapping
        category_defaults = {
            'SEC': 'IAM',
            'NFR': 'CloudWatch',
            'LRR': 'Lambda',
            'ESA': 'API Gateway',
            'OBS': 'CloudWatch'
        }
        
        return category_defaults.get(requirement.category, 'Lambda')
    
    def suggest_enforcement_method(self, requirement: RequirementEntry, aws_service: str) -> str:
        """Suggest enforcement method based on service and requirement"""
        content = requirement.description.lower()
        
        enforcement_patterns = {
            'IAM': {
                'policy': 'IAM policy with least privilege principles',
                'role': 'IAM role configuration with permission boundaries',
                'boundary': 'Permission boundary policy enforcement'
            },
            'Lambda': {
                'signing': 'Code Signing Configuration attachment',
                'version': 'Lambda versioning and alias configuration',
                'concurrency': 'Reserved/provisioned concurrency limits'
            },
            'CloudWatch': {
                'log': 'CloudWatch Logs configuration with retention',
                'metric': 'Custom metrics and alarm configuration',
                'alarm': 'CloudWatch alarm thresholds and actions'
            },
            'Config': {
                'rule': 'AWS Config rule evaluation',
                'compliance': 'Config compliance monitoring'
            }
        }
        
        # Find matching patterns
        if aws_service in enforcement_patterns:
            for pattern, method in enforcement_patterns[aws_service].items():
                if pattern in content:
                    return method
        
        # Default enforcement methods by service
        default_methods = {
            'IAM': 'IAM policy configuration',
            'Lambda': 'Lambda function configuration',
            'CloudWatch': 'CloudWatch configuration',
            'KMS': 'KMS key policy and configuration',
            'Config': 'AWS Config rule enforcement',
            'S3': 'S3 bucket policy and configuration'
        }
        
        return default_methods.get(aws_service, f'{aws_service} configuration')
    
    def suggest_automated_check(self, aws_service: str) -> str:
        """Suggest automated check method based on AWS service"""
        check_mapping = {
            'IAM': 'IAM Access Analyzer',
            'Lambda': 'AWS Config Rule: lambda-function-settings-check',
            'CloudWatch': 'CloudWatch metrics and alarms',
            'KMS': 'AWS Config Rule: cmk-backing-key-rotation-enabled',
            'Secrets Manager': 'AWS Config Rule: secretsmanager-rotation-enabled-check',
            'Parameter Store': 'AWS Config Rule: ssm-document-not-public',
            'VPC': 'AWS Config Rule: lambda-inside-vpc',
            'API Gateway': 'AWS Config Rule: api-gw-associated-with-waf',
            'S3': 'S3 bucket compliance monitoring',
            'Config': 'Config rule evaluation status',
            'Security Hub': 'Security Hub findings aggregation',
            'X-Ray': 'X-Ray service map and trace analysis'
        }
        
        return check_mapping.get(aws_service, f'{aws_service} compliance monitoring')
    
    def suggest_evidence_artifact(self, aws_service: str, requirement_id: str) -> str:
        """Suggest evidence artifact location based on service"""
        artifact_mapping = {
            'IAM': f'CloudTrail logs: arn:aws:logs:*:*:log-group:/aws/cloudtrail/*',
            'Lambda': f'Lambda console configuration for {requirement_id}',
            'CloudWatch': f'CloudWatch dashboard: {requirement_id.lower()}-monitoring',
            'KMS': 'KMS console key rotation status',
            'Secrets Manager': 'Secrets Manager console rotation status',
            'Parameter Store': 'Parameter Store console encryption status',
            'Config': f'Config compliance dashboard: {requirement_id.lower()}',
            'Security Hub': 'Security Hub findings dashboard',
            'API Gateway': 'API Gateway console configuration'
        }
        
        return artifact_mapping.get(aws_service, f'{aws_service} console configuration')
    
    def suggest_compliance_mapping(self, requirement: RequirementEntry) -> str:
        """Suggest compliance framework mapping"""
        content = requirement.description.lower()
        
        # Compliance keyword mapping
        compliance_keywords = {
            'ISO 27001 A.9.2.3': ['access', 'privilege', 'permission', 'identity'],
            'ISO 27001 A.9.4.2': ['authentication', 'mfa', 'login', 'session'],
            'ISO 27001 A.10.1.2': ['encryption', 'key', 'crypto', 'secure'],
            'ISO 27001 A.12.4.1': ['log', 'audit', 'monitoring', 'event'],
            'ISO 27001 A.12.3.1': ['backup', 'recovery', 'restore', 'disaster'],
            'ISO 27001 A.13.1.1': ['network', 'vpc', 'security group', 'firewall'],
            'SOC 2 CC6.1': ['logical', 'access', 'authorization'],
            'SOC 2 CC6.7': ['transmission', 'transit', 'communication'],
            'NIST CSF PR.AC-1': ['identity', 'credential', 'access']
        }
        
        # Find best matching compliance framework
        best_match = 'ISO 27001'
        best_score = 0
        
        for framework, keywords in compliance_keywords.items():
            score = sum(1 for keyword in keywords if keyword in content)
            if score > best_score:
                best_score = score
                best_match = framework
        
        return best_match
    
    def generate_control_matrix(self, output_file: Path) -> bool:
        """Generate control matrix CSV file"""
        requirements = self.extract_requirements()
        
        if not requirements:
            print("No requirements found to generate control matrix")
            return False
        
        try:
            with open(output_file, 'w', newline='', encoding='utf-8') as f:
                fieldnames = [
                    'Requirement ID',
                    'Requirement Description',
                    'AWS Service/Feature',
                    'How Enforced/Configured',
                    'Automated Check/Test',
                    'Evidence Artifact',
                    'Compliance Mapping'
                ]
                
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                
                for req in requirements:
                    aws_service = self.suggest_aws_service(req)
                    
                    row = {
                        'Requirement ID': req.requirement_id,
                        'Requirement Description': req.description[:100] + '...' if len(req.description) > 100 else req.description,
                        'AWS Service/Feature': aws_service,
                        'How Enforced/Configured': self.suggest_enforcement_method(req, aws_service),
                        'Automated Check/Test': self.suggest_automated_check(aws_service),
                        'Evidence Artifact': self.suggest_evidence_artifact(aws_service, req.requirement_id),
                        'Compliance Mapping': self.suggest_compliance_mapping(req)
                    }
                    
                    writer.writerow(row)
            
            print(f"Generated control matrix with {len(requirements)} entries: {output_file}")
            return True
            
        except Exception as e:
            print(f"Error generating control matrix: {e}")
            return False

def main():
    """Main function for command-line usage"""
    parser = argparse.ArgumentParser(description='Generate control matrix from PRR document')
    parser.add_argument('--prr', required=True, help='Path to PRR document')
    parser.add_argument('--output', required=True, help='Output CSV file for control matrix')
    parser.add_argument('--overwrite', action='store_true', help='Overwrite existing output file')
    
    args = parser.parse_args()
    
    # Validate input file
    prr_path = Path(args.prr)
    if not prr_path.exists():
        print(f"Error: PRR file not found: {prr_path}")
        return 1
    
    # Check output file
    output_path = Path(args.output)
    if output_path.exists() and not args.overwrite:
        print(f"Error: Output file already exists: {output_path}")
        print("Use --overwrite to replace existing file")
        return 1
    
    # Generate control matrix
    generator = ControlMatrixGenerator(prr_path)
    success = generator.generate_control_matrix(output_path)
    
    return 0 if success else 1

if __name__ == '__main__':
    exit(main())