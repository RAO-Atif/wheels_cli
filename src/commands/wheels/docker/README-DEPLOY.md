# Wheels Docker Remote Deployment

Deploy your Wheels application to single or multiple remote servers via SSH with Docker.

## Features

- 🚀 Deploy to single or multiple servers with one command
- 🛑 Stop containers on all or specific servers
- 🐳 Automatic Docker or Docker Compose detection
- 📦 Automatic port detection from Dockerfile
- 🔒 SSH key-based authentication
- 📊 Deployment summary with success/failure tracking
- 🎯 Simple text or JSON configuration file
- 🎛️ Selective server control (stop specific servers by number)
- 🗄️ Database support via docker-compose

## Usage

### Deploying

**The command requires `deploy-servers.txt` or `deploy-servers.json` in your project root.**

This unified approach works for single or multiple servers:

#### Option 1: Simple Text File (Recommended)

Create `deploy-servers.txt` in your project root:

```
# Single server example
192.168.1.100 ubuntu 22
```

Or multiple servers:

```
# Production servers
192.168.1.100 ubuntu 22
192.168.1.101 ubuntu 22
192.168.1.102 ubuntu

# Staging server with custom port
staging.example.com deploy 2222

# Development server (port defaults to 22)
dev.example.com developer
```

**Format:** `host username [port]`
- Lines starting with `#` are comments
- Port is optional (defaults to 22)
- Separate values with spaces or tabs
- Image/container name derived from project directory name (uniform across all servers)

#### Option 2: JSON File (Advanced)

Create `deploy-servers.json` in your project root:

```json
{
  "servers": [
    {
      "host": "192.168.1.100",
      "user": "ubuntu",
      "port": 22,
      "remoteDir": "/home/ubuntu/myapp",
      "imageName": "myapp"
    },
    {
      "host": "192.168.1.101",
      "user": "admin",
      "port": 2222
    },
    {
      "host": "production.example.com",
      "user": "deploy"
    }
  ]
}
```

**Note:** JSON format allows more customization (remoteDir, imageName per server)

#### Deploy Command

Run the deploy command:

```bash
wheels docker deploy-remote
```

**The command automatically:**
- ✅ Detects `deploy-servers.txt` or `deploy-servers.json`
- ✅ Prioritizes `.txt` format if both exist
- ✅ Uses project directory name for uniform image/container naming across all servers
- ✅ Detects docker-compose files (uses `docker-compose up -d --build`)
- ✅ Falls back to standard Docker if no compose file
- ✅ Deploys to all servers sequentially
- ✅ Shows progress for each server
- ✅ Provides a summary of successful/failed deployments

### Stopping Containers

**The stop command also requires `deploy-servers.txt` or `deploy-servers.json` in your project root.**

#### Stop all servers

```bash
wheels docker stop
```

#### Stop specific servers only

```bash
# Stop only servers 1, 3, and 5 from config file
wheels docker stop --servers=1,3,5
```

#### Stop and remove containers

```bash
# Stop and remove containers on all servers
wheels docker stop --removeContainer=true

# Stop and remove on specific servers
wheels docker stop --servers=2,4 --removeContainer=true
```

**The stop command automatically:**
- ✅ Detects docker-compose files on remote servers
- ✅ Uses `docker-compose down` if compose file exists
- ✅ Falls back to `docker stop` and `docker rm` for standard Docker

## Container Naming

The deployment uses your **project directory name** to create uniform container and image names across all servers.

**Example:**
- Project directory: `/myproject` → Container/Image name: `myproject`
- Project directory: `/My Project` → Container/Image name: `my-project` (sanitized)
- Project directory: `/wheels_app` → Container/Image name: `wheels-app`

**Benefits:**
- ✅ Same container name on all servers (not based on SSH username)
- ✅ Easy to identify and manage containers
- ✅ Consistent naming in docker commands

**Note:** Names are automatically sanitized to be Docker-compatible (lowercase, alphanumeric, hyphens only).

## Configuration File Formats

### Simple Text File Format (`deploy-servers.txt`)

**Format:** `host username [port]`

**Example:**
```
# Comments start with #
192.168.1.100 ubuntu 22
192.168.1.101 ubuntu
production.example.com deploy 2222
```

**Rules:**
- One server per line
- Separate values with spaces or tabs
- Port is optional (defaults to 22)
- Empty lines and comments (starting with `#`) are ignored
- remoteDir defaults to `/home/{user}/{user}-app`
- imageName defaults to `{user}-app`

### JSON File Format (`deploy-servers.json`)

**Format:**
```json
{
  "servers": [
    {
      "host": "required",
      "user": "required",
      "port": 22,
      "remoteDir": "optional",
      "imageName": "optional"
    }
  ]
}
```

**Required Fields:**
- `host` - Server hostname or IP address
- `user` - SSH username

**Optional Fields:**
- `port` - SSH port (default: 22)
- `remoteDir` - Remote deployment directory (default: `/home/{user}/{project-name}`)
- `imageName` - Docker image name (default: `{project-name}` derived from project directory)

### Example Files

- See `examples/deploy-servers.example.txt` for text format example
- See `examples/deploy-servers.example.json` for JSON format example

## Prerequisites

1. **SSH Key Authentication**
   - SSH keys must be set up for passwordless authentication
   - Keys should be in `~/.ssh/` directory
   - Public key must be in remote server's `~/.ssh/authorized_keys`

2. **Remote Server Requirements**
   - Docker installed and running
   - SSH access with appropriate permissions
   - User has Docker permissions (in `docker` group)

3. **Local Requirements**
   - `tar` command available
   - `scp` command available
   - `ssh` command available
   - Dockerfile in project root
   - EXPOSE directive in Dockerfile (optional, defaults to 8080)

## How It Works

1. **Validates SSH connection** to remote server
2. **Creates remote directory** if it doesn't exist
3. **Detects port** from Dockerfile EXPOSE directive
4. **Creates tarball** of your application
5. **Uploads tarball** to remote server
6. **Extracts files** on remote server
7. **Builds Docker image** on remote server
8. **Stops old container** (if exists)
9. **Starts new container** with detected port mapping

## Port Detection

The command automatically detects the port from your Dockerfile:

```dockerfile
# Automatically uses port 3000
EXPOSE 3000
```

If no EXPOSE directive is found, it defaults to port 8080.

## Deployment Summary

After deployment, you'll see a summary:

```
📊 Deployment Summary:
   ✅ Successful: 2
   ❌ Failed: 1
```

## Troubleshooting

### SSH Connection Failed

- Verify SSH keys are set up correctly
- Check that you can manually SSH: `ssh user@host`
- Verify the user has necessary permissions

### Docker Build Failed

- Check that Docker is installed on remote server
- Verify user is in `docker` group: `docker ps` should work without sudo
- Check Dockerfile syntax

### Permission Denied

- Ensure remote user has write permissions to deployment directory
- Verify Docker socket permissions

## Examples

### Deployment Examples

#### Deploy to single staging server

1. Create `deploy-servers.txt`:
```
staging.example.com deploy
```

2. Deploy:
```bash
wheels docker deploy-remote
```

#### Deploy to multiple production servers

1. Create `deploy-servers.txt`:
```
# Production cluster
prod1.example.com deploy
prod2.example.com deploy
prod3.example.com deploy
```

2. Deploy:
```bash
wheels docker deploy-remote
```

#### Deploy with database (docker-compose)

1. Create `deploy-servers.txt`:
```
production.example.com deploy
```

2. Create `docker-compose.yml` in your project:
```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "8080:8080"
    depends_on:
      - db
  db:
    image: postgres:14
    environment:
      POSTGRES_PASSWORD: secret
```

3. Deploy:
```bash
wheels docker deploy-remote
```

### Stop Examples

#### Stop containers on all servers

Using the same `deploy-servers.txt`:
```
# Production cluster
prod1.example.com deploy
prod2.example.com deploy
prod3.example.com deploy
```

Stop all:
```bash
wheels docker stop
```

#### Stop specific servers only

```bash
# Stop only servers 1 and 3
wheels docker stop --servers=1,3
```

#### Stop and remove containers

```bash
# Stop and remove on all servers
wheels docker stop --removeContainer=true

# Stop and remove on specific servers
wheels docker stop --servers=1,2 --removeContainer=true
```

### Different environments

**Development:**

Create `deploy-servers.txt`:
```
dev.example.com developer
```

Deploy:
```bash
wheels docker deploy-remote
```

**Production:**

Create `deploy-servers.txt`:
```
prod1.example.com deploy
prod2.example.com deploy
```

Deploy:
```bash
wheels docker deploy-remote
```

## Workflow Tips

1. **Configuration file**: Always create `deploy-servers.txt` in your project root (works for single or multiple servers)
2. **Version control**: Commit `deploy-servers.txt` to your repo for consistent deployments
3. **Simple format**: Use `.txt` format for basic deployments (easier to read/edit)
4. **Advanced format**: Use `.json` format when you need custom remoteDir or imageName per server
5. **Docker Compose**: Use docker-compose.yml for apps with databases or multiple services
6. **Selective stopping**: Use `--servers=1,3,5` to stop specific servers without affecting others
7. **Clean removal**: Use `--removeContainer=true` when you want to fully remove containers, not just stop them
8. **CI/CD Integration**: Add `wheels docker deploy-remote` to your deployment pipeline

## Future Enhancements

- ⚡ Parallel deployment to multiple servers
- 🔄 Rollback support
- 📝 Deployment logs
- 🔔 Webhook notifications
- 📋 Support for custom config file names
- 🔐 Secrets management
