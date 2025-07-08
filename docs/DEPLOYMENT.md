# PDFy Deployment Guide

This guide covers the complete deployment process for PDFy using GitHub Actions and Railway.

## Overview

PDFy uses a comprehensive CI/CD pipeline with the following workflows:

- **CI Pipeline**: Runs tests on every push and PR
- **Security Pipeline**: Security scans and dependency audits
- **Deployment Pipeline**: Automated deployment to Railway
- **Release Pipeline**: Tagged releases with Docker images

## Prerequisites

### 1. GitHub CLI Setup

Install the GitHub CLI:
```bash
# macOS
brew install gh

# Windows
winget install --id GitHub.cli

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
```

### 2. Railway CLI Setup

Install the Railway CLI:
```bash
curl -fsSL https://railway.app/install.sh | sh
```

## Setup Process

### 1. Clone and Setup Repository

```bash
git clone https://github.com/yourusername/pdfy.git
cd pdfy
```

### 2. Setup GitHub Secrets

Run the automated setup script:
```bash
./scripts/setup-github-secrets.sh
```

Or set secrets manually using GitHub CLI:

#### Required Secrets

**Rails Application:**
```bash
# Rails master key (from config/master.key)
gh secret set RAILS_MASTER_KEY --body "$(cat config/master.key)"
```

**Railway Integration:**
```bash
# Get these from Railway dashboard
gh secret set RAILWAY_TOKEN --body "your-railway-token"
gh secret set RAILWAY_PROJECT_ID --body "your-project-id"
gh secret set RAILWAY_SERVICE_NAME --body "your-service-name"
gh secret set RAILWAY_PUBLIC_URL --body "https://your-app.railway.app"
```

**API Keys (Optional):**
```bash
gh secret set OPENWEATHER_API_KEY --body "your-openweather-key"
gh secret set ALPHA_VANTAGE_API_KEY --body "your-alphavantage-key"
gh secret set NEWS_API_KEY --body "your-news-api-key"
```

### 3. Railway Configuration

1. **Create Railway Project:**
   ```bash
   railway login
   railway new pdfy
   ```

2. **Add PostgreSQL Database:**
   ```bash
   railway add --database postgresql
   ```

3. **Add Redis:**
   ```bash
   railway add --database redis
   ```

4. **Set Environment Variables:**
   ```bash
   railway variables set RAILS_ENV=production
   railway variables set RAILS_MASTER_KEY=$(cat config/master.key)
   railway variables set PORT=3000
   ```

### 4. Configure Railway Settings

Update your Railway service settings:

- **Build Command**: Automatic (uses Dockerfile)
- **Start Command**: Set via `railway.toml` (includes migrations and conditional seeding)
- **Health Check**: `/health` endpoint
- **Restart Policy**: On failure with max 3 retries

## Workflows Explanation

### CI Workflow (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`

**Services:**
- PostgreSQL 15
- Redis 7

**Steps:**
1. Checkout code
2. Setup Ruby 3.2.0 and Node.js 18
3. Install Chrome for PDF generation
4. Install dependencies
5. Setup test database
6. Run test suite and system tests
7. Upload test artifacts on failure

### Deployment Workflow (`.github/workflows/deploy.yml`)

**Triggers:**
- Push to `main` branch
- Manual trigger (`workflow_dispatch`)

**Steps:**
1. Install Railway CLI
2. Deploy to Railway
3. Run database migrations
4. **Conditional seeding** (only if database is empty)
5. Restart application
6. Health check verification

### Release Workflow (`.github/workflows/release.yml`)

**Triggers:**
- Git tags matching `v*` pattern

**Steps:**
1. Generate changelog from commits
2. Create GitHub release
3. Build and push Docker image to GitHub Container Registry
4. Trigger deployment workflow

### Security Workflow (`.github/workflows/security.yml`)

**Triggers:**
- Push to `main` or `develop`
- Pull requests to `main`
- Daily scheduled scan at 2 AM UTC

**Scans:**
1. **Bundler Audit**: Ruby gem vulnerabilities
2. **Brakeman**: Rails security scanner
3. **Dependency Review**: Dependency vulnerabilities on PRs
4. **CodeQL**: Static code analysis for Ruby and JavaScript

## Database Seeding Strategy

### One-Time Seeding

The application implements a smart seeding strategy:

1. **Development/Test**: Always seed
2. **Production**: Only seed if database is empty (User.count == 0)

### Custom Rake Tasks

```bash
# Conditional seeding (production-safe)
rails db:conditional_seed

# Database health check
rails db:health

# Safe database reset (blocks production)
rails db:safe_reset

# Create sample data (development only)
rails db:sample_data
```

### How It Works

1. **Initial Deploy**: Database is empty → Seeds run automatically
2. **Subsequent Deploys**: Database has data → Seeding skipped
3. **Manual Seeding**: Use `rails db:conditional_seed` if needed

## Deployment Process

### Automatic Deployment

1. **Push to main** triggers deployment
2. **Tests must pass** in CI before deployment
3. **Railway CLI** deploys the application
4. **Migrations** run automatically
5. **Conditional seeding** occurs only on first deploy
6. **Health check** verifies successful deployment

### Manual Deployment

```bash
# Deploy current branch
railway up

# Deploy with specific environment
railway up --environment production

# Run one-off commands
railway run rails db:migrate
railway run rails db:conditional_seed
```

### Creating Releases

1. **Tag a release:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Automatic process:**
   - GitHub release created with changelog
   - Docker image built and pushed
   - Deployment triggered

## Health Monitoring

### Health Check Endpoint

**URL:** `/health`

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z",
  "environment": "production",
  "version": "v1.0.0",
  "services": {
    "database": "healthy",
    "redis": "healthy",
    "sidekiq": {
      "status": "healthy",
      "processed": 1250,
      "failed": 2,
      "queues": {}
    }
  }
}
```

### Monitoring Commands

```bash
# Check application health
curl https://your-app.railway.app/health

# View Railway logs
railway logs

# Check service status
railway status

# View metrics
railway metrics
```

## Troubleshooting

### Common Issues

1. **Seeding runs on every deploy:**
   - Check if User model exists in production
   - Verify conditional seeding logic in rake task

2. **Health check fails:**
   - Check database connectivity
   - Verify Redis connection
   - Check Sidekiq status

3. **Deployment fails:**
   - Verify all secrets are set
   - Check Railway service logs
   - Ensure migrations are working

4. **Tests fail:**
   - Check database setup in CI
   - Verify Chrome installation for PDF tests
   - Check environment variables

### Debugging Commands

```bash
# Check GitHub secrets
gh secret list

# View workflow runs
gh run list

# Check Railway environment
railway variables

# Debug database
railway connect postgresql
```

### Recovery Procedures

**Database Issues:**
```bash
# Reset database (staging only)
railway run rails db:safe_reset
ALLOW_PRODUCTION_RESET=true railway run rails db:safe_reset

# Manual seed
railway run rails db:conditional_seed
```

**Service Recovery:**
```bash
# Restart service
railway service restart

# Redeploy
railway up --detach
```

## Security Considerations

1. **Secrets Management**: All secrets stored in GitHub secrets
2. **Environment Separation**: Production/staging isolation
3. **Security Scanning**: Automated vulnerability detection
4. **Access Control**: Railway and GitHub access controls
5. **Health Monitoring**: Continuous service monitoring

## Best Practices

1. **Never commit secrets** to repository
2. **Use environment-specific configurations**
3. **Monitor health checks** regularly
4. **Review security scan results**
5. **Test deployments** in staging first
6. **Keep dependencies updated**
7. **Document configuration changes**

## Support

For deployment issues:
1. Check this documentation
2. Review GitHub Actions logs
3. Check Railway service logs
4. Verify environment configuration
5. Contact the development team

## Resources

- [Railway Documentation](https://docs.railway.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub CLI Documentation](https://cli.github.com/)
- [Rails Deployment Guide](https://guides.rubyonrails.org/deployment.html)