#!/usr/bin/env python3
"""
Test suite for compliance mapping verification against ISO 27001, SOC 2, NIST CSF.
Validates that all controls are properly mapped to compliance frameworks.
"""

import csv
import json
from pathlib import Path
import pytest
from collections import defaultdict
import re


class TestComplianceMapping:
    """Test cases for compliance framework mapping validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment and load compliance mappings."""
        cls.project_root = Path(__file__).parent.parent.parent
        cls.docs_dir = cls.project_root / "docs"
        
        # Load control matrix
        cls.control_matrix = cls._load_control_matrix()
        
        # Define compliance framework mappings
        cls.compliance_frameworks = {
            'ISO27001': cls._get_iso27001_controls(),
            'SOC2': cls._get_soc2_controls(),
            'NISTCSF': cls._get_nist_csf_controls()
        }
    
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
    def _get_iso27001_controls(cls):
        """Get relevant ISO 27001 controls for Lambda production readiness."""
        return {
            'A.8.1.1': 'Inventory of assets',
            'A.8.1.2': 'Ownership of assets',
            'A.8.2.1': 'Classification of information',
            'A.8.2.2': 'Labelling of information',
            'A.8.2.3': 'Handling of assets',
            'A.8.3.1': 'Management of removable media',
            'A.8.3.2': 'Disposal of media',
            'A.8.3.3': 'Physical media transfer',
            'A.9.1.1': 'Access control policy',
            'A.9.1.2': 'Access to networks and network services',
            'A.9.2.1': 'User registration and de-registration',
            'A.9.2.2': 'User access provisioning',
            'A.9.2.3': 'Management of privileged access rights',
            'A.9.2.4': 'Management of secret authentication information of users',
            'A.9.2.5': 'Review of user access rights',
            'A.9.2.6': 'Removal or adjustment of access rights',
            'A.9.3.1': 'Use of secret authentication information',
            'A.9.4.1': 'Information access restriction',
            'A.9.4.2': 'Secure log-on procedures',
            'A.9.4.3': 'Password management system',
            'A.9.4.4': 'Use of privileged utility programs',
            'A.9.4.5': 'Access control to program source code',
            'A.10.1.1': 'Policy on the use of cryptographic controls',
            'A.10.1.2': 'Key management',
            'A.12.1.1': 'Documented operating procedures',
            'A.12.1.2': 'Change management',
            'A.12.1.3': 'Capacity management',
            'A.12.1.4': 'Separation of development, testing and operational environments',
            'A.12.2.1': 'Controls against malware',
            'A.12.3.1': 'Information backup',
            'A.12.4.1': 'Event logging',
            'A.12.4.2': 'Protection of log information',
            'A.12.4.3': 'Administrator and operator logs',
            'A.12.4.4': 'Clock synchronisation',
            'A.12.5.1': 'Installation of software on operational systems',
            'A.12.6.1': 'Management of technical vulnerabilities',
            'A.12.6.2': 'Restrictions on software installation',
            'A.12.7.1': 'Information systems audit controls',
            'A.13.1.1': 'Network controls',
            'A.13.1.2': 'Security of network services',
            'A.13.1.3': 'Separation of networks',
            'A.13.2.1': 'Information transfer policies and procedures',
            'A.13.2.2': 'Agreements on information transfer',
            'A.13.2.3': 'Electronic messaging',
            'A.14.1.1': 'Information security requirements analysis and specification',
            'A.14.1.2': 'Securing application services on public networks',
            'A.14.1.3': 'Protecting application services transactions',
            'A.14.2.1': 'Secure development policy',
            'A.14.2.2': 'System change control procedures',
            'A.14.2.3': 'Technical review of applications after operating platform changes',
            'A.14.2.4': 'Restrictions on changes to software packages',
            'A.14.2.5': 'Secure system engineering principles',
            'A.14.2.6': 'Secure development environment',
            'A.14.2.7': 'Outsourced development',
            'A.14.2.8': 'System security testing',
            'A.14.2.9': 'System acceptance testing',
            'A.14.3.1': 'Protection of test data',
            'A.15.1.1': 'Information security policy for supplier relationships',
            'A.15.1.2': 'Addressing security within supplier agreements',
            'A.15.1.3': 'Information and communication technology supply chain',
            'A.15.2.1': 'Monitoring and review of supplier services',
            'A.15.2.2': 'Managing changes to supplier services',
            'A.16.1.1': 'Responsibilities and procedures',
            'A.16.1.2': 'Reporting information security events',
            'A.16.1.3': 'Reporting information security weaknesses',
            'A.16.1.4': 'Assessment of and decision on information security events',
            'A.16.1.5': 'Response to information security incidents',
            'A.16.1.6': 'Learning from information security incidents',
            'A.16.1.7': 'Collection of evidence',
            'A.17.1.1': 'Planning information security continuity',
            'A.17.1.2': 'Implementing information security continuity',
            'A.17.1.3': 'Verify, review and evaluate information security continuity',
            'A.17.2.1': 'Availability of information processing facilities',
            'A.18.1.1': 'Identification of applicable legislation and contractual requirements',
            'A.18.1.2': 'Intellectual property rights',
            'A.18.1.3': 'Protection of records',
            'A.18.1.4': 'Privacy and protection of personally identifiable information',
            'A.18.1.5': 'Regulation of cryptographic controls',
            'A.18.2.1': 'Independent review of information security',
            'A.18.2.2': 'Compliance with security policies and standards',
            'A.18.2.3': 'Technical compliance review'
        }
    
    @classmethod
    def _get_soc2_controls(cls):
        """Get relevant SOC 2 controls for Lambda production readiness."""
        return {
            'CC1.1': 'COSO Principle 1: The entity demonstrates a commitment to integrity and ethical values',
            'CC1.2': 'COSO Principle 2: The board of directors demonstrates independence from management',
            'CC1.3': 'COSO Principle 3: Management establishes structure, authority, and responsibility',
            'CC1.4': 'COSO Principle 4: The entity demonstrates a commitment to attract, develop, and retain competent individuals',
            'CC1.5': 'COSO Principle 5: The entity holds individuals accountable for their internal control responsibilities',
            'CC2.1': 'COSO Principle 6: The entity specifies objectives with sufficient clarity',
            'CC2.2': 'COSO Principle 7: The entity identifies and analyzes risks to the achievement of objectives',
            'CC2.3': 'COSO Principle 8: The entity considers the potential for fraud in assessing risks',
            'CC3.1': 'COSO Principle 9: The entity identifies and assesses changes that could significantly impact the system',
            'CC3.2': 'COSO Principle 10: The entity selects and develops control activities',
            'CC3.3': 'COSO Principle 11: The entity selects and develops general controls over technology',
            'CC3.4': 'COSO Principle 12: The entity deploys control activities through policies and procedures',
            'CC4.1': 'COSO Principle 13: The entity obtains or generates and uses relevant, quality information',
            'CC4.2': 'COSO Principle 14: The entity internally communicates information necessary to support functioning of internal control',
            'CC5.1': 'COSO Principle 15: The entity selects, develops, and performs ongoing and/or separate evaluations',
            'CC5.2': 'COSO Principle 16: The entity evaluates and communicates internal control deficiencies',
            'CC5.3': 'COSO Principle 17: The entity responds to risks associated with reporting',
            'CC6.1': 'Logical and physical access controls',
            'CC6.2': 'System access is restricted to authorized users',
            'CC6.3': 'Data transmission is protected',
            'CC6.4': 'Mobile devices are protected',
            'CC6.5': 'Data at rest is protected',
            'CC6.6': 'Transmission of data and system outputs is complete and accurate',
            'CC6.7': 'System processing is complete and accurate',
            'CC6.8': 'System processing is authorized',
            'CC7.1': 'System capacity is monitored',
            'CC7.2': 'System monitoring includes data and processing integrity',
            'CC7.3': 'Alerts are communicated to responsible personnel',
            'CC7.4': 'System availability and security incidents are resolved',
            'CC7.5': 'System availability and security incidents are identified and communicated',
            'CC8.1': 'Change management process and procedures are defined and implemented',
            'CC9.1': 'Risk assessment and risk mitigation',
            'A1.1': 'Access controls are implemented',
            'A1.2': 'Logical access security measures protect against threats from sources outside its system boundaries',
            'A1.3': 'Multi-factor authentication or other security measures protect against unauthorized access',
            'PI1.1': 'Personal information is collected, used, retained, disclosed, and disposed of in conformity with the commitments in the entity\'s privacy notice',
            'PI1.2': 'Personal information is processed for the purposes identified in the entity\'s privacy notice',
            'PI1.3': 'Personal information is complete and accurate for the purposes identified in the entity\'s privacy notice',
            'PI1.4': 'Personal information processing activities are restricted to those identified in the entity\'s privacy notice',
            'PI1.5': 'Personal information is retained and disposed of in conformity with the commitments in the entity\'s privacy notice'
        }
    
    @classmethod
    def _get_nist_csf_controls(cls):
        """Get relevant NIST Cybersecurity Framework controls for Lambda production readiness."""
        return {
            'ID.AM-1': 'Physical devices and systems within the organization are inventoried',
            'ID.AM-2': 'Software platforms and applications within the organization are inventoried',
            'ID.AM-3': 'Organizational communication and data flows are mapped',
            'ID.AM-4': 'External information systems are catalogued',
            'ID.AM-5': 'Resources (e.g., hardware, devices, data, time, personnel, and software) are prioritized based on their classification, criticality, and business value',
            'ID.AM-6': 'Cybersecurity roles and responsibilities for the entire workforce and third-party stakeholders are established',
            'ID.BE-1': 'The organization\'s role in the supply chain is identified and communicated',
            'ID.BE-2': 'The organization\'s place in critical infrastructure and its industry sector is identified and communicated',
            'ID.BE-3': 'Priorities for organizational mission, objectives, and activities are established and communicated',
            'ID.BE-4': 'Dependencies and critical functions for delivery of critical services are established',
            'ID.BE-5': 'Resilience requirements to support delivery of critical services are established for all operating states',
            'ID.GV-1': 'Organizational cybersecurity policy is established and communicated',
            'ID.GV-2': 'Cybersecurity roles and responsibilities are coordinated and aligned with internal roles and external partners',
            'ID.GV-3': 'Legal and regulatory requirements regarding cybersecurity, including privacy and civil liberties obligations, are understood and managed',
            'ID.GV-4': 'Governance and risk management processes address cybersecurity risks',
            'ID.RA-1': 'Asset vulnerabilities are identified and documented',
            'ID.RA-2': 'Cyber threat intelligence is received from information sharing forums and sources',
            'ID.RA-3': 'Threats, both internal and external, are identified and documented',
            'ID.RA-4': 'Potential business impacts and likelihoods are identified',
            'ID.RA-5': 'Threats, vulnerabilities, likelihoods, and impacts are used to determine risk',
            'ID.RA-6': 'Risk responses are identified and prioritized',
            'ID.RM-1': 'Risk management processes are established, managed, and agreed to by organizational stakeholders',
            'ID.RM-2': 'Organizational risk tolerance is determined and clearly expressed',
            'ID.RM-3': 'The organization\'s determination of risk tolerance is informed by its role in critical infrastructure and sector specific risk analysis',
            'ID.SC-1': 'Cyber supply chain risk management processes are identified, established, assessed, managed, and agreed to by organizational stakeholders',
            'ID.SC-2': 'Suppliers and third party partners of information systems, components, and services are identified, prioritized, and assessed using a cyber supply chain risk assessment process',
            'ID.SC-3': 'Contracts with suppliers and third-party partners are used to implement appropriate measures designed to meet the objectives of an organization\'s cybersecurity program',
            'ID.SC-4': 'Suppliers and third-party partners are routinely assessed using audits, test results, or other forms of evaluations to confirm they are meeting their contractual obligations',
            'ID.SC-5': 'Response and recovery planning and testing are conducted with suppliers and third-party providers',
            'PR.AC-1': 'Identities and credentials are issued, managed, verified, revoked, and audited for authorized devices, users and processes',
            'PR.AC-2': 'Physical access to assets is managed and protected',
            'PR.AC-3': 'Remote access is managed',
            'PR.AC-4': 'Access permissions and authorizations are managed, incorporating the principles of least privilege and separation of duties',
            'PR.AC-5': 'Network integrity is protected (e.g., network segregation, network segmentation)',
            'PR.AC-6': 'Identities are proofed and bound to credentials and asserted in interactions',
            'PR.AC-7': 'Users, devices, and other assets are authenticated (e.g., single-factor, multi-factor) commensurate with the risk of the transaction',
            'PR.AT-1': 'All users are informed and trained',
            'PR.AT-2': 'Privileged users understand their roles and responsibilities',
            'PR.AT-3': 'Third-party stakeholders (e.g., suppliers, customers, partners) understand their roles and responsibilities',
            'PR.AT-4': 'Senior executives understand their roles and responsibilities',
            'PR.AT-5': 'Physical and cybersecurity personnel understand their roles and responsibilities',
            'PR.DS-1': 'Data-at-rest is protected',
            'PR.DS-2': 'Data-in-transit is protected',
            'PR.DS-3': 'Assets are formally managed throughout removal, transfers, and disposition',
            'PR.DS-4': 'Adequate capacity to ensure availability is maintained',
            'PR.DS-5': 'Protections against data leaks are implemented',
            'PR.DS-6': 'Integrity checking mechanisms are used to verify software, firmware, and information integrity',
            'PR.DS-7': 'The development and testing environment(s) are separate from the production environment',
            'PR.DS-8': 'Integrity checking mechanisms are used to verify hardware integrity',
            'PR.IP-1': 'A baseline configuration of information technology/industrial control systems is created and maintained incorporating security principles',
            'PR.IP-2': 'A System Development Life Cycle to manage systems is implemented',
            'PR.IP-3': 'Configuration change control processes are in place',
            'PR.IP-4': 'Backups of information are conducted, maintained, and tested',
            'PR.IP-5': 'Policy and regulations regarding the physical operating environment for organizational assets are met',
            'PR.IP-6': 'Data is destroyed according to policy',
            'PR.IP-7': 'Protection processes are improved',
            'PR.IP-8': 'Effectiveness of protection technologies is shared',
            'PR.IP-9': 'Response plans (Incident Response and Business Continuity) and recovery plans (Incident Recovery and Disaster Recovery) are in place and managed',
            'PR.IP-10': 'Response and recovery plans are tested',
            'PR.IP-11': 'Cybersecurity is included in human resources practices',
            'PR.IP-12': 'A vulnerability management plan is developed and implemented',
            'PR.MA-1': 'Maintenance and repair of organizational assets are performed and logged, with approved and controlled tools',
            'PR.MA-2': 'Remote maintenance of organizational assets is approved, logged, and performed in a manner that prevents unauthorized access',
            'PR.PT-1': 'Audit/log records are determined, documented, implemented, and reviewed in accordance with policy',
            'PR.PT-2': 'Removable media is protected and its use restricted according to policy',
            'PR.PT-3': 'The principle of least functionality is incorporated by configuring systems to provide only essential capabilities',
            'PR.PT-4': 'Communications and control networks are protected',
            'PR.PT-5': 'Mechanisms (e.g., failsafe, load balancing, hot swap) are implemented to achieve resilience requirements in normal and adverse situations',
            'DE.AE-1': 'A baseline of network operations and expected data flows for users and systems is established and managed',
            'DE.AE-2': 'Detected events are analyzed to understand attack targets and methods',
            'DE.AE-3': 'Event data are collected and correlated from multiple sources and sensors',
            'DE.AE-4': 'Impact of events is determined',
            'DE.AE-5': 'Incident alert thresholds are established',
            'DE.CM-1': 'The network is monitored to detect potential cybersecurity events',
            'DE.CM-2': 'The physical environment is monitored to detect potential cybersecurity events',
            'DE.CM-3': 'Personnel activity is monitored to detect potential cybersecurity events',
            'DE.CM-4': 'Malicious code is detected',
            'DE.CM-5': 'Unauthorized mobile code is detected',
            'DE.CM-6': 'External service provider activity is monitored to detect potential cybersecurity events',
            'DE.CM-7': 'Monitoring for unauthorized personnel, connections, devices, and software is performed',
            'DE.CM-8': 'Vulnerability scans are performed',
            'DE.DP-1': 'Roles and responsibilities for detection are well defined to ensure accountability',
            'DE.DP-2': 'Detection activities comply with all applicable requirements',
            'DE.DP-3': 'Detection processes are tested',
            'DE.DP-4': 'Event detection information is communicated',
            'DE.DP-5': 'Detection processes are continuously improved',
            'RS.RP-1': 'Response plan is executed during or after an incident',
            'RS.CO-1': 'Personnel know their roles and order of operations when a response is needed',
            'RS.CO-2': 'Incidents are reported consistent with established criteria',
            'RS.CO-3': 'Information is shared consistent with response plans',
            'RS.CO-4': 'Coordination with stakeholders occurs consistent with response plans',
            'RS.CO-5': 'Voluntary information sharing occurs with external stakeholders to achieve broader cybersecurity situational awareness',
            'RS.AN-1': 'Notifications from detection systems are investigated',
            'RS.AN-2': 'The impact of the incident is understood',
            'RS.AN-3': 'Forensics are performed',
            'RS.AN-4': 'Incidents are categorized consistent with response plans',
            'RS.AN-5': 'Processes are established to receive, analyze and respond to vulnerabilities disclosed to the organization from internal and external sources',
            'RS.MI-1': 'Incidents are contained',
            'RS.MI-2': 'Incidents are mitigated',
            'RS.MI-3': 'Newly identified vulnerabilities are mitigated or documented as accepted risks',
            'RS.IM-1': 'Response plans incorporate lessons learned',
            'RS.IM-2': 'Response strategies are updated',
            'RC.RP-1': 'Recovery plan is executed during or after a cybersecurity incident',
            'RC.IM-1': 'Recovery plans incorporate lessons learned',
            'RC.IM-2': 'Recovery strategies are updated',
            'RC.CO-1': 'Public relations are managed',
            'RC.CO-2': 'Reputation is repaired after an incident',
            'RC.CO-3': 'Recovery activities are communicated to internal and external stakeholders as well as executive and management teams'
        }
    
    def test_control_matrix_has_compliance_mappings(self):
        """Test that control matrix includes compliance framework mappings."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Check for compliance mapping columns
        if not self.control_matrix:
            pytest.fail("Control matrix is empty")
        
        headers = list(self.control_matrix[0].keys())
        
        # Look for compliance-related columns
        compliance_columns = []
        for header in headers:
            header_lower = header.lower()
            if any(framework.lower() in header_lower for framework in ['iso', 'soc', 'nist', 'compliance']):
                compliance_columns.append(header)
        
        assert len(compliance_columns) >= 1, f"Control matrix should have compliance mapping columns, found headers: {headers}"
    
    def test_iso27001_control_coverage(self):
        """Test coverage of ISO 27001 controls relevant to Lambda production readiness."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Extract ISO 27001 mappings from control matrix
        iso_mappings = set()
        
        for control in self.control_matrix:
            # Look for ISO 27001 references in any field
            for field_name, field_value in control.items():
                if field_value and isinstance(field_value, str):
                    # Look for ISO control patterns like A.9.1.1, A.12.4.1, etc.
                    iso_matches = re.findall(r'A\.(\d+\.\d+\.\d+)', field_value)
                    for match in iso_matches:
                        iso_mappings.add(f'A.{match}')
        
        # Check coverage of critical ISO controls for serverless/cloud environments
        critical_iso_controls = [
            'A.9.1.1',  # Access control policy
            'A.9.2.4',  # Management of secret authentication information
            'A.10.1.1', # Policy on the use of cryptographic controls
            'A.12.1.2', # Change management
            'A.12.4.1', # Event logging
            'A.12.6.1', # Management of technical vulnerabilities
            'A.13.1.1', # Network controls
            'A.14.2.1', # Secure development policy
            'A.16.1.1', # Responsibilities and procedures (incident response)
        ]
        
        mapped_critical = iso_mappings.intersection(set(critical_iso_controls))
        coverage_ratio = len(mapped_critical) / len(critical_iso_controls)
        
        assert coverage_ratio >= 0.6, f"Should map at least 60% of critical ISO 27001 controls, got {coverage_ratio:.2%}. Mapped: {mapped_critical}"
    
    def test_soc2_control_coverage(self):
        """Test coverage of SOC 2 controls relevant to Lambda production readiness."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Extract SOC 2 mappings from control matrix
        soc2_mappings = set()
        
        for control in self.control_matrix:
            for field_name, field_value in control.items():
                if field_value and isinstance(field_value, str):
                    # Look for SOC 2 control patterns like CC6.1, CC7.2, A1.1, etc.
                    soc2_matches = re.findall(r'(CC\d+\.\d+|A\d+\.\d+|PI\d+\.\d+)', field_value)
                    soc2_mappings.update(soc2_matches)
        
        # Check coverage of critical SOC 2 controls
        critical_soc2_controls = [
            'CC6.1',  # Logical and physical access controls
            'CC6.2',  # System access is restricted to authorized users
            'CC6.3',  # Data transmission is protected
            'CC6.7',  # System processing is complete and accurate
            'CC7.1',  # System capacity is monitored
            'CC7.4',  # System availability and security incidents are resolved
            'CC8.1',  # Change management process and procedures
        ]
        
        mapped_critical = soc2_mappings.intersection(set(critical_soc2_controls))
        coverage_ratio = len(mapped_critical) / len(critical_soc2_controls)
        
        assert coverage_ratio >= 0.5, f"Should map at least 50% of critical SOC 2 controls, got {coverage_ratio:.2%}. Mapped: {mapped_critical}"
    
    def test_nist_csf_control_coverage(self):
        """Test coverage of NIST Cybersecurity Framework controls."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Extract NIST CSF mappings from control matrix
        nist_mappings = set()
        
        for control in self.control_matrix:
            for field_name, field_value in control.items():
                if field_value and isinstance(field_value, str):
                    # Look for NIST CSF control patterns like PR.AC-1, DE.CM-1, etc.
                    nist_matches = re.findall(r'([A-Z]{2}\.[A-Z]{2}-\d+)', field_value)
                    nist_mappings.update(nist_matches)
        
        # Check coverage of critical NIST CSF controls
        critical_nist_controls = [
            'PR.AC-1',  # Identities and credentials are managed
            'PR.AC-4',  # Access permissions incorporate least privilege
            'PR.DS-1',  # Data-at-rest is protected
            'PR.DS-2',  # Data-in-transit is protected
            'PR.IP-2',  # System Development Life Cycle is implemented
            'PR.IP-3',  # Configuration change control processes
            'PR.PT-1',  # Audit/log records are implemented
            'DE.CM-1',  # Network is monitored
            'RS.RP-1',  # Response plan is executed
        ]
        
        mapped_critical = nist_mappings.intersection(set(critical_nist_controls))
        coverage_ratio = len(mapped_critical) / len(critical_nist_controls)
        
        assert coverage_ratio >= 0.4, f"Should map at least 40% of critical NIST CSF controls, got {coverage_ratio:.2%}. Mapped: {mapped_critical}"
    
    def test_compliance_mapping_consistency(self):
        """Test that compliance mappings are consistent and not contradictory."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Check for consistent mapping patterns
        mapping_patterns = defaultdict(list)
        
        for i, control in enumerate(self.control_matrix):
            control_id = control.get('Requirement', f'Control-{i}')
            
            # Extract all compliance references
            compliance_refs = []
            for field_name, field_value in control.items():
                if field_value and isinstance(field_value, str):
                    # Find all compliance control references
                    iso_refs = re.findall(r'A\.\d+\.\d+\.\d+', field_value)
                    soc2_refs = re.findall(r'CC\d+\.\d+|A\d+\.\d+|PI\d+\.\d+', field_value)
                    nist_refs = re.findall(r'[A-Z]{2}\.[A-Z]{2}-\d+', field_value)
                    
                    compliance_refs.extend(iso_refs)
                    compliance_refs.extend(soc2_refs)
                    compliance_refs.extend(nist_refs)
            
            if compliance_refs:
                mapping_patterns[control_id] = compliance_refs
        
        # Check for reasonable mapping distribution
        total_mappings = sum(len(refs) for refs in mapping_patterns.values())
        controls_with_mappings = len(mapping_patterns)
        
        if controls_with_mappings > 0:
            avg_mappings_per_control = total_mappings / controls_with_mappings
            assert avg_mappings_per_control >= 1.0, f"Controls should have at least 1 compliance mapping on average, got {avg_mappings_per_control:.2f}"
            assert avg_mappings_per_control <= 10.0, f"Controls should not have excessive mappings, got {avg_mappings_per_control:.2f}"
    
    def test_compliance_framework_completeness(self):
        """Test that all major compliance frameworks are represented."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Check for presence of each framework
        frameworks_found = {
            'ISO27001': False,
            'SOC2': False,
            'NISTCSF': False
        }
        
        for control in self.control_matrix:
            for field_name, field_value in control.items():
                if field_value and isinstance(field_value, str):
                    field_lower = field_value.lower()
                    
                    # Check for ISO 27001
                    if re.search(r'a\.\d+\.\d+\.\d+', field_lower) or 'iso' in field_lower:
                        frameworks_found['ISO27001'] = True
                    
                    # Check for SOC 2
                    if re.search(r'cc\d+\.\d+', field_lower) or 'soc' in field_lower:
                        frameworks_found['SOC2'] = True
                    
                    # Check for NIST CSF
                    if re.search(r'[a-z]{2}\.[a-z]{2}-\d+', field_lower) or 'nist' in field_lower:
                        frameworks_found['NISTCSF'] = True
        
        # At least 2 out of 3 frameworks should be represented
        frameworks_present = sum(frameworks_found.values())
        assert frameworks_present >= 2, f"At least 2 compliance frameworks should be represented, found: {frameworks_found}"
    
    def test_control_traceability_to_compliance(self):
        """Test that controls can be traced to specific compliance requirements."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Check that controls have clear traceability
        controls_with_traceability = 0
        total_controls = len(self.control_matrix)
        
        for control in self.control_matrix:
            has_traceability = False
            
            # Check if control has compliance mapping or clear requirement reference
            for field_name, field_value in control.items():
                if field_value and isinstance(field_value, str):
                    # Look for compliance references or requirement IDs
                    if (re.search(r'A\.\d+\.\d+\.\d+', field_value) or  # ISO
                        re.search(r'CC\d+\.\d+', field_value) or        # SOC 2
                        re.search(r'[A-Z]{2}\.[A-Z]{2}-\d+', field_value) or  # NIST
                        re.search(r'\d+\.\d+', field_value)):           # Requirement ID
                        has_traceability = True
                        break
            
            if has_traceability:
                controls_with_traceability += 1
        
        traceability_ratio = controls_with_traceability / total_controls if total_controls > 0 else 0
        assert traceability_ratio >= 0.8, f"At least 80% of controls should have traceability, got {traceability_ratio:.2%}"
    
    def test_compliance_gap_analysis(self):
        """Test for gaps in compliance coverage."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Define critical security domains that should be covered
        critical_domains = {
            'access_control': ['access', 'authentication', 'authorization', 'identity'],
            'data_protection': ['encryption', 'data', 'protection', 'confidentiality'],
            'logging_monitoring': ['logging', 'monitoring', 'audit', 'detection'],
            'incident_response': ['incident', 'response', 'recovery', 'continuity'],
            'change_management': ['change', 'deployment', 'configuration', 'version'],
            'vulnerability_management': ['vulnerability', 'patch', 'security', 'scanning']
        }
        
        domain_coverage = {}
        
        for domain, keywords in critical_domains.items():
            domain_controls = 0
            
            for control in self.control_matrix:
                control_text = ' '.join(str(v) for v in control.values() if v).lower()
                
                if any(keyword in control_text for keyword in keywords):
                    domain_controls += 1
            
            domain_coverage[domain] = domain_controls
        
        # Each critical domain should have at least some controls
        for domain, count in domain_coverage.items():
            assert count >= 1, f"Critical domain '{domain}' should have at least 1 control, got {count}"
        
        # Overall coverage should be reasonable
        total_domain_controls = sum(domain_coverage.values())
        assert total_domain_controls >= len(critical_domains), f"Should have controls covering all critical domains"
    
    def test_compliance_documentation_references(self):
        """Test that compliance mappings reference proper documentation."""
        if not self.control_matrix:
            pytest.skip("Control matrix not found")
        
        # Check for documentation references in compliance mappings
        doc_references = 0
        
        for control in self.control_matrix:
            evidence_field = control.get('Evidence Artifact', '')
            
            if evidence_field:
                # Look for references to documentation, policies, or procedures
                doc_keywords = ['policy', 'procedure', 'document', 'guide', 'manual', 'standard']
                
                if any(keyword in evidence_field.lower() for keyword in doc_keywords):
                    doc_references += 1
        
        # At least some controls should reference documentation
        doc_ratio = doc_references / len(self.control_matrix) if self.control_matrix else 0
        assert doc_ratio >= 0.3, f"At least 30% of controls should reference documentation, got {doc_ratio:.2%}"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])