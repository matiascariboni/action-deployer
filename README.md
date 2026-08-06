# action-deployer

A GitHub Action to deploy projects on different AWS services, specifically EC2 instances, using Docker Compose.

## Description

`action-deployer` is a composite GitHub action designed to deploy Dockerized applications to AWS EC2 instances. It builds the Docker Compose configuration (ports, networks, volumes) directly from Dockerfile comments and deploys it alongside the image produced by `action-dockerization`.

This action is designed to automate the deployment process, allowing you to manage your EC2 infrastructure efficiently by running Docker containers on your instances with the help of Docker Compose.

## Requirements

- This action must run after `actions/checkout` in the same job, since it reads the Dockerfile from the repository to derive the Docker Compose configuration.
- It's typically used alongside [action-dockerization](https://github.com/matiascariboni/action-dockerization), which builds the Docker image tar (`IMAGE_TAR_PATH`) that this action copies and deploys. Pass the same `DOCKERFILE_PATH` to both actions.

## Inputs

### `METHOD`
- **Required**: `true`
- **Description**: The delivery/deployment method. `EC2` delivers and deploys the image to an EC2 instance via SCP/SSH. `ECR` pushes the image to an Amazon ECR repository (`DELIVER` phase only — see [Delivering to ECR](#delivering-to-ecr)).

### `EC2_IP`
- **Required**: `true`
- **Description**: The IP address of the EC2 server to deploy the application to.

### `EC2_USER`
- **Required**: `true`
- **Description**: The user used to log into the EC2 instance.

### `EC2_KEY`
- **Required**: `true`
- **Description**: The PEM key for SSH access to the EC2 instance.

### `IMAGE_TAR_PATH`
- **Required**: `true`
- **Description**: Absolute path to the `.tar` file with the Docker image to be copied and deployed.

### `ECR_REPOSITORY`
- **Required**: `false` (required when `METHOD` is `ECR`)
- **Description**: Name of the Amazon ECR repository to push the image to. Created automatically if it doesn't already exist. AWS credentials and region must already be configured in the job before this step (e.g. via [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials)).

### `DOCKERFILE_PATH`
- **Required**: `false`
- **Default**: `Dockerfile`
- **Description**: Relative path to the Dockerfile to parse for ports, networks and volumes. Should be the same value passed to `action-dockerization`.

### `COMPOSE_NAME`
- **Required**: `false`
- **Description**: Base name for the generated Docker Compose file (`<COMPOSE_NAME>.yml`). Defaults to the repository name if not provided.

### `ACTION`
- **Required**: `false`
- **Description**: Which phase of the deployment to run: `DELIVER`, `DEPLOY`, or omitted to run both.
  - `DELIVER`: copies the image to the EC2 instance, loads it into Docker, and prepares/updates `docker-compose.yml` with the parsed ports/networks/volumes. The currently running container is left untouched — no downtime.
  - `DEPLOY`: swaps the running container for the image already loaded by a previous `DELIVER` run (`docker-compose up -d --force-recreate` scoped to that service) and removes the old image. Doesn't copy anything or parse the Dockerfile.
  - Omitted: runs `DELIVER` followed by `DEPLOY` in the same job, matching the previous all-in-one behavior.

  Splitting the two phases lets you prepare a release (e.g. build + deliver in one workflow run) and trigger the actual swap later, independently — without having to pass image/Dockerfile information to the job that just flips the switch.

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
        IMAGE_TAR_PATH: ${{ github.workspace }}/${{ steps.dockerize.outputs.IMAGE_NAME }}.tar
        DOCKERFILE_PATH: Dockerfile
```

## How It Works

1. **Validation**: The action validates all required inputs (and `ACTION`, if provided) and displays configuration details for debugging.
2. **Script Preparation**: Makes deployment scripts executable.
3. **Compose configuration**: Resolves the Docker Compose file name. If `ACTION` is `DEPLOY`, the Dockerfile isn't required to exist and isn't parsed, since that phase doesn't need ports/networks/volumes.
4. **SSH Setup**: Prepares the EC2 PEM key and establishes SSH connectivity to the target instance.
5. **Delivery** (skipped if `ACTION` is `DEPLOY`): if `METHOD` is `EC2`, copies the Docker image file to the EC2 instance via SCP, then runs `ec2_deliver.sh` remotely to install Docker/Docker Compose if needed, load the image, and prepare/update `docker-compose.yml`. If `METHOD` is `ECR`, runs `ecr_deliver.sh` locally to load the image, create the ECR repository if needed, and push the image to it. Either way, the currently running container isn't touched.
6. **Deploy** (skipped if `ACTION` is `DELIVER`, and a no-op if `METHOD` is `ECR`): runs `ec2_deploy_run.sh` remotely to force-recreate the service's container with the already-loaded image and remove the old image, minimizing downtime.

## Debugging

The action provides detailed logging at each step:
- Input parameter validation and display
- Dockerfile parsing (ports, networks, volumes) and compose file name resolution
- SSH connection establishment
- File transfer progress
- Delivery phase (image loading, compose configuration, formatting)
- Deploy phase (container swap, old image removal, network cleanup)

All critical operations include error checking with clear failure messages to help troubleshoot deployment issues.

## Splitting delivery and deployment

By default (no `ACTION` input) the action delivers and deploys in the same run, same as before. To split them across separate jobs or workflow runs:

```yaml
# Job/run 1 — has the Dockerfile and the built image
- name: Deliver to EC2
  uses: matiascariboni/action-deployer@v2
  with:
    METHOD: 'EC2'
    ACTION: 'DELIVER'
    EC2_IP: ${{ secrets.EC2_IP }}
    EC2_USER: ${{ secrets.EC2_USER }}
    EC2_KEY: ${{ secrets.EC2_KEY }}
    IMAGE_TAR_PATH: ${{ github.workspace }}/${{ steps.dockerize.outputs.IMAGE_NAME }}.tar
    DOCKERFILE_PATH: Dockerfile

# Job/run 2 — only needs EC2 credentials and IMAGE_TAR_PATH (its basename identifies the service), not the Dockerfile.
# The tar file itself doesn't need to exist on this runner — only the path's basename is used.
- name: Deploy on EC2
  uses: matiascariboni/action-deployer@v2
  with:
    METHOD: 'EC2'
    ACTION: 'DEPLOY'
    EC2_IP: ${{ secrets.EC2_IP }}
    EC2_USER: ${{ secrets.EC2_USER }}
    EC2_KEY: ${{ secrets.EC2_KEY }}
    IMAGE_TAR_PATH: ${{ github.workspace }}/${{ steps.dockerize.outputs.IMAGE_NAME }}.tar
```

`DEPLOY` only needs `IMAGE_TAR_PATH` (its basename, without `.tar`) to know which service to swap inside the shared `docker-compose.yml` — it doesn't re-copy or re-load anything, so the Dockerfile/build context don't need to be available in that job.

## Delivering to ECR

`METHOD: 'ECR'` pushes the image built by `action-dockerization` to an Amazon ECR repository instead of an EC2 instance. Only the `DELIVER` phase applies to this method — `ACTION: 'DEPLOY'` is a no-op when `METHOD` is `ECR`.

AWS credentials and region must already be configured in the job before this action runs — this action doesn't accept AWS credentials as inputs, it relies on whatever is already configured (e.g. by [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials)). The image is pushed with the same tag it already has after being loaded from `IMAGE_TAR_PATH` — there's no separate `IMAGE_TAG` input.

```yaml
jobs:
  deliver:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Dockerize project
      id: dockerize
      uses: matiascariboni/action-dockerization@v3
      with:
        IMAGE_ARCH: linux/amd64
        DOCKERFILE_PATH: Dockerfile

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: us-east-1

    - name: Deliver to ECR
      uses: matiascariboni/action-deployer@v2
      with:
        METHOD: 'ECR'
        ACTION: 'DELIVER'
        ECR_REPOSITORY: 'my-app'
        IMAGE_TAR_PATH: ${{ github.workspace }}/${{ steps.dockerize.outputs.IMAGE_NAME }}.tar
```

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
