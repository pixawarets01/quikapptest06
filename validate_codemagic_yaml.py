#!/usr/bin/env python3
"""
Codemagic YAML Validation Script
Validates the codemagic_optimized.yaml file for proper variable definitions
"""

import yaml
import sys
import re
from typing import Dict, List, Any

def load_yaml_file(file_path: str) -> Dict[str, Any]:
    """Load and parse YAML file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            return yaml.safe_load(file)
    except Exception as e:
        print(f"❌ Error loading YAML file: {e}")
        sys.exit(1)

def extract_variables_from_yaml(yaml_content: Dict[str, Any]) -> List[str]:
    """Extract all variable references from YAML content"""
    variables = []
    
    def extract_vars_from_value(value):
        if isinstance(value, str):
            # Find all $VARIABLE_NAME patterns
            matches = re.findall(r'\$([A-Z_][A-Z0-9_]*)', value)
            variables.extend(matches)
        elif isinstance(value, dict):
            for v in value.values():
                extract_vars_from_value(v)
        elif isinstance(value, list):
            for item in value:
                extract_vars_from_value(item)
    
    extract_vars_from_value(yaml_content)
    return list(set(variables))  # Remove duplicates

def validate_workflow_variables(workflows: Dict[str, Any]) -> Dict[str, List[str]]:
    """Validate that all workflows have required variables defined"""
    issues = {}
    
    for workflow_name, workflow_config in workflows.items():
        if 'environment' in workflow_config and 'vars' in workflow_config['environment']:
            vars_section = workflow_config['environment']['vars']
            
            # Check for common issues
            workflow_issues = []
            
            # Check if Firebase variables are properly handled
            if workflow_name == 'android-free':
                if 'FIREBASE_CONFIG_ANDROID' not in vars_section:
                    workflow_issues.append("Missing FIREBASE_CONFIG_ANDROID (should be empty string)")
                elif vars_section.get('FIREBASE_CONFIG_ANDROID') != "":
                    workflow_issues.append("FIREBASE_CONFIG_ANDROID should be empty string for free workflow")
            
            elif workflow_name in ['android-paid', 'android-publish', 'combined']:
                if 'FIREBASE_CONFIG_ANDROID' not in vars_section:
                    workflow_issues.append("Missing FIREBASE_CONFIG_ANDROID")
            
            if workflow_name in ['ios-workflow', 'combined']:
                if 'FIREBASE_CONFIG_IOS' not in vars_section:
                    workflow_issues.append("Missing FIREBASE_CONFIG_IOS")
            
            # Check for required workflow-specific variables
            if workflow_name in ['android-free', 'android-paid', 'android-publish', 'combined']:
                if 'PKG_NAME' not in vars_section:
                    workflow_issues.append("Missing PKG_NAME")
            
            if workflow_name in ['ios-workflow', 'combined']:
                if 'BUNDLE_ID' not in vars_section:
                    workflow_issues.append("Missing BUNDLE_ID")
            
            if workflow_issues:
                issues[workflow_name] = workflow_issues
    
    return issues

def main():
    """Main validation function"""
    print("🔍 Validating codemagic_optimized.yaml...")
    
    # Load YAML file
    yaml_content = load_yaml_file('codemagic_optimized.yaml')
    
    # Extract all variable references
    variables = extract_variables_from_yaml(yaml_content)
    print(f"📊 Found {len(variables)} unique variable references")
    
    # Validate workflows
    if 'workflows' in yaml_content:
        workflow_issues = validate_workflow_variables(yaml_content['workflows'])
        
        if workflow_issues:
            print("\n❌ Validation Issues Found:")
            for workflow, issues in workflow_issues.items():
                print(f"\n  {workflow}:")
                for issue in issues:
                    print(f"    - {issue}")
        else:
            print("\n✅ No validation issues found!")
    
    # Check for common patterns
    print("\n📋 Variable Categories Found:")
    categories = {
        'Firebase': [v for v in variables if 'FIREBASE' in v],
        'Android': [v for v in variables if 'ANDROID' in v or 'PKG_NAME' in v],
        'iOS': [v for v in variables if 'IOS' in v or 'BUNDLE_ID' in v or 'APPLE' in v or 'CERT' in v or 'PROFILE' in v],
        'UI': [v for v in variables if 'SPLASH' in v or 'LOGO' in v or 'BOTTOMMENU' in v],
        'Permissions': [v for v in variables if v.startswith('IS_') and v not in ['IS_TESTFLIGHT']],
        'Email': [v for v in variables if 'EMAIL' in v],
        'Other': [v for v in variables if not any(keyword in v for keyword in ['FIREBASE', 'ANDROID', 'IOS', 'SPLASH', 'LOGO', 'BOTTOMMENU', 'IS_', 'EMAIL'])]
    }
    
    for category, vars_list in categories.items():
        if vars_list:
            print(f"  {category}: {len(vars_list)} variables")
    
    print("\n✅ YAML validation completed!")

if __name__ == "__main__":
    main() 