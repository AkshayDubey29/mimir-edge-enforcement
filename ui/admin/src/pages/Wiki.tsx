import React, { useState, useEffect } from 'react';
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
  Info,
  Play,
  Pause,
  RotateCcw
} from 'lucide-react';

// Interactive Architecture Flow Component
function ArchitectureFlow() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentStep, setCurrentStep] = useState(0);
  const [showDetails, setShowDetails] = useState(false);

  const steps = [
    {
      id: 1,
      title: "Client Request",
      description: "Prometheus/Alloy sends metrics with X-Scope-OrgID header",
      icon: Users,
      color: "bg-blue-500",
      details: "Metrics data with tenant identification header"
    },
    {
      id: 2,
      title: "NGINX Router",
      description: "Canary routing: 90% direct, 10% edge enforcement",
      icon: Network,
      color: "bg-green-500",
      details: "Traffic distribution based on canary configuration"
    },
    {
      id: 3,
      title: "Envoy Proxy",
      description: "Ext_authz + ratelimit filters for edge enforcement",
      icon: Zap,
      color: "bg-purple-500",
      details: "Authorization and rate limiting decisions"
    },
    {
      id: 4,
      title: "RLS Service",
      description: "Lightning-fast decision engine (0.28ms)",
      icon: Shield,
      color: "bg-orange-500",
      details: "Token bucket algorithm with tenant limits"
    },
    {
      id: 5,
      title: "Mimir Distributor",
      description: "Protected metrics ingestion",
      icon: Database,
      color: "bg-red-500",
      details: "Validated requests within enforced limits"
    }
  ];

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (isPlaying) {
      interval = setInterval(() => {
        setCurrentStep((prev) => (prev + 1) % steps.length);
      }, 2000);
    }
    return () => clearInterval(interval);
  }, [isPlaying, steps.length]);

  const handlePlayPause = () => {
    setIsPlaying(!isPlaying);
  };

  const handleReset = () => {
    setCurrentStep(0);
    setIsPlaying(false);
  };

  return (
    <div className="space-y-6">
      {/* Controls */}
      <div className="flex items-center justify-center gap-4 mb-6">
        <button
          onClick={handlePlayPause}
          className="flex items-center gap-2 px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
        >
          {isPlaying ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" />}
          {isPlaying ? 'Pause' : 'Play'} Animation
        </button>
        <button
          onClick={handleReset}
          className="flex items-center gap-2 px-4 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition-colors"
        >
          <RotateCcw className="h-4 w-4" />
          Reset
        </button>
        <button
          onClick={() => setShowDetails(!showDetails)}
          className="flex items-center gap-2 px-4 py-2 bg-purple-500 text-white rounded-lg hover:bg-purple-600 transition-colors"
        >
          <Info className="h-4 w-4" />
          {showDetails ? 'Hide' : 'Show'} Details
        </button>
      </div>

      {/* Flow Diagram */}
      <div className="relative">
        {/* Connection Lines */}
        <svg className="absolute inset-0 w-full h-full pointer-events-none">
          {steps.map((step, index) => {
            if (index === steps.length - 1) return null;
            const isActive = currentStep >= index;
            return (
              <g key={`line-${index}`}>
                <line
                  x1={`${(index + 1) * 20}%`}
                  y1="50%"
                  x2={`${(index + 2) * 20}%`}
                  y2="50%"
                  stroke={isActive ? "#3b82f6" : "#e5e7eb"}
                  strokeWidth="3"
                  strokeDasharray={isActive ? "none" : "5,5"}
                  className="transition-all duration-1000"
                />
                {isActive && (
                  <circle
                    cx={`${(index + 1.5) * 20}%`}
                    cy="50%"
                    r="4"
                    fill="#3b82f6"
                    className="animate-pulse"
                  />
                )}
              </g>
            );
          })}
        </svg>

        {/* Steps */}
        <div className="flex justify-between items-center relative z-10">
          {steps.map((step, index) => {
            const isActive = currentStep === index;
            const isCompleted = currentStep > index;
            const Icon = step.icon;
            
            return (
              <div key={step.id} className="flex flex-col items-center">
                <div
                  className={`w-16 h-16 rounded-full flex items-center justify-center transition-all duration-500 ${
                    isActive 
                      ? `${step.color} text-white scale-110 shadow-lg` 
                      : isCompleted 
                        ? `${step.color} text-white` 
                        : 'bg-gray-200 text-gray-500'
                  }`}
                >
                  <Icon className="h-8 w-8" />
                </div>
                <div className="mt-3 text-center max-w-32">
                  <div className={`font-medium text-sm ${
                    isActive ? 'text-blue-600' : 'text-gray-600'
                  }`}>
                    {step.title}
                  </div>
                  {showDetails && (
                    <div className="text-xs text-gray-500 mt-1">
                      {step.description}
                    </div>
                  )}
                </div>
                {isActive && (
                  <div className="mt-2 px-3 py-2 bg-blue-50 border border-blue-200 rounded-lg text-xs text-blue-800 max-w-48">
                    {step.details}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Performance Metrics */}
      <div className="grid grid-cols-3 gap-4 mt-8">
        <div className="text-center p-4 bg-green-50 rounded-lg">
          <div className="text-2xl font-bold text-green-600">0.28ms</div>
          <div className="text-sm text-green-800">RLS Response Time</div>
        </div>
        <div className="text-center p-4 bg-blue-50 rounded-lg">
          <div className="text-2xl font-bold text-blue-600">10K+</div>
          <div className="text-sm text-blue-800">Requests/sec</div>
        </div>
        <div className="text-center p-4 bg-purple-50 rounded-lg">
          <div className="text-2xl font-bold text-purple-600">99.9%</div>
          <div className="text-sm text-purple-800">Success Rate</div>
        </div>
      </div>

      {/* Traffic Flow Visualization */}
      <div className="mt-8">
        <h4 className="font-medium mb-4">Traffic Flow Distribution</h4>
        <div className="flex items-center justify-center gap-8">
          <div className="text-center">
            <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mb-2">
              <div className="text-2xl font-bold text-green-600">90%</div>
            </div>
            <div className="text-sm text-gray-600">Direct to Mimir</div>
          </div>
          <ArrowRight className="h-6 w-6 text-gray-400" />
          <div className="text-center">
            <div className="w-20 h-20 bg-blue-100 rounded-full flex items-center justify-center mb-2">
              <div className="text-2xl font-bold text-blue-600">10%</div>
            </div>
            <div className="text-sm text-gray-600">Edge Enforcement</div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Technical Architecture Component
function TechnicalArchitecture() {
  const [selectedComponent, setSelectedComponent] = useState<string | null>(null);

  const components = [
    {
      id: 'nginx',
      name: 'NGINX Ingress',
      description: 'Traffic routing and canary deployment',
      details: {
        role: 'Traffic Router',
        protocol: 'HTTP/1.1, HTTP/2',
        features: ['Canary Routing', 'SSL Termination', 'Load Balancing'],
        config: 'nginx.ingress.kubernetes.io/rewrite-target: /'
      },
      color: 'bg-green-500',
      icon: Network
    },
    {
      id: 'envoy',
      name: 'Envoy Proxy',
      description: 'Edge enforcement with ext_authz and ratelimit',
      details: {
        role: 'Edge Enforcement',
        protocol: 'gRPC, HTTP/1.1',
        features: ['ext_authz Filter', 'ratelimit Filter', 'Circuit Breakers'],
        config: 'envoy.filters.http.ext_authz'
      },
      color: 'bg-purple-500',
      icon: Zap
    },
    {
      id: 'rls',
      name: 'RLS Service',
      description: 'Lightning-fast authorization and rate limiting',
      details: {
        role: 'Decision Engine',
        protocol: 'gRPC, HTTP/2',
        features: ['Token Bucket', 'Tenant Limits', 'Real-time Metrics'],
        config: 'envoy.service.auth.v3.Authorization'
      },
      color: 'bg-orange-500',
      icon: Shield
    },
    {
      id: 'overrides',
      name: 'Overrides Sync',
      description: 'Kubernetes controller for limit synchronization',
      details: {
        role: 'Config Sync',
        protocol: 'HTTP/1.1',
        features: ['ConfigMap Watcher', 'Limit Sync', 'Health Checks'],
        config: 'mimir-overrides ConfigMap'
      },
      color: 'bg-blue-500',
      icon: Settings
    },
    {
      id: 'mimir',
      name: 'Mimir Distributor',
      description: 'Protected metrics ingestion endpoint',
      details: {
        role: 'Metrics Storage',
        protocol: 'HTTP/1.1',
        features: ['Remote Write', 'Tenant Isolation', 'Series Limits'],
        config: '/api/v1/push'
      },
      color: 'bg-red-500',
      icon: Database
    },
    {
      id: 'admin',
      name: 'Admin UI',
      description: 'Real-time monitoring and management',
      details: {
        role: 'Monitoring Dashboard',
        protocol: 'HTTP/1.1',
        features: ['Live Metrics', 'Blocking Reasons', 'Tenant Management'],
        config: 'React + TypeScript'
      },
      color: 'bg-indigo-500',
      icon: Eye
    }
  ];

  return (
    <div className="space-y-6">
      {/* Component Grid */}
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
        {components.map((component) => {
          const Icon = component.icon;
          const isSelected = selectedComponent === component.id;
          
          return (
            <div
              key={component.id}
              onClick={() => setSelectedComponent(isSelected ? null : component.id)}
              className={`p-4 border rounded-lg cursor-pointer transition-all duration-300 ${
                isSelected 
                  ? 'border-blue-500 bg-blue-50 shadow-lg' 
                  : 'border-gray-200 hover:border-gray-300 hover:shadow-md'
              }`}
            >
              <div className="flex items-center gap-3 mb-3">
                <div className={`w-10 h-10 rounded-full ${component.color} flex items-center justify-center`}>
                  <Icon className="h-5 w-5 text-white" />
                </div>
                <div>
                  <div className="font-medium text-gray-900">{component.name}</div>
                  <div className="text-sm text-gray-500">{component.description}</div>
                </div>
              </div>
              
              {isSelected && (
                <div className="mt-4 space-y-3 text-sm">
                  <div>
                    <div className="font-medium text-gray-700">Role:</div>
                    <div className="text-gray-600">{component.details.role}</div>
                  </div>
                  <div>
                    <div className="font-medium text-gray-700">Protocol:</div>
                    <div className="text-gray-600">{component.details.protocol}</div>
                  </div>
                  <div>
                    <div className="font-medium text-gray-700">Features:</div>
                    <ul className="text-gray-600 list-disc list-inside">
                      {component.details.features.map((feature, index) => (
                        <li key={index}>{feature}</li>
                      ))}
                    </ul>
                  </div>
                  <div>
                    <div className="font-medium text-gray-700">Config:</div>
                    <code className="text-xs bg-gray-100 px-2 py-1 rounded">
                      {component.details.config}
                    </code>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Data Flow Diagram */}
      <div className="mt-8">
        <h4 className="font-medium mb-4">Data Flow & Communication</h4>
        <div className="bg-gray-50 p-6 rounded-lg">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div>
              <h5 className="font-medium text-gray-900 mb-3">Request Flow</h5>
              <div className="space-y-2 text-sm">
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
                  <span>Client → NGINX (HTTP/1.1)</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span>NGINX → Envoy (HTTP/1.1)</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-purple-500 rounded-full"></div>
                  <span>Envoy → RLS (gRPC)</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
                  <span>RLS → Envoy (gRPC Response)</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-red-500 rounded-full"></div>
                  <span>Envoy → Mimir (HTTP/1.1)</span>
                </div>
              </div>
            </div>
            <div>
              <h5 className="font-medium text-gray-900 mb-3">Configuration Flow</h5>
              <div className="space-y-2 text-sm">
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
                  <span>ConfigMap → Overrides Sync</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span>Overrides Sync → RLS (HTTP)</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-purple-500 rounded-full"></div>
                  <span>RLS → Admin UI (HTTP)</span>
                </div>
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
                  <span>Admin UI → User (WebSocket)</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Performance Characteristics */}
      <div className="mt-8">
        <h4 className="font-medium mb-4">Performance Characteristics</h4>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="text-center p-4 bg-green-50 rounded-lg">
            <div className="text-lg font-bold text-green-600">0.28ms</div>
            <div className="text-xs text-green-800">RLS Decision Time</div>
          </div>
          <div className="text-center p-4 bg-blue-50 rounded-lg">
            <div className="text-lg font-bold text-blue-600">10K+</div>
            <div className="text-xs text-blue-800">Requests/sec</div>
          </div>
          <div className="text-center p-4 bg-purple-50 rounded-lg">
            <div className="text-lg font-bold text-purple-600">99.9%</div>
            <div className="text-xs text-purple-800">Availability</div>
          </div>
          <div className="text-center p-4 bg-orange-50 rounded-lg">
            <div className="text-lg font-bold text-orange-600">&lt;1ms</div>
            <div className="text-xs text-orange-800">End-to-End Latency</div>
          </div>
        </div>
      </div>
    </div>
  );
}

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

      {/* Interactive Architecture Flow */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Network className="h-5 w-5" />
            Interactive Architecture Flow
          </CardTitle>
          <CardDescription>See how requests flow through the system in real-time</CardDescription>
        </CardHeader>
        <CardContent>
          <ArchitectureFlow />
        </CardContent>
      </Card>

      {/* Technical Architecture Diagram */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Server className="h-5 w-5" />
            Technical Architecture Details
          </CardTitle>
          <CardDescription>Detailed component interactions and data flow</CardDescription>
        </CardHeader>
        <CardContent>
          <TechnicalArchitecture />
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

      {/* Comprehensive Blocking Reasons */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5" />
            Comprehensive Blocking Reasons Guide
          </CardTitle>
          <CardDescription>Complete reference of all blocking reasons with explanations and examples</CardDescription>
        </CardHeader>
        <CardContent className="space-y-8">
          {/* Overview */}
          <div>
            <h3 className="text-lg font-semibold mb-4">🔍 Understanding Blocking Reasons</h3>
            <p className="text-gray-700 mb-4">
              Mimir Edge Enforcement provides detailed blocking reasons to help you understand exactly why requests 
              are being denied. Each blocking reason includes specific information about the violation, observed values, 
              and recommendations for resolution.
            </p>
            <div className="grid gap-4 md:grid-cols-3">
              <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <h4 className="font-medium text-blue-900 mb-2">📊 Real-time Visibility</h4>
                <p className="text-sm text-blue-800">
                  See exactly why requests are blocked with detailed metrics and timestamps
                </p>
              </div>
              <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
                <h4 className="font-medium text-green-900 mb-2">🎯 Specific Actions</h4>
                <p className="text-sm text-green-800">
                  Each reason provides clear guidance on how to resolve the issue
                </p>
              </div>
              <div className="p-4 bg-purple-50 border border-purple-200 rounded-lg">
                <h4 className="font-medium text-purple-900 mb-2">📈 Historical Tracking</h4>
                <p className="text-sm text-purple-800">
                  Track blocking patterns over time to identify trends and optimize limits
                </p>
              </div>
            </div>
          </div>

          {/* Rate Limiting Blocking Reasons */}
          <div>
            <h3 className="text-lg font-semibold mb-4">⚡ Rate Limiting Blocking Reasons</h3>
            <div className="space-y-4">
              <div className="p-4 border border-red-200 rounded-lg bg-red-50">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="h-5 w-5 text-red-600 mt-0.5" />
                  <div className="flex-1">
                    <h4 className="font-semibold text-red-900 mb-2">samples_rate_exceeded</h4>
                    <p className="text-sm text-red-800 mb-3">
                      The tenant has exceeded their samples per second rate limit. This is the most common 
                      blocking reason for high-volume metric ingestion.
                    </p>
                    <div className="grid gap-3 md:grid-cols-2">
                      <div>
                        <h5 className="font-medium text-red-900 mb-1">🔍 What it means:</h5>
                        <ul className="text-sm text-red-800 space-y-1">
                          <li>• Tenant sending too many samples too quickly</li>
                          <li>• Token bucket algorithm detected rate violation</li>
                          <li>• Temporary blocking until rate normalizes</li>
                        </ul>
                      </div>
                      <div>
                        <h5 className="font-medium text-red-900 mb-1">🛠️ How to fix:</h5>
                        <ul className="text-sm text-red-800 space-y-1">
                          <li>• Increase <code>samples_per_second</code> limit</li>
                          <li>• Optimize client batching/compression</li>
                          <li>• Reduce metric cardinality</li>
                          <li>• Implement client-side rate limiting</li>
                        </ul>
                      </div>
                    </div>
                    <div className="mt-3 p-3 bg-white rounded border">
                      <h5 className="font-medium text-red-900 mb-1">📝 Example:</h5>
                      <div className="text-sm text-red-800 font-mono">
                        <div>Reason: samples_rate_exceeded</div>
                        <div>Observed: 1,500 samples in 1 second</div>
                        <div>Limit: 1,000 samples per second</div>
                        <div>Status: 429 Too Many Requests</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-4 border border-orange-200 rounded-lg bg-orange-50">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="h-5 w-5 text-orange-600 mt-0.5" />
                  <div className="flex-1">
                    <h4 className="font-semibold text-orange-900 mb-2">bytes_rate_exceeded</h4>
                    <p className="text-sm text-orange-800 mb-3">
                      The tenant has exceeded their bytes per second rate limit. This protects against 
                      bandwidth abuse and ensures fair resource allocation.
                    </p>
                    <div className="grid gap-3 md:grid-cols-2">
                      <div>
                        <h5 className="font-medium text-orange-900 mb-1">🔍 What it means:</h5>
                        <ul className="text-sm text-orange-800 space-y-1">
                          <li>• Tenant sending too much data too quickly</li>
                          <li>• Network bandwidth limit exceeded</li>
                          <li>• Large payloads or high compression</li>
                        </ul>
                      </div>
                      <div>
                        <h5 className="font-medium text-orange-900 mb-1">🛠️ How to fix:</h5>
                        <ul className="text-sm text-orange-800 space-y-1">
                          <li>• Increase <code>max_body_bytes</code> limit</li>
                          <li>• Optimize payload compression</li>
                          <li>• Reduce batch sizes</li>
                          <li>• Implement client-side throttling</li>
                        </ul>
                      </div>
                    </div>
                    <div className="mt-3 p-3 bg-white rounded border">
                      <h5 className="font-medium text-orange-900 mb-1">📝 Example:</h5>
                      <div className="text-sm text-orange-800 font-mono">
                        <div>Reason: bytes_rate_exceeded</div>
                        <div>Observed: 2.5 MB in 1 second</div>
                        <div>Limit: 1 MB per second</div>
                        <div>Status: 429 Too Many Requests</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Size Limit Blocking Reasons */}
          <div>
            <h3 className="text-lg font-semibold mb-4">📏 Size Limit Blocking Reasons</h3>
            <div className="space-y-4">
              <div className="p-4 border border-red-200 rounded-lg bg-red-50">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="h-5 w-5 text-red-600 mt-0.5" />
                  <div className="flex-1">
                    <h4 className="font-semibold text-red-900 mb-2">body_size_exceeded</h4>
                    <p className="text-sm text-red-800 mb-3">
                      The request body size exceeds the maximum allowed limit. This prevents memory exhaustion 
                      and protects against DoS attacks.
                    </p>
                    <div className="grid gap-3 md:grid-cols-2">
                      <div>
                        <h5 className="font-medium text-red-900 mb-1">🔍 What it means:</h5>
                        <ul className="text-sm text-red-800 space-y-1">
                          <li>• Single request too large</li>
                          <li>• Memory protection mechanism</li>
                          <li>• Prevents resource exhaustion</li>
                        </ul>
                      </div>
                      <div>
                        <h5 className="font-medium text-red-900 mb-1">🛠️ How to fix:</h5>
                        <ul className="text-sm text-red-800 space-y-1">
                          <li>• Split large batches into smaller requests</li>
                          <li>• Increase <code>max_body_bytes</code> limit</li>
                          <li>• Optimize metric compression</li>
                          <li>• Reduce metric cardinality</li>
                        </ul>
                      </div>
                    </div>
                    <div className="mt-3 p-3 bg-white rounded border">
                      <h5 className="font-medium text-red-900 mb-1">📝 Example:</h5>
                      <div className="text-sm text-red-800 font-mono">
                        <div>Reason: body_size_exceeded</div>
                        <div>Observed: 12 MB request body</div>
                        <div>Limit: 10 MB maximum</div>
                        <div>Status: 413 Request Entity Too Large</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Data Validation Blocking Reasons */}
          <div>
            <h3 className="text-lg font-semibold mb-4">🔍 Data Validation Blocking Reasons</h3>
            <div className="space-y-4">
              <div className="p-4 border border-purple-200 rounded-lg bg-purple-50">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="h-5 w-5 text-purple-600 mt-0.5" />
                  <div className="flex-1">
                    <h4 className="font-semibold text-purple-900 mb-2">parse_failed_deny</h4>
                    <p className="text-sm text-purple-800 mb-3">
                      The request body could not be parsed as valid Prometheus remote write protobuf data. 
                      This indicates malformed or corrupted data.
                    </p>
                    <div className="grid gap-3 md:grid-cols-2">
                      <div>
                        <h5 className="font-medium text-purple-900 mb-1">🔍 What it means:</h5>
                        <ul className="text-sm text-purple-800 space-y-1">
                          <li>• Invalid protobuf format</li>
                          <li>• Corrupted snappy/gzip compression</li>
                          <li>• Malformed metric data</li>
                          <li>• Network transmission errors</li>
                        </ul>
                      </div>
                      <div>
                        <h5 className="font-medium text-purple-900 mb-1">🛠️ How to fix:</h5>
                        <ul className="text-sm text-purple-800 space-y-1">
                          <li>• Check client protobuf generation</li>
                          <li>• Verify compression settings</li>
                          <li>• Test with valid sample data</li>
                          <li>• Check network connectivity</li>
                        </ul>
                      </div>
                    </div>
                    <div className="mt-3 p-3 bg-white rounded border">
                      <h5 className="font-medium text-purple-900 mb-1">📝 Example:</h5>
                      <div className="text-sm text-purple-800 font-mono">
                        <div>Reason: parse_failed_deny</div>
                        <div>Error: proto: cannot parse invalid wire-format data</div>
                        <div>Body Size: 1,234 bytes</div>
                        <div>Status: 400 Bad Request</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-4 border border-purple-200 rounded-lg bg-purple-50">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="h-5 w-5 text-purple-600 mt-0.5" />
                  <div className="flex-1">
                    <h4 className="font-semibold text-purple-900 mb-2">body_extract_failed_deny</h4>
                    <p className="text-sm text-purple-800 mb-3">
                      Failed to extract the request body from the HTTP request. This usually indicates 
                      a problem with the request format or Envoy configuration.
                    </p>
                    <div className="grid gap-3 md:grid-cols-2">
                      <div>
                        <h5 className="font-medium text-purple-900 mb-1">🔍 What it means:</h5>
                        <ul className="text-sm text-purple-800 space-y-1">
                          <li>• Empty request body</li>
                          <li>• Envoy body parsing issue</li>
                          <li>• Content-Length mismatch</li>
                          <li>• Request truncation</li>
                        </ul>
                      </div>
                      <div>
                        <h5 className="font-medium text-purple-900 mb-1">🛠️ How to fix:</h5>
                        <ul className="text-sm text-purple-800 space-y-1">
                          <li>• Check client request format</li>
                          <li>• Verify Envoy body parsing config</li>
                          <li>• Ensure proper Content-Length</li>
                          <li>• Test with valid request body</li>
                        </ul>
                      </div>
                    </div>
                    <div className="mt-3 p-3 bg-white rounded border">
                      <h5 className="font-medium text-purple-900 mb-1">📝 Example:</h5>
                      <div className="text-sm text-purple-800 font-mono">
                        <div>Reason: body_extract_failed_deny</div>
                        <div>Error: no body in request</div>
                        <div>Content-Length: 0</div>
                        <div>Status: 400 Bad Request</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Configuration Blocking Reasons */}
          <div>
            <h3 className="text-lg font-semibold mb-4">⚙️ Configuration Blocking Reasons</h3>
            <div className="space-y-4">
              <div className="p-4 border border-yellow-200 rounded-lg bg-yellow-50">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="h-5 w-5 text-yellow-600 mt-0.5" />
                  <div className="flex-1">
                    <h4 className="font-semibold text-yellow-900 mb-2">missing_tenant_header</h4>
                    <p className="text-sm text-yellow-800 mb-3">
                      The request is missing the required tenant identification header. This prevents 
                      the system from applying tenant-specific limits.
                    </p>
                    <div className="grid gap-3 md:grid-cols-2">
                      <div>
                        <h5 className="font-medium text-yellow-900 mb-1">🔍 What it means:</h5>
                        <ul className="text-sm text-yellow-800 space-y-1">
                          <li>• No X-Scope-OrgID header</li>
                          <li>• No Authorization header (for Alloy)</li>
                          <li>• Client not configured properly</li>
                          <li>• Cannot identify tenant</li>
                        </ul>
                      </div>
                      <div>
                        <h5 className="font-medium text-yellow-900 mb-1">🛠️ How to fix:</h5>
                        <ul className="text-sm text-yellow-800 space-y-1">
                          <li>• Add X-Scope-OrgID header to requests</li>
                          <li>• Configure basic auth for Alloy</li>
                          <li>• Update client configuration</li>
                          <li>• Check tenant header format</li>
                        </ul>
                      </div>
                    </div>
                    <div className="mt-3 p-3 bg-white rounded border">
                      <h5 className="font-medium text-yellow-900 mb-1">📝 Example:</h5>
                      <div className="text-sm text-yellow-800 font-mono">
                        <div>Reason: missing_tenant_header</div>
                        <div>Required: X-Scope-OrgID or Authorization</div>
                        <div>Found: No tenant headers</div>
                        <div>Status: 400 Bad Request</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-4 border border-blue-200 rounded-lg bg-blue-50">
                <div className="flex items-start gap-3">
                  <Info className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div className="flex-1">
                    <h4 className="font-semibold text-blue-900 mb-2">enforcement_disabled</h4>
                    <p className="text-sm text-blue-800 mb-3">
                      Enforcement is disabled for this tenant. Requests are allowed to pass through 
                      without limit checking (monitoring only mode).
                    </p>
                    <div className="grid gap-3 md:grid-cols-2">
                      <div>
                        <h5 className="font-medium text-blue-900 mb-1">🔍 What it means:</h5>
                        <ul className="text-sm text-blue-800 space-y-1">
                          <li>• Tenant in monitoring mode</li>
                          <li>• No limits enforced</li>
                          <li>• Requests always allowed</li>
                          <li>• Metrics still collected</li>
                        </ul>
                      </div>
                      <div>
                        <h5 className="font-medium text-blue-900 mb-1">🛠️ How to enable:</h5>
                        <ul className="text-sm text-blue-800 space-y-1">
                          <li>• Set enforcement.enabled: true</li>
                          <li>• Configure tenant limits</li>
                          <li>• Update via Admin API</li>
                          <li>• Use overrides-sync controller</li>
                        </ul>
                      </div>
                    </div>
                    <div className="mt-3 p-3 bg-white rounded border">
                      <h5 className="font-medium text-blue-900 mb-1">📝 Example:</h5>
                      <div className="text-sm text-blue-800 font-mono">
                        <div>Reason: enforcement_disabled</div>
                        <div>Tenant: new-tenant</div>
                        <div>Status: Monitoring only</div>
                        <div>Action: Allowed (no limits)</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Failure Mode Blocking Reasons */}
          <div>
            <h3 className="text-lg font-semibold mb-4">🔄 Failure Mode Blocking Reasons</h3>
            <div className="space-y-4">
              <div className="p-4 border border-green-200 rounded-lg bg-green-50">
                <div className="flex items-start gap-3">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                  <div className="flex-1">
                    <h4 className="font-semibold text-green-900 mb-2">parse_failed_allow</h4>
                    <p className="text-sm text-green-800 mb-3">
                      Request parsing failed but was allowed due to failure mode configuration. 
                      Limits are still enforced using fallback values.
                    </p>
                    <div className="grid gap-3 md:grid-cols-2">
                      <div>
                        <h5 className="font-medium text-green-900 mb-1">🔍 What it means:</h5>
                        <ul className="text-sm text-green-800 space-y-1">
                          <li>• Data corruption detected</li>
                          <li>• Fallback limit enforcement</li>
                          <li>• Conservative sample counting</li>
                          <li>• Protection still active</li>
                        </ul>
                      </div>
                      <div>
                        <h5 className="font-medium text-green-900 mb-1">🛠️ Best practices:</h5>
                        <ul className="text-sm text-green-800 space-y-1">
                          <li>• Monitor corruption patterns</li>
                          <li>• Investigate data sources</li>
                          <li>• Check network stability</li>
                          <li>• Review client configuration</li>
                        </ul>
                      </div>
                    </div>
                    <div className="mt-3 p-3 bg-white rounded border">
                      <h5 className="font-medium text-green-900 mb-1">📝 Example:</h5>
                      <div className="text-sm text-green-800 font-mono">
                        <div>Reason: parse_failed_allow</div>
                        <div>Fallback: 1 sample, 123 bytes</div>
                        <div>Limits: Still enforced</div>
                        <div>Status: 200 OK (with limits)</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-4 border border-green-200 rounded-lg bg-green-50">
                <div className="flex items-start gap-3">
                  <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
                  <div className="flex-1">
                    <h4 className="font-semibold text-green-900 mb-2">body_extract_failed_allow</h4>
                    <p className="text-sm text-green-800 mb-3">
                      Body extraction failed but was allowed due to failure mode configuration. 
                      Conservative limits are applied using raw body size.
                    </p>
                    <div className="grid gap-3 md:grid-cols-2">
                      <div>
                        <h5 className="font-medium text-green-900 mb-1">🔍 What it means:</h5>
                        <ul className="text-sm text-green-800 space-y-1">
                          <li>• Body parsing issue</li>
                          <li>• Raw size limit enforcement</li>
                          <li>• Conservative protection</li>
                          <li>• System still protected</li>
                        </ul>
                      </div>
                      <div>
                        <h5 className="font-medium text-green-900 mb-1">🛠️ Best practices:</h5>
                        <ul className="text-sm text-green-800 space-y-1">
                          <li>• Monitor extraction failures</li>
                          <li>• Check Envoy configuration</li>
                          <li>• Verify request format</li>
                          <li>• Review client setup</li>
                        </ul>
                      </div>
                    </div>
                    <div className="mt-3 p-3 bg-white rounded border">
                      <h5 className="font-medium text-green-900 mb-1">📝 Example:</h5>
                      <div className="text-sm text-green-800 font-mono">
                        <div>Reason: body_extract_failed_allow</div>
                        <div>Fallback: 1 sample, 456 bytes</div>
                        <div>Limits: Raw size enforced</div>
                        <div>Status: 200 OK (with limits)</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Monitoring and Resolution */}
          <div>
            <h3 className="text-lg font-semibold mb-4">📊 Monitoring and Resolution</h3>
            <div className="grid gap-4 md:grid-cols-2">
              <div className="p-4 bg-gray-50 border border-gray-200 rounded-lg">
                <h4 className="font-medium text-gray-900 mb-2">🔍 Real-time Monitoring</h4>
                <ul className="text-sm text-gray-700 space-y-1">
                  <li>• <strong>Blocking Dashboard</strong> - Live view of all blocking reasons</li>
                  <li>• <strong>Tenant Details</strong> - Per-tenant blocking history</li>
                  <li>• <strong>Trend Analysis</strong> - Identify patterns over time</li>
                  <li>• <strong>Alert Integration</strong> - Get notified of violations</li>
                  <li>• <strong>Metrics Export</strong> - Prometheus metrics for monitoring</li>
                </ul>
              </div>
              <div className="p-4 bg-gray-50 border border-gray-200 rounded-lg">
                <h4 className="font-medium text-gray-900 mb-2">🛠️ Resolution Workflow</h4>
                <ul className="text-sm text-gray-700 space-y-1">
                  <li>• <strong>1. Identify</strong> - Check blocking reason in UI</li>
                  <li>• <strong>2. Analyze</strong> - Review observed vs limit values</li>
                  <li>• <strong>3. Investigate</strong> - Check client configuration</li>
                  <li>• <strong>4. Adjust</strong> - Update limits or fix client</li>
                  <li>• <strong>5. Monitor</strong> - Verify resolution effectiveness</li>
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
