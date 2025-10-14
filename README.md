# Small Bets

[Small Bets](https://smallbets.com) is an online community to support new and aspiring entrepreneurs. This repository contains the source code for the Small Bets web application, which is based on a modified version of [Campfire](https://github.com/basecamp/once-campfire/), a Ruby on Rails chat application built by [37signals](https://once.com/campfire).

We modified Campfire extensively to serve the needs of the Small Bets community. We have a list of [some of the major modifications](campfire-mods.md), along with references to the source code. If you like any of our changes, feel free to incorporate them into your own Campfire instance.

<img width="1297" height="867" src="https://github.com/user-attachments/assets/a615c6df-1952-49af-872a-793743e6ad6e" />

If you would like to help us improve Small Bets, we pay bounties for pull requests that [resolve our issues](https://github.com/antiwork/smallbets/issues). If you find a bug or have a feature request, we would appreciate it if you [post an issue](https://github.com/antiwork/smallbets/issues/new). Thank you!

And if you're not part of the [Small Bets](https://smallbets.com) community yet, we would love to welcome you onboard!

## Running in development

### Prerequisites

- Ruby 3.3.1 (check with `ruby --version`)
- Redis server
- SQLite3
- Node.js with npm (or bun) for Tailwind CSS builds

### Setup

    bin/setup
    bin/rails server

The `bin/setup` script will install dependencies, prepare the database, build Tailwind CSS, and configure the application.

If you're actively developing with Tailwind CSS and need continuous builds, run `bin/tailwind-build --watch` in a separate terminal.

## Running in production

Small Bets uses [Kamal](https://kamal-deploy.org/docs/installation/) for deployment. A modern tool that provides zero-downtime deployments with Docker.

### Prerequisites

- A Linux server (Ubuntu 20.04+ recommended)
- Docker installed on the server
- A domain name pointing to your server
- Docker Hub account (or another container registry)
- Kamal CLI installed locally (install via `gem install kamal`)

### Initial Server Setup

1. **Initialize Kamal (creates `.kamal/secrets` if missing):**
   ```bash
   kamal init
   ```

2. **Configure environment variables:**
   Edit `.kamal/secrets` and add your production secrets, for example:
   ```bash
   # Registry
   KAMAL_REGISTRY_PASSWORD=your-docker-hub-password
   REGISTRY_USERNAME=your-docker-hub-username

   # Server + domain
   SERVER_IP=your-server-ip
   PROXY_HOST=your-domain.com

   # Application secrets (generate with: rails secret)
   SECRET_KEY_BASE=your-rails-secret-key
   RESEND_API_KEY=your-resend-api-key
   VIMEO_ACCESS_TOKEN=your-vimeo-api-key
   AWS_ACCESS_KEY_ID=your-aws-access-key
   AWS_SECRET_ACCESS_KEY=your-aws-secret-key
   AWS_DEFAULT_REGION=us-east-1
   VAPID_PUBLIC_KEY=your-vapid-public-key
   VAPID_PRIVATE_KEY=your-vapid-private-key
   WEBHOOK_SECRET=your-webhook-secret
   COOKIE_DOMAIN=your-domain.com

   # Optional features
   GUMROAD_ON=false
   ```

3. **Initial deployment:**
   ```bash
   kamal setup    # Sets up Docker, builds image, starts services
   ```

### Subsequent Deployments

```bash
kamal deploy   # Zero-downtime deployment
```

### Automated Deployments

This repository includes GitHub Actions for automatic deployment:

1. **Set GitHub Secrets** in your repository settings:
   - `SSH_PRIVATE_KEY` - SSH key for server access
   - `SERVER_IP` - Your production server IP
   - `DOMAIN` - Your domain name (PROXY_HOST)
   - `DOCKER_USERNAME` & `DOCKER_PASSWORD` - Docker Hub credentials
   - `SECRET_KEY_BASE` - Rails encryption key
   - `RESEND_API_KEY` - Email delivery service
   - `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY` - File storage
   - `AWS_DEFAULT_REGION` - AWS region (default: us-east-1)
   - `VAPID_PUBLIC_KEY` & `VAPID_PRIVATE_KEY` - Push notifications
   - `WEBHOOK_SECRET` - Webhook security
   - `COOKIE_DOMAIN` - Your domain for cookies
   - Optional: `GUMROAD_ACCESS_TOKEN`, `GUMROAD_ON`, `GUMROAD_PRODUCT_IDS`

2. **Deploy automatically:**
   - Push to `master` branch for automatic deployment
   - Or use "Deploy with Kamal" workflow for manual deployment

### Alternative: Manual Docker Deployment

If you prefer not to use Kamal, you can deploy manually with Docker:

```bash
# Build and run
docker build -t smallbets/campfire .
docker run -p 3000:3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=your-secret-key \
  -v /path/to/storage:/rails/storage \
  smallbets/campfire
```

### Environment Variables Reference

| Variable | Purpose | Required |
|----------|---------|----------|
| `SECRET_KEY_BASE` | Rails encryption key | ✅ |
| `RESEND_API_KEY` | Email delivery via Resend | ✅ |
| `AWS_ACCESS_KEY_ID` | File storage on AWS | ✅ |
| `AWS_SECRET_ACCESS_KEY` | File storage on AWS | ✅ |
| `AWS_DEFAULT_REGION` | AWS region (us-east-1) | ✅ |
| `VAPID_PUBLIC_KEY` | Web push notifications | ✅ |
| `VAPID_PRIVATE_KEY` | Web push notifications | ✅ |
| `WEBHOOK_SECRET` | Webhook security | ✅ |
| `COOKIE_DOMAIN` | Session cookies domain | ✅ |
| `VIMEO_ACCESS_TOKEN` | Video downloads | ⚠️ |
| `GUMROAD_ACCESS_TOKEN` | Payment processing | ⚠️ |
| `GUMROAD_ON` | Enable Gumroad features | ⚠️ |
| `GUMROAD_PRODUCT_IDS` | Gumroad product IDs | ⚠️ |

✅ = Required for production deployment  
⚠️ = Optional
