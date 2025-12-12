#!/usr/bin/env python3
"""
N8N Workflow Validation Script
Validates n8n workflow JSON for common errors before testing
"""
import json
import re
import sys
from pathlib import Path

def validate_code_node_return(code, node_name):
    """Validate Code node returns proper n8n format"""
    errors = []
    warnings = []

    # Check 1: Has return statement
    if 'return' not in code:
        errors.append(f"{node_name}: No return statement")
        return errors, warnings

    # Check 2: Returns array
    if not re.search(r'return\s*\[', code):
        errors.append(f"{node_name}: Must return an array")
        return errors, warnings

    # Check 3: Has json property
    if not re.search(r'\{\s*json\s*:', code, re.MULTILINE):
        errors.append(f"{node_name}: Objects must have 'json' property")
        return errors, warnings

    # Check 4: json property is an object, not array/string/etc
    # Look for patterns that set json to non-object:
    # BAD: json: allItems (where allItems is array)
    # BAD: json: $input.all()
    # BAD: json: someArray
    # GOOD: json: { key: value }

    # Extract the json property assignment
    json_assignments = re.findall(r'json\s*:\s*([^,}]+)', code)
    for assignment in json_assignments:
        assignment = assignment.strip()

        # Check if it's clearly an object literal
        if assignment.startswith('{'):
            continue  # Good - object literal

        # Check if it's a variable that might be an array
        if any(suspicious in assignment.lower() for suspicious in ['all()', 'items', 'array']):
            warnings.append(f"{node_name}: json property set to '{assignment}' - verify this is an object, not an array")

        # Check if returning allItems directly
        if assignment == 'allItems' and '$input.all()' in code:
            errors.append(f"{node_name}: json property is set to array. Must be object: {{ key: value }}")

    return errors, warnings

def validate_merge_nodes(data):
    """Validate Merge nodes have proper input configuration"""
    errors = []
    warnings = []

    merge_nodes = [n['name'] for n in data['nodes'] if 'merge' in n['type'].lower()]

    for merge_name in merge_nodes:
        inputs = {0: [], 1: []}

        for source, targets in data['connections'].items():
            main_conns = targets.get('main', [[]])[0]
            for conn in main_conns:
                if isinstance(conn, dict) and conn.get('node') == merge_name:
                    idx = conn.get('index', 0)
                    inputs[idx].append(source)

        # Merge needs 2 inputs to create sync point
        if len(inputs[0]) > 0 and len(inputs[1]) > 0:
            pass  # Good - has 2 inputs
        elif len(inputs[0]) > 1 and len(inputs[1]) == 0:
            warnings.append(f"{merge_name}: {len(inputs[0])} sources on input 0, none on input 1 - no sync point")

    return errors, warnings

def validate_workflow(workflow_path):
    """Main validation function"""
    print("="*70)
    print("N8N WORKFLOW VALIDATION")
    print("="*70)
    print()

    try:
        with open(workflow_path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"✗ INVALID JSON: {e}")
        return False

    all_errors = []
    all_warnings = []

    # Validate Code nodes
    print("1. CODE NODE VALIDATION")
    print("-" * 70)
    code_nodes = [n for n in data['nodes'] if n['type'] == 'n8n-nodes-base.code']

    if not code_nodes:
        print("  (No Code nodes found)")

    for node in code_nodes:
        node_name = node['name']
        code = node['parameters'].get('jsCode', '')
        mode = node['parameters'].get('mode', 'runOnceForEachItem')

        print(f"  {node_name}:")
        print(f"    Mode: {mode}")

        errors, warnings = validate_code_node_return(code, node_name)

        if errors:
            for err in errors:
                print(f"    ✗ ERROR: {err}")
                all_errors.append(err)
        elif warnings:
            for warn in warnings:
                print(f"    ⚠ WARNING: {warn}")
                all_warnings.append(warn)
        else:
            print(f"    ✓ Return format valid")

    print()

    # Validate Merge nodes
    print("2. MERGE NODE VALIDATION")
    print("-" * 70)
    errors, warnings = validate_merge_nodes(data)
    all_errors.extend(errors)
    all_warnings.extend(warnings)

    merge_nodes = [n['name'] for n in data['nodes'] if 'merge' in n['type'].lower()]
    if not merge_nodes:
        print("  (No Merge nodes found)")
    else:
        for merge_name in merge_nodes:
            inputs = {0: [], 1: []}
            for source, targets in data['connections'].items():
                main_conns = targets.get('main', [[]])[0]
                for conn in main_conns:
                    if isinstance(conn, dict) and conn.get('node') == merge_name:
                        idx = conn.get('index', 0)
                        inputs[idx].append(source)

            print(f"  {merge_name}:")
            print(f"    Input 0: {', '.join(inputs[0]) if inputs[0] else 'None'}")
            print(f"    Input 1: {', '.join(inputs[1]) if inputs[1] else 'None'}")

            if len(inputs[0]) > 0 and len(inputs[1]) > 0:
                print(f"    ✓ Two inputs - creates sync point")

    print()

    # Summary
    print("="*70)
    print("VALIDATION SUMMARY")
    print("="*70)

    if all_errors:
        print("✗ ERRORS FOUND - DO NOT TEST:")
        for err in all_errors:
            print(f"  • {err}")
        return False
    elif all_warnings:
        print("⚠ WARNINGS:")
        for warn in all_warnings:
            print(f"  • {warn}")
        print("\n⚠ Review warnings - may cause issues")
        return True
    else:
        print("✓ ALL VALIDATIONS PASSED")
        print("✓ Workflow ready to test")
        return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate-n8n-workflow.py <workflow.json>")
        sys.exit(1)

    workflow_path = Path(sys.argv[1])
    if not workflow_path.exists():
        print(f"Error: File not found: {workflow_path}")
        sys.exit(1)

    success = validate_workflow(workflow_path)
    sys.exit(0 if success else 1)
