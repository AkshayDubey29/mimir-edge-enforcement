#!/bin/bash

# Mimir Edge Enforcement - Documentation Consolidation Script
# This script consolidates all markdown files into a single comprehensive document

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_FILE="MIMIR_EDGE_ENFORCEMENT_COMPREHENSIVE_DOCUMENTATION.md"
TEMP_FILE="temp_consolidated.md"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Function to add section header
add_section() {
    local title="$1"
    local level="$2"
    local prefix=""
    
    for ((i=0; i<level; i++)); do
        prefix="$prefix#"
    done
    
    echo "" >> "$TEMP_FILE"
    echo "$prefix $title" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
}

# Function to process a markdown file
process_file() {
    local file="$1"
    local section_title="$2"
    local level="$3"
    
    if [[ -f "$file" ]]; then
        print_status "Processing: $file"
        
        # Add section header
        add_section "$section_title" "$level"
        
        # Add file content (skip the first line if it's a title)
        if [[ "$(head -n1 "$file")" =~ ^#\ .* ]]; then
            # Skip the first line (title) and add the rest
            tail -n +2 "$file" >> "$TEMP_FILE"
        else
            # Add the entire file
            cat "$file" >> "$TEMP_FILE"
        fi
        
        echo "" >> "$TEMP_FILE"
        echo "---" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
    else
        print_warning "File not found: $file"
    fi
}

# Function to create table of contents
create_toc() {
    print_status "Creating table of contents..."
    
    cat > "$TEMP_FILE" << 'EOF'
# Mimir Edge Enforcement - Comprehensive Documentation

## Table of Contents

### 📋 Executive Summary
- [Executive Summary](#executive-summary)
- [Business Value](#business-value)
- [Problem Statement](#problem-statement)

### 🏗️ Architecture & Design
- [System Architecture](#system-architecture)
- [Component Architecture](#component-architecture)
- [Data Flow Diagrams](#data-flow-diagrams)
- [Network Architecture](#network-architecture)

### 🔧 Components Deep Dive
- [Rate Limit Service (RLS)](#rate-limit-service-rls)
- [Envoy Proxy](#envoy-proxy)
- [Overrides-Sync Controller](#overrides-sync-controller)
- [Admin UI](#admin-ui)

### ✨ Features & Capabilities
- [Core Features](#core-features)
- [Advanced Features](#advanced-features)
- [Selective Traffic Routing](#selective-traffic-routing)
- [Time-Based Aggregation](#time-based-aggregation)

### 🚀 Deployment & Operations
- [Deployment Strategy](#deployment-strategy)
- [Production Deployment](#production-deployment)
- [Scaling Strategy](#scaling-strategy)
- [Rollback Procedures](#rollback-procedures)

### 📊 Monitoring & Observability
- [Monitoring Strategy](#monitoring-strategy)
- [Metrics & Dashboards](#metrics--dashboards)
- [Alerting Strategy](#alerting-strategy)
- [Logging Strategy](#logging-strategy)

### 🔒 Security & Compliance
- [Security Architecture](#security-architecture)
- [Network Security](#network-security)
- [Container Security](#container-security)
- [Compliance](#compliance)

### ⚡ Performance & Scalability
- [Performance Characteristics](#performance-characteristics)
- [Scalability Analysis](#scalability-analysis)
- [Bottleneck Analysis](#bottleneck-analysis)
- [Load Testing Results](#load-testing-results)

### 🛠️ API Reference
- [API Overview](#api-overview)
- [REST API Reference](#rest-api-reference)
- [gRPC API Reference](#grpc-api-reference)
- [API Examples](#api-examples)

### 💻 Code Examples
- [Backend Code Examples](#backend-code-examples)
- [Frontend Code Examples](#frontend-code-examples)
- [Configuration Examples](#configuration-examples)
- [Kubernetes Manifests](#kubernetes-manifests)

### 🔧 Troubleshooting
- [Common Issues](#common-issues)
- [Debug Procedures](#debug-procedures)
- [Performance Troubleshooting](#performance-troubleshooting)
- [Recovery Procedures](#recovery-procedures)

### 🚀 Future Enhancements
- [Roadmap](#roadmap)
- [Feature Requests](#feature-requests)
- [Technical Debt](#technical-debt)
- [Architecture Evolution](#architecture-evolution)

---

## Document Information

- **Version**: 1.0
- **Last Updated**: January 2024
- **Maintainer**: Development Team
- **Review Cycle**: Quarterly
- **Update Process**: Pull request workflow

---

EOF
}

# Main execution
main() {
    print_header "Starting documentation consolidation..."
    
    # Check if we're in the right directory
    if [[ ! -f "README.md" ]]; then
        print_error "Please run this script from the design-documentation directory"
        exit 1
    fi
    
    # Create temporary file
    create_toc
    
    print_status "Consolidating documentation files..."
    
    # Executive Summary
    process_file "executive-summary.md" "Executive Summary" 2
    process_file "business-value.md" "Business Value" 2
    process_file "problem-statement.md" "Problem Statement" 2
    
    # Architecture & Design
    process_file "architecture/system-architecture.md" "System Architecture" 2
    process_file "architecture/component-architecture.md" "Component Architecture" 2
    process_file "architecture/data-flow-diagrams.md" "Data Flow Diagrams" 2
    process_file "architecture/network-architecture.md" "Network Architecture" 2
    
    # Components Deep Dive
    process_file "components/rate-limit-service.md" "Rate Limit Service (RLS)" 2
    process_file "components/envoy-proxy.md" "Envoy Proxy" 2
    process_file "components/overrides-sync-controller.md" "Overrides-Sync Controller" 2
    process_file "components/admin-ui.md" "Admin UI" 2
    
    # Features & Capabilities
    process_file "features/core-features.md" "Core Features" 2
    process_file "features/advanced-features.md" "Advanced Features" 2
    process_file "features/selective-traffic-routing.md" "Selective Traffic Routing" 2
    process_file "features/time-based-aggregation.md" "Time-Based Aggregation" 2
    
    # Deployment & Operations
    process_file "deployment/deployment-strategy.md" "Deployment Strategy" 2
    process_file "deployment/production-deployment.md" "Production Deployment" 2
    process_file "deployment/scaling-strategy.md" "Scaling Strategy" 2
    process_file "deployment/rollback-procedures.md" "Rollback Procedures" 2
    
    # Monitoring & Observability
    process_file "monitoring/monitoring-strategy.md" "Monitoring Strategy" 2
    process_file "monitoring/metrics-dashboards.md" "Metrics & Dashboards" 2
    process_file "monitoring/alerting-strategy.md" "Alerting Strategy" 2
    process_file "monitoring/logging-strategy.md" "Logging Strategy" 2
    
    # Security & Compliance
    process_file "security/security-architecture.md" "Security Architecture" 2
    process_file "security/network-security.md" "Network Security" 2
    process_file "security/container-security.md" "Container Security" 2
    process_file "security/compliance.md" "Compliance" 2
    
    # Performance & Scalability
    process_file "performance/performance-characteristics.md" "Performance Characteristics" 2
    process_file "performance/scalability-analysis.md" "Scalability Analysis" 2
    process_file "performance/bottleneck-analysis.md" "Bottleneck Analysis" 2
    process_file "performance/load-testing-results.md" "Load Testing Results" 2
    
    # API Reference
    process_file "api-reference/api-overview.md" "API Overview" 2
    process_file "api-reference/rest-api-reference.md" "REST API Reference" 2
    process_file "api-reference/grpc-api-reference.md" "gRPC API Reference" 2
    process_file "api-reference/api-examples.md" "API Examples" 2
    
    # Code Examples
    process_file "code-examples/backend-examples.md" "Backend Code Examples" 2
    process_file "code-examples/frontend-examples.md" "Frontend Code Examples" 2
    process_file "code-examples/configuration-examples.md" "Configuration Examples" 2
    process_file "code-examples/kubernetes-manifests.md" "Kubernetes Manifests" 2
    
    # Troubleshooting
    process_file "troubleshooting/common-issues.md" "Common Issues" 2
    process_file "troubleshooting/debug-procedures.md" "Debug Procedures" 2
    process_file "troubleshooting/performance-troubleshooting.md" "Performance Troubleshooting" 2
    process_file "troubleshooting/recovery-procedures.md" "Recovery Procedures" 2
    
    # Future Enhancements
    process_file "future-enhancements/roadmap.md" "Roadmap" 2
    process_file "future-enhancements/feature-requests.md" "Feature Requests" 2
    process_file "future-enhancements/technical-debt.md" "Technical Debt" 2
    process_file "future-enhancements/architecture-evolution.md" "Architecture Evolution" 2
    
    # Add footer
    cat >> "$TEMP_FILE" << 'EOF'

## Conclusion

This comprehensive documentation provides a complete overview of the Mimir Edge Enforcement system, covering all aspects from architecture and design to deployment and operations. The documentation is designed to serve multiple stakeholders including leadership, architects, developers, and operations engineers.

For questions or contributions, please contact the development team or submit a pull request to update this documentation.

---

**Document Version**: 1.0  
**Last Updated**: January 2024  
**Maintainer**: Development Team  
**License**: Apache-2.0

EOF
    
    # Move temporary file to final location
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    
    print_status "Documentation consolidation complete!"
    print_status "Output file: $OUTPUT_FILE"
    
    # Show file statistics
    local line_count=$(wc -l < "$OUTPUT_FILE")
    local word_count=$(wc -w < "$OUTPUT_FILE")
    local char_count=$(wc -c < "$OUTPUT_FILE")
    
    print_status "Document statistics:"
    echo "  - Lines: $line_count"
    echo "  - Words: $word_count"
    echo "  - Characters: $char_count"
    
    print_status "You can now convert this markdown file to Word format using:"
    echo "  - Pandoc: pandoc $OUTPUT_FILE -o Mimir_Edge_Enforcement_Documentation.docx"
    echo "  - Online converters: Copy the content to a markdown-to-word converter"
    echo "  - Microsoft Word: Open the .md file directly in Word"
}

# Run main function
main "$@"
