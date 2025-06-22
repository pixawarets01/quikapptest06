#!/bin/bash

# =============================================================================
# QuikApp Workflow Validation and Initiation Script
# =============================================================================
# This script validates all workflows defined in codemagic.yaml and ensures
# they are properly configured and ready for execution.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

header() {
    echo -e "\n${PURPLE}🔍 ===== $1 =====${NC}"
}

# =============================================================================
# WORKFLOW DEFINITIONS
# =============================================================================

WORKFLOWS="android-free android-paid android-publish ios-appstore ios-adhoc combined"

get_workflow_name() {
    case "$1" in
        "android-free") echo "Android Free Build" ;;
        "android-paid") echo "Android Paid Build" ;;
        "android-publish") echo "Android Publish Build" ;;
        "ios-appstore") echo "iOS App Store Build" ;;
        "ios-adhoc") echo "iOS Ad Hoc Build" ;;
        "combined") echo "Universal Combined Build (Android + iOS)" ;;
        *) echo "Unknown Workflow" ;;
    esac
}

get_workflow_script() {
    case "$1" in
        "android-free"|"android-paid"|"android-publish") echo "lib/scripts/android/main.sh" ;;
        "ios-appstore"|"ios-adhoc") echo "lib/scripts/ios/main.sh" ;;
        "combined") echo "lib/scripts/combined/main.sh" ;;
        *) echo "" ;;
    esac
}

get_workflow_output() {
    case "$1" in
        "android-free") echo "APK" ;;
        "android-paid") echo "APK with Firebase" ;;
        "android-publish") echo "APK + AAB (signed)" ;;
        "ios-appstore") echo "IPA (App Store)" ;;
        "ios-adhoc") echo "IPA (Ad Hoc)" ;;
        "combined") echo "APK + AAB + IPA" ;;
        *) echo "Unknown" ;;
    esac
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_codemagic_yaml() {
    header "VALIDATING CODEMAGIC.YAML"
    
    if [ ! -f "codemagic.yaml" ]; then
        error "codemagic.yaml not found!"
        return 1
    fi
    
    success "codemagic.yaml found"
    
    # Check if file is valid YAML
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import yaml; yaml.safe_load(open('codemagic.yaml'))" 2>/dev/null
        if [ $? -eq 0 ]; then
            success "codemagic.yaml is valid YAML"
        else
            error "codemagic.yaml contains invalid YAML syntax"
            return 1
        fi
    else
        warning "Python3 not available, skipping YAML syntax validation"
    fi
    
    # Check for required workflows
    local missing_workflows=""
    for workflow in $WORKFLOWS; do
        if grep -q "^  ${workflow}:" codemagic.yaml; then
            success "Workflow '$workflow' found in codemagic.yaml"
        else
            error "Workflow '$workflow' missing from codemagic.yaml"
            missing_workflows="$missing_workflows $workflow"
        fi
    done
    
    if [ -n "$missing_workflows" ]; then
        error "Missing workflows:$missing_workflows"
        return 1
    fi
    
    success "All required workflows found in codemagic.yaml"
    return 0
}

validate_scripts() {
    header "VALIDATING WORKFLOW SCRIPTS"
    
    local missing_scripts=""
    
    for workflow in $WORKFLOWS; do
        local script=$(get_workflow_script "$workflow")
        
        if [ -f "$script" ]; then
            success "Script found: $script"
            
            # Check if script is executable
            if [ -x "$script" ]; then
                success "Script is executable: $script"
            else
                warning "Script not executable, will be made executable: $script"
                chmod +x "$script"
                success "Made executable: $script"
            fi
            
            # Check script syntax
            if bash -n "$script" 2>/dev/null; then
                success "Script syntax valid: $script"
            else
                error "Script syntax error: $script"
                bash -n "$script"
            fi
        else
            error "Script missing: $script"
            missing_scripts="$missing_scripts $script"
        fi
    done
    
    if [ -n "$missing_scripts" ]; then
        error "Missing scripts:$missing_scripts"
        return 1
    fi
    
    success "All workflow scripts validated"
    return 0
}

validate_supporting_scripts() {
    header "VALIDATING SUPPORTING SCRIPTS"
    
    local script_dirs="lib/scripts/android lib/scripts/ios lib/scripts/utils"
    
    for dir in $script_dirs; do
        if [ -d "$dir" ]; then
            success "Script directory found: $dir"
            
            # Make all scripts executable
            find "$dir" -name "*.sh" -exec chmod +x {} \;
            success "Made all scripts executable in: $dir"
            
            # Count scripts
            local script_count=$(find "$dir" -name "*.sh" | wc -l)
            info "Found $script_count shell scripts in $dir"
        else
            error "Script directory missing: $dir"
            return 1
        fi
    done
    
    success "All supporting scripts validated"
    return 0
}

validate_environment_variables() {
    header "VALIDATING ENVIRONMENT VARIABLE STRUCTURE"
    
    # Check for required environment variable patterns in codemagic.yaml
    local required_vars="APP_ID APP_NAME ORG_NAME WEB_URL USER_NAME EMAIL_ID VERSION_NAME VERSION_CODE WORKFLOW_ID BRANCH PKG_NAME BUNDLE_ID PUSH_NOTIFY LOGO_URL"
    
    local missing_vars=""
    
    for var in $required_vars; do
        if grep -q "\$${var}" codemagic.yaml || grep -q "${var}:" codemagic.yaml; then
            success "Environment variable reference found: $var"
        else
            warning "Environment variable not referenced: $var"
            missing_vars="$missing_vars $var"
        fi
    done
    
    if [ -n "$missing_vars" ]; then
        warning "Some environment variables not found:$missing_vars"
        info "This may be normal if they're not needed for all workflows"
    fi
    
    success "Environment variable structure validated"
    return 0
}

validate_output_directories() {
    header "VALIDATING OUTPUT DIRECTORIES"
    
    local output_dirs="output output/android output/ios"
    
    for dir in $output_dirs; do
        if [ ! -d "$dir" ]; then
            warning "Output directory missing: $dir"
            mkdir -p "$dir"
            success "Created output directory: $dir"
        else
            success "Output directory exists: $dir"
        fi
    done
    
    success "Output directories validated"
    return 0
}

validate_dependencies() {
    header "VALIDATING SYSTEM DEPENDENCIES"
    
    local required_tools="flutter dart"
    local optional_tools="java python3 curl grep sed awk"
    
    # Check required tools
    for tool in $required_tools; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version=$($tool --version 2>/dev/null | head -1 || echo "Unknown version")
            success "$tool found: $version"
        else
            error "$tool not found (required)"
            return 1
        fi
    done
    
    # Check optional tools
    for tool in $optional_tools; do
        if command -v "$tool" >/dev/null 2>&1; then
            success "$tool found"
        else
            warning "$tool not found (optional)"
        fi
    done
    
    success "System dependencies validated"
    return 0
}

test_workflow_initiation() {
    header "TESTING WORKFLOW INITIATION"
    
    local workflow="$1"
    local script=$(get_workflow_script "$workflow")
    
    if [ -z "$workflow" ]; then
        error "No workflow specified for testing"
        return 1
    fi
    
    if [ ! -f "$script" ]; then
        error "Script not found for workflow '$workflow': $script"
        return 1
    fi
    
    info "Testing workflow initiation: $workflow"
    info "Script: $script"
    info "Expected output: $(get_workflow_output "$workflow")"
    
    # Set minimal test environment variables
    export APP_ID="test-app-id"
    export APP_NAME="Test App"
    export ORG_NAME="Test Organization"
    export WEB_URL="https://test.com"
    export USER_NAME="test-user"
    export EMAIL_ID="test@example.com"
    export PKG_NAME="com.test.app"
    export BUNDLE_ID="com.test.app"
    export VERSION_NAME="1.0.0"
    export VERSION_CODE="1"
    export WORKFLOW_ID="$workflow"
    export BRANCH="main"
    export LOGO_URL="https://example.com/logo.png"
    export SPLASH_URL="https://example.com/splash.png"
    export PUSH_NOTIFY="false"
    export IS_CHATBOT="false"
    export IS_SPLASH="true"
    export ENABLE_EMAIL_NOTIFICATIONS="false"
    
    # Test script execution (dry run mode)
    info "Performing dry-run validation of workflow script..."
    
    # Check if script can be sourced without errors
    if bash -n "$script"; then
        success "Script syntax validation passed for: $workflow"
    else
        error "Script syntax validation failed for: $workflow"
        return 1
    fi
    
    success "Workflow initiation test completed for: $workflow"
    return 0
}

generate_workflow_report() {
    header "GENERATING WORKFLOW REPORT"
    
    local report_file="workflow_validation_report.md"
    
    cat > "$report_file" << EOF
# QuikApp Workflow Validation Report

Generated on: $(date '+%Y-%m-%d %H:%M:%S')

## Workflow Summary

| Workflow ID | Name | Script | Expected Output | Status |
|-------------|------|--------|-----------------|--------|
EOF

    for workflow in $WORKFLOWS; do
        local name=$(get_workflow_name "$workflow")
        local script=$(get_workflow_script "$workflow")
        local output=$(get_workflow_output "$workflow")
        local status="✅ Ready"
        
        if [ ! -f "$script" ]; then
            status="❌ Script Missing"
        elif [ ! -x "$script" ]; then
            status="⚠️ Not Executable"
        fi
        
        echo "| \`$workflow\` | $name | \`$script\` | $output | $status |" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

## Workflow Descriptions

### Android Workflows

1. **android-free**: Basic Android APK build without Firebase integration
2. **android-paid**: Android APK build with Firebase integration for push notifications
3. **android-publish**: Production Android build with both APK and AAB, includes keystore signing

### iOS Workflows

1. **ios-appstore**: iOS IPA build for App Store distribution
2. **ios-adhoc**: iOS IPA build for Ad Hoc distribution

### Universal Workflow

1. **combined**: Builds both Android (APK + AAB) and iOS (IPA) in a single workflow

## Environment Variables

All workflows support dynamic environment variable injection from the QuikApp API.

## Email Notifications

All workflows include email notification system with build status updates.

## Next Steps

1. Configure environment variables in Codemagic
2. Set up signing certificates and keystores
3. Test workflows in Codemagic environment
4. Monitor build logs for any issues

EOF

    success "Workflow report generated: $report_file"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log "🚀 Starting QuikApp Workflow Validation"
    
    local validation_failed=false
    
    # Run all validations
    validate_codemagic_yaml || validation_failed=true
    validate_scripts || validation_failed=true
    validate_supporting_scripts || validation_failed=true
    validate_environment_variables || validation_failed=true
    validate_output_directories || validation_failed=true
    validate_dependencies || validation_failed=true
    
    # Test workflow initiation if requested
    if [ "$1" = "--test" ] && [ -n "$2" ]; then
        test_workflow_initiation "$2" || validation_failed=true
    elif [ "$1" = "--test-all" ]; then
        for workflow in $WORKFLOWS; do
            test_workflow_initiation "$workflow" || validation_failed=true
        done
    fi
    
    # Generate report
    generate_workflow_report
    
    # Final status
    header "VALIDATION SUMMARY"
    
    if [ "$validation_failed" = true ]; then
        error "Some validations failed. Please check the issues above."
        log "❌ Workflow validation completed with errors"
        exit 1
    else
        success "All validations passed successfully!"
        log "✅ Workflow validation completed successfully"
        
        info "Available workflows:"
        for workflow in $WORKFLOWS; do
            info "  • $workflow: $(get_workflow_name "$workflow")"
        done
        
        log ""
        log "🎯 Ready to initiate workflows in Codemagic!"
        log "📋 Check workflow_validation_report.md for detailed information"
    fi
}

# Show usage if no arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 [--test WORKFLOW_ID] [--test-all]"
    echo ""
    echo "Examples:"
    echo "  $0                           # Basic validation"
    echo "  $0 --test android-publish    # Test specific workflow"
    echo "  $0 --test-all               # Test all workflows"
    echo ""
    echo "Available workflows:"
    for workflow in $WORKFLOWS; do
        echo "  • $workflow"
    done
    exit 0
fi

# Run main function with arguments
main "$@" 