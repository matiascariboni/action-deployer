# action-deployer

A GitHub Action to deploy projects on different AWS services, specifically EC2 instances, using Docker Compose.

## Description

`action-deployer` is a composite GitHub action designed to deploy Dockerized applications to AWS EC2 instances. It builds the Docker Compose configuration (ports, networks, volumes) directly from Dockerfile comments and deploys it alongside the image produced by `action-dockerization`.

This action is designed to automate the deployment process, allowing you to manage your EC2 infrastructure efficiently by running Docker containers on your instances with the help of Docker Compose.

## Requirements

- This action must run after `actions/checkout` in the same job, since it reads the Dockerfile from the repository to derive the Docker Compose configuration.
- It's typically used alongside [action-dockerization](https://github.com/matiascariboni/action-dockerization), which builds the Docker image (`IMAGE_NAME`) that this action copies and deploys. Pass the same `DOCKERFILE_PATH` to both actions.

## Inputs

### `METHOD`
- **Required**: `true`
- **Description**: The deployment method. Currently, "EC2" is supported.

### `EC2_IP`
- **Required**: `true`
- **Description**: The IP address of the EC2 server to deploy the application to.

### `EC2_USER`
- **Required**: `true`
- **Description**: The user used to log into the EC2 instance.

### `EC2_KEY`
- **Required**: `true`
- **Description**: The PEM key for SSH access to the EC2 instance.

### `IMAGE_NAME`
- **Required**: `true`
- **Description**: The name of the zipped Docker image file to be copied and deployed.

### `DOCKERFILE_PATH`
- **Required**: `false`
- **Default**: `Dockerfile`
- **Description**: Relative path to the Dockerfile to parse for ports, networks and volumes. Should be the same value passed to `action-dockerization`.

### `COMPOSE_NAME`
- **Required**: `false`
- **Description**: Base name for the generated Docker Compose file (`<COMPOSE_NAME>.yml`). Defaults to the repository name if not provided.

## Dockerfile comment syntax

Ports, networks and volumes are derived automatically from comments in the Dockerfile pointed to by `DOCKERFILE_PATH`:

```Dockerfile
EXPOSE 3000
# TO 80
# NETWORK my-network
# VOLUME /host/path:/container/path
```

- `EXPOSE 3000` + `# TO 80` → maps host port `80` to container port `3000`.
- `# NETWORK my-network` → attaches the service to `my-network`.
- `# VOLUME /host/path:/container/path` → bind-mounts `/host/path` into `/container/path` (only bind mounts are supported, not named volumes).

Any of these can be omitted; the container is deployed without ports, without extra networks, and/or without volumes accordingly.

## Example Usage

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Dockerize project
      uses: matiascariboni/action-dockerization@v3
      with:
        IMAGE_ARCH: linux/amd64
        DOCKERFILE_PATH: Dockerfile

    - name: Deploy to EC2
      uses: matiascariboni/action-deployer@v2
      with:
        METHOD: 'EC2'
        EC2_IP: ${{ secrets.EC2_IP }}
        EC2_USER: ${{ secrets.EC2_USER }}
        EC2_KEY: ${{ secrets.EC2_KEY }}
        IMAGE_NAME: ${{ steps.dockerize.outputs.IMAGE_NAME }}
        DOCKERFILE_PATH: Dockerfile
```

## How It Works

1. **Validation**: The action validates all required inputs and displays configuration details for debugging.
2. **Script Preparation**: Makes deployment scripts executable.
3. **Compose configuration**: Resolves the Docker Compose file name and parses `DOCKERFILE_PATH` for ports, networks and volumes.
4. **SSH Setup**: Prepares the EC2 PEM key and establishes SSH connectivity to the target instance.
5. **Image Transfer**: Copies the Docker image file to the EC2 instance via SCP.
6. **Deployment**: Executes the deployment script (`ec2_deploy.sh`) on the EC2 instance to:
   - Install Docker and Docker Compose if not already installed
   - Load the Docker image and configure Docker Compose
   - Deploy the service with proper error handling and progress tracking

## Debugging

The action provides detailed logging at each step:
- Input parameter validation and display
- Dockerfile parsing (ports, networks, volumes) and compose file name resolution
- SSH connection establishment
- File transfer progress
- Deployment phases (validation, image loading, configuration, formatting, network cleanup, container startup)

All critical operations include error checking with clear failure messages to help troubleshoot deployment issues.

## Optional Parameters

The action intelligently handles optional parameters:
- If no `# TO` port mappings are found, the container runs without port mappings
- If no `# NETWORK` comments are found, Docker's default networking is used
- If no `# VOLUME` comments are found, no volumes are mounted
- Network sections are only created in the Compose file when networks are actually used

## Troubleshooting

If deployment fails, check the GitHub Actions logs for:
1. **Input validation errors**: Ensure all required secrets are set
2. **Dockerfile not found**: Verify `DOCKERFILE_PATH` points to an existing file relative to the repo root
3. **SSH connectivity issues**: Verify EC2 security groups allow SSH from GitHub Actions IPs
4. **File transfer errors**: Check EC2 instance disk space and permissions
5. **Docker errors**: Review the deployment script output for Docker/Compose issues

## License

This action is licensed under the MIT License.
