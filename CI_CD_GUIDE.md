# CI/CD Guide - EagleSpy V5

## Overview

This guide covers the comprehensive CI/CD pipeline implemented for EagleSpy V5, including automated security scanning, dependency management, release automation, and blue-green deployment strategies.

## Table of Contents

1. [Security Scanning](#security-scanning)
2. [Dependency Management](#dependency-management)
3. [Automated Releases](#automated-releases)
4. [Blue-Green Deployment](#blue-green-deployment)
5. [Setup Instructions](#setup-instructions)
6. [Best Practices](#best-practices)

---

## Security Scanning

### Overview

The security scanning workflow (`.github/workflows/security-scan.yml`) runs automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Weekly schedule (Mondays at midnight UTC)

### Components

#### 1. Dependency Scanning
- **Bundler Audit**: Scans Ruby gems for known vulnerabilities
- **npm audit**: Checks JavaScript dependencies for security issues
- **Audit Level**: Configured to flag moderate and above severity issues

#### 2. Container Scanning
- **Trivy**: Scans Docker images for vulnerabilities
- **SARIF Upload**: Integrates with GitHub Security tab
- **Severity Filter**: CRITICAL and HIGH vulnerabilities only

#### 3. SAST (Static Application Security Testing)
- **CodeQL**: Analyzes Ruby and JavaScript code for security vulnerabilities
- **Languages**: Ruby, JavaScript
- **Integration**: Results appear in GitHub Security tab

#### 4. Secret Scanning
- **Gitleaks**: Scans git history for exposed secrets
- **Coverage**: Full repository history
- **Action**: Fails CI if secrets detected

### Viewing Results

1. Navigate to **Security** → **Code scanning alerts**
2. Filter by tool (Trivy, CodeQL, Gitleaks)
3. Review and remediate findings

---

## Dependency Management

### Dependabot Configuration

Dependabot automatically creates pull requests for dependency updates based on the configuration in `.github/dependabot.yml`.

#### Update Schedules

| Ecosystem | Directory | Schedule | PR Limit |
|-----------|-----------|----------|----------|
| Bundler (Ruby) | `/` | Weekly (Monday) | 10 |
| npm (JavaScript) | `/frontend` | Weekly (Monday) | 10 |
| Docker | `/docker` | Weekly | 5 |
| GitHub Actions | `/` | Monthly | 5 |

#### Automated Ignores

- **Major version updates**: Ignored by default for Ruby gems
- Prevents breaking changes from auto-updating

#### PR Configuration

- **Labels**: Automatically tagged with `dependencies`, ecosystem
- **Reviewers**: Assigned to relevant teams
- **Commit Message**: Follows conventional commit format (`chore:`)

### Managing Dependabot PRs

1. **Review**: Check changelog and breaking changes
2. **Test**: CI runs automatically on Dependabot PRs
3. **Merge**: Approve if tests pass and changes are safe
4. **Batch**: Consider batching minor updates weekly

---

## Automated Releases

### Release Workflow

The release workflow (`.github/workflows/release.yml`) triggers on version tags.

#### Triggering a Release

```bash
# Create and push a version tag
git tag -a v1.2.3 -m "Release version 1.2.3"
git push origin v1.2.3
```

#### Release Process

1. **Generate Release Notes**: Automatically categorizes commits
   - ✨ New Features (`feat:`)
   - 🐛 Bug Fixes (`fix:`)
   - 🔧 Chores (`chore:`)

2. **Create GitHub Release**: Publishes release with notes

3. **Build Docker Image**: Creates multi-tag image
   - `eaglespy:v1.2.3` (version-specific)
   - `eaglespy:latest` (latest stable)

4. **Push to Registry**: Uploads to configured Docker registry

### Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/) for automatic categorization:

```
feat: Add new feature
fix: Fix bug in authentication
chore: Update dependencies
docs: Update documentation
```

### Required Secrets

Configure these in **Settings** → **Secrets and variables** → **Actions**:

- `DOCKER_USERNAME`: Docker registry username
- `DOCKER_PASSWORD`: Docker registry password/token
- `DOCKER_REGISTRY`: Registry URL (e.g., `docker.io/yourorg`)

---

## Blue-Green Deployment

### Overview

Blue-green deployment minimizes downtime and allows instant rollback by running two production environments (blue and green).

### Architecture

```
┌─────────────┐
│Load Balancer│
└──────┬──────┘
       │
   ┌───┴────┐
   │        │
┌──▼──┐  ┌──▼───┐
│Blue │  │Green │
│ Env │  │ Env  │
└─────┘  └──────┘
```

### Deployment Script

Located at `scripts/deploy_blue_green.sh`:

```bash
./deploy_blue_green.sh v1.2.3
```

#### Deployment Steps

1. **Detect Current Environment**: Determines active environment (blue/green)
2. **Pull New Image**: Downloads specified version
3. **Start New Environment**: Launches inactive environment
4. **Health Check**: Waits for application readiness (30 attempts, 2s interval)
5. **Smoke Tests**: Runs automated smoke tests
6. **Traffic Switch**: Updates load balancer to route to new environment
7. **Traffic Drain**: Waits for existing connections to complete (10s)
8. **Stop Old Environment**: Shuts down previous environment

### Smoke Tests

Located at `scripts/smoke_test.sh`:

```bash
./smoke_test.sh http://localhost:3001
```

#### Test Coverage

1. **Health Endpoint**: Verifies `/health` returns "ok"
2. **Admin Login**: Checks `/admin/login` accessibility
3. **API Health**: Validates `/api/health` responds correctly

### Rollback Procedure

If issues are detected after deployment:

```bash
# Switch back to previous environment
./scripts/switch_traffic.sh blue  # or green

# Restart previous environment if stopped
docker-compose -f docker-compose.blue.yml up -d
```

### Prerequisites

1. **Docker Compose Files**: Create `docker-compose.blue.yml` and `docker-compose.green.yml`
2. **Traffic Switch Script**: Implement `scripts/switch_traffic.sh` for your load balancer
3. **Health Endpoints**: Ensure `/health` endpoint exists in application

---

## Setup Instructions

### Initial Configuration

#### 1. GitHub Repository Settings

Enable GitHub Actions:
1. Navigate to **Settings** → **Actions** → **General**
2. Select "Allow all actions and reusable workflows"
3. Enable "Read and write permissions" for workflows

#### 2. Configure Secrets

Add the following secrets in **Settings** → **Secrets and variables** → **Actions**:

```
DOCKER_USERNAME=your-docker-username
DOCKER_PASSWORD=your-docker-password
DOCKER_REGISTRY=docker.io/yourorg
```

#### 3. Enable Security Features

1. **Code Scanning**: Navigate to **Security** → **Code scanning** → Enable CodeQL
2. **Secret Scanning**: Navigate to **Security** → **Secret scanning** → Enable
3. **Dependabot**: Navigate to **Security** → **Dependabot** → Enable alerts

#### 4. Configure Branch Protection

For `main` branch:
1. **Settings** → **Branches** → **Add rule**
2. Branch name pattern: `main`
3. Enable:
   - Require pull request reviews
   - Require status checks (select security-scan jobs)
   - Require up-to-date branches
   - Include administrators

### Local Development Setup

#### Running Security Scans Locally

```bash
# Ruby dependency audit
gem install bundler-audit
bundler-audit check --update

# Rails security scan
gem install brakeman
brakeman -q -z

# JavaScript audit
cd frontend
npm audit --audit-level=moderate

# Container scan
docker build -t eaglespy:local .
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image eaglespy:local
```

#### Testing Deployment Scripts

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Test smoke tests
./scripts/smoke_test.sh http://localhost:3000

# Dry run deployment (without actual deployment)
export DRY_RUN=true
./scripts/deploy_blue_green.sh latest
```

---

## Best Practices

### Security

1. **Regular Scans**: Don't disable scheduled security scans
2. **Prompt Updates**: Address security vulnerabilities within 7 days
3. **Secret Management**: Never commit secrets; use environment variables
4. **Review Dependabot**: Don't auto-merge without review
5. **SARIF Integration**: Monitor GitHub Security tab weekly

### Dependency Management

1. **Test Before Merge**: Always run full test suite on Dependabot PRs
2. **Batch Updates**: Group minor updates to reduce noise
3. **Major Versions**: Review breaking changes carefully
4. **Lock Files**: Commit `Gemfile.lock` and `package-lock.json`
5. **Audit Regularly**: Run `bundle audit` and `npm audit` locally

### Releases

1. **Semantic Versioning**: Follow [SemVer](https://semver.org/)
   - MAJOR: Breaking changes (v2.0.0)
   - MINOR: New features (v1.1.0)
   - PATCH: Bug fixes (v1.0.1)
2. **Conventional Commits**: Use prefixes for automatic categorization
3. **Changelog**: Review generated release notes before publishing
4. **Tag Annotations**: Add meaningful messages to tags
5. **Pre-release Testing**: Test release builds before tagging

### Deployment

1. **Health Checks**: Implement comprehensive health endpoints
2. **Smoke Tests**: Cover critical user journeys
3. **Monitoring**: Watch logs during and after deployment
4. **Rollback Plan**: Always have rollback procedure ready
5. **Off-Peak Hours**: Deploy during low-traffic periods
6. **Communication**: Notify team before production deployments

### CI/CD Optimization

1. **Caching**: Leverage GitHub Actions cache for dependencies
2. **Parallelization**: Run independent jobs concurrently
3. **Fail Fast**: Put quick checks (linting) before slow ones (E2E tests)
4. **Artifacts**: Store build artifacts for debugging
5. **Timeouts**: Set reasonable timeouts to catch hanging jobs

---

## Troubleshooting

### Common Issues

#### Security Scan Failures

**Issue**: Bundler audit fails with outdated database

```bash
# Solution: Update audit database
gem install bundler-audit
bundler-audit update
```

**Issue**: Trivy scan times out

```bash
# Solution: Increase timeout or use light scan
trivy image --timeout 10m eaglespy:latest
```

#### Dependabot Issues

**Issue**: Dependabot PRs fail tests

1. Review the dependency changelog
2. Check for breaking changes
3. Update application code if necessary
4. Consider pinning to previous version temporarily

**Issue**: Too many Dependabot PRs

```yaml
# Reduce PR limit in .github/dependabot.yml
open-pull-requests-limit: 5  # Lower limit
```

#### Deployment Issues

**Issue**: Health check never passes

1. Check application logs: `docker logs eaglespy-green`
2. Verify health endpoint: `curl http://localhost:3001/health`
3. Increase health check timeout in script
4. Check database connectivity

**Issue**: Smoke tests fail

1. Verify endpoints exist in application
2. Check response format matches expectations
3. Test manually: `curl -v http://localhost:3001/health`
4. Review application logs

---

## Monitoring and Alerts

### GitHub Actions Notifications

Configure workflow failure notifications:
1. **Settings** → **Notifications** → **Actions**
2. Enable "Send notifications for failed workflows"
3. Choose notification method (email, web, mobile)

### Security Alerts

1. **Dependabot Alerts**: Enable in Security settings
2. **Code Scanning**: Enable email notifications
3. **Secret Scanning**: Configure custom patterns if needed

### Deployment Monitoring

After deployment, monitor:
- Application logs: `docker logs -f eaglespy-prod`
- Error rates: Check monitoring dashboards
- Response times: API latency metrics
- Database connections: Connection pool status

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [CodeQL Documentation](https://codeql.github.com/docs/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)

---

## Support

For issues or questions:
1. Check this guide for troubleshooting steps
2. Review GitHub Actions logs for error details
3. Consult team documentation
4. Contact DevOps team for deployment assistance

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Maintained By**: DevOps Team
