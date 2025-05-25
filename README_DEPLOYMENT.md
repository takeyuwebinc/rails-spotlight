# Kamal Deployment Setup for spotlight-rails

## Overview

This Rails application is now configured for deployment using Kamal to the production server.

## Configuration Summary

- **Service**: spotlight-rails
- **Host**: www-takeyuweb-co-jp
- **Domain**: takeyuweb.co.jp (with SSL)
- **Registry**: takeyuwebinc-spotlight-rails.sakuracr.jp
- **Database**: SQLite with persistent storage

## Quick Start

### 1. Set up secrets
Edit `.kamal/secrets` with your actual values:
```bash
RAILS_MASTER_KEY=your_actual_rails_master_key
KAMAL_REGISTRY_USERNAME=your_registry_username
KAMAL_REGISTRY_PASSWORD=your_registry_password
```

### 2. Verify configuration
```bash
kamal config
```

### 3. Deploy
```bash
# Initial deployment
kamal setup

# Subsequent deployments
kamal deploy
```

## Files Created/Modified

1. **config/deploy.yml** - Main Kamal configuration
2. **.kamal/secrets** - Environment variables template
3. **.gitignore** - Updated to exclude secrets
4. **config/environments/production.rb** - Updated domain configuration
5. **docs/adr/014_Kamalデプロイメント設定.md** - Architecture decision record
6. **docs/specs/kamal_deployment_guide.md** - Detailed deployment guide

## Key Features

- ✅ Zero-downtime deployments
- ✅ Automatic SSL certificate management
- ✅ SQLite database persistence
- ✅ Docker container orchestration
- ✅ Health monitoring
- ✅ Log management

## Next Steps

1. Fill in the actual values in `.kamal/secrets`
2. Ensure SSH access to the target server
3. Set up Docker registry authentication
4. Run `kamal setup` for initial deployment

## Documentation

- See `docs/specs/kamal_deployment_guide.md` for detailed deployment instructions
- See `docs/adr/014_Kamalデプロイメント設定.md` for architectural decisions

## Support

For troubleshooting, refer to the deployment guide or check:
- `kamal app logs` for application logs
- `kamal proxy logs` for proxy logs
- `kamal app details` for container status
