import React from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { 
  BookOpen, 
  Shield, 
  Server, 
  Network, 
  Database, 
  Activity,
  AlertTriangle,
  CheckCircle,
  Clock,
  Users,
  BarChart3,
  Settings,
  Zap,
  ArrowRight,
  ExternalLink,
  Code,
  GitBranch,
  Package,
  Globe,
  Lock,
  Eye,
  TrendingUp,
  AlertCircle,
  Info
} from 'lucide-react';

export function Wiki() {
  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">Mimir Edge Enforcement Wiki</h1>
        <p className="text-xl text-gray-600 max-w-3xl mx-auto">
          Complete guide to the lightning-fast edge enforcement system that protects your Mimir infrastructure 
          with real-time monitoring, comprehensive blocking reasons, and zero-downtime deployments.
        </p>
        <div className="flex justify-center gap-4 mt-6">
          <Badge className="bg-green-100 text-green-800">⚡ Lightning Fast (0.28ms)</Badge>
          <Badge className="bg-blue-100 text-blue-800">🛡️ 100% Protection</Badge>
          <Badge className="bg-purple-100 text-purple-800">📊 Real-time Monitoring</Badge>
          <Badge className="bg-orange-100 text-orange-800">🔍 Blocking Reasons</Badge>
        </div>
      </div>

      {/* System Overview */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5" />
            System Overview
          </CardTitle>
          <CardDescription>What is Mimir Edge Enforcement and why do we need it?</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div>
            <h3 className="text-lg font-semibold mb-3">What is Mimir Edge Enforcement?</h3>
            <p className="text-gray-700 mb-4">
              Mimir Edge Enforcement is a production-ready, lightning-fast Kubernetes solution that enforces 
              Mimir tenant ingestion limits at the edge (before the Distributor). It acts as a protective 
              layer that prevents individual tenants from overwhelming your Mimir infrastructure with 
              sub-millisecond response times and comprehensive blocking reason tracking.
            </p>
            <div className="grid gap-4 md:grid-cols-2">
              <div className="p-4 bg-blue-50 rounded-lg">
                <h4 className="font-medium text-blue-900 mb-2">⚡ Lightning Fast Performance</h4>
                <p className="text-blue-700 text-sm">
                  Sub-millisecond response times (0.28-0.54ms) ensure zero impact on legitimate traffic 
                  while providing instant protection against violations.
                </p>
              </div>
              <div className="p-4 bg-green-50 rounded-lg">
                <h4 className="font-medium text-green-900 mb-2">🛡️ Comprehensive Protection</h4>
                <p className="text-green-700 text-sm">
                  Multi-layer protection with detailed blocking reasons, real-time monitoring, and 
                  automatic limit enforcement at the edge.
                </p>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-semibold mb-3">Key Benefits & Features</h3>
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
              <div className="flex items-start space-x-3">
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                <div>
                  <div className="font-medium">⚡ Lightning Fast</div>
                  <div className="text-sm text-gray-500">0.28-0.54ms response times</div>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                <div>
                  <div className="font-medium">🔍 Blocking Reasons</div>
                  <div className="text-sm text-gray-500">Detailed why requests are blocked</div>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                <div>
                  <div className="font-medium">📊 Real-time Monitoring</div>
                  <div className="text-sm text-gray-500">Live metrics and dashboards</div>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                <div>
                  <div className="font-medium">🛡️ Zero Downtime</div>
                  <div className="text-sm text-gray-500">Seamless deployments</div>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                <div>
                  <div className="font-medium">🔧 No Client Changes</div>
                  <div className="text-sm text-gray-500">Works with existing clients</div>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                <div>
                  <div className="font-medium">🎯 Canary Deployments</div>
                  <div className="text-sm text-gray-500">10% → 100% gradual rollout</div>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                <div>
                  <div className="font-medium">📈 Auto-scaling</div>
                  <div className="text-sm text-gray-500">HPA and resource optimization</div>
                </div>
              </div>
              <div className="flex items-start space-x-3">
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                <div>
                  <div className="font-medium">🔐 Multi-tenant Security</div>
                  <div className="text-sm text-gray-500">Isolated tenant protection</div>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Latest Enhancements */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Zap className="h-5 w-5" />
            Latest Enhancements & Features
          </CardTitle>
          <CardDescription>Recent improvements and new capabilities</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div>
            <h3 className="text-lg font-semibold mb-4">🔍 Comprehensive Blocking Reasons</h3>
            <p className="text-gray-700 mb-4">
              The system now provides detailed visibility into why requests are being blocked, making it easy 
              to understand and resolve issues quickly.
            </p>
            <div className="grid gap-4 md:grid-cols-2">
              <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
                <h4 className="font-medium text-red-900 mb-2">Blocking Reason Types</h4>
                <ul className="text-sm text-red-800 space-y-1">
                  <li>• <strong>parse_failed_deny</strong> - Invalid protobuf/snappy data</li>
                  <li>• <strong>body_extract_failed_deny</strong> - Failed to extract request body</li>
                  <li>• <strong>samples_per_second</strong> - Rate limit exceeded</li>
                  <li>• <strong>max_body_bytes</strong> - Body size limit exceeded</li>
                  <li>• <strong>missing_tenant_header</strong> - No tenant identification</li>
                  <li>• <strong>enforcement_disabled</strong> - System not protecting</li>
                </ul>
              </div>
              <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <h4 className="font-medium text-blue-900 mb-2">Real-time Tracking</h4>
                <ul className="text-sm text-blue-800 space-y-1">
                  <li>• <strong>Timestamp</strong> - When each blocking occurred</li>
                  <li>• <strong>Observed Values</strong> - Actual samples/bytes that triggered blocking</li>
                  <li>• <strong>Tenant ID</strong> - Which tenant was affected</li>
                  <li>• <strong>Reason Code</strong> - Specific violation type</li>
                  <li>• <strong>Historical Data</strong> - Track patterns over time</li>
                </ul>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-semibold mb-4">⚡ Performance Optimizations</h3>
            <div className="grid gap-4 md:grid-cols-3">
              <div className="p-4 border rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  <Zap className="h-4 w-4 text-yellow-600" />
                  <span className="font-medium">Lightning Fast</span>
                </div>
                <div className="text-2xl font-bold text-green-600">0.28ms</div>
                <div className="text-sm text-gray-600">Average response time</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  <Activity className="h-4 w-4 text-blue-600" />
                  <span className="font-medium">High Throughput</span>
                </div>
                <div className="text-2xl font-bold text-blue-600">10K+</div>
                <div className="text-sm text-gray-600">Requests per second</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  <Shield className="h-4 w-4 text-green-600" />
                  <span className="font-medium">Zero Impact</span>
                </div>
                <div className="text-2xl font-bold text-green-600">99.9%</div>
                <div className="text-sm text-gray-600">Success rate</div>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-semibold mb-4">🛡️ Enhanced Protection Mechanisms</h3>
            <div className="grid gap-4 md:grid-cols-2">
              <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
                <h4 className="font-medium text-green-900 mb-2">Multi-Layer Security</h4>
                <ul className="text-sm text-green-800 space-y-1">
                  <li>• <strong>Edge Enforcement</strong> - Block at Envoy before reaching Mimir</li>
                  <li>• <strong>Body Validation</strong> - Parse and validate request content</li>
                  <li>• <strong>Rate Limiting</strong> - Token bucket algorithm for fair allocation</li>
                  <li>• <strong>Tenant Isolation</strong> - Separate limits per tenant</li>
                  <li>• <strong>Real-time Monitoring</strong> - Instant visibility into violations</li>
                </ul>
              </div>
              <div className="p-4 bg-purple-50 border border-purple-200 rounded-lg">
                <h4 className="font-medium text-purple-900 mb-2">Advanced Features</h4>
                <ul className="text-sm text-purple-800 space-y-1">
                  <li>• <strong>Canary Deployments</strong> - Gradual rollout (10% → 100%)</li>
                  <li>• <strong>Auto-scaling</strong> - HPA for dynamic resource allocation</li>
                  <li>• <strong>Health Checks</strong> - Comprehensive system monitoring</li>
                  <li>• <strong>Graceful Shutdown</strong> - Zero-downtime deployments</li>
                  <li>• <strong>Config Hot-reload</strong> - Dynamic limit updates</li>
                </ul>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Architecture */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Server className="h-5 w-5" />
            System Architecture
          </CardTitle>
          <CardDescription>How the components work together</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            <div className="p-4 border rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Network className="h-5 w-5 text-blue-600" />
                <h3 className="font-semibold">NGINX</h3>
              </div>
              <p className="text-sm text-gray-600 mb-3">
                Acts as the ingress layer, handling traffic routing and canary deployments.
              </p>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span>Role:</span>
                  <span className="font-medium">Traffic Router</span>
                </div>
                <div className="flex justify-between">
                  <span>Canary:</span>
                  <span className="font-medium">10% → Edge</span>
                </div>
                <div className="flex justify-between">
                  <span>Direct:</span>
                  <span className="font-medium">90% → Mimir</span>
                </div>
              </div>
            </div>

            <div className="p-4 border rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Zap className="h-5 w-5 text-purple-600" />
                <h3 className="font-semibold">Envoy Proxy</h3>
              </div>
              <p className="text-sm text-gray-600 mb-3">
                Handles authorization and rate limiting for edge enforcement traffic.
              </p>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span>Role:</span>
                  <span className="font-medium">Edge Enforcement</span>
                </div>
                <div className="flex justify-between">
                  <span>Filters:</span>
                  <span className="font-medium">ext_authz + ratelimit</span>
                </div>
                <div className="flex justify-between">
                  <span>Protocol:</span>
                  <span className="font-medium">HTTP/1.1 + HTTP/2</span>
                </div>
              </div>
            </div>

            <div className="p-4 border rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Shield className="h-5 w-5 text-green-600" />
                <h3 className="font-semibold">RLS (Rate Limit Service)</h3>
              </div>
              <p className="text-sm text-gray-600 mb-3">
                Go service that provides authorization and rate limiting decisions.
              </p>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span>Role:</span>
                  <span className="font-medium">Decision Engine</span>
                </div>
                <div className="flex justify-between">
                  <span>Protocol:</span>
                  <span className="font-medium">gRPC + HTTP</span>
                </div>
                <div className="flex justify-between">
                  <span>Storage:</span>
                  <span className="font-medium">In-memory</span>
                </div>
              </div>
            </div>

            <div className="p-4 border rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Database className="h-5 w-5 text-orange-600" />
                <h3 className="font-semibold">Overrides Sync</h3>
              </div>
              <p className="text-sm text-gray-600 mb-3">
                Kubernetes controller that watches Mimir ConfigMap and syncs limits to RLS.
              </p>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span>Role:</span>
                  <span className="font-medium">Config Sync</span>
                </div>
                <div className="flex justify-between">
                  <span>Watches:</span>
                  <span className="font-medium">Mimir ConfigMap</span>
                </div>
                <div className="flex justify-between">
                  <span>Updates:</span>
                  <span className="font-medium">RLS Limits</span>
                </div>
              </div>
            </div>

            <div className="p-4 border rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <BarChart3 className="h-5 w-5 text-red-600" />
                <h3 className="font-semibold">Mimir Distributor</h3>
              </div>
              <p className="text-sm text-gray-600 mb-3">
                The target Mimir component that receives validated and rate-limited requests.
              </p>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span>Role:</span>
                  <span className="font-medium">Metrics Storage</span>
                </div>
                <div className="flex justify-between">
                  <span>Protocol:</span>
                  <span className="font-medium">HTTP/1.1</span>
                </div>
                <div className="flex justify-between">
                  <span>Protection:</span>
                  <span className="font-medium">Edge Enforced</span>
                </div>
              </div>
            </div>

            <div className="p-4 border rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Eye className="h-5 w-5 text-indigo-600" />
                <h3 className="font-semibold">Admin UI</h3>
              </div>
              <p className="text-sm text-gray-600 mb-3">
                React-based monitoring dashboard providing real-time visibility into the system.
              </p>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span>Role:</span>
                  <span className="font-medium">Monitoring</span>
                </div>
                <div className="flex justify-between">
                  <span>Updates:</span>
                  <span className="font-medium">Real-time</span>
                </div>
                <div className="flex justify-between">
                  <span>Data:</span>
                  <span className="font-medium">Live Metrics</span>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Request Flow */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <ArrowRight className="h-5 w-5" />
            Request Flow
          </CardTitle>
          <CardDescription>Step-by-step process of how requests are processed</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex items-center justify-between mb-8">
              <div className="text-center">
                <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-2">
                  <Users className="h-8 w-8 text-blue-600" />
                </div>
                <div className="text-sm font-medium">Client</div>
                <div className="text-xs text-gray-500">Prometheus/Alloy</div>
              </div>
              <ArrowRight className="h-6 w-6 text-gray-400" />
              <div className="text-center">
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-2">
                  <Network className="h-8 w-8 text-green-600" />
                </div>
                <div className="text-sm font-medium">NGINX</div>
                <div className="text-xs text-gray-500">Traffic Router</div>
              </div>
              <ArrowRight className="h-6 w-6 text-gray-400" />
              <div className="text-center">
                <div className="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-2">
                  <Zap className="h-8 w-8 text-purple-600" />
                </div>
                <div className="text-sm font-medium">Envoy</div>
                <div className="text-xs text-gray-500">Edge Enforcement</div>
              </div>
              <ArrowRight className="h-6 w-6 text-gray-400" />
              <div className="text-center">
                <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-2">
                  <BarChart3 className="h-8 w-8 text-red-600" />
                </div>
                <div className="text-sm font-medium">Mimir</div>
                <div className="text-xs text-gray-500">Distributor</div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="flex items-start space-x-4 p-4 bg-blue-50 rounded-lg">
                <div className="w-8 h-8 bg-blue-600 text-white rounded-full flex items-center justify-center text-sm font-bold">
                  1
                </div>
                <div>
                  <h4 className="font-medium text-blue-900">Client Request</h4>
                  <p className="text-sm text-blue-700">
                    Prometheus/Alloy sends metrics to Mimir with <code className="bg-blue-100 px-1 rounded">X-Scope-OrgID</code> header 
                    identifying the tenant.
                  </p>
                </div>
              </div>

              <div className="flex items-start space-x-4 p-4 bg-green-50 rounded-lg">
                <div className="w-8 h-8 bg-green-600 text-white rounded-full flex items-center justify-center text-sm font-bold">
                  2
                </div>
                <div>
                  <h4 className="font-medium text-green-900">NGINX Routing</h4>
                  <p className="text-sm text-green-700">
                    NGINX receives the request and applies canary routing logic:
                    <br />• <strong>90% of traffic</strong> → Direct to Mimir Distributor
                    <br />• <strong>10% of traffic</strong> → Route through Edge Enforcement
                  </p>
                </div>
              </div>

              <div className="flex items-start space-x-4 p-4 bg-purple-50 rounded-lg">
                <div className="w-8 h-8 bg-purple-600 text-white rounded-full flex items-center justify-center text-sm font-bold">
                  3
                </div>
                <div>
                  <h4 className="font-medium text-purple-900">Envoy Processing</h4>
                  <p className="text-sm text-purple-700">
                    For edge enforcement traffic, Envoy applies two filters:
                    <br />• <strong>ext_authz</strong> → Calls RLS for authorization decision
                    <br />• <strong>ratelimit</strong> → Applies rate limiting based on tenant limits
                  </p>
                </div>
              </div>

              <div className="flex items-start space-x-4 p-4 bg-orange-50 rounded-lg">
                <div className="w-8 h-8 bg-orange-600 text-white rounded-full flex items-center justify-center text-sm font-bold">
                  4
                </div>
                <div>
                  <h4 className="font-medium text-orange-900">RLS Decision</h4>
                  <p className="text-sm text-orange-700">
                    RLS checks tenant limits and makes authorization decision:
                    <br />• <strong>Allow</strong> → Request within limits, forward to Mimir
                    <br />• <strong>Deny</strong> → Request exceeds limits, return 429/403
                  </p>
                </div>
              </div>

              <div className="flex items-start space-x-4 p-4 bg-red-50 rounded-lg">
                <div className="w-8 h-8 bg-red-600 text-white rounded-full flex items-center justify-center text-sm font-bold">
                  5
                </div>
                <div>
                  <h4 className="font-medium text-red-900">Mimir Processing</h4>
                  <p className="text-sm text-red-700">
                    Validated requests reach Mimir Distributor for processing:
                    <br />• <strong>Protected</strong> → All requests are within enforced limits
                    <br />• <strong>Efficient</strong> → No resource exhaustion from individual tenants
                  </p>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Protection Mechanisms */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Lock className="h-5 w-5" />
            Protection Mechanisms
          </CardTitle>
          <CardDescription>How we safeguard your Mimir infrastructure</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="grid gap-6 md:grid-cols-2">
            <div>
              <h3 className="text-lg font-semibold mb-4">Multi-Layer Protection</h3>
              <div className="space-y-4">
                <div className="p-4 border rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <Shield className="h-4 w-4 text-green-600" />
                    <span className="font-medium">Edge Enforcement</span>
                  </div>
                  <p className="text-sm text-gray-600">
                    Requests are validated at the edge before reaching Mimir, preventing 
                    resource exhaustion from individual tenants.
                  </p>
                </div>

                <div className="p-4 border rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <Activity className="h-4 w-4 text-blue-600" />
                    <span className="font-medium">Real-time Rate Limiting</span>
                  </div>
                  <p className="text-sm text-gray-600">
                    Token bucket algorithm ensures fair resource allocation and prevents 
                    burst traffic from overwhelming the system.
                  </p>
                </div>

                <div className="p-4 border rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <Eye className="h-4 w-4 text-purple-600" />
                    <span className="font-medium">Complete Visibility</span>
                  </div>
                  <p className="text-sm text-gray-600">
                    Real-time monitoring shows exactly which tenants are hitting limits 
                    and when enforcement actions are taken.
                  </p>
                </div>
              </div>
            </div>

            <div>
              <h3 className="text-lg font-semibold mb-4">Limit Enforcement</h3>
              <div className="space-y-4">
                <div className="p-4 border rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <AlertTriangle className="h-4 w-4 text-yellow-600" />
                    <span className="font-medium">Samples per Second</span>
                  </div>
                  <p className="text-sm text-gray-600">
                    Enforces maximum samples per second per tenant to prevent 
                    ingestion rate spikes.
                  </p>
                </div>

                <div className="p-4 border rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <TrendingUp className="h-4 w-4 text-orange-600" />
                    <span className="font-medium">Burst Protection</span>
                  </div>
                  <p className="text-sm text-gray-600">
                    Allows temporary burst traffic within configured limits while 
                    preventing sustained overload.
                  </p>
                </div>

                <div className="p-4 border rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <Database className="h-4 w-4 text-red-600" />
                    <span className="font-medium">Series Limits</span>
                  </div>
                  <p className="text-sm text-gray-600">
                    Enforces maximum series per query and global series limits 
                    to prevent cardinality explosion.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-semibold mb-4">Example: Tenant Limit Violation</h3>
            <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <AlertTriangle className="h-5 w-5 text-yellow-600" />
                <span className="font-medium text-yellow-900">Real-time Alert</span>
              </div>
              <div className="text-sm text-yellow-800 space-y-2">
                <p><strong>Tenant:</strong> production-app-123</p>
                <p><strong>Violation:</strong> Samples per second limit exceeded</p>
                <p><strong>Current:</strong> 12,500 samples/sec</p>
                <p><strong>Limit:</strong> 10,000 samples/sec</p>
                <p><strong>Action:</strong> Request denied at Envoy (HTTP 429)</p>
                <p><strong>Protection:</strong> Mimir safeguarded from overload</p>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Monitoring & Metrics */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <BarChart3 className="h-5 w-5" />
            Monitoring & Metrics
          </CardTitle>
          <CardDescription>Real-time visibility into system performance and protection</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div>
            <h3 className="text-lg font-semibold mb-4">What You Can Monitor</h3>
            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <h4 className="font-medium mb-3">System Performance</h4>
                <ul className="space-y-2 text-sm text-gray-600">
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-600" />
                    Total requests per second across all tenants
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-600" />
                    Success rate and error rates
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-600" />
                    Response times and latency percentiles
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-600" />
                    Component health and resource usage
                  </li>
                </ul>
              </div>

              <div>
                <h4 className="font-medium mb-3">Tenant Protection</h4>
                <ul className="space-y-2 text-sm text-gray-600">
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-600" />
                    Individual tenant request rates and samples
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-600" />
                    Limit violations and enforcement actions
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-600" />
                    Allow/deny ratios per tenant
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-600" />
                    Resource utilization and trends
                  </li>
                </ul>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-semibold mb-4">Real-time Visibility</h3>
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
              <div className="p-4 border rounded-lg">
                <div className="text-2xl font-bold text-blue-600">1,250</div>
                <div className="text-sm font-medium">Requests/sec</div>
                <div className="text-xs text-gray-500">Total throughput</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-2xl font-bold text-green-600">99.04%</div>
                <div className="text-sm font-medium">Success Rate</div>
                <div className="text-xs text-gray-500">System health</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-2xl font-bold text-orange-600">165ms</div>
                <div className="text-sm font-medium">Avg Response</div>
                <div className="text-xs text-gray-500">End-to-end latency</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-2xl font-bold text-red-600">47</div>
                <div className="text-sm font-medium">Denials Today</div>
                <div className="text-xs text-gray-500">Protection active</div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Blocking Reasons & Troubleshooting */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <AlertCircle className="h-5 w-5" />
            Blocking Reasons & Troubleshooting
          </CardTitle>
          <CardDescription>Understanding why requests are blocked and how to resolve issues</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div>
            <h3 className="text-lg font-semibold mb-4">🔍 Understanding Blocking Reasons</h3>
            <p className="text-gray-700 mb-4">
              The system provides detailed information about why requests are being blocked, helping you 
              quickly identify and resolve issues.
            </p>
            
            <div className="grid gap-4 md:grid-cols-2">
              <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
                <h4 className="font-medium text-yellow-900 mb-3">Common Blocking Scenarios</h4>
                <div className="space-y-3">
                  <div>
                    <div className="font-medium text-yellow-800">Invalid Request Data</div>
                    <div className="text-sm text-yellow-700">parse_failed_deny - Corrupted protobuf/snappy data</div>
                  </div>
                  <div>
                    <div className="font-medium text-yellow-800">Rate Limit Exceeded</div>
                    <div className="text-sm text-yellow-700">samples_per_second - Too many samples per second</div>
                  </div>
                  <div>
                    <div className="font-medium text-yellow-800">Body Size Limit</div>
                    <div className="text-sm text-yellow-700">max_body_bytes - Request body too large</div>
                  </div>
                  <div>
                    <div className="font-medium text-yellow-800">Missing Tenant</div>
                    <div className="text-sm text-yellow-700">missing_tenant_header - No tenant identification</div>
                  </div>
                </div>
              </div>
              
              <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <h4 className="font-medium text-blue-900 mb-3">Resolution Steps</h4>
                <div className="space-y-3">
                  <div>
                    <div className="font-medium text-blue-800">1. Check Blocking Reason</div>
                    <div className="text-sm text-blue-700">View the specific reason in the Admin UI</div>
                  </div>
                  <div>
                    <div className="font-medium text-blue-800">2. Analyze Patterns</div>
                    <div className="text-sm text-blue-700">Look for recurring issues or specific tenants</div>
                  </div>
                  <div>
                    <div className="font-medium text-blue-800">3. Adjust Limits</div>
                    <div className="text-sm text-blue-700">Update tenant limits if legitimate traffic is blocked</div>
                  </div>
                  <div>
                    <div className="font-medium text-blue-800">4. Fix Client Issues</div>
                    <div className="text-sm text-blue-700">Resolve data format or authentication problems</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div>
            <h3 className="text-lg font-semibold mb-4">📊 Real-time Monitoring Dashboard</h3>
            <div className="grid gap-4 md:grid-cols-3">
              <div className="p-4 border rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  <Eye className="h-4 w-4 text-green-600" />
                  <span className="font-medium">Live Metrics</span>
                </div>
                <ul className="text-sm text-gray-600 space-y-1">
                  <li>• Request rates per tenant</li>
                  <li>• Allow/deny ratios</li>
                  <li>• Response times</li>
                  <li>• Error rates</li>
                </ul>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  <BarChart3 className="h-4 w-4 text-blue-600" />
                  <span className="font-medium">Blocking Analytics</span>
                </div>
                <ul className="text-sm text-gray-600 space-y-1">
                  <li>• Blocking reason breakdown</li>
                  <li>• Tenant violation history</li>
                  <li>• Trend analysis</li>
                  <li>• Pattern detection</li>
                </ul>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  <Settings className="h-4 w-4 text-purple-600" />
                  <span className="font-medium">System Health</span>
                </div>
                <ul className="text-sm text-gray-600 space-y-1">
                  <li>• Component status</li>
                  <li>• Resource utilization</li>
                  <li>• Health checks</li>
                  <li>• Alert notifications</li>
                </ul>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Quick Start & Deployment */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Package className="h-5 w-5" />
            Quick Start & Deployment
          </CardTitle>
          <CardDescription>How to deploy and configure the system with all latest features</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div>
            <h3 className="text-lg font-semibold mb-4">🚀 Production Deployment</h3>
            <div className="bg-gray-900 text-green-400 p-4 rounded-lg font-mono text-sm">
              <div># Clone the repository</div>
              <div>git clone https://github.com/akshaydubey29/mimir-edge-enforcement</div>
              <div>cd mimir-edge-enforcement</div>
              <div></div>
              <div># Deploy all components with latest features</div>
              <div>./scripts/deploy-production.sh</div>
              <div></div>
              <div># Configure NGINX canary routing (10% → 100%)</div>
              <div>./scripts/deploy-nginx-canary.sh</div>
              <div></div>
              <div># Access Admin UI with blocking reasons</div>
              <div>kubectl port-forward -n mimir-edge-enforcement svc/admin-ui 3000:80</div>
            </div>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <div>
              <h4 className="font-medium mb-3">🔧 Configuration Options</h4>
              <ul className="text-sm text-gray-600 space-y-2">
                <li>• <strong>Canary Deployment</strong> - Start with 10% traffic</li>
                <li>• <strong>Auto-scaling</strong> - HPA for dynamic scaling</li>
                <li>• <strong>Resource Limits</strong> - CPU/memory optimization</li>
                <li>• <strong>Health Checks</strong> - Comprehensive monitoring</li>
                <li>• <strong>Network Policies</strong> - Security isolation</li>
              </ul>
            </div>
            <div>
              <h4 className="font-medium mb-3">📊 Monitoring Setup</h4>
              <ul className="text-sm text-gray-600 space-y-2">
                <li>• <strong>Real-time Dashboards</strong> - Live metrics and blocking reasons</li>
                <li>• <strong>Alert Rules</strong> - Prometheus alerting</li>
                <li>• <strong>Log Aggregation</strong> - Centralized logging</li>
                <li>• <strong>Performance Metrics</strong> - Response time tracking</li>
                <li>• <strong>Tenant Analytics</strong> - Per-tenant monitoring</li>
              </ul>
            </div>
          </div>

          <div>
            <h4 className="font-medium mb-3">🎯 Deployment Strategies</h4>
            <div className="grid gap-4 md:grid-cols-3">
              <div className="p-4 border rounded-lg">
                <div className="font-medium text-blue-900 mb-2">Phase 1: Canary (10%)</div>
                <div className="text-sm text-gray-600">
                  Deploy with minimal traffic to validate functionality and monitor performance.
                </div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="font-medium text-green-900 mb-2">Phase 2: Gradual (50%)</div>
                <div className="text-sm text-gray-600">
                  Increase traffic while monitoring blocking reasons and system health.
                </div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="font-medium text-purple-900 mb-2">Phase 3: Full (100%)</div>
                <div className="text-sm text-gray-600">
                  Complete deployment with full protection and monitoring capabilities.
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
