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


## Executive Summary


## Overview

**Mimir Edge Enforcement** is a production-ready, cloud-agnostic Kubernetes solution that enforces Mimir tenant ingestion limits at the edge using Envoy, a Rate/Authorization Service (RLS), an overrides-sync controller, and a React Admin UI.

## Business Problem

Traditional Mimir deployments lack tenant-level enforcement at the edge, leading to:
- **Resource Exhaustion**: Abusive tenants consuming disproportionate resources
- **Unfair Resource Allocation**: No mechanism to enforce contractual limits
- **Operational Challenges**: Difficulty in monitoring and controlling tenant behavior
- **Cost Overruns**: Uncontrolled resource consumption impacting infrastructure costs

## Solution Overview

### High-Level Architecture
```
Alloy → NGINX → Envoy → Mimir Distributor
              ↓
           RLS (ext_authz + ratelimit)
              ↓
        overrides-sync (watches ConfigMap)
              ↓
         Admin UI (monitoring & controls)
```

### Key Components
1. **Rate Limit Service (RLS)**: Core enforcement engine with gRPC and HTTP APIs
2. **Envoy Proxy**: Edge proxy with external authorization and rate limiting filters
3. **Overrides-Sync Controller**: Kubernetes controller for dynamic limit management
4. **Admin UI**: React-based web interface for monitoring and management

## Business Value

### 🎯 **Cost Control**
- Prevents tenant abuse and resource exhaustion
- Enforces fair resource allocation based on contracts
- Reduces infrastructure costs through controlled consumption

### 🛡️ **Service Protection**
- Ensures system stability under high load
- Protects against tenant misbehavior
- Maintains service quality for all tenants

### 📊 **Operational Excellence**
- Real-time monitoring and alerting
- Comprehensive dashboards and metrics
- Proactive issue detection and resolution

### 🔄 **Zero Disruption**
- Bump-in-the-wire deployment
- No client application changes required
- Instant rollback capability

## Technical Highlights

### **Zero Client Changes**
- Deployed behind existing NGINX infrastructure
- No application modifications required
- Instant rollback via NGINX reload

### **Accurate Enforcement**
- Real-time tenant limit enforcement
- Protobuf parsing for precise metrics
- Token bucket algorithm for rate limiting

### **Observability-First**
- Comprehensive Prometheus metrics
- Structured JSON logging
- Real-time dashboards and alerting

### **Production-Ready**
- High availability with multiple replicas
- Horizontal scaling with auto-scaling
- Security hardening and RBAC

## Deployment Strategy

### **Phase 1: Mirror Mode (Zero Impact)**
- Shadow traffic to validate system
- No user-visible impact
- Metrics and monitoring validation

### **Phase 2: Canary Mode (Gradual Rollout)**
- Weighted traffic splitting (1% → 100%)
- Controlled rollout with monitoring
- Performance validation

### **Phase 3: Full Mode (Complete Deployment)**
- All traffic through enforcement
- Full tenant limit enforcement
- Production monitoring and alerting

## Performance Characteristics

### **Latency Impact**
- Total overhead: ~2-8ms per request
- ext_authz: ~1-5ms additional latency
- Body parsing: ~0.5-2ms for typical requests

### **Throughput**
- RLS: 10,000+ requests/second per instance
- Envoy: 50,000+ requests/second per instance
- Horizontal scaling: 10-40 replicas per service

### **Resource Usage**
- Memory: ~100-500MB per RLS instance
- CPU: ~0.1-1 CPU core per RLS instance
- Network: Minimal overhead for control plane

## Success Metrics

### **Operational Metrics**
- 99.9% system uptime
- <10ms average latency impact
- Zero client-side changes required
- <5 minute rollback capability

### **Business Metrics**
- 100% tenant limit enforcement
- 50% reduction in resource abuse
- 30% improvement in system stability
- 25% reduction in infrastructure costs

## Risk Mitigation

### **Technical Risks**
- **Service Failure**: Configurable failure modes (allow/deny)
- **Performance Impact**: Comprehensive load testing and monitoring
- **Data Loss**: In-memory state with optional Redis persistence

### **Operational Risks**
- **Rollout Issues**: Gradual deployment with rollback capability
- **Monitoring Gaps**: Comprehensive observability and alerting
- **Security Concerns**: Security hardening and RBAC implementation

## Investment Summary

### **Development Effort**
- **Phase 1**: 2-3 months (Core development)
- **Phase 2**: 1-2 months (Testing and refinement)
- **Phase 3**: 1 month (Production deployment)

### **Infrastructure Costs**
- **Development**: Minimal (uses existing infrastructure)
- **Production**: ~$5K-10K/month for high-scale deployment
- **ROI**: 3-6 month payback period

### **Operational Costs**
- **Maintenance**: 0.5 FTE for ongoing operations
- **Monitoring**: Integrated with existing monitoring stack
- **Support**: Self-service with comprehensive documentation

## Competitive Advantages

### **Technical Advantages**
- Zero client changes required
- Real-time enforcement with sub-10ms latency
- Comprehensive observability and monitoring
- Production-ready with enterprise features

### **Operational Advantages**
- Gradual deployment with zero risk
- Instant rollback capability
- Self-service management interface
- Comprehensive troubleshooting tools

### **Business Advantages**
- Immediate cost savings through resource control
- Improved system stability and reliability
- Enhanced tenant experience and fairness
- Reduced operational overhead

## Next Steps

### **Immediate Actions (Next 30 Days)**
1. **Architecture Review**: Technical deep-dive with architecture team
2. **Proof of Concept**: Deploy in development environment
3. **Performance Testing**: Validate performance characteristics
4. **Security Review**: Security assessment and hardening

### **Short-term Goals (Next 90 Days)**
1. **Production Deployment**: Phase 1 mirror mode deployment
2. **Monitoring Setup**: Comprehensive monitoring and alerting
3. **Team Training**: Operations team training and documentation
4. **Performance Optimization**: Fine-tune based on real-world usage

### **Long-term Vision (Next 6-12 Months)**
1. **Full Production**: Complete deployment across all environments
2. **Feature Enhancement**: Advanced features and capabilities
3. **Scale Optimization**: Performance and scalability improvements
4. **Integration Expansion**: Additional integrations and use cases

## Conclusion

Mimir Edge Enforcement provides a comprehensive, production-ready solution for enforcing tenant ingestion limits at the edge. With its zero-client-change deployment model, comprehensive monitoring, and safe rollout strategies, it enables organizations to protect their Mimir infrastructure while maintaining operational excellence.

The solution delivers immediate business value through cost control, service protection, and operational excellence, with a clear path to production deployment and long-term success.

---

**Recommendation**: Proceed with architecture review and proof of concept deployment to validate the solution in our environment.

**Contact**: Development Team  
**Next Review**: Architecture Review Meeting

---


## Business Value


## Executive Summary

The Mimir Edge Enforcement system delivers significant business value through cost control, service protection, operational excellence, and competitive advantage. This document outlines the quantifiable benefits and return on investment (ROI) for implementing the solution.

## Business Problem & Impact

### Current Challenges

#### Resource Exhaustion
- **Problem**: Abusive tenants consuming disproportionate infrastructure resources
- **Impact**: 30-50% of infrastructure costs wasted on resource abuse
- **Risk**: Service degradation for legitimate tenants

#### Unfair Resource Allocation
- **Problem**: No mechanism to enforce contractual limits
- **Impact**: Inability to monetize resource usage effectively
- **Risk**: Revenue leakage and customer dissatisfaction

#### Operational Overhead
- **Problem**: Manual monitoring and intervention required
- **Impact**: 20-30% of operations team time spent on resource management
- **Risk**: Increased operational costs and reduced efficiency

#### Compliance Risk
- **Problem**: No audit trail for resource usage
- **Impact**: Difficulty in enforcing SLAs and contracts
- **Risk**: Legal and compliance issues

## Solution Benefits

### 🎯 Cost Control & Revenue Protection

#### Infrastructure Cost Reduction
- **Resource Abuse Prevention**: 40-60% reduction in wasted infrastructure costs
- **Fair Resource Allocation**: Enables per-tenant resource billing
- **Predictable Costs**: Better capacity planning and budgeting

#### Revenue Protection
- **Contractual Enforcement**: Ensures tenants pay for actual usage
- **Overage Billing**: Enables billing for resource overages
- **Revenue Recovery**: 15-25% increase in revenue through proper billing

#### Quantified Savings
```
Annual Infrastructure Cost: $2,000,000
Resource Abuse Reduction: 40% = $800,000 savings
Revenue Recovery: 20% = $400,000 additional revenue
Total Annual Benefit: $1,200,000
```

### 🛡️ Service Protection & Reliability

#### System Stability
- **Prevents Resource Exhaustion**: Ensures system stability under load
- **Fair Resource Distribution**: All tenants get their fair share
- **Predictable Performance**: Consistent service quality

#### SLA Compliance
- **Enforced Limits**: Guarantees resource availability
- **Performance Monitoring**: Real-time performance tracking
- **Proactive Alerts**: Early warning of potential issues

#### Quantified Benefits
```
System Uptime Improvement: 99.9% → 99.95% = 0.05% improvement
Customer Satisfaction: 85% → 95% = 10% improvement
Support Ticket Reduction: 30% reduction in resource-related issues
```

### 📊 Operational Excellence

#### Automation & Efficiency
- **Zero Manual Intervention**: Automated enforcement and monitoring
- **Real-time Visibility**: Comprehensive dashboards and metrics
- **Proactive Management**: Early detection and resolution of issues

#### Team Productivity
- **Reduced Operational Overhead**: 60-80% reduction in manual monitoring
- **Focused Engineering**: Teams can focus on core product development
- **Improved Response Time**: Faster issue detection and resolution

#### Quantified Benefits
```
Operations Team Size: 5 engineers
Time Saved per Engineer: 20 hours/week
Annual Time Savings: 5 × 20 × 52 = 5,200 hours
Cost Savings: 5,200 × $100/hour = $520,000
```

### 🔄 Zero Disruption Deployment

#### Risk Mitigation
- **Zero Client Changes**: No application modifications required
- **Instant Rollback**: 5-minute emergency rollback capability
- **Gradual Rollout**: Phased deployment with monitoring

#### Business Continuity
- **No Service Interruption**: Zero downtime deployment
- **Continuous Monitoring**: Real-time validation during rollout
- **Risk-Free Testing**: Shadow mode validation

#### Quantified Benefits
```
Deployment Risk Reduction: 90% reduction in deployment risks
Rollback Time: 5 minutes vs. traditional 2-4 hours
Testing Confidence: 100% validation before production impact
```

## Return on Investment (ROI)

### Investment Costs

#### Development Costs
- **Phase 1 (Core Development)**: 2-3 months × 3 engineers = 18-27 person-months
- **Phase 2 (Testing & Refinement)**: 1-2 months × 2 engineers = 2-4 person-months
- **Phase 3 (Production Deployment)**: 1 month × 2 engineers = 2 person-months
- **Total Development**: 22-33 person-months × $15,000/month = $330,000 - $495,000

#### Infrastructure Costs
- **Development Environment**: $2,000/month × 3 months = $6,000
- **Staging Environment**: $5,000/month × 2 months = $10,000
- **Production Environment**: $8,000/month × 12 months = $96,000
- **Total Infrastructure**: $112,000/year

#### Operational Costs
- **Ongoing Maintenance**: 0.5 FTE × $120,000/year = $60,000
- **Monitoring & Support**: $24,000/year
- **Total Operational**: $84,000/year

#### Total Investment
```
Development: $412,500 (average)
Infrastructure: $112,000
Operations: $84,000
Total First Year: $608,500
Annual Ongoing: $196,000
```

### Return on Investment

#### First Year ROI
```
Total Investment: $608,500
Annual Benefits: $1,200,000 (cost savings) + $520,000 (operations) = $1,720,000
Net Benefit: $1,720,000 - $608,500 = $1,111,500
ROI: ($1,111,500 / $608,500) × 100 = 183%
```

#### 3-Year ROI
```
Total Investment: $608,500 + ($196,000 × 2) = $1,000,500
Total Benefits: $1,720,000 × 3 = $5,160,000
Net Benefit: $5,160,000 - $1,000,500 = $4,159,500
ROI: ($4,159,500 / $1,000,500) × 100 = 416%
```

#### Payback Period
```
Monthly Benefits: $1,720,000 / 12 = $143,333
Payback Period: $608,500 / $143,333 = 4.2 months
```

## Competitive Advantages

### Technical Advantages

#### Zero Client Changes
- **Market Differentiation**: No other solution offers zero-impact deployment
- **Customer Adoption**: Faster customer onboarding and adoption
- **Risk Reduction**: Eliminates deployment risks and customer concerns

#### Real-time Enforcement
- **Performance**: Sub-10ms latency impact
- **Accuracy**: Precise resource measurement and enforcement
- **Scalability**: Handles 10,000+ requests/second per instance

#### Comprehensive Observability
- **Visibility**: Real-time monitoring and alerting
- **Analytics**: Detailed usage analytics and insights
- **Compliance**: Complete audit trail and reporting

### Business Advantages

#### Revenue Optimization
- **Usage-Based Billing**: Enables per-tenant resource billing
- **Overage Management**: Automatic detection and billing of overages
- **Revenue Recovery**: Recovers lost revenue from resource abuse

#### Customer Experience
- **Fair Resource Allocation**: Ensures all customers get their fair share
- **Predictable Performance**: Consistent service quality
- **Transparent Billing**: Clear resource usage and billing

#### Operational Efficiency
- **Automation**: Reduces manual operational overhead
- **Proactive Management**: Early detection and resolution of issues
- **Scalable Operations**: Supports growth without proportional operational cost increase

## Risk Mitigation

### Technical Risks

#### Service Failure
- **Risk**: RLS or Envoy service failure
- **Mitigation**: Configurable failure modes (allow/deny)
- **Impact**: Minimal service disruption
- **Cost**: $0 (built-in redundancy)

#### Performance Impact
- **Risk**: High latency or throughput degradation
- **Mitigation**: Comprehensive load testing and monitoring
- **Impact**: <10ms latency impact
- **Cost**: $50,000 (testing and optimization)

#### Configuration Errors
- **Risk**: Incorrect tenant limits or enforcement rules
- **Mitigation**: Configuration validation and testing
- **Impact**: Minimal with proper testing
- **Cost**: $25,000 (validation and testing)

### Business Risks

#### Deployment Issues
- **Risk**: Failed deployment or configuration
- **Mitigation**: Gradual rollout with rollback capability
- **Impact**: Zero with proper procedures
- **Cost**: $0 (built-in rollback)

#### Customer Impact
- **Risk**: Negative impact on customer experience
- **Mitigation**: Zero-impact deployment and monitoring
- **Impact**: Positive (improved service quality)
- **Cost**: $0 (improved experience)

#### Compliance Issues
- **Risk**: Regulatory or compliance violations
- **Mitigation**: Comprehensive audit trail and reporting
- **Impact**: Improved compliance posture
- **Cost**: $0 (enhanced compliance)

## Success Metrics

### Financial Metrics

#### Cost Savings
- **Infrastructure Cost Reduction**: 40-60% reduction in wasted costs
- **Operational Cost Reduction**: 60-80% reduction in manual overhead
- **Revenue Recovery**: 15-25% increase in revenue through proper billing

#### ROI Metrics
- **First Year ROI**: 183%
- **3-Year ROI**: 416%
- **Payback Period**: 4.2 months

### Operational Metrics

#### System Performance
- **Uptime**: 99.95% (improvement from 99.9%)
- **Latency Impact**: <10ms additional latency
- **Throughput**: 10,000+ requests/second per instance

#### Customer Experience
- **Customer Satisfaction**: 95% (improvement from 85%)
- **Support Tickets**: 30% reduction in resource-related issues
- **Service Quality**: Consistent performance across all tenants

### Business Metrics

#### Revenue Impact
- **Resource Billing**: 100% of tenants properly billed
- **Overage Recovery**: 90% of overages detected and billed
- **Revenue Growth**: 20% increase in resource-related revenue

#### Operational Efficiency
- **Team Productivity**: 60-80% reduction in manual monitoring
- **Response Time**: 50% faster issue detection and resolution
- **Scalability**: Support 10x growth without proportional operational cost increase

## Implementation Timeline

### Phase 1: Development (Months 1-3)
- **Deliverables**: Core system development
- **Investment**: $330,000 - $495,000
- **Risk**: Low (development phase)
- **Benefits**: None (development phase)

### Phase 2: Testing & Validation (Months 4-5)
- **Deliverables**: Testing and refinement
- **Investment**: $50,000 - $100,000
- **Risk**: Low (testing phase)
- **Benefits**: None (testing phase)

### Phase 3: Production Deployment (Month 6)
- **Deliverables**: Production deployment
- **Investment**: $50,000
- **Risk**: Medium (deployment phase)
- **Benefits**: Immediate cost savings and revenue recovery

### Phase 4: Optimization (Months 7-12)
- **Deliverables**: Performance optimization and feature enhancement
- **Investment**: $100,000
- **Risk**: Low (optimization phase)
- **Benefits**: Additional cost savings and efficiency improvements

## Conclusion

The Mimir Edge Enforcement system delivers exceptional business value with a compelling ROI of 183% in the first year and 416% over three years. The solution addresses critical business challenges while providing significant competitive advantages.

Key benefits include:
- **$1.2M annual cost savings** through resource abuse prevention
- **$520K annual operational efficiency** improvements
- **4.2-month payback period** with immediate benefits
- **Zero deployment risk** with comprehensive rollback capabilities
- **Competitive differentiation** through unique technical capabilities

The investment is justified by the immediate and long-term benefits, with minimal risk due to the zero-impact deployment strategy and comprehensive monitoring capabilities.

---

**Recommendation**: Proceed with implementation based on the compelling business case and low-risk deployment strategy.

**Next Steps**: 
1. Secure executive approval for the $608K initial investment
2. Begin Phase 1 development with 3 engineers
3. Establish success metrics and monitoring framework
4. Plan Phase 2 testing and validation approach

---


## Problem Statement


## Overview

This document outlines the critical challenges and pain points that the Mimir Edge Enforcement system addresses in modern observability and monitoring environments.

## Business Challenges

### 1. Uncontrolled Infrastructure Costs

#### Problem
- **Exponential Cost Growth**: Monitoring infrastructure costs growing 300-500% year-over-year
- **No Visibility**: Lack of real-time visibility into cost drivers and usage patterns
- **Budget Overruns**: Monthly infrastructure bills exceeding allocated budgets by 200-400%
- **Resource Waste**: 40-60% of monitoring resources consumed by non-critical or duplicate data

#### Impact
- **Financial**: $500K - $2M annual overspend on monitoring infrastructure
- **Operational**: Delayed feature development due to cost constraints
- **Strategic**: Reduced investment in core business initiatives

#### Root Causes
- No centralized rate limiting or quota enforcement
- Inability to differentiate between critical and non-critical metrics
- Lack of tenant-aware resource allocation
- Missing cost attribution and chargeback mechanisms

### 2. Service Reliability Degradation

#### Problem
- **Performance Degradation**: 30-50% increase in query response times during peak loads
- **Service Outages**: 2-3 major outages per quarter due to resource exhaustion
- **Cascading Failures**: Single tenant's excessive usage affecting all users
- **Resource Contention**: CPU and memory contention leading to service degradation

#### Impact
- **User Experience**: 40-60% increase in support tickets during peak periods
- **Business Continuity**: Critical business operations disrupted during outages
- **Reputation**: Customer trust and satisfaction impacted by service instability

#### Root Causes
- No protection against resource abuse
- Missing circuit breakers and throttling mechanisms
- Inadequate resource isolation between tenants
- Lack of proactive monitoring and alerting

### 3. Operational Complexity

#### Problem
- **Manual Interventions**: 15-20 hours per week spent on manual resource management
- **Reactive Operations**: 80% of operational work is reactive rather than proactive
- **Knowledge Silos**: Critical operational knowledge concentrated in few team members
- **Inconsistent Policies**: Different rate limiting policies across environments

#### Impact
- **Productivity**: 25-30% of engineering time spent on operational tasks
- **Scalability**: Operations team unable to scale with business growth
- **Risk**: High dependency on individual team members

#### Root Causes
- No automated enforcement mechanisms
- Missing centralized policy management
- Lack of standardized operational procedures
- Insufficient tooling for proactive management

## Technical Challenges

### 1. Distributed Rate Limiting

#### Problem
- **Inconsistent Enforcement**: Rate limits applied differently across services
- **State Management**: Complex distributed state management for rate limiting
- **Latency Impact**: Rate limiting decisions adding 50-100ms to request latency
- **Scalability Issues**: Rate limiting not scaling with traffic growth

#### Technical Details
```yaml
# Current State - Inconsistent Rate Limiting
services:
  - name: service-a
    rate_limit: 1000 req/sec
    window: 1 minute
  - name: service-b
    rate_limit: 500 req/sec
    window: 5 minutes
  - name: service-c
    rate_limit: none  # No rate limiting
```

#### Impact
- **Reliability**: Inconsistent service behavior
- **Performance**: Unpredictable latency patterns
- **Maintenance**: Complex configuration management

### 2. Multi-Tenant Resource Management

#### Problem
- **Resource Isolation**: Poor isolation between tenant workloads
- **Fair Sharing**: No fair resource allocation mechanisms
- **Quota Enforcement**: Inability to enforce tenant-specific quotas
- **Usage Tracking**: Limited visibility into per-tenant resource consumption

#### Technical Details
```yaml
# Current State - No Tenant Isolation
resources:
  cpu: shared_pool
  memory: shared_pool
  storage: shared_pool
  network: shared_pool

# Desired State - Tenant-Aware Allocation
resources:
  tenant_a:
    cpu: 20%
    memory: 2GB
    storage: 100GB
  tenant_b:
    cpu: 30%
    memory: 4GB
    storage: 200GB
```

#### Impact
- **Fairness**: Some tenants consuming disproportionate resources
- **Predictability**: Unpredictable performance for all tenants
- **Compliance**: Difficulty meeting SLA commitments

### 3. Real-Time Decision Making

#### Problem
- **Latency Requirements**: Need sub-10ms decision latency for rate limiting
- **Accuracy**: High accuracy requirements for enforcement decisions
- **Consistency**: Need consistent decisions across distributed components
- **Scalability**: Must handle 10K+ requests per second

#### Technical Details
```yaml
# Current State - High Latency Decisions
decision_flow:
  request_received: 0ms
  policy_lookup: 50ms
  rate_limit_check: 100ms
  decision_made: 150ms
  response_sent: 200ms

# Desired State - Low Latency Decisions
decision_flow:
  request_received: 0ms
  policy_lookup: 2ms
  rate_limit_check: 5ms
  decision_made: 8ms
  response_sent: 10ms
```

#### Impact
- **User Experience**: Poor response times
- **Throughput**: Limited system capacity
- **Cost**: Higher infrastructure costs due to inefficiency

## Security Challenges

### 1. Resource Abuse Prevention

#### Problem
- **DDoS Protection**: No protection against distributed denial of service attacks
- **Resource Exhaustion**: Malicious actors can exhaust system resources
- **Quota Bypass**: Users can bypass rate limiting through various techniques
- **Authentication Bypass**: Insufficient authentication and authorization

#### Security Implications
- **Service Availability**: Risk of complete service outage
- **Data Integrity**: Potential data corruption or loss
- **Compliance**: Failure to meet security compliance requirements

### 2. Audit and Compliance

#### Problem
- **Audit Trail**: Insufficient logging of rate limiting decisions
- **Compliance Reporting**: Difficulty generating compliance reports
- **Forensic Analysis**: Limited ability to investigate security incidents
- **Policy Enforcement**: No verification of policy compliance

#### Compliance Requirements
- **SOC 2**: Security controls and monitoring
- **GDPR**: Data protection and privacy
- **ISO 27001**: Information security management
- **PCI DSS**: Payment card industry compliance

## Scalability Challenges

### 1. Horizontal Scaling

#### Problem
- **State Synchronization**: Complex state synchronization across instances
- **Load Distribution**: Uneven load distribution across components
- **Resource Utilization**: Poor resource utilization patterns
- **Failure Recovery**: Slow recovery from component failures

#### Scaling Requirements
```yaml
# Current Capacity
requests_per_second: 1,000
concurrent_tenants: 100
data_points_per_second: 10,000

# Target Capacity
requests_per_second: 100,000
concurrent_tenants: 10,000
data_points_per_second: 1,000,000
```

### 2. Data Management

#### Problem
- **Storage Growth**: Exponential storage growth (100% year-over-year)
- **Query Performance**: Degrading query performance with data growth
- **Retention Management**: Complex data retention and archival policies
- **Data Quality**: Inconsistent data quality and completeness

#### Data Challenges
- **Volume**: Petabytes of time-series data
- **Velocity**: Millions of data points per second
- **Variety**: Multiple data formats and sources
- **Veracity**: Data quality and accuracy concerns

## Monitoring and Observability Challenges

### 1. Visibility Gaps

#### Problem
- **Limited Metrics**: Insufficient metrics for rate limiting decisions
- **No Correlation**: Unable to correlate rate limiting with business metrics
- **Alert Fatigue**: Too many alerts with low signal-to-noise ratio
- **Root Cause Analysis**: Difficulty identifying root causes of issues

#### Observability Requirements
```yaml
# Required Metrics
rate_limiting:
  - requests_per_second
  - denied_requests
  - allowed_requests
  - latency_percentiles
  - error_rates

business:
  - cost_per_tenant
  - resource_utilization
  - sla_compliance
  - user_satisfaction
```

### 2. Performance Monitoring

#### Problem
- **Latency Spikes**: Unpredictable latency spikes during peak loads
- **Resource Bottlenecks**: Difficulty identifying resource bottlenecks
- **Capacity Planning**: Insufficient data for capacity planning
- **Performance Regression**: Hard to detect performance regressions

## Compliance and Governance Challenges

### 1. Policy Management

#### Problem
- **Policy Complexity**: Complex and conflicting rate limiting policies
- **Policy Enforcement**: Inconsistent policy enforcement across environments
- **Policy Updates**: Slow and error-prone policy updates
- **Policy Auditing**: Difficulty auditing policy compliance

#### Policy Requirements
```yaml
# Policy Types
policies:
  - tenant_quotas
  - rate_limits
  - resource_limits
  - security_policies
  - compliance_policies

# Enforcement Levels
enforcement:
  - soft_limits
  - hard_limits
  - graduated_response
  - emergency_shutdown
```

### 2. Regulatory Compliance

#### Problem
- **Multiple Regulations**: Need to comply with multiple regulations
- **Audit Requirements**: Complex audit and reporting requirements
- **Data Privacy**: Data privacy and protection requirements
- **Change Management**: Strict change management and approval processes

## Solution Requirements

### 1. Functional Requirements

#### Core Functionality
- **Real-time Rate Limiting**: Sub-10ms rate limiting decisions
- **Multi-tenant Support**: Support for 10,000+ concurrent tenants
- **Policy Management**: Centralized policy management and enforcement
- **Monitoring**: Comprehensive monitoring and alerting
- **Audit Trail**: Complete audit trail for all decisions

#### Advanced Features
- **Selective Enforcement**: Ability to selectively apply enforcement
- **Time-based Aggregation**: Intelligent time-based metric aggregation
- **Dynamic Scaling**: Automatic scaling based on load
- **Fail-safe Operation**: Graceful degradation during failures

### 2. Non-Functional Requirements

#### Performance
- **Latency**: <10ms for rate limiting decisions
- **Throughput**: 100,000 requests per second
- **Availability**: 99.9% uptime
- **Scalability**: Linear scaling with load

#### Reliability
- **Fault Tolerance**: Continue operation during component failures
- **Data Consistency**: Consistent data across distributed components
- **Recovery Time**: <5 minutes recovery from failures
- **Backup and Restore**: Automated backup and restore capabilities

#### Security
- **Authentication**: Strong authentication mechanisms
- **Authorization**: Role-based access control
- **Encryption**: Data encryption in transit and at rest
- **Audit**: Comprehensive audit logging

### 3. Operational Requirements

#### Deployment
- **Zero Downtime**: Zero-downtime deployments
- **Rollback**: Quick rollback capabilities
- **Configuration Management**: Centralized configuration management
- **Environment Consistency**: Consistent behavior across environments

#### Monitoring
- **Health Checks**: Comprehensive health check mechanisms
- **Alerting**: Intelligent alerting with low false positives
- **Dashboards**: Real-time dashboards for operational visibility
- **Logging**: Structured logging for operational analysis

## Success Criteria

### 1. Business Metrics

#### Cost Reduction
- **Infrastructure Costs**: 50-70% reduction in monitoring infrastructure costs
- **Operational Costs**: 40-60% reduction in operational overhead
- **Time to Resolution**: 80% reduction in time to resolve issues
- **Resource Utilization**: 30-50% improvement in resource utilization

#### Service Quality
- **Availability**: 99.9% service availability
- **Performance**: <10ms average response time
- **Reliability**: <1% error rate
- **User Satisfaction**: >95% user satisfaction score

### 2. Technical Metrics

#### Performance
- **Throughput**: 100,000 requests per second
- **Latency**: <10ms p95 latency
- **Scalability**: Linear scaling with load
- **Efficiency**: 90%+ resource utilization

#### Reliability
- **Uptime**: 99.9% uptime
- **Recovery**: <5 minutes recovery time
- **Consistency**: 99.99% data consistency
- **Durability**: 99.999% data durability

### 3. Operational Metrics

#### Efficiency
- **Automation**: 90%+ operational tasks automated
- **Response Time**: <15 minutes response to incidents
- **Resolution Time**: <2 hours resolution time
- **Change Velocity**: 10x increase in deployment frequency

#### Quality
- **Defect Rate**: <1% defect rate in production
- **Rollback Rate**: <5% rollback rate
- **Compliance**: 100% compliance with policies
- **Documentation**: 100% documentation coverage

## Conclusion

The Mimir Edge Enforcement system addresses critical challenges in modern observability environments by providing:

1. **Cost Control**: Automated cost management and resource optimization
2. **Service Protection**: Proactive protection against resource abuse and service degradation
3. **Operational Excellence**: Automated operations with comprehensive monitoring
4. **Compliance**: Built-in compliance and governance capabilities
5. **Scalability**: Linear scaling with business growth

By solving these challenges, the system enables organizations to:
- Reduce infrastructure costs by 50-70%
- Improve service reliability and performance
- Scale operations efficiently
- Meet compliance requirements
- Focus on core business objectives

---

**Next Steps**: 
1. Review the solution architecture in `architecture/system-architecture.md`
2. Understand the business value in `business-value.md`
3. Explore implementation details in `components/rate-limit-service.md`
4. Review deployment strategy in `deployment/deployment-strategy.md`

**Related Documents**:
- [Executive Summary](executive-summary.md)
- [Business Value](business-value.md)
- [System Architecture](architecture/system-architecture.md)
- [Deployment Strategy](deployment/deployment-strategy.md)

---


## System Architecture


## Overview

The Mimir Edge Enforcement system is designed as a modular, cloud-agnostic Kubernetes solution that enforces tenant ingestion limits at the edge with zero client changes and comprehensive observability.

## High-Level System Architecture

### System Components Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Mimir Edge Enforcement                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Alloy     │───▶│   NGINX     │───▶│   Envoy     │───▶│   Mimir     │     │
│  │  (Client)   │    │  (Proxy)    │    │ (Edge)      │    │Distributor  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘     │
│                           │                   │                                │
│                           ▼                   ▼                                │
│                    ┌─────────────┐    ┌─────────────┐                         │
│                    │   RLS       │    │Overrides-   │                         │
│                    │(Auth/Rate)  │    │Sync         │                         │
│                    └─────────────┘    └─────────────┘                         │
│                           │                   │                                │
│                           ▼                   ▼                                │
│                    ┌─────────────┐    ┌─────────────┐                         │
│                    │  Admin UI   │    │   Mimir     │                         │
│                    │  (React)    │    │ Overrides   │                         │
│                    └─────────────┘    │ ConfigMap   │                         │
│                                       └─────────────┘                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

```mermaid
graph TB
    A[Alloy Client] --> B[NGINX Proxy]
    B --> C[Envoy Proxy]
    C --> D[RLS Service]
    D --> E[Token Buckets]
    D --> F[Tenant Limits]
    C --> G[Mimir Distributor]
    H[Overrides-Sync] --> I[Mimir ConfigMap]
    H --> D
    J[Admin UI] --> D
    K[Prometheus] --> D
    K --> C
    K --> H
    L[Grafana] --> K
```

## Detailed Component Architecture

### 1. Client Layer

#### Alloy Client
- **Purpose**: Prometheus remote write client
- **Protocol**: HTTP/HTTPS
- **Authentication**: Bearer token or API key
- **Compression**: gzip, snappy, or uncompressed
- **Batch Size**: Configurable (default: 1MB)

#### NGINX Proxy
- **Purpose**: Load balancer and traffic router
- **Features**:
  - SSL termination
  - Request routing
  - Traffic splitting (mirror/canary)
  - Health checks
  - Rate limiting (coarse)
- **Configuration**: Dynamic reload capability

### 2. Edge Layer

#### Envoy Proxy
- **Purpose**: HTTP proxy with external authorization
- **Filters**:
  - `ext_authz`: External authorization filter
  - `rate_limit`: Rate limiting filter
  - `cors`: Cross-origin resource sharing
  - `compressor`: Response compression
- **Protocols**: HTTP/1.1, HTTP/2, gRPC
- **Clusters**: RLS service clusters

### 3. Enforcement Layer

#### Rate Limit Service (RLS)
- **Purpose**: Core enforcement engine
- **Services**:
  - gRPC ext_authz server
  - gRPC ratelimit server
  - HTTP admin API
- **Features**:
  - Protobuf parsing
  - Token bucket algorithm
  - Time-based aggregation
  - Intelligent caching

### 4. Management Layer

#### Overrides-Sync Controller
- **Purpose**: Kubernetes controller for limit management
- **Features**:
  - ConfigMap watcher
  - Limit parsing
  - RLS synchronization
  - Fallback polling
- **Reconciliation**: Event-driven with polling fallback

#### Admin UI
- **Purpose**: Web-based management interface
- **Technology**: React 18 + TypeScript
- **Features**:
  - Real-time monitoring
  - Tenant management
  - Configuration interface
  - Export capabilities

### 5. Storage Layer

#### In-Memory Storage
- **Purpose**: Primary state storage
- **Data**: Tenant limits, token buckets, metrics
- **Persistence**: Optional Redis backend
- **Scaling**: Horizontal scaling with state sharing

#### Kubernetes Resources
- **ConfigMaps**: Mimir overrides configuration
- **Secrets**: TLS certificates, API keys
- **PersistentVolumes**: Optional Redis storage

## Data Flow Architecture

### 1. Normal Request Flow

```mermaid
sequenceDiagram
    participant A as Alloy Client
    participant N as NGINX
    participant E as Envoy
    participant R as RLS
    participant M as Mimir Distributor

    A->>N: POST /api/v1/push
    N->>E: Forward request
    E->>R: ext_authz.Check()
    R->>R: Parse protobuf body
    R->>R: Check tenant limits
    R->>R: Update token buckets
    R-->>E: ALLOW/DENY response
    alt ALLOW
        E->>M: Forward to distributor
        M-->>E: Response
        E-->>N: Response
        N-->>A: Response
    else DENY
        E-->>N: 429 Too Many Requests
        N-->>A: 429 Too Many Requests
    end
```

### 2. Rate Limiting Flow

```mermaid
sequenceDiagram
    participant E as Envoy
    participant R as RLS
    participant T as Token Bucket

    E->>R: ratelimit.ShouldRateLimit()
    R->>T: Check bucket capacity
    alt Sufficient tokens
        T-->>R: OK
        R-->>E: OK
    else Insufficient tokens
        T-->>R: OVER_LIMIT
        R-->>E: OVER_LIMIT
    end
```

### 3. Configuration Sync Flow

```mermaid
sequenceDiagram
    participant K as Kubernetes
    participant O as Overrides-Sync
    participant R as RLS

    K->>O: ConfigMap updated
    O->>O: Parse overrides
    O->>R: SetTenantLimits()
    R->>R: Update token buckets
    R-->>O: Success
```

## Network Architecture

### Network Topology

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                              Ingress Layer                                  │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │ │
│  │  │   NGINX     │  │   NGINX     │  │   NGINX     │  │   NGINX     │       │ │
│  │  │  Ingress    │  │  Ingress    │  │  Ingress    │  │  Ingress    │       │ │
│  │  │ Controller  │  │ Controller  │  │ Controller  │  │ Controller  │       │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                             │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                              Service Layer                                  │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │ │
│  │  │   Envoy     │  │   Envoy     │  │   Envoy     │  │   Envoy     │       │ │
│  │  │   Proxy     │  │   Proxy     │  │   Proxy     │  │   Proxy     │       │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                             │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                            Enforcement Layer                                │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │ │
│  │  │     RLS     │  │     RLS     │  │     RLS     │  │     RLS     │       │ │
│  │  │   Service   │  │   Service   │  │   Service   │  │   Service   │       │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                             │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                             Management Layer                                 │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │ │
│  │  │ Overrides-  │  │   Admin     │  │ Prometheus  │  │   Grafana   │       │ │
│  │  │   Sync      │  │     UI      │  │             │  │             │       │ │
│  │  │ Controller  │  │             │  │             │  │             │       │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Network Policies

#### Pod-to-Pod Communication
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mimir-edge-enforcement-network-policy
spec:
  podSelector:
    matchLabels:
      app: mimir-edge-enforcement
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: mimir-distributor
    ports:
    - protocol: TCP
      port: 8080
```

## Security Architecture

### Authentication & Authorization

#### Tenant Identification
- **Method**: HTTP header extraction
- **Default Header**: `X-Scope-OrgID`
- **Configurable**: Custom header support
- **Validation**: Header presence and format

#### Service Authentication
- **gRPC**: mTLS for inter-service communication
- **HTTP**: Bearer tokens for admin API
- **Kubernetes**: Service accounts and RBAC

### Data Protection

#### Request Body Handling
- **Size Limits**: Configurable (default: 50MB)
- **Parsing**: Protobuf parsing with validation
- **Logging**: No sensitive data in logs
- **Storage**: In-memory only, no persistence

#### Metrics & Logging
- **Tenant Context**: Tenant ID in all metrics
- **Privacy**: No sensitive data exposure
- **Retention**: Configurable retention policies
- **Audit**: Complete request audit trail

## Scalability Architecture

### Horizontal Scaling

#### Auto-Scaling Configuration
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mimir-rls-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mimir-rls
  minReplicas: 10
  maxReplicas: 40
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 60
```

#### Load Distribution
- **Algorithm**: Round-robin with health checks
- **Session Affinity**: Optional for stateful operations
- **Health Checks**: Liveness and readiness probes
- **Circuit Breaker**: Automatic failure detection

### State Management

#### In-Memory State
- **Primary**: In-memory storage for performance
- **Scaling**: State sharing across replicas
- **Consistency**: Eventual consistency model
- **Recovery**: Automatic state reconstruction

#### Optional Redis Backend
- **Purpose**: Shared state across replicas
- **Configuration**: Optional for high-scale deployments
- **Fallback**: In-memory if Redis unavailable
- **Performance**: Minimal latency impact

## High Availability

### Multi-Zone Deployment

#### Pod Anti-Affinity
```yaml
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - mimir-rls
              topologyKey: kubernetes.io/hostname
```

#### Pod Disruption Budget
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: mimir-rls-pdb
spec:
  minAvailable: 5
  selector:
    matchLabels:
      app: mimir-rls
```

### Failure Recovery

#### Service Failure Modes
- **ext_authz**: Configurable (allow/deny on failure)
- **ratelimit**: Configurable (allow/deny on failure)
- **RLS Service**: Automatic restart via Kubernetes
- **Envoy Proxy**: Health check failover

#### Data Recovery
- **State Loss**: Automatic reconstruction from ConfigMap
- **Metrics Loss**: Prometheus handles gaps
- **Configuration Loss**: ConfigMap sync restores limits

## Monitoring Architecture

### Metrics Collection

#### Prometheus Integration
- **Scraping**: ServiceMonitor for automatic discovery
- **Metrics**: Custom metrics for all components
- **Labels**: Tenant-aware metric labeling
- **Retention**: Configurable retention policies

#### Custom Metrics
- **RLS Metrics**: Decisions, latency, errors
- **Envoy Metrics**: HTTP stats, filter stats
- **Business Metrics**: Tenant utilization, denials
- **System Metrics**: Resource usage, health status

### Logging Strategy

#### Structured Logging
- **Format**: JSON structured logs
- **Levels**: DEBUG, INFO, WARN, ERROR
- **Context**: Tenant ID, request ID, correlation ID
- **Output**: stdout/stderr for Kubernetes

#### Log Aggregation
- **Collection**: Kubernetes log aggregation
- **Processing**: Optional log processing pipeline
- **Storage**: Centralized log storage
- **Search**: Full-text search capabilities

## Configuration Management

### Dynamic Configuration

#### ConfigMap Integration
- **Source**: Mimir overrides ConfigMap
- **Sync**: Real-time ConfigMap watching
- **Fallback**: Polling when watch fails
- **Validation**: Configuration validation

#### Environment Variables
- **Runtime**: Environment variable configuration
- **Secrets**: Kubernetes secrets for sensitive data
- **Validation**: Configuration validation at startup
- **Documentation**: Comprehensive configuration docs

### Configuration Validation

#### Schema Validation
- **Format**: JSON schema validation
- **Types**: Strong typing for all configurations
- **Defaults**: Sensible defaults for all options
- **Documentation**: Inline configuration documentation

## Integration Points

### External Systems

#### Mimir Integration
- **Protocol**: HTTP/HTTPS
- **Authentication**: Bearer tokens
- **Configuration**: ConfigMap synchronization
- **Monitoring**: Mimir metrics integration

#### Kubernetes Integration
- **Resources**: Native Kubernetes resources
- **RBAC**: Role-based access control
- **Networking**: Network policies and services
- **Storage**: Persistent volumes and secrets

#### Monitoring Integration
- **Prometheus**: Metrics scraping and alerting
- **Grafana**: Dashboard and visualization
- **AlertManager**: Alert routing and notification
- **Logging**: Centralized log aggregation

## Performance Considerations

### Latency Optimization

#### Request Processing
- **Parsing**: Optimized protobuf parsing
- **Validation**: Minimal validation overhead
- **Caching**: Intelligent caching strategies
- **Batching**: Request batching where possible

#### Network Optimization
- **Connection Pooling**: HTTP/2 connection reuse
- **Compression**: Response compression
- **Caching**: Response caching strategies
- **Load Balancing**: Efficient load distribution

### Resource Optimization

#### Memory Management
- **Allocation**: Efficient memory allocation
- **Garbage Collection**: Optimized GC settings
- **Caching**: Memory-efficient caching
- **Monitoring**: Memory usage monitoring

#### CPU Optimization
- **Concurrency**: Efficient concurrency patterns
- **Profiling**: Regular performance profiling
- **Optimization**: Continuous performance optimization
- **Monitoring**: CPU usage monitoring

## Conclusion

The Mimir Edge Enforcement system architecture provides a comprehensive, scalable, and maintainable solution for tenant limit enforcement at the edge. The modular design ensures clear separation of concerns, while the comprehensive monitoring and observability capabilities enable effective operation and troubleshooting.

The architecture supports both current requirements and future growth, with clear upgrade paths and enhancement capabilities. The security-first approach ensures data protection and compliance, while the performance optimizations deliver minimal latency impact.

---

**Next Steps**: Review component-specific architecture documents for detailed implementation details.

---


## Component Architecture


## Overview

This document provides a detailed architectural overview of each component in the Mimir Edge Enforcement system, including their responsibilities, interactions, and design patterns.

## Architecture Overview

### High-Level Component Diagram

```mermaid
graph TB
    Client[Client Applications] --> NGINX[NGINX Proxy]
    NGINX --> RLS[Rate Limit Service]
    NGINX --> Distributor[Mimir Distributor]
    RLS --> Envoy[Envoy Proxy]
    Envoy --> Distributor
    RLS --> Controller[Overrides-Sync Controller]
    Controller --> K8s[Kubernetes API]
    Admin[Admin UI] --> RLS
    Grafana[Grafana] --> RLS
    Prometheus[Prometheus] --> RLS
    
    subgraph "Edge Layer"
        NGINX
    end
    
    subgraph "Enforcement Layer"
        RLS
        Envoy
    end
    
    subgraph "Management Layer"
        Controller
        Admin
    end
    
    subgraph "Storage Layer"
        K8s
    end
    
    subgraph "Observability Layer"
        Grafana
        Prometheus
    end
```

## Component Details

### 1. NGINX Proxy (Edge Layer)

#### Purpose
The NGINX proxy serves as the entry point for all incoming traffic and implements selective routing based on user identity.

#### Responsibilities
- **Traffic Routing**: Route traffic based on user identity (`$remote_user`)
- **Load Balancing**: Distribute traffic across backend services
- **SSL Termination**: Handle SSL/TLS termination
- **Request Logging**: Log all requests with routing decisions
- **Health Checking**: Monitor backend service health

#### Architecture
```nginx
# Core Routing Logic
map $remote_user $route_decision {
    "boltx"      "edge";
    "cloudwatch" "edge";
    default      "direct";
}

# Selective Proxy Configuration
location /api/v1/push {
    if ($route_decision = "edge") {
        proxy_pass http://mimir_rls;
        add_header X-Edge-Enforcement "selective";
    }
    if ($route_decision = "direct") {
        proxy_pass http://mimir_direct;
        add_header X-Edge-Enforcement "none";
    }
    add_header X-Route-Decision $route_decision;
}
```

#### Key Features
- **User-based Routing**: Route traffic based on user identity
- **Selective Enforcement**: Apply rate limiting only to specific users
- **Transparent Proxy**: Maintain original request headers and metadata
- **Health Monitoring**: Monitor backend service availability

#### Performance Characteristics
- **Latency**: <1ms routing overhead
- **Throughput**: 100,000+ requests per second
- **Memory**: <100MB per instance
- **CPU**: <5% CPU utilization under normal load

### 2. Rate Limit Service (RLS)

#### Purpose
The Rate Limit Service is the core enforcement engine that implements rate limiting, quota management, and policy enforcement.

#### Responsibilities
- **Rate Limiting**: Implement token bucket rate limiting
- **Quota Management**: Enforce tenant-specific quotas
- **Policy Enforcement**: Apply rate limiting policies
- **Metrics Collection**: Collect and aggregate metrics
- **gRPC Services**: Provide ext_authz and rate limit gRPC APIs

#### Architecture
```go
// Core Service Structure
type RateLimitService struct {
    tenants        map[string]*TenantInfo
    tokenBuckets   map[string]*TokenBucket
    timeAggregator *TimeAggregator
    metrics        *MetricsCollector
    config         *Config
}

// Request Processing Flow
func (rls *RateLimitService) CheckRemoteWriteLimits(tenantID string, body []byte, encoding string) error {
    // 1. Extract tenant information
    tenant := rls.GetOrCreateTenant(tenantID)
    
    // 2. Parse request body
    metrics, err := rls.parseMetrics(body, encoding)
    
    // 3. Check rate limits
    allowed, err := rls.checkRateLimits(tenant, metrics)
    
    // 4. Update metrics
    rls.updateMetrics(tenant, metrics, allowed)
    
    return err
}
```

#### Key Features
- **Token Bucket Algorithm**: Efficient rate limiting with burst support
- **Time-based Aggregation**: Intelligent metric aggregation over time
- **Multi-tenant Support**: Isolated rate limiting per tenant
- **Dynamic Configuration**: Runtime configuration updates
- **Comprehensive Metrics**: Detailed metrics for monitoring and alerting

#### Performance Characteristics
- **Latency**: <5ms for rate limiting decisions
- **Throughput**: 50,000+ requests per second
- **Memory**: <2GB per instance
- **CPU**: <20% CPU utilization under normal load

#### API Endpoints
```yaml
# gRPC Services
grpc_services:
  - name: ext_authz
    port: 8080
    protocol: grpc
    purpose: External authorization decisions
    
  - name: rate_limit
    port: 8081
    protocol: grpc
    purpose: Rate limiting decisions

# HTTP Admin API
http_endpoints:
  - path: /api/tenants
    method: GET
    purpose: List tenants with metrics
    
  - path: /api/overview
    method: GET
    purpose: System overview metrics
    
  - path: /api/health
    method: GET
    purpose: Health check
```

### 3. Envoy Proxy

#### Purpose
Envoy Proxy serves as the internal proxy that handles communication between the RLS and Mimir Distributor, implementing additional rate limiting and load balancing.

#### Responsibilities
- **Internal Routing**: Route requests between RLS and Distributor
- **Rate Limiting**: Apply additional rate limiting filters
- **Load Balancing**: Distribute load across Distributor instances
- **Circuit Breaking**: Implement circuit breakers for fault tolerance
- **Metrics Collection**: Collect proxy-level metrics

#### Architecture
```yaml
# Envoy Configuration
static_resources:
  listeners:
    - name: mimir_listener
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 8080
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: mimir
                route_config:
                  name: mimir_route
                  virtual_hosts:
                    - name: mimir
                      domains: ["*"]
                      routes:
                        - match:
                            prefix: "/"
                          route:
                            cluster: mimir_distributor
                http_filters:
                  - name: envoy.filters.http.ext_authz
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
                      grpc_service:
                        envoy_grpc:
                          cluster_name: rls_service
                  - name: envoy.filters.http.rate_limit
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.rate_limit.v3.RateLimit
                      domain: mimir
                      rate_limit_service:
                        grpc_service:
                          envoy_grpc:
                            cluster_name: rls_service
```

#### Key Features
- **Ext Authz Integration**: External authorization with RLS
- **Rate Limiting**: Additional rate limiting layer
- **Load Balancing**: Round-robin load balancing
- **Health Checking**: Active health checking
- **Circuit Breaking**: Fault tolerance mechanisms

#### Performance Characteristics
- **Latency**: <2ms proxy overhead
- **Throughput**: 100,000+ requests per second
- **Memory**: <500MB per instance
- **CPU**: <10% CPU utilization under normal load

### 4. Overrides-Sync Controller

#### Purpose
The Overrides-Sync Controller manages the synchronization of rate limiting configurations between Kubernetes ConfigMaps and the RLS service.

#### Responsibilities
- **Config Synchronization**: Sync ConfigMap changes to RLS
- **Dynamic Updates**: Update rate limiting policies without restarts
- **Validation**: Validate configuration changes
- **Rollback**: Support configuration rollbacks
- **Audit Trail**: Maintain configuration change history

#### Architecture
```go
// Controller Structure
type OverridesSyncController struct {
    k8sClient    kubernetes.Interface
    rlsClient    *RLSClient
    configMapWatcher *ConfigMapWatcher
    eventRecorder record.EventRecorder
}

// Configuration Sync Flow
func (c *OverridesSyncController) syncConfigMap(namespace, name string) error {
    // 1. Get ConfigMap from Kubernetes
    configMap, err := c.k8sClient.CoreV1().ConfigMaps(namespace).Get(name, metav1.GetOptions{})
    
    // 2. Parse configuration
    config, err := c.parseConfig(configMap.Data)
    
    // 3. Validate configuration
    if err := c.validateConfig(config); err != nil {
        return err
    }
    
    // 4. Sync to RLS
    return c.rlsClient.UpdateConfig(config)
}
```

#### Key Features
- **Real-time Sync**: Immediate configuration updates
- **Validation**: Comprehensive configuration validation
- **Rollback Support**: Quick rollback to previous configurations
- **Audit Logging**: Complete audit trail of changes
- **Error Handling**: Graceful error handling and recovery

#### Performance Characteristics
- **Sync Latency**: <1 second for configuration updates
- **Memory**: <100MB per instance
- **CPU**: <5% CPU utilization
- **Reliability**: 99.9% configuration sync success rate

### 5. Admin UI

#### Purpose
The Admin UI provides a web-based interface for monitoring, managing, and configuring the Mimir Edge Enforcement system.

#### Responsibilities
- **System Monitoring**: Real-time system metrics and health
- **Tenant Management**: Tenant-specific metrics and configuration
- **Policy Management**: Rate limiting policy configuration
- **Troubleshooting**: Debug and diagnostic tools
- **Reporting**: Generate reports and analytics

#### Architecture
```typescript
// React Component Structure
interface AdminUIProps {
  apiClient: APIClient;
  config: UIConfig;
}

// Main Application Structure
const AdminUI: React.FC<AdminUIProps> = ({ apiClient, config }) => {
  return (
    <Router>
      <Layout>
        <Sidebar />
        <MainContent>
          <Routes>
            <Route path="/" element={<Overview />} />
            <Route path="/tenants" element={<Tenants />} />
            <Route path="/tenants/:id" element={<TenantDetails />} />
            <Route path="/system" element={<SystemHealth />} />
            <Route path="/wiki" element={<Wiki />} />
          </Routes>
        </MainContent>
      </Layout>
    </Router>
  );
};
```

#### Key Features
- **Real-time Updates**: Live metrics and status updates
- **Interactive Dashboards**: Rich, interactive dashboards
- **Responsive Design**: Mobile-friendly interface
- **Search and Filtering**: Advanced search and filtering capabilities
- **Export Functionality**: Export data and reports

#### Performance Characteristics
- **Load Time**: <2 seconds initial load
- **Update Frequency**: 5-second refresh intervals
- **Memory**: <200MB browser memory usage
- **Responsiveness**: <100ms UI interactions

### 6. Mimir Distributor

#### Purpose
The Mimir Distributor is the target service that receives metrics after rate limiting decisions are made.

#### Responsibilities
- **Metrics Ingestion**: Receive and process metrics
- **Data Distribution**: Distribute data to storage backends
- **Validation**: Validate incoming metrics
- **Compression**: Handle compressed metric data
- **Authentication**: Authenticate incoming requests

#### Integration Points
```yaml
# Integration with Edge Enforcement
integration:
  upstream: distributor.mimir.svc.cluster.local:8080
  protocol: HTTP/2
  authentication: Bearer token
  compression: gzip, snappy
  
# Rate Limiting Headers
headers:
  - X-Edge-Enforcement: selective|none
  - X-Route-Decision: edge|direct
  - X-Tenant-ID: <tenant_id>
  - X-Rate-Limited: true|false
```

## Component Interactions

### 1. Request Flow

#### Normal Request Flow
```mermaid
sequenceDiagram
    participant Client
    participant NGINX
    participant RLS
    participant Envoy
    participant Distributor
    
    Client->>NGINX: POST /api/v1/push
    NGINX->>NGINX: Determine route based on user
    alt Route to Edge Enforcement
        NGINX->>RLS: Forward request
        RLS->>RLS: Check rate limits
        RLS->>Envoy: Forward if allowed
        Envoy->>Distributor: Forward to distributor
    else Route Directly
        NGINX->>Distributor: Forward directly
    end
    Distributor->>Client: Response
```

#### Rate Limited Request Flow
```mermaid
sequenceDiagram
    participant Client
    participant NGINX
    participant RLS
    
    Client->>NGINX: POST /api/v1/push
    NGINX->>RLS: Forward request
    RLS->>RLS: Check rate limits
    RLS->>RLS: Rate limit exceeded
    RLS->>Client: 429 Too Many Requests
```

### 2. Configuration Flow

#### Dynamic Configuration Update
```mermaid
sequenceDiagram
    participant Admin
    participant Controller
    participant K8s
    participant RLS
    
    Admin->>Controller: Update configuration
    Controller->>K8s: Update ConfigMap
    K8s->>Controller: ConfigMap updated
    Controller->>RLS: Sync configuration
    RLS->>RLS: Apply new configuration
    RLS->>Admin: Configuration applied
```

### 3. Monitoring Flow

#### Metrics Collection
```mermaid
sequenceDiagram
    participant RLS
    participant Prometheus
    participant Grafana
    participant Admin
    
    RLS->>RLS: Collect metrics
    RLS->>Prometheus: Expose metrics
    Prometheus->>Prometheus: Scrape metrics
    Prometheus->>Grafana: Provide metrics
    Grafana->>Grafana: Create dashboards
    Admin->>RLS: Fetch metrics via API
    Admin->>Admin: Display in UI
```

## Design Patterns

### 1. Microservices Architecture

#### Benefits
- **Independent Deployment**: Each component can be deployed independently
- **Technology Diversity**: Different components can use different technologies
- **Scalability**: Components can be scaled independently
- **Fault Isolation**: Failures in one component don't affect others

#### Implementation
```yaml
# Service Independence
services:
  nginx:
    deployment: independent
    scaling: horizontal
    technology: nginx
    
  rls:
    deployment: independent
    scaling: horizontal
    technology: golang
    
  envoy:
    deployment: independent
    scaling: horizontal
    technology: envoy
    
  admin-ui:
    deployment: independent
    scaling: horizontal
    technology: react
```

### 2. Event-Driven Architecture

#### Benefits
- **Loose Coupling**: Components communicate through events
- **Scalability**: Easy to add new event consumers
- **Reliability**: Event persistence and replay capabilities
- **Flexibility**: Dynamic event routing and filtering

#### Implementation
```go
// Event Structure
type Event struct {
    ID        string                 `json:"id"`
    Type      string                 `json:"type"`
    Timestamp time.Time              `json:"timestamp"`
    Data      map[string]interface{} `json:"data"`
    Source    string                 `json:"source"`
}

// Event Types
const (
    EventRateLimitExceeded = "rate_limit_exceeded"
    EventTenantCreated     = "tenant_created"
    EventConfigUpdated     = "config_updated"
    EventHealthCheck       = "health_check"
)
```

### 3. Circuit Breaker Pattern

#### Benefits
- **Fault Tolerance**: Prevent cascading failures
- **Performance**: Fail fast when services are unavailable
- **Recovery**: Automatic recovery when services become available
- **Monitoring**: Clear visibility into service health

#### Implementation
```go
// Circuit Breaker States
type CircuitBreakerState int

const (
    StateClosed CircuitBreakerState = iota
    StateOpen
    StateHalfOpen
)

// Circuit Breaker Implementation
type CircuitBreaker struct {
    state       CircuitBreakerState
    failureCount int
    threshold   int
    timeout     time.Duration
    lastFailure time.Time
    mutex       sync.RWMutex
}
```

### 4. Observer Pattern

#### Benefits
- **Loose Coupling**: Observers don't depend on subject implementation
- **Dynamic Registration**: Observers can be added/removed at runtime
- **Event Broadcasting**: Multiple observers can receive the same event
- **Extensibility**: Easy to add new observers

#### Implementation
```go
// Observer Interface
type Observer interface {
    Update(event Event)
}

// Subject Interface
type Subject interface {
    Attach(observer Observer)
    Detach(observer Observer)
    Notify(event Event)
}

// RLS as Subject
type RateLimitService struct {
    observers []Observer
    mutex     sync.RWMutex
}
```

## Performance Considerations

### 1. Caching Strategy

#### Multi-Level Caching
```yaml
# Cache Levels
caching:
  level_1:
    type: in_memory
    location: process
    size: 100MB
    ttl: 1 minute
    
  level_2:
    type: redis
    location: external
    size: 1GB
    ttl: 10 minutes
    
  level_3:
    type: database
    location: persistent
    size: unlimited
    ttl: 1 hour
```

#### Cache Invalidation
```go
// Cache Invalidation Strategy
type CacheManager struct {
    caches map[string]Cache
    invalidationRules map[string][]InvalidationRule
}

type InvalidationRule struct {
    Pattern string
    TTL     time.Duration
    Priority int
}
```

### 2. Connection Pooling

#### Database Connections
```go
// Connection Pool Configuration
type DBConfig struct {
    MaxOpenConns    int           `yaml:"max_open_conns"`
    MaxIdleConns    int           `yaml:"max_idle_conns"`
    ConnMaxLifetime time.Duration `yaml:"conn_max_lifetime"`
    ConnMaxIdleTime time.Duration `yaml:"conn_max_idle_time"`
}
```

#### HTTP Client Pooling
```go
// HTTP Client Configuration
type HTTPClientConfig struct {
    MaxIdleConns        int           `yaml:"max_idle_conns"`
    MaxIdleConnsPerHost int           `yaml:"max_idle_conns_per_host"`
    IdleConnTimeout     time.Duration `yaml:"idle_conn_timeout"`
    DisableCompression  bool          `yaml:"disable_compression"`
}
```

### 3. Async Processing

#### Background Workers
```go
// Worker Pool
type WorkerPool struct {
    workers    int
    jobQueue   chan Job
    resultChan chan Result
    wg         sync.WaitGroup
}

// Job Processing
func (wp *WorkerPool) Start() {
    for i := 0; i < wp.workers; i++ {
        wp.wg.Add(1)
        go wp.worker()
    }
}
```

## Security Considerations

### 1. Authentication and Authorization

#### Multi-Factor Authentication
```yaml
# Authentication Methods
authentication:
  methods:
    - type: bearer_token
      provider: kubernetes
      
    - type: oauth2
      provider: google
      
    - type: saml
      provider: okta
```

#### Role-Based Access Control
```yaml
# RBAC Configuration
rbac:
  roles:
    - name: admin
      permissions:
        - "*"
        
    - name: operator
      permissions:
        - "read:metrics"
        - "write:config"
        
    - name: viewer
      permissions:
        - "read:metrics"
```

### 2. Data Protection

#### Encryption at Rest
```yaml
# Encryption Configuration
encryption:
  at_rest:
    algorithm: AES-256-GCM
    key_rotation: 90 days
    
  in_transit:
    protocol: TLS 1.3
    cipher_suites:
      - TLS_AES_256_GCM_SHA384
      - TLS_CHACHA20_POLY1305_SHA256
```

#### Data Masking
```go
// Sensitive Data Masking
type DataMasker struct {
    patterns []regexp.Regexp
    masks    map[string]string
}

func (dm *DataMasker) Mask(data []byte) []byte {
    // Implementation for masking sensitive data
}
```

## Conclusion

The Mimir Edge Enforcement system employs a well-architected, microservices-based design that provides:

1. **Scalability**: Each component can be scaled independently
2. **Reliability**: Fault isolation and circuit breaker patterns
3. **Performance**: Optimized for low latency and high throughput
4. **Security**: Comprehensive security measures at all layers
5. **Observability**: Rich monitoring and debugging capabilities

The component architecture ensures that the system can handle the demanding requirements of modern observability environments while maintaining operational simplicity and cost-effectiveness.

---

**Next Steps**:
1. Review deployment strategies in `deployment/deployment-strategy.md`
2. Explore monitoring and observability in `monitoring/monitoring-strategy.md`
3. Understand security architecture in `security/security-architecture.md`
4. Learn about performance characteristics in `performance/performance-characteristics.md`

**Related Documents**:
- [System Architecture](system-architecture.md)
- [Rate Limit Service](../components/rate-limit-service.md)
- [Deployment Strategy](../deployment/deployment-strategy.md)
- [Security Architecture](../security/security-architecture.md)

---


## Rate Limit Service (RLS)


## Overview

The Rate Limit Service (RLS) is the core enforcement engine of the Mimir Edge Enforcement system. It provides authorization and rate limiting decisions through gRPC and HTTP APIs, with comprehensive monitoring and management capabilities.

## Architecture

### Service Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            Rate Limit Service (RLS)                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                              API Layer                                     │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │ │
│  │  │   gRPC      │  │   gRPC      │  │   HTTP      │  │   HTTP      │       │ │
│  │  │ ext_authz   │  │ ratelimit   │  │   Admin     │  │   Health    │       │ │
│  │  │   Server    │  │   Server    │  │    API      │  │   Check     │       │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                             │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                           Request Processing                               │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │ │
│  │  │   Tenant    │  │   Body      │  │   Limit     │  │   Token     │       │ │
│  │  │     ID      │  │  Parsing    │  │   Check     │  │  Bucket     │       │ │
│  │  │ Extraction  │  │(Protobuf)   │  │             │  │ Algorithm   │       │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                             │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                            State Management                                │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │ │
│  │  │   Tenant    │  │   Token     │  │   Time      │  │   Cache     │       │ │
│  │  │   Limits    │  │  Buckets    │  │Aggregator   │  │  System     │       │ │
│  │  │             │  │             │  │             │  │             │       │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                             │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                            Observability                                   │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │ │
│  │  │ Prometheus  │  │ Structured  │  │   Health    │  │   Metrics   │       │ │
│  │  │   Metrics   │  │   Logging   │  │   Checks    │  │  Collection │       │ │
│  │  │             │  │             │  │             │  │             │       │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

```mermaid
graph TB
    A[Request] --> B[API Layer]
    B --> C[Request Processing]
    C --> D[Tenant ID Extraction]
    C --> E[Body Parsing]
    C --> F[Limit Check]
    C --> G[Token Bucket]
    D --> H[State Management]
    E --> H
    F --> H
    G --> H
    H --> I[Decision]
    I --> J[Response]
    H --> K[Observability]
    K --> L[Metrics]
    K --> M[Logging]
    K --> N[Health Checks]
```

## API Services

### 1. gRPC ext_authz Server

#### Purpose
Provides external authorization decisions for Envoy's ext_authz filter.

#### Protocol
- **Service**: `envoy.service.auth.v3.Authorization`
- **Method**: `Check`
- **Port**: 8081 (default)

#### Request Flow
```go
func (rls *RLS) Check(ctx context.Context, req *envoy_service_auth_v3.CheckRequest) (*envoy_service_auth_v3.CheckResponse, error) {
    // 1. Extract tenant ID from request
    tenantID := rls.extractTenantID(req)
    
    // 2. Parse request body (protobuf)
    body, err := rls.parseRequestBody(req)
    if err != nil {
        return rls.createDenyResponse("body_parse_error"), nil
    }
    
    // 3. Check tenant limits
    decision := rls.checkLimits(tenantID, body)
    
    // 4. Record decision for metrics
    rls.recordDecision(tenantID, decision.Allowed, decision.Reason, body.Samples, body.Bytes, nil, nil, nil)
    
    // 5. Return response
    if decision.Allowed {
        return rls.createAllowResponse(), nil
    }
    return rls.createDenyResponse(decision.Reason), nil
}
```

#### Configuration
```yaml
# Envoy ext_authz filter configuration
http_filters:
- name: envoy.filters.http.ext_authz
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
    with_request_body:
      max_request_bytes: 52428800  # 50MB
    failure_mode_allow: false
    grpc_service:
      envoy_grpc:
        cluster_name: rls_ext_authz
```

### 2. gRPC ratelimit Server

#### Purpose
Provides rate limiting decisions for Envoy's rate_limit filter.

#### Protocol
- **Service**: `envoy.service.ratelimit.v3.RateLimitService`
- **Method**: `ShouldRateLimit`
- **Port**: 8083 (default)

#### Request Flow
```go
func (rls *RLS) ShouldRateLimit(ctx context.Context, req *envoy_service_ratelimit_v3.RateLimitRequest) (*envoy_service_ratelimit_v3.RateLimitResponse, error) {
    // 1. Extract tenant ID from descriptors
    tenantID := rls.extractTenantIDFromDescriptors(req.Descriptors)
    
    // 2. Check token bucket for rate limiting
    allowed := rls.checkRateLimit(tenantID, req)
    
    // 3. Return rate limit response
    if allowed {
        return &envoy_service_ratelimit_v3.RateLimitResponse{
            OverallCode: envoy_service_ratelimit_v3.RateLimitResponse_OK,
        }, nil
    }
    
    return &envoy_service_ratelimit_v3.RateLimitResponse{
        OverallCode: envoy_service_ratelimit_v3.RateLimitResponse_OVER_LIMIT,
    }, nil
}
```

#### Configuration
```yaml
# Envoy rate_limit filter configuration
http_filters:
- name: envoy.filters.http.ratelimit
  typed_config:
    "@type": type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimit
    domain: mimir_remote_write
    rate_limit_service:
      grpc_service:
        envoy_grpc:
          cluster_name: rls_ratelimit
```

### 3. HTTP Admin API

#### Purpose
Provides management and monitoring capabilities through REST API.

#### Endpoints
```bash
# Overview and System Metrics
GET /api/overview?range=1h
GET /api/system/status
GET /api/health

# Tenant Management
GET /api/tenants?range=1h
GET /api/tenants/{id}?range=24h
PUT /api/tenants/{id}/limits
POST /api/tenants/{id}/enforcement

# Denials and Monitoring
GET /api/denials
GET /api/denials/enhanced
GET /api/denials/trends

# Cardinality Management
GET /api/cardinality
GET /api/cardinality/violations
GET /api/cardinality/trends

# Traffic Flow
GET /api/traffic/flow
GET /api/flow/status
GET /api/timeseries/{timeRange}/flow

# Debug and Testing
GET /api/debug/routes
GET /api/debug/tenants
POST /api/debug/add-test-data
```

#### Port Configuration
- **Admin API**: 8082 (default)
- **Metrics**: 9090 (default)
- **Health Check**: 8082/health

## Request Processing

### 1. Tenant ID Extraction

#### Methods
- **HTTP Header**: `X-Scope-OrgID` (default)
- **Configurable**: Custom header support
- **Validation**: Header presence and format

#### Implementation
```go
func (rls *RLS) extractTenantID(req *envoy_service_auth_v3.CheckRequest) string {
    // Extract from HTTP headers
    if req.Attributes.Request.Http != nil {
        for _, header := range req.Attributes.Request.Http.Headers {
            if header.Key == rls.config.TenantHeader {
                return header.Value
            }
        }
    }
    
    // Return default tenant if not found
    return "default"
}
```

### 2. Body Parsing

#### Protobuf Parsing
- **Format**: Prometheus remote write protobuf
- **Compression**: gzip, snappy, uncompressed
- **Validation**: Size limits and format validation

#### Implementation
```go
func (rls *RLS) parseRequestBody(req *envoy_service_auth_v3.CheckRequest) (*RequestInfo, error) {
    // Get request body
    body := req.Attributes.Request.Http.Body
    
    // Check size limits
    if len(body) > rls.config.MaxRequestBytes {
        return nil, fmt.Errorf("request body too large: %d bytes", len(body))
    }
    
    // Parse protobuf
    var writeRequest prompb.WriteRequest
    if err := proto.Unmarshal(body, &writeRequest); err != nil {
        return nil, fmt.Errorf("failed to parse protobuf: %w", err)
    }
    
    // Extract metrics
    info := &RequestInfo{
        Samples: int64(len(writeRequest.Timeseries)),
        Bytes:   int64(len(body)),
    }
    
    // Calculate series and labels
    for _, ts := range writeRequest.Timeseries {
        info.ObservedSeries++
        info.ObservedLabels += int64(len(ts.Labels))
    }
    
    return info, nil
}
```

### 3. Limit Checking

#### Limit Types
- **Samples per Second**: Rate limiting for samples
- **Max Body Bytes**: Request size limits
- **Max Series per Request**: Cardinality limits
- **Max Labels per Series**: Label count limits

#### Implementation
```go
func (rls *RLS) checkLimits(tenantID string, info *RequestInfo) limits.Decision {
    // Get tenant state
    tenant := rls.getTenant(tenantID)
    
    // Check samples per second
    if tenant.Info.Enforcement.EnforceSamplesPerSecond {
        if !tenant.SamplesBucket.Take(float64(info.Samples)) {
            return limits.Decision{
                Allowed: false,
                Reason:  "samples_per_second_exceeded",
                Code:    429,
            }
        }
    }
    
    // Check body size
    if tenant.Info.Enforcement.EnforceMaxBodyBytes {
        if info.Bytes > tenant.Info.Limits.MaxBodyBytes {
            return limits.Decision{
                Allowed: false,
                Reason:  "max_body_bytes_exceeded",
                Code:    413,
            }
        }
    }
    
    // Check series limits
    if tenant.Info.Enforcement.EnforceMaxSeriesPerRequest {
        if info.ObservedSeries > tenant.Info.Limits.MaxSeriesPerRequest {
            return limits.Decision{
                Allowed: false,
                Reason:  "max_series_per_request_exceeded",
                Code:    429,
            }
        }
    }
    
    return limits.Decision{
        Allowed: true,
        Reason:  "allowed",
        Code:    200,
    }
}
```

## State Management

### 1. Tenant Limits

#### Data Structure
```go
type TenantLimits struct {
    SamplesPerSecond    float64 `json:"samples_per_second"`
    MaxBodyBytes        int64   `json:"max_body_bytes"`
    MaxSeriesPerRequest int64   `json:"max_series_per_request"`
    MaxLabelsPerSeries  int64   `json:"max_labels_per_series"`
}

type EnforcementConfig struct {
    Enabled                        bool `json:"enabled"`
    EnforceSamplesPerSecond        bool `json:"enforce_samples_per_second"`
    EnforceMaxBodyBytes            bool `json:"enforce_max_body_bytes"`
    EnforceMaxSeriesPerRequest     bool `json:"enforce_max_series_per_request"`
    EnforceMaxLabelsPerSeries      bool `json:"enforce_max_labels_per_series"`
}
```

#### Storage
- **Primary**: In-memory map
- **Key**: Tenant ID
- **Value**: TenantState with limits and buckets
- **Persistence**: Optional Redis backend

### 2. Token Buckets

#### Algorithm
- **Type**: Token bucket algorithm
- **Refill Rate**: Based on tenant limits
- **Capacity**: Configurable burst capacity
- **Thread Safety**: Concurrent access support

#### Implementation
```go
type TokenBucket struct {
    mu       sync.Mutex
    tokens   float64
    capacity float64
    rate     float64
    lastRefill time.Time
}

func (tb *TokenBucket) Take(tokens float64) bool {
    tb.mu.Lock()
    defer tb.mu.Unlock()
    
    // Refill tokens
    now := time.Now()
    elapsed := now.Sub(tb.lastRefill).Seconds()
    tb.tokens = math.Min(tb.capacity, tb.tokens + elapsed * tb.rate)
    tb.lastRefill = now
    
    // Check if enough tokens
    if tb.tokens >= tokens {
        tb.tokens -= tokens
        return true
    }
    
    return false
}
```

### 3. Time-Based Aggregation

#### Bucket Types
- **15-minute buckets**: Short-term analysis
- **1-hour buckets**: Operational monitoring
- **24-hour buckets**: Daily trends
- **1-week buckets**: Long-term planning

#### Implementation
```go
type TimeBucket struct {
    StartTime         time.Time
    EndTime           time.Time
    TotalRequests     int64
    AllowedRequests   int64
    DeniedRequests    int64
    TotalSeries       int64
    TotalLabels       int64
    Violations        int64
    AvgResponseTime   float64
    MaxResponseTime   float64
    MinResponseTime   float64
    ResponseTimeCount int64
}

type TimeAggregator struct {
    mu sync.RWMutex
    buckets15min map[string]*TimeBucket
    buckets1h    map[string]*TimeBucket
    buckets24h   map[string]*TimeBucket
    buckets1w    map[string]*TimeBucket
}
```

### 4. Caching System

#### Cache Types
- **Overview Cache**: System-wide metrics
- **Tenant Cache**: Per-tenant metrics
- **Configuration Cache**: Tenant limits and settings

#### Implementation
```go
type Cache struct {
    mu    sync.RWMutex
    data  map[string]cacheEntry
    ttl   time.Duration
}

type cacheEntry struct {
    data      interface{}
    timestamp time.Time
    ttl       time.Duration
}

func (c *Cache) Get(key string) (interface{}, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    
    entry, exists := c.data[key]
    if !exists {
        return nil, false
    }
    
    if time.Since(entry.timestamp) > entry.ttl {
        return nil, false
    }
    
    return entry.data, true
}
```

## Observability

### 1. Prometheus Metrics

#### Core Metrics
```promql
# Authorization decisions
rls_decisions_total{decision="allow|deny", tenant="tenant-id", reason="reason"}

# Performance
rls_authz_check_duration_seconds_bucket
rls_body_parse_duration_seconds_bucket

# Errors
rls_body_parse_errors_total
rls_limits_stale_seconds

# Token bucket states
rls_tenant_bucket_tokens{tenant="tenant-id", bucket_type="samples|bytes|requests"}

# Time-based aggregation
rls_time_aggregator_buckets_total{time_range="1h"}
rls_cache_hits_total{cache_type="overview|tenants"}
```

#### Metric Collection
```go
type Metrics struct {
    DecisionsTotal           *prometheus.CounterVec
    AuthzCheckDuration       *prometheus.HistogramVec
    BodyParseDuration        *prometheus.HistogramVec
    BodyParseErrorsTotal     *prometheus.CounterVec
    LimitsStaleSeconds       *prometheus.GaugeVec
    TenantBucketTokens       *prometheus.GaugeVec
    TimeAggregatorBuckets    *prometheus.GaugeVec
    CacheHitsTotal           *prometheus.CounterVec
}
```

### 2. Structured Logging

#### Log Format
```json
{
  "level": "info",
  "time": "2024-01-15T10:30:00Z",
  "tenant": "tenant-1",
  "decision": "deny",
  "reason": "samples_per_second_exceeded",
  "observed_samples": 15000,
  "limit": 10000,
  "request_id": "req-12345",
  "duration_ms": 2.5
}
```

#### Logging Implementation
```go
func (rls *RLS) recordDecision(tenantID string, allowed bool, reason string, samples, bytes int64, requestInfo *limits.RequestInfo, sampleMetrics []limits.SampleMetric, parseInfo *limits.ParseInfo) {
    rls.logger.Info().
        Str("tenant", tenantID).
        Bool("decision", allowed).
        Str("reason", reason).
        Int64("observed_samples", samples).
        Int64("observed_bytes", bytes).
        Interface("request_info", requestInfo).
        Interface("sample_metrics", sampleMetrics).
        Interface("parse_info", parseInfo).
        Msg("RLS decision recorded")
}
```

### 3. Health Checks

#### Health Endpoints
```bash
# Basic health check
GET /api/health

# Detailed health check
GET /api/system/status

# Component health
GET /api/flow/status
```

#### Health Check Implementation
```go
func (rls *RLS) healthCheck(w http.ResponseWriter, r *http.Request) {
    status := map[string]interface{}{
        "status": "healthy",
        "timestamp": time.Now().Format(time.RFC3339),
        "version": rls.version,
        "uptime": time.Since(rls.startTime).String(),
    }
    
    // Check critical components
    if !rls.checkCriticalComponents() {
        status["status"] = "unhealthy"
        w.WriteHeader(http.StatusServiceUnavailable)
    }
    
    writeJSON(w, http.StatusOK, status)
}
```

## Configuration

### 1. Environment Variables

#### Core Configuration
```bash
# Service Configuration
MAX_REQUEST_BYTES=52428800
TENANT_HEADER=X-Scope-OrgID
FAILURE_MODE_ALLOW=false

# Default Limits
DEFAULT_SAMPLES_PER_SECOND=10000
DEFAULT_MAX_BODY_BYTES=52428800
DEFAULT_MAX_SERIES_PER_REQUEST=1000000
DEFAULT_MAX_LABELS_PER_SERIES=30

# Redis Configuration (optional)
REDIS_ADDRESS=redis:6379
REDIS_POOL_SIZE=200
REDIS_MIN_IDLE_CONNS=50

# Logging Configuration
LOG_LEVEL=info
LOG_FORMAT=json
```

### 2. Kubernetes Configuration

#### Deployment Configuration
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mimir-rls
spec:
  replicas: 10
  selector:
    matchLabels:
      app: mimir-rls
  template:
    spec:
      containers:
      - name: rls
        image: mimir-rls:latest
        ports:
        - containerPort: 8081  # gRPC ext_authz
        - containerPort: 8082  # HTTP admin
        - containerPort: 8083  # gRPC ratelimit
        - containerPort: 9090  # Metrics
        env:
        - name: MAX_REQUEST_BYTES
          value: "52428800"
        - name: TENANT_HEADER
          value: "X-Scope-OrgID"
        resources:
          requests:
            memory: 8Gi
            cpu: 1000m
          limits:
            memory: 16Gi
            cpu: 4000m
```

## Performance Characteristics

### 1. Latency Impact

#### Request Processing Latency
- **Tenant ID Extraction**: ~0.1ms
- **Body Parsing**: ~0.5-2ms (depending on size)
- **Limit Checking**: ~0.1-1ms
- **Token Bucket Operations**: ~0.1ms
- **Total Overhead**: ~1-5ms per request

#### Optimization Techniques
- **Connection Pooling**: HTTP/2 connection reuse
- **Memory Pooling**: Efficient memory allocation
- **Concurrent Processing**: Goroutine-based request handling
- **Caching**: Intelligent caching strategies

### 2. Throughput

#### Performance Benchmarks
- **Requests per Second**: 10,000+ per instance
- **Concurrent Connections**: 1,000+ per instance
- **Memory Usage**: ~100-500MB per instance
- **CPU Usage**: ~0.1-1 CPU core per instance

#### Scaling Characteristics
- **Horizontal Scaling**: Linear scaling with replicas
- **Load Distribution**: Round-robin with health checks
- **State Sharing**: Optional Redis backend for shared state
- **Auto-scaling**: HPA with CPU/memory targets

### 3. Resource Usage

#### Memory Management
- **In-Memory State**: ~50-200MB per tenant
- **Token Buckets**: ~1KB per tenant
- **Time Aggregator**: ~10-50MB total
- **Cache System**: ~10-100MB total

#### CPU Optimization
- **Goroutine Pool**: Efficient concurrency
- **Lock-Free Operations**: Where possible
- **Batch Processing**: Request batching
- **Profiling**: Regular performance profiling

## Security Considerations

### 1. Authentication & Authorization

#### Service Authentication
- **gRPC**: mTLS for inter-service communication
- **HTTP**: Bearer tokens for admin API
- **Kubernetes**: Service accounts and RBAC

#### Tenant Authentication
- **Header Validation**: Tenant ID header validation
- **Rate Limiting**: Per-tenant rate limiting
- **Access Control**: Tenant isolation

### 2. Data Protection

#### Request Body Handling
- **Size Limits**: Configurable request size limits
- **Parsing Validation**: Protobuf format validation
- **No Persistence**: In-memory only, no disk storage
- **Logging**: No sensitive data in logs

#### Metrics & Logging
- **Tenant Context**: Tenant ID in all metrics
- **Privacy**: No sensitive data exposure
- **Audit Trail**: Complete request audit trail
- **Retention**: Configurable retention policies

## Troubleshooting

### 1. Common Issues

#### High Latency
**Symptoms**: Increased request latency
**Causes**:
- High CPU usage
- Memory pressure
- Network issues
- Token bucket contention

**Solutions**:
```bash
# Check resource usage
kubectl top pods -n mimir-edge-enforcement

# Check metrics
curl http://localhost:9090/metrics | grep rls_authz_check_duration

# Scale up replicas
kubectl scale deployment mimir-rls --replicas=20
```

#### Memory Issues
**Symptoms**: High memory usage or OOM kills
**Causes**:
- Too many tenants
- Large request bodies
- Memory leaks
- Inefficient caching

**Solutions**:
```bash
# Check memory usage
kubectl top pods -n mimir-edge-enforcement

# Check tenant count
curl http://localhost:8082/api/tenants | jq '.tenants | length'

# Increase memory limits
kubectl patch deployment mimir-rls -p '{"spec":{"template":{"spec":{"containers":[{"name":"rls","resources":{"limits":{"memory":"32Gi"}}}]}}}}'
```

### 2. Debug Procedures

#### Enable Debug Logging
```bash
# Update deployment with debug logging
kubectl patch deployment mimir-rls -p '{"spec":{"template":{"spec":{"containers":[{"name":"rls","env":[{"name":"LOG_LEVEL","value":"debug"}]}]}}}}'
```

#### Check Service Health
```bash
# Basic health check
curl http://localhost:8082/api/health

# Detailed status
curl http://localhost:8082/api/system/status

# Component health
curl http://localhost:8082/api/flow/status
```

#### Debug Endpoints
```bash
# List all routes
curl http://localhost:8082/api/debug/routes

# Check tenant state
curl http://localhost:8082/api/debug/tenants

# Add test data
curl -X POST http://localhost:8082/api/debug/add-test-data
```

## Future Enhancements

### 1. Planned Features

#### Advanced Rate Limiting
- **Adaptive Rate Limiting**: Dynamic rate adjustment
- **Burst Handling**: Improved burst capacity management
- **Priority Queuing**: Priority-based request handling
- **Fair Queuing**: Fair resource allocation

#### Enhanced Monitoring
- **Real-time Dashboards**: Live monitoring dashboards
- **Predictive Analytics**: Anomaly detection
- **Custom Alerts**: Tenant-specific alerting
- **Performance Insights**: Detailed performance analysis

### 2. Technical Improvements

#### Performance Optimization
- **Zero-Copy Parsing**: Efficient protobuf parsing
- **Memory Pooling**: Advanced memory management
- **Lock-Free Data Structures**: Improved concurrency
- **Compression**: Response compression

#### Scalability Enhancements
- **Distributed State**: Redis-based state sharing
- **Sharding**: Tenant-based sharding
- **Caching**: Multi-level caching
- **Load Balancing**: Advanced load balancing

## Conclusion

The Rate Limit Service (RLS) is the core enforcement engine of the Mimir Edge Enforcement system, providing comprehensive authorization and rate limiting capabilities. With its modular architecture, comprehensive observability, and production-ready features, it delivers reliable and scalable tenant limit enforcement.

The service's performance characteristics, security features, and troubleshooting capabilities make it suitable for high-scale production environments, while its extensible design supports future enhancements and improvements.

---

**Next Steps**: Review other component documents for integration details and deployment guides.

---


## Core Features


## Overview

This document provides a comprehensive overview of the core features and capabilities of the Mimir Edge Enforcement system, including detailed explanations, use cases, and implementation details.

## Feature Categories

### 1. Rate Limiting and Quota Management

#### Selective Traffic Routing

**Description**: Intelligent routing of traffic based on user identity, allowing selective application of rate limiting to specific users while bypassing others.

**Implementation**:
```nginx
# NGINX Configuration
map $remote_user $route_decision {
    "boltx"      "edge";
    "cloudwatch" "edge";
    default      "direct";
}

location /api/v1/push {
    if ($route_decision = "edge") {
        proxy_pass http://mimir_rls;
        add_header X-Edge-Enforcement "selective";
    }
    if ($route_decision = "direct") {
        proxy_pass http://mimir_direct;
        add_header X-Edge-Enforcement "none";
    }
    add_header X-Route-Decision $route_decision;
}
```

**Use Cases**:
- **Cost Control**: Apply rate limiting to high-volume users to control costs
- **Resource Protection**: Protect critical infrastructure from resource exhaustion
- **Fair Usage**: Ensure fair resource allocation across tenants
- **Compliance**: Meet regulatory requirements for resource usage

**Benefits**:
- **Flexibility**: Granular control over which users are rate limited
- **Transparency**: Clear visibility into routing decisions
- **Performance**: Minimal overhead for non-rate-limited traffic
- **Scalability**: Easy to add or remove users from rate limiting

#### Token Bucket Rate Limiting

**Description**: Implementation of the token bucket algorithm for efficient and fair rate limiting with burst support.

**Implementation**:
```go
// Token Bucket Implementation
type TokenBucket struct {
    capacity     int64
    tokens       int64
    refillRate   float64
    lastRefill   time.Time
    mutex        sync.RWMutex
}

func (tb *TokenBucket) Take(tokens int64) bool {
    tb.mutex.Lock()
    defer tb.mutex.Unlock()
    
    // Refill tokens based on time elapsed
    now := time.Now()
    elapsed := now.Sub(tb.lastRefill).Seconds()
    newTokens := int64(elapsed * tb.refillRate)
    
    if newTokens > 0 {
        tb.tokens = min(tb.capacity, tb.tokens+newTokens)
        tb.lastRefill = now
    }
    
    // Check if enough tokens available
    if tb.tokens >= tokens {
        tb.tokens -= tokens
        return true
    }
    
    return false
}
```

**Features**:
- **Burst Support**: Allow temporary bursts above the sustained rate
- **Fair Distribution**: Ensure fair token distribution across tenants
- **Configurable Parameters**: Adjustable capacity and refill rates
- **Real-time Updates**: Dynamic rate limit adjustments

**Configuration**:
```yaml
# Rate Limiting Configuration
rate_limits:
  tenant_default:
    requests_per_second: 1000
    burst_capacity: 2000
    refill_rate: 1000.0
    
  tenant_premium:
    requests_per_second: 5000
    burst_capacity: 10000
    refill_rate: 5000.0
```

#### Multi-Tenant Quota Management

**Description**: Comprehensive quota management system that enforces tenant-specific limits on various resources.

**Implementation**:
```go
// Tenant Quota Structure
type TenantQuota struct {
    TenantID           string    `json:"tenant_id"`
    MaxRequestsPerSec  int64     `json:"max_requests_per_sec"`
    MaxSamplesPerSec   int64     `json:"max_samples_per_sec"`
    MaxBytesPerSec     int64     `json:"max_bytes_per_sec"`
    MaxSeriesPerMetric int64     `json:"max_series_per_metric"`
    MaxMetricsPerTenant int64    `json:"max_metrics_per_tenant"`
    SoftLimit          bool      `json:"soft_limit"`
    HardLimit          bool      `json:"hard_limit"`
}

// Quota Enforcement
func (rls *RateLimitService) enforceQuota(tenant *TenantInfo, request *MetricRequest) error {
    quota := rls.getTenantQuota(tenant.ID)
    
    // Check various quota limits
    if err := rls.checkRequestRate(tenant, quota); err != nil {
        return err
    }
    
    if err := rls.checkSampleRate(tenant, quota); err != nil {
        return err
    }
    
    if err := rls.checkByteRate(tenant, quota); err != nil {
        return err
    }
    
    return nil
}
```

**Quota Types**:
- **Request Rate**: Maximum requests per second
- **Sample Rate**: Maximum samples per second
- **Byte Rate**: Maximum bytes per second
- **Series Limit**: Maximum series per metric
- **Metric Limit**: Maximum metrics per tenant

### 2. Time-Based Aggregation

#### Intelligent Metric Aggregation

**Description**: Advanced time-based aggregation system that provides intelligent caching and metric calculation over various time ranges.

**Implementation**:
```go
// Time Aggregator Structure
type TimeAggregator struct {
    windows    map[string]*TimeWindow
    cache      *Cache
    mutex      sync.RWMutex
}

type TimeWindow struct {
    Start     time.Time
    End       time.Time
    Metrics   map[string]float64
    Count     int64
    LastUpdate time.Time
}

// Aggregation Methods
func (ta *TimeAggregator) RecordDecision(tenantID string, decision Decision, timestamp time.Time) {
    ta.mutex.Lock()
    defer ta.mutex.Unlock()
    
    // Update all relevant time windows
    for windowKey, window := range ta.windows {
        if timestamp.After(window.Start) && timestamp.Before(window.End) {
            ta.updateWindow(windowKey, tenantID, decision)
        }
    }
}

func (ta *TimeAggregator) GetTenantAggregatedData(tenantID, timeRange string) map[string]interface{} {
    normalizedRange := ta.normalizeTimeRange(timeRange)
    window := ta.getOrCreateWindow(normalizedRange)
    
    return map[string]interface{}{
        "rps":             ta.calculateRPS(window, tenantID),
        "allow_rate":      ta.calculateAllowRate(window, tenantID),
        "deny_rate":       ta.calculateDenyRate(window, tenantID),
        "samples_per_sec": ta.calculateSamplesPerSec(window, tenantID),
        "bytes_per_sec":   ta.calculateBytesPerSec(window, tenantID),
        "utilization_pct": ta.calculateUtilization(window, tenantID),
    }
}
```

**Time Ranges**:
- **1 Minute**: Real-time monitoring
- **5 Minutes**: Short-term trends
- **1 Hour**: Medium-term analysis
- **24 Hours**: Daily patterns
- **7 Days**: Weekly trends
- **30 Days**: Monthly analysis

**Aggregation Functions**:
- **Rate Calculation**: Requests per second, samples per second
- **Percentage Calculation**: Allow rate, deny rate, utilization
- **Statistical Functions**: Min, max, average, percentiles
- **Trend Analysis**: Rate of change, acceleration

#### Caching Strategy

**Description**: Multi-level caching system that optimizes performance while maintaining data accuracy.

**Implementation**:
```go
// Cache Levels
type CacheLevel int

const (
    Level1Cache CacheLevel = iota // In-memory cache
    Level2Cache                   // Redis cache
    Level3Cache                   // Database cache
)

type CacheManager struct {
    level1 *MemoryCache
    level2 *RedisCache
    level3 *DatabaseCache
}

func (cm *CacheManager) Get(key string) (interface{}, bool) {
    // Try Level 1 (fastest)
    if value, found := cm.level1.Get(key); found {
        return value, true
    }
    
    // Try Level 2
    if value, found := cm.level2.Get(key); found {
        cm.level1.Set(key, value) // Populate Level 1
        return value, true
    }
    
    // Try Level 3
    if value, found := cm.level3.Get(key); found {
        cm.level2.Set(key, value) // Populate Level 2
        cm.level1.Set(key, value) // Populate Level 1
        return value, true
    }
    
    return nil, false
}
```

**Cache Characteristics**:
- **Level 1**: In-memory, <1ms access, 100MB size
- **Level 2**: Redis, <5ms access, 1GB size
- **Level 3**: Database, <50ms access, unlimited size

### 3. External Authorization (Ext Authz)

#### gRPC Ext Authz Integration

**Description**: Integration with Envoy's external authorization filter for real-time authorization decisions.

**Implementation**:
```protobuf
// Ext Authz Service Definition
service Authorization {
    rpc Check(CheckRequest) returns (CheckResponse);
}

message CheckRequest {
    repeated Attribute attributes = 1;
}

message CheckResponse {
    Status status = 1;
    repeated HeaderValueOption headers_to_add = 2;
    repeated HeaderValueOption headers_to_set = 3;
    repeated HeaderValueOption headers_to_remove = 4;
}
```

**Go Implementation**:
```go
// Ext Authz Handler
func (s *ExtAuthzServer) Check(ctx context.Context, req *authz.CheckRequest) (*authz.CheckResponse, error) {
    // Extract tenant ID from request
    tenantID := extractTenantID(req)
    
    // Get tenant information
    tenant := s.rls.GetOrCreateTenant(tenantID)
    
    // Check rate limits
    allowed, err := s.rls.CheckRateLimits(tenant, req)
    if err != nil {
        return &authz.CheckResponse{
            Status: &rpc.Status{
                Code: int32(codes.Internal),
                Message: err.Error(),
            },
        }, nil
    }
    
    if allowed {
        return &authz.CheckResponse{
            Status: &rpc.Status{Code: int32(codes.OK)},
            HeadersToAdd: []*core.HeaderValueOption{
                {Header: &core.HeaderValue{Key: "X-Rate-Limited", Value: "false"}},
            },
        }, nil
    }
    
    return &authz.CheckResponse{
        Status: &rpc.Status{
            Code: int32(codes.PermissionDenied),
            Message: "Rate limit exceeded",
        },
        HeadersToAdd: []*core.HeaderValueOption{
            {Header: &core.HeaderValue{Key: "X-Rate-Limited", Value: "true"}},
        },
    }, nil
}
```

**Features**:
- **Real-time Decisions**: Sub-10ms authorization decisions
- **Header Injection**: Add custom headers to requests
- **Status Codes**: Proper HTTP status codes for different scenarios
- **Error Handling**: Comprehensive error handling and logging

### 4. Dynamic Configuration Management

#### Runtime Configuration Updates

**Description**: Ability to update rate limiting configurations without service restarts.

**Implementation**:
```go
// Configuration Manager
type ConfigManager struct {
    config     *Config
    watchers   []ConfigWatcher
    mutex      sync.RWMutex
}

type Config struct {
    GlobalLimits    GlobalLimits    `yaml:"global_limits"`
    TenantLimits    map[string]TenantLimits `yaml:"tenant_limits"`
    EnforcementMode string          `yaml:"enforcement_mode"`
    Logging         LoggingConfig   `yaml:"logging"`
}

// Configuration Update Handler
func (cm *ConfigManager) UpdateConfig(newConfig *Config) error {
    cm.mutex.Lock()
    defer cm.mutex.Unlock()
    
    // Validate new configuration
    if err := cm.validateConfig(newConfig); err != nil {
        return err
    }
    
    // Apply configuration changes
    cm.applyConfigChanges(cm.config, newConfig)
    
    // Update current configuration
    cm.config = newConfig
    
    // Notify watchers
    cm.notifyWatchers(newConfig)
    
    return nil
}
```

**Configuration Sources**:
- **Kubernetes ConfigMaps**: Primary configuration source
- **Environment Variables**: Runtime overrides
- **API Endpoints**: Dynamic updates via REST API
- **File System**: Local configuration files

**Update Mechanisms**:
- **Hot Reload**: Configuration changes applied immediately
- **Validation**: Comprehensive validation before application
- **Rollback**: Automatic rollback on validation failures
- **Audit Trail**: Complete audit trail of configuration changes

### 5. Comprehensive Monitoring and Metrics

#### Prometheus Metrics

**Description**: Extensive Prometheus metrics for monitoring system health, performance, and rate limiting decisions.

**Implementation**:
```go
// Metrics Collection
type MetricsCollector struct {
    requestCounter    *prometheus.CounterVec
    requestDuration   *prometheus.HistogramVec
    rateLimitCounter  *prometheus.CounterVec
    tenantMetrics     *prometheus.GaugeVec
    systemMetrics     *prometheus.GaugeVec
}

// Metric Definitions
var (
    requestCounter = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "mimir_edge_requests_total",
            Help: "Total number of requests processed",
        },
        []string{"tenant_id", "route_decision", "status"},
    )
    
    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "mimir_edge_request_duration_seconds",
            Help:    "Request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"tenant_id", "route_decision"},
    )
    
    rateLimitCounter = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "mimir_edge_rate_limits_total",
            Help: "Total number of rate limiting decisions",
        },
        []string{"tenant_id", "decision", "limit_type"},
    )
)
```

**Metric Categories**:
- **Request Metrics**: Total requests, duration, status codes
- **Rate Limiting Metrics**: Allow/deny decisions, limit types
- **Tenant Metrics**: Per-tenant usage and limits
- **System Metrics**: Resource utilization, health status
- **Business Metrics**: Cost tracking, SLA compliance

#### Health Checks

**Description**: Comprehensive health checking system for all components.

**Implementation**:
```go
// Health Check Structure
type HealthCheck struct {
    Name     string                 `json:"name"`
    Status   string                 `json:"status"`
    Details  map[string]interface{} `json:"details,omitempty"`
    Timestamp time.Time             `json:"timestamp"`
}

type HealthChecker struct {
    checks map[string]HealthCheckFunc
}

// Health Check Functions
func (hc *HealthChecker) AddCheck(name string, check HealthCheckFunc) {
    hc.checks[name] = check
}

func (hc *HealthChecker) RunChecks() map[string]HealthCheck {
    results := make(map[string]HealthCheck)
    
    for name, check := range hc.checks {
        status, details := check()
        results[name] = HealthCheck{
            Name:      name,
            Status:    status,
            Details:   details,
            Timestamp: time.Now(),
        }
    }
    
    return results
}
```

**Health Check Types**:
- **Liveness**: Service is running and responsive
- **Readiness**: Service is ready to handle requests
- **Dependencies**: External dependencies are available
- **Performance**: Service is performing within acceptable limits

### 6. Admin UI and Management

#### Real-time Dashboard

**Description**: Comprehensive web-based interface for monitoring and managing the system.

**Features**:
- **Real-time Metrics**: Live updates of system metrics
- **Interactive Charts**: Rich, interactive visualizations
- **Tenant Management**: Per-tenant monitoring and configuration
- **System Health**: Comprehensive health status monitoring
- **Configuration Management**: Runtime configuration updates

**Implementation**:
```typescript
// Dashboard Component
interface DashboardProps {
  apiClient: APIClient;
  refreshInterval: number;
}

const Dashboard: React.FC<DashboardProps> = ({ apiClient, refreshInterval }) => {
  const [metrics, setMetrics] = useState<SystemMetrics | null>(null);
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [health, setHealth] = useState<HealthStatus | null>(null);
  
  // Real-time updates
  useEffect(() => {
    const interval = setInterval(async () => {
      const [metricsData, tenantsData, healthData] = await Promise.all([
        apiClient.getMetrics(),
        apiClient.getTenants(),
        apiClient.getHealth(),
      ]);
      
      setMetrics(metricsData);
      setTenants(tenantsData);
      setHealth(healthData);
    }, refreshInterval);
    
    return () => clearInterval(interval);
  }, [apiClient, refreshInterval]);
  
  return (
    <div className="dashboard">
      <MetricsOverview metrics={metrics} />
      <TenantsTable tenants={tenants} />
      <HealthStatus health={health} />
    </div>
  );
};
```

**Dashboard Sections**:
- **Overview**: System-wide metrics and status
- **Tenants**: Per-tenant metrics and configuration
- **System Health**: Component health and performance
- **Configuration**: Runtime configuration management
- **Wiki**: Documentation and troubleshooting guides

### 7. Advanced Security Features

#### Authentication and Authorization

**Description**: Comprehensive security features including authentication, authorization, and audit logging.

**Implementation**:
```go
// Authentication Middleware
type AuthMiddleware struct {
    authenticator Authenticator
    authorizer    Authorizer
}

func (am *AuthMiddleware) Authenticate(r *http.Request) (*User, error) {
    // Extract credentials
    token := extractToken(r)
    
    // Validate token
    user, err := am.authenticator.ValidateToken(token)
    if err != nil {
        return nil, err
    }
    
    return user, nil
}

func (am *AuthMiddleware) Authorize(user *User, resource string, action string) bool {
    return am.authorizer.CheckPermission(user, resource, action)
}
```

**Security Features**:
- **Token-based Authentication**: JWT token validation
- **Role-based Access Control**: Granular permission management
- **Audit Logging**: Complete audit trail of all actions
- **Data Encryption**: Encryption in transit and at rest
- **Rate Limiting**: Protection against abuse

### 8. Performance Optimization

#### High-Performance Architecture

**Description**: Optimized architecture for high throughput and low latency.

**Optimization Techniques**:
- **Connection Pooling**: Efficient connection management
- **Async Processing**: Non-blocking I/O operations
- **Memory Optimization**: Efficient memory usage patterns
- **Caching**: Multi-level caching strategies
- **Load Balancing**: Intelligent load distribution

**Performance Targets**:
- **Latency**: <10ms for rate limiting decisions
- **Throughput**: 100,000+ requests per second
- **Memory**: <2GB per instance
- **CPU**: <20% utilization under normal load

## Feature Benefits

### 1. Cost Control
- **50-70% Cost Reduction**: Significant infrastructure cost savings
- **Resource Optimization**: Efficient resource utilization
- **Predictable Costs**: Transparent cost attribution and billing
- **Budget Management**: Proactive budget control mechanisms

### 2. Service Protection
- **DDoS Protection**: Protection against distributed attacks
- **Resource Isolation**: Tenant isolation prevents resource exhaustion
- **Circuit Breaking**: Automatic failure protection
- **Graceful Degradation**: Maintain service during high load

### 3. Operational Excellence
- **Automated Operations**: Reduced manual intervention
- **Real-time Monitoring**: Comprehensive visibility into system health
- **Proactive Alerting**: Early warning of potential issues
- **Self-healing**: Automatic recovery from failures

### 4. Compliance and Governance
- **Audit Trail**: Complete audit logging for compliance
- **Policy Enforcement**: Automated policy enforcement
- **Data Protection**: Comprehensive data security measures
- **Regulatory Compliance**: Built-in compliance features

## Conclusion

The Mimir Edge Enforcement system provides a comprehensive set of core features that address the critical challenges of modern observability environments:

1. **Advanced Rate Limiting**: Sophisticated rate limiting with selective enforcement
2. **Intelligent Aggregation**: Time-based aggregation with intelligent caching
3. **Real-time Authorization**: Fast, reliable authorization decisions
4. **Dynamic Configuration**: Runtime configuration updates without downtime
5. **Comprehensive Monitoring**: Extensive metrics and health monitoring
6. **Rich Management Interface**: Powerful admin UI for system management
7. **Enterprise Security**: Comprehensive security and compliance features
8. **High Performance**: Optimized for high throughput and low latency

These features work together to provide a robust, scalable, and cost-effective solution for managing observability infrastructure.

---

**Next Steps**:
1. Explore advanced features in `features/advanced-features.md`
2. Review selective traffic routing in `features/selective-traffic-routing.md`
3. Understand time-based aggregation in `features/time-based-aggregation.md`
4. Learn about deployment strategies in `deployment/deployment-strategy.md`

**Related Documents**:
- [Advanced Features](advanced-features.md)
- [Selective Traffic Routing](selective-traffic-routing.md)
- [Time-based Aggregation](time-based-aggregation.md)
- [Rate Limit Service](../components/rate-limit-service.md)

---


## Deployment Strategy


## Overview

The Mimir Edge Enforcement system is designed for zero-risk deployment with comprehensive rollback capabilities. The deployment strategy follows a phased approach that ensures minimal impact on existing services while providing full validation and monitoring capabilities.

## Deployment Phases

### Phase 1: Mirror Mode (Zero Impact)

#### Objective
Deploy the system in shadow mode to validate functionality and collect baseline metrics without any impact on production traffic.

#### Architecture
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Phase 1: Mirror Mode                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Alloy     │───▶│   NGINX     │───▶│   Mimir     │    │             │     │
│  │  (Client)   │    │  (Proxy)    │    │Distributor  │    │             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    │             │     │
│                           │                                │             │     │
│                           ▼                                │             │     │
│                    ┌─────────────┐                        │             │     │
│                    │   Mirror    │                        │             │     │
│                    │   Traffic   │                        │             │     │
│                    └─────────────┘                        │             │     │
│                           │                                │             │     │
│                           ▼                                │             │     │
│                    ┌─────────────┐    ┌─────────────┐    │             │     │
│                    │   Envoy     │───▶│   RLS       │    │             │     │
│                    │ (Shadow)    │    │(Shadow)     │    │             │     │
│                    └─────────────┘    └─────────────┘    │             │     │
│                                                           │             │     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### NGINX Configuration
```nginx
# nginx-mirror.conf
upstream mimir_direct {
    server distributor.mimir.svc.cluster.local:8080;
}

upstream mimirrls {
    server mimirrls.mimir-edge-enforcement.svc.cluster.local:8080;
}

server {
    listen 80;
    
    # Main traffic - direct to Mimir
    location /api/v1/push {
        proxy_pass http://mimir_direct;
        
        # Mirror traffic to Envoy (shadow mode)
        mirror /mirror;
        mirror_request_body on;
    }
    
    # Mirror endpoint - traffic goes to Envoy but response is ignored
    location = /mirror {
        internal;
        proxy_pass http://mimirrls;
        proxy_pass_request_body on;
        proxy_set_header Content-Length "";
        proxy_set_header X-Original-URI $request_uri;
        
        # Ignore response from mirror
        proxy_ignore_client_abort on;
        proxy_ignore_headers X-Accel-*;
    }
}
```

#### Deployment Steps
```bash
# 1. Deploy RLS service
helm install mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set rls.replicas=3 \
  --set rls.config.failureModeAllow=true

# 2. Deploy Envoy proxy
helm install mimir-envoy charts/envoy/ \
  --namespace mimir-edge-enforcement \
  --set envoy.replicas=3

# 3. Deploy overrides-sync controller
helm install overrides-sync charts/overrides-sync/ \
  --namespace mimir-edge-enforcement

# 4. Apply NGINX mirror configuration
kubectl apply -f examples/nginx-mirror.yaml

# 5. Verify deployment
kubectl get pods -n mimir-edge-enforcement
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement
```

#### Validation Criteria
- [ ] All pods are running and healthy
- [ ] RLS service is receiving mirrored traffic
- [ ] No impact on existing Mimir traffic
- [ ] Metrics are being collected
- [ ] Admin UI is accessible and showing data

#### Success Metrics
- **Zero Impact**: 100% of requests reach Mimir distributor
- **Shadow Traffic**: RLS receives mirrored requests
- **System Health**: All components healthy
- **Metrics Collection**: Prometheus metrics populated

### Phase 2: Canary Mode (Gradual Rollout)

#### Objective
Gradually shift traffic from direct Mimir access to Envoy enforcement, starting with a small percentage and monitoring closely.

#### Architecture
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Phase 2: Canary Mode                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Alloy     │───▶│   NGINX     │───▶│   Envoy     │───▶│   Mimir     │     │
│  │  (Client)   │    │  (Proxy)    │    │ (Canary)    │    │Distributor  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘     │
│                           │                   │                                │
│                           ▼                   ▼                                │
│                    ┌─────────────┐    ┌─────────────┐                         │
│                    │   RLS       │    │   RLS       │                         │
│                    │(Canary)     │    │(Canary)     │                         │
│                    └─────────────┘    └─────────────┘                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### NGINX Configuration (10% Canary)
```nginx
# nginx-canary-10.conf
upstream mimir_direct {
    server distributor.mimir.svc.cluster.local:8080;
}

upstream mimirrls {
    server mimirrls.mimir-edge-enforcement.svc.cluster.local:8080;
}

# Split traffic based on request ID hash
split_clients "${request_id}" $backend {
    10%     mimirrls;
    *       mimir_direct;
}

server {
    listen 80;
    
    location /api/v1/push {
        proxy_pass http://$backend;
        
        # Add headers for tracking
        add_header X-Edge-Enforcement $backend;
        add_header X-Canary-Percentage "10%";
    }
}
```

#### Deployment Steps
```bash
# 1. Scale up RLS service for canary traffic
helm upgrade mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set rls.replicas=5 \
  --set rls.config.failureModeAllow=false

# 2. Scale up Envoy proxy
helm upgrade mimir-envoy charts/envoy/ \
  --namespace mimir-edge-enforcement \
  --set envoy.replicas=5

# 3. Apply canary NGINX configuration
kubectl apply -f examples/nginx-canary-10.yaml

# 4. Monitor canary traffic
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement | grep "canary"
```

#### Canary Progression
```bash
# 10% canary
kubectl apply -f examples/nginx-canary-10.yaml

# 25% canary
kubectl apply -f examples/nginx-canary-25.yaml

# 50% canary
kubectl apply -f examples/nginx-canary-50.yaml

# 75% canary
kubectl apply -f examples/nginx-canary-75.yaml

# 100% canary
kubectl apply -f examples/nginx-canary-100.yaml
```

#### Validation Criteria
- [ ] Canary traffic is being routed correctly
- [ ] Error rates are within acceptable limits
- [ ] Latency impact is minimal
- [ ] All tenants are being enforced
- [ ] Rollback capability is tested

#### Success Metrics
- **Error Rate**: <0.1% error rate for canary traffic
- **Latency Impact**: <10ms additional latency
- **Throughput**: No degradation in request processing
- **Enforcement**: All tenant limits being enforced correctly

### Phase 3: Full Mode (Complete Deployment)

#### Objective
Deploy the system in full enforcement mode with all traffic going through Envoy and RLS.

#### Architecture
```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Phase 3: Full Mode                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Alloy     │───▶│   NGINX     │───▶│   Envoy     │───▶│   Mimir     │     │
│  │  (Client)   │    │  (Proxy)    │    │ (Full)      │    │Distributor  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘     │
│                           │                   │                                │
│                           ▼                   ▼                                │
│                    ┌─────────────┐    ┌─────────────┐                         │
│                    │   RLS       │    │   RLS       │                         │
│                    │(Full)       │    │(Full)       │                         │
│                    └─────────────┘    └─────────────┘                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### NGINX Configuration (Full Mode)
```nginx
# nginx-full.conf
upstream mimirrls {
    server mimirrls.mimir-edge-enforcement.svc.cluster.local:8080;
}

server {
    listen 80;
    
    location /api/v1/push {
        proxy_pass http://mimirrls;
        
        # Add headers for tracking
        add_header X-Edge-Enforcement "full";
        add_header X-Deployment-Mode "production";
    }
}
```

#### Deployment Steps
```bash
# 1. Scale to production capacity
helm upgrade mimir-rls charts/mimir-rls/ \
  --namespace mimir-edge-enforcement \
  --set rls.replicas=10 \
  --set rls.config.failureModeAllow=false \
  --set rls.resources.requests.memory=8Gi \
  --set rls.resources.requests.cpu=1000m

# 2. Scale Envoy to production capacity
helm upgrade mimir-envoy charts/envoy/ \
  --namespace mimir-edge-enforcement \
  --set envoy.replicas=10 \
  --set envoy.resources.requests.memory=4Gi \
  --set envoy.resources.requests.cpu=500m

# 3. Apply full NGINX configuration
kubectl apply -f examples/nginx-full.yaml

# 4. Enable HPA for auto-scaling
kubectl apply -f examples/hpa-rls.yaml
kubectl apply -f examples/hpa-envoy.yaml
```

#### Validation Criteria
- [ ] All traffic is going through Envoy
- [ ] All tenant limits are being enforced
- [ ] System performance is stable
- [ ] Monitoring and alerting are working
- [ ] Rollback procedures are documented and tested

#### Success Metrics
- **Full Enforcement**: 100% of traffic through Envoy
- **System Stability**: 99.9% uptime
- **Performance**: <10ms latency impact
- **Compliance**: All tenant limits enforced

## Rollback Procedures

### Emergency Rollback (5 Minutes)

#### Quick Rollback
```bash
# 1. Revert NGINX configuration to direct Mimir access
kubectl apply -f examples/nginx-direct.yaml

# 2. Verify traffic is flowing directly to Mimir
kubectl logs -f deployment/nginx-ingress -n ingress-nginx

# 3. Scale down enforcement components
kubectl scale deployment mimir-rls --replicas=0 -n mimir-edge-enforcement
kubectl scale deployment mimir-envoy --replicas=0 -n mimir-edge-enforcement
```

#### NGINX Direct Configuration
```nginx
# nginx-direct.yaml
upstream mimir_direct {
    server distributor.mimir.svc.cluster.local:8080;
}

server {
    listen 80;
    
    location /api/v1/push {
        proxy_pass http://mimir_direct;
        
        # Add header indicating direct access
        add_header X-Edge-Enforcement "disabled";
        add_header X-Rollback "emergency";
    }
}
```

### Graceful Rollback (30 Minutes)

#### Step-by-Step Rollback
```bash
# 1. Reduce canary percentage gradually
kubectl apply -f examples/nginx-canary-50.yaml
sleep 300  # Wait 5 minutes

kubectl apply -f examples/nginx-canary-25.yaml
sleep 300  # Wait 5 minutes

kubectl apply -f examples/nginx-canary-10.yaml
sleep 300  # Wait 5 minutes

# 2. Switch to mirror mode
kubectl apply -f examples/nginx-mirror.yaml

# 3. Scale down enforcement components
kubectl scale deployment mimir-rls --replicas=3 -n mimir-edge-enforcement
kubectl scale deployment mimir-envoy --replicas=3 -n mimir-edge-enforcement

# 4. Disable enforcement
kubectl patch deployment mimir-rls -p '{"spec":{"template":{"spec":{"containers":[{"name":"rls","env":[{"name":"ENFORCEMENT_DISABLED","value":"true"}]}]}}}}'
```

## Monitoring and Validation

### Pre-Deployment Checks

#### Infrastructure Validation
```bash
# Check cluster resources
kubectl get nodes -o custom-columns="NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory"

# Check namespace resources
kubectl get pods -n mimir-edge-enforcement -o wide

# Check network connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup mimirrls.mimir-edge-enforcement.svc.cluster.local
```

#### Configuration Validation
```bash
# Validate Helm charts
helm lint charts/mimir-rls/
helm lint charts/envoy/
helm lint charts/overrides-sync/

# Dry run deployment
helm install mimir-rls charts/mimir-rls/ --dry-run --debug

# Validate ConfigMaps
kubectl get configmap mimir-overrides -n mimir -o yaml
```

### Post-Deployment Validation

#### Health Checks
```bash
# Check pod health
kubectl get pods -n mimir-edge-enforcement

# Check service health
kubectl get svc -n mimir-edge-enforcement

# Check endpoints
kubectl get endpoints -n mimir-edge-enforcement

# Check logs
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement
kubectl logs -f deployment/mimir-envoy -n mimir-edge-enforcement
```

#### Performance Validation
```bash
# Check resource usage
kubectl top pods -n mimir-edge-enforcement

# Check metrics
curl http://localhost:9090/metrics | grep rls_

# Check API endpoints
curl http://localhost:8082/api/health
curl http://localhost:8082/api/overview
```

#### Traffic Validation
```bash
# Check NGINX logs
kubectl logs -f deployment/nginx-ingress -n ingress-nginx | grep "api/v1/push"

# Check Envoy logs
kubectl logs -f deployment/mimir-envoy -n mimir-edge-enforcement

# Check RLS logs
kubectl logs -f deployment/mimir-rls -n mimir-edge-enforcement | grep "decision"
```

## Configuration Management

### Environment-Specific Configurations

#### Development Environment
```yaml
# values-dev.yaml
global:
  environment: development

rls:
  replicas: 1
  config:
    maxRequestBytes: 10485760  # 10MB
    failureModeAllow: true
  resources:
    requests:
      memory: 1Gi
      cpu: 100m
    limits:
      memory: 2Gi
      cpu: 200m

envoy:
  replicas: 1
  resources:
    requests:
      memory: 512Mi
      cpu: 50m
    limits:
      memory: 1Gi
      cpu: 100m
```

#### Staging Environment
```yaml
# values-staging.yaml
global:
  environment: staging

rls:
  replicas: 3
  config:
    maxRequestBytes: 52428800  # 50MB
    failureModeAllow: false
  resources:
    requests:
      memory: 4Gi
      cpu: 500m
    limits:
      memory: 8Gi
      cpu: 1000m

envoy:
  replicas: 3
  resources:
    requests:
      memory: 2Gi
      cpu: 250m
    limits:
      memory: 4Gi
      cpu: 500m
```

#### Production Environment
```yaml
# values-production.yaml
global:
  environment: production

rls:
  replicas: 10
  config:
    maxRequestBytes: 52428800  # 50MB
    failureModeAllow: false
  resources:
    requests:
      memory: 8Gi
      cpu: 1000m
    limits:
      memory: 16Gi
      cpu: 4000m

envoy:
  replicas: 10
  resources:
    requests:
      memory: 4Gi
      cpu: 500m
    limits:
      memory: 8Gi
      cpu: 2000m
```

### Deployment Commands

#### Development Deployment
```bash
# Deploy to development
helm install mimir-edge-enforcement charts/ \
  --namespace mimir-edge-enforcement \
  -f values-dev.yaml \
  --set global.environment=development
```

#### Staging Deployment
```bash
# Deploy to staging
helm install mimir-edge-enforcement charts/ \
  --namespace mimir-edge-enforcement \
  -f values-staging.yaml \
  --set global.environment=staging
```

#### Production Deployment
```bash
# Deploy to production
helm install mimir-edge-enforcement charts/ \
  --namespace mimir-edge-enforcement \
  -f values-production.yaml \
  --set global.environment=production
```

## Risk Mitigation

### Technical Risks

#### Service Failure
- **Risk**: RLS or Envoy service failure
- **Mitigation**: Configurable failure modes (allow/deny)
- **Monitoring**: Health checks and alerting
- **Recovery**: Automatic restart via Kubernetes

#### Performance Impact
- **Risk**: High latency or throughput degradation
- **Mitigation**: Comprehensive load testing
- **Monitoring**: Real-time performance metrics
- **Recovery**: Auto-scaling and rollback procedures

#### Configuration Errors
- **Risk**: Incorrect tenant limits or enforcement rules
- **Mitigation**: Configuration validation
- **Monitoring**: Configuration drift detection
- **Recovery**: ConfigMap sync and validation

### Operational Risks

#### Deployment Issues
- **Risk**: Failed deployment or configuration
- **Mitigation**: Gradual rollout with rollback capability
- **Monitoring**: Deployment status and health checks
- **Recovery**: Instant rollback procedures

#### Monitoring Gaps
- **Risk**: Insufficient monitoring or alerting
- **Mitigation**: Comprehensive observability
- **Monitoring**: Multi-level monitoring and alerting
- **Recovery**: Manual intervention procedures

#### Security Concerns
- **Risk**: Security vulnerabilities or data exposure
- **Mitigation**: Security hardening and RBAC
- **Monitoring**: Security scanning and audit logs
- **Recovery**: Security incident response procedures

## Success Criteria

### Phase 1 Success Criteria
- [ ] Zero impact on existing Mimir traffic
- [ ] RLS service receiving and processing mirrored traffic
- [ ] All metrics and monitoring working correctly
- [ ] Admin UI accessible and functional

### Phase 2 Success Criteria
- [ ] Canary traffic being processed correctly
- [ ] Error rates within acceptable limits (<0.1%)
- [ ] Latency impact minimal (<10ms)
- [ ] Rollback procedures tested and working

### Phase 3 Success Criteria
- [ ] All traffic going through enforcement
- [ ] System performance stable and acceptable
- [ ] All tenant limits being enforced correctly
- [ ] Monitoring and alerting fully operational

## Conclusion

The deployment strategy provides a comprehensive, risk-mitigated approach to deploying the Mimir Edge Enforcement system. The phased approach ensures minimal impact on existing services while providing full validation and monitoring capabilities.

The rollback procedures ensure that any issues can be quickly addressed, while the monitoring and validation procedures provide confidence in the deployment process. The configuration management approach supports multiple environments and ensures consistent deployments across development, staging, and production.

---

**Next Steps**: Review component-specific deployment guides and monitoring setup procedures.

---


## Conclusion

This comprehensive documentation provides a complete overview of the Mimir Edge Enforcement system, covering all aspects from architecture and design to deployment and operations. The documentation is designed to serve multiple stakeholders including leadership, architects, developers, and operations engineers.

For questions or contributions, please contact the development team or submit a pull request to update this documentation.

---

**Document Version**: 1.0  
**Last Updated**: January 2024  
**Maintainer**: Development Team  
**License**: Apache-2.0

