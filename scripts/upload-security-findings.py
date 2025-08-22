#!/usr/bin/env python3
"""
Upload security scan findings to AWS Security Hub
Supports npm audit and Checkov SARIF format results
"""

import json
import argparse
import boto3
import uuid
import os
from datetime import datetime, timezone
from typing import List, Dict, Any

def convert_npm_audit_to_asff(audit_data: Dict[str, Any], environment: str) -> List[Dict[str, Any]]:
    """Convert npm audit JSON to AWS Security Finding Format (ASFF)"""
    findings = []
    
    if 'vulnerabilities' not in audit_data:
        return findings
    
    for package_name, vuln_data in audit_data['vulnerabilities'].items():
        # Skip if no vulnerability data
        if not isinstance(vuln_data, dict) or 'severity' not in vuln_data:
            continue
            
        severity_mapping = {
            'critical': 90,
            'high': 70,
            'moderate': 40,
            'low': 10,
            'info': 1
        }
        
        finding = {
            'SchemaVersion': '2018-10-08',
            'Id': f"npm-audit/{package_name}/{vuln_data.get('via', ['unknown'])[0] if isinstance(vuln_data.get('via'), list) else 'unknown'}",
            'ProductArn': f"arn:aws:securityhub:us-east-1::product/npm/audit",
            'GeneratorId': 'npm-audit',
            'AwsAccountId': boto3.client('sts').get_caller_identity()['Account'],
            'Types': ['Software and Configuration Checks/Vulnerabilities/CVE'],
            'CreatedAt': datetime.now(timezone.utc).isoformat(),
            'UpdatedAt': datetime.now(timezone.utc).isoformat(),
            'Severity': {
                'Label': vuln_data['severity'].upper(),
                'Normalized': severity_mapping.get(vuln_data['severity'], 40)
            },
            'Title': f"Vulnerable npm package: {package_name}",
            'Description': f"Package {package_name} has {vuln_data['severity']} severity vulnerability",
            'Resources': [{
                'Type': 'Other',
                'Id': f"npm-package/{package_name}",
                'Region': 'us-east-1',
                'Details': {
                    'Other': {
                        'PackageName': package_name,
                        'CurrentVersion': vuln_data.get('range', 'unknown'),
                        'Environment': environment
                    }
                }
            }],
            'WorkflowState': 'NEW',
            'RecordState': 'ACTIVE'
        }
        
        # Add CVE information if available
        if 'via' in vuln_data and isinstance(vuln_data['via'], list):
            for via_item in vuln_data['via']:
                if isinstance(via_item, dict) and 'cve' in via_item:
                    finding['Types'] = [f"Software and Configuration Checks/Vulnerabilities/{via_item['cve']}"]
                    break
        
        findings.append(finding)
    
    return findings

def convert_sarif_to_asff(sarif_data: Dict[str, Any], source: str, environment: str) -> List[Dict[str, Any]]:
    """Convert SARIF format to AWS Security Finding Format (ASFF)"""
    findings = []
    
    if 'runs' not in sarif_data:
        return findings
    
    for run in sarif_data['runs']:
        if 'results' not in run:
            continue
            
        for result in run['results']:
            severity_mapping = {
                'error': 70,
                'warning': 40,
                'note': 10,
                'info': 1
            }
            
            level = result.get('level', 'warning')
            rule_id = result.get('ruleId', 'unknown')
            
            finding = {
                'SchemaVersion': '2018-10-08',
                'Id': f"{source}/{rule_id}/{str(uuid.uuid4())[:8]}",
                'ProductArn': f"arn:aws:securityhub:us-east-1::product/{source}/scanner",
                'GeneratorId': source,
                'AwsAccountId': boto3.client('sts').get_caller_identity()['Account'],
                'Types': ['Software and Configuration Checks/Industry and Regulatory Standards'],
                'CreatedAt': datetime.now(timezone.utc).isoformat(),
                'UpdatedAt': datetime.now(timezone.utc).isoformat(),
                'Severity': {
                    'Label': level.upper() if level.upper() in ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'] else 'MEDIUM',
                    'Normalized': severity_mapping.get(level, 40)
                },
                'Title': f"{source.title()} Policy Violation: {rule_id}",
                'Description': result.get('message', {}).get('text', f"Policy violation detected by {source}"),
                'Resources': [{
                    'Type': 'Other',
                    'Id': f"{source}-scan/{rule_id}",
                    'Region': 'us-east-1',
                    'Details': {
                        'Other': {
                            'RuleId': rule_id,
                            'Source': source,
                            'Environment': environment
                        }
                    }
                }],
                'WorkflowState': 'NEW',
                'RecordState': 'ACTIVE'
            }
            
            # Add location information if available
            if 'locations' in result and result['locations']:
                location = result['locations'][0]
                if 'physicalLocation' in location:
                    phys_loc = location['physicalLocation']
                    if 'artifactLocation' in phys_loc:
                        finding['Resources'][0]['Details']['Other']['FilePath'] = phys_loc['artifactLocation'].get('uri', 'unknown')
                    if 'region' in phys_loc:
                        region = phys_loc['region']
                        finding['Resources'][0]['Details']['Other']['LineNumber'] = str(region.get('startLine', 'unknown'))
            
            findings.append(finding)
    
    return findings

def upload_findings_to_security_hub(findings: List[Dict[str, Any]], region: str = 'us-east-1'):
    """Upload findings to AWS Security Hub"""
    if not findings:
        print("No findings to upload")
        return
    
    securityhub = boto3.client('securityhub', region_name=region)
    
    # Security Hub has a limit of 100 findings per batch
    batch_size = 100
    
    for i in range(0, len(findings), batch_size):
        batch = findings[i:i + batch_size]
        
        try:
            response = securityhub.batch_import_findings(Findings=batch)
            
            if response['FailedCount'] > 0:
                print(f"Failed to import {response['FailedCount']} findings:")
                for failure in response.get('FailedFindings', []):
                    print(f"  - {failure}")
            
            print(f"Successfully imported {response['SuccessCount']} findings to Security Hub")
            
        except Exception as e:
            print(f"Error uploading findings to Security Hub: {e}")
            raise

def validate_security_hub_integration():
    """Validate that Security Hub is enabled and accessible"""
    try:
        securityhub = boto3.client('securityhub')
        securityhub.describe_hub()
        return True
    except Exception as e:
        print(f"Warning: Security Hub not accessible: {e}")
        print("Findings will be logged locally instead of uploaded to Security Hub")
        return False

def log_findings_locally(findings: List[Dict[str, Any]], source: str, environment: str):
    """Log findings locally when Security Hub is not available"""
    if not findings:
        return
    
    log_file = f"security-findings-{source}-{environment}.json"
    
    with open(log_file, 'w') as f:
        json.dump({
            'source': source,
            'environment': environment,
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'findings_count': len(findings),
            'findings': findings
        }, f, indent=2)
    
    print(f"Logged {len(findings)} findings to {log_file}")

def main():
    parser = argparse.ArgumentParser(description='Upload security scan findings to AWS Security Hub')
    parser.add_argument('--source', required=True, choices=['npm-audit', 'checkov', 'codeql'],
                       help='Source of the security scan')
    parser.add_argument('--file', required=True, help='Path to the scan results file')
    parser.add_argument('--environment', required=True, help='Environment (staging/production)')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--local-only', action='store_true', 
                       help='Log findings locally instead of uploading to Security Hub')
    
    args = parser.parse_args()
    
    try:
        # Check if file exists and is readable
        if not os.path.exists(args.file):
            print(f"Warning: File {args.file} not found, skipping {args.source} scan results")
            return 0
            
        with open(args.file, 'r') as f:
            scan_data = json.load(f)
        
        findings = []
        
        if args.source == 'npm-audit':
            findings = convert_npm_audit_to_asff(scan_data, args.environment)
        elif args.source in ['checkov', 'codeql']:
            findings = convert_sarif_to_asff(scan_data, args.source, args.environment)
        
        if not findings:
            print(f"No findings found in {args.source} results")
            return 0
        
        # Upload to Security Hub or log locally
        if args.local_only or not validate_security_hub_integration():
            log_findings_locally(findings, args.source, args.environment)
        else:
            upload_findings_to_security_hub(findings, args.region)
            print(f"Uploaded {len(findings)} findings from {args.source} to Security Hub")
            
    except FileNotFoundError:
        print(f"Warning: File {args.file} not found, skipping {args.source} scan results")
        return 0
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in file {args.file}")
        return 1
    except Exception as e:
        print(f"Error processing {args.source} results: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())