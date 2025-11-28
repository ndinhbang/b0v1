### Project structure
```
b0v1/
├── apps/               # Application codebases
│   ├── auth/           # Authentication API (Laravel 12)
│   ├── api/            # Recource API (Laravel 12)
│   ├── admin/          # Admin dashboard SPA (React 19 + Vite + TS + PWA)
│   ├── usr/            # User dashboard SPA (Vue 3 + Vite + TS + PWA)
│   └── lp/             # Landing page
├── packages/           # Shared packages
│   ├── types/          # Shared TypeScript types
│   ├── ui/             # Shared UI components
│   └── utils/          # Shared utility functions
├── infra/              # Infrastructure as Code (IaC) files
│   ├── docker/         # Docker configurations
│   ├── terraform/      # Terraform configurations
│   └── kubernetes/     # Kubernetes manifests
├── scripts/            # Automation and setup scripts
├── docs/               # Documentation files
├── compose.yaml        # Docker Compose configuration
├── mise.toml           # Mise development environment configuration
├── turbo.json          # Turborepo configuration
├── pnpm-workspace.yaml # PNPM workspace configuration
└── README.md           # Project overview
```