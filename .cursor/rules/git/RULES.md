# Project Rules and Guidelines

## Core Principles

### Git as Source of Truth
**Git repository is the single source of truth for all code, configuration, and infrastructure definitions.**

- When comparing deployed resources vs git repository:
  - Git wins - deployed resources should be updated to match git
  - Any drift from git is considered incorrect and should be remediated
  - Document drift in issues/PRs before remediation
  
- When comparing local changes vs git:
  - Committed code in git is authoritative
  - Local uncommitted changes are experimental/WIP
  - Always verify against latest git state before making decisions

- When comparing documentation vs implementation:
  - If code in git differs from documentation, code is correct
  - Update documentation to match git, not the reverse
  - Documentation bugs are tracked and fixed like code bugs

- When comparing environment configurations:
  - Git-stored configs (terraform, k8s manifests, etc.) are canonical
  - Manual changes to infrastructure should be captured back to git
  - Use infrastructure-as-code for all persistent changes

## Technology Stack

### Languages
- **Primary**: Go, Python, TypeScript/JavaScript
- **Go**: Preferred for CLI tools, APIs, and performance-critical services
- **Python**: Preferred for automation, data processing, and quick scripts
- **TypeScript**: Preferred for web frontends and Node.js backends

### Frontend Frameworks & Libraries
- **CSS Framework**: Tailwind CSS (preferred)
- **Component Libraries**: 
  - ShadCN/UI (preferred for React projects)
  - DaisyUI (preferred for general Tailwind projects)
  - Material UI (acceptable alternative)
- **Go TUI**: BubbleTea for terminal interfaces
- **Desktop Apps**: Wails2 for cross-platform desktop applications

### Infrastructure & Cloud
- **Cloud Providers**: AWS (expert level), GCP (learning), Oracle Cloud Infrastructure
- **Infrastructure as Code**: Terraform (required for all cloud resources)
- **CI/CD**: GitHub Actions (preferred)
- **Configuration Management**: Ansible (where applicable)

### Development Tools
- **Primary IDE**: Cursor with MCP server integrations
- **AI Assistants**: Claude (for complex reasoning), cursor native AI
- **Version Control**: Git with GitHub

## Code Standards

### General Principles
- Write clear, self-documenting code with meaningful variable names
- Prefer explicit over implicit
- Include error handling for all external calls
- Log appropriately: info for normal ops, warn for degraded state, error for failures
- Write tests for critical paths and business logic

### Go Standards
- Follow standard Go conventions (gofmt, golint)
- Use Go modules for dependency management
- Structure projects with clear separation: cmd/, internal/, pkg/
- Use context.Context for cancellation and timeouts
- Prefer table-driven tests
- Keep functions focused and small
- Use interfaces for testability
- Handle errors explicitly, don't ignore them

### Python Standards
- Follow PEP 8 style guide
- Use type hints for function signatures
- Use virtual environments (venv or poetry)
- Structure projects: src/, tests/, docs/
- Use pytest for testing
- Use logging module, not print statements
- Use async/await for I/O bound operations when appropriate

### TypeScript/JavaScript Standards
- Use TypeScript for all new code (strict mode enabled)
- Follow ESLint recommended rules
- Use async/await over promises chains
- Use meaningful variable names, avoid abbreviations
- Use functional components in React
- Keep components small and focused
- Use hooks appropriately

## Infrastructure as Code

### Terraform Standards
- All cloud resources must be defined in Terraform
- Use modules for reusable components
- Use terraform workspaces or separate state files per environment
- Run `terraform fmt` before committing
- Use `terraform validate` in CI/CD
- Store state remotely (S3, GCS, or Terraform Cloud)
- Use variable files for environment-specific configs
- Tag all resources appropriately (Environment, Project, Owner, ManagedBy)

### Kubernetes/Container Standards
- Use Kubernetes manifests or Helm charts stored in git
- Define resource limits and requests
- Use namespaces for environment separation
- Use ConfigMaps and Secrets for configuration
- Include health checks (liveness and readiness probes)
- Use GitOps practices (ArgoCD, Flux, etc.)

## SRE & Operations

### Observability
- Implement structured logging (JSON format preferred)
- Include trace IDs for request correlation
- Expose metrics in Prometheus format
- Implement health check endpoints (/health, /ready)
- Use distributed tracing where appropriate
- Alert on symptoms, not causes
- Document runbooks for common alerts

### Security
- Never commit secrets to git (use secret management tools)
- Use environment variables or secret stores for sensitive data
- Implement least privilege access
- Keep dependencies updated (use Dependabot or similar)
- Scan containers for vulnerabilities
- Use network policies in Kubernetes
- Enable audit logging for critical systems

### Deployment
- Use immutable infrastructure principles
- Implement blue-green or canary deployments for critical services
- Always have rollback procedures
- Test deployments in non-prod first
- Use semantic versioning for releases
- Tag container images with git commit SHA and version
- Automate deployments via CI/CD

## Git Workflow

### Branching Strategy
- `main` branch is protected and always deployable
- Use feature branches: `feature/description` or `feat/description`
- Use fix branches: `fix/description` or `bugfix/description`
- Use descriptive branch names
- Delete branches after merge

### Commit Messages
- Use conventional commit format:
  - `feat: add new feature`
  - `fix: resolve bug in X`
  - `docs: update README`
  - `refactor: restructure module Y`
  - `test: add tests for Z`
  - `chore: update dependencies`
- Write clear, descriptive commit messages
- Reference issue numbers where applicable

### Pull Requests
- Keep PRs focused and reasonably sized
- Include description of changes and why
- Link to related issues
- Ensure CI/CD passes before requesting review
- Address review comments promptly
- Squash commits when merging if history is messy

## Documentation

### Code Documentation
- Document public APIs and exported functions
- Include usage examples in README
- Keep inline comments focused on "why", not "what"
- Update documentation when changing behavior
- Include architecture diagrams for complex systems

### README Requirements
Every project should have a README with:
- Project description and purpose
- Prerequisites and dependencies
- Installation instructions
- Usage examples
- Configuration options
- Development setup
- Testing instructions
- Deployment process
- License information

## Testing

### Test Coverage
- Write unit tests for business logic
- Write integration tests for external dependencies
- Include end-to-end tests for critical paths
- Aim for >80% code coverage on critical modules
- Run tests in CI/CD before merge

### Test Organization
- Keep tests close to code (Go) or in tests/ directory (Python)
- Use table-driven tests where applicable
- Mock external dependencies
- Use test fixtures for complex data
- Clean up test resources after execution

## AI Assistant Guidelines

### When Working with Claude/Cursor
- Provide context about the project and current task
- Reference this RULES.md when making architectural decisions
- Ask for explanations of unfamiliar patterns or tools
- Request code reviews for critical changes
- Use AI for boilerplate generation but review carefully
- Iterate on solutions until they meet standards
- Don't blindly accept suggestions - understand them

### Code Generation
- Generated code should follow all standards in this document
- Include error handling in generated code
- Add appropriate logging
- Include basic tests for generated code
- Review for security issues before committing

## Conflict Resolution Priority

When there are conflicts between different sources:

1. **Git Repository** (highest priority)
2. **This RULES.md file**
3. **Project-specific documentation**
4. **Industry best practices**
5. **AI assistant suggestions**

## Continuous Improvement

- Review and update these rules quarterly
- Propose changes via PR with rationale
- Document lessons learned from incidents
- Share knowledge across team
- Stay current with ecosystem changes

---

*Last Updated: 2025-01-02*
*This is a living document - update as practices evolve*
