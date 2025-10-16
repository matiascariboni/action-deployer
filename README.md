# action-deployer

A GitHub Action to deploy projects on different AWS services, specifically EC2 instances, using Docker Compose.

## Description

`action-deployer` is a composite GitHub action designed to deploy Dockerized applications to AWS EC2 instances. The action integrates with `action-dockerization` to prepare the necessary inputs for deployment, such as Docker image creation and configuration.

This action is designed to automate the deployment process, allowing you to manage your EC2 infrastructure efficiently by running Docker containers on your instances with the help of Docker Compose.

## Requirements

For `action-deployer` to function correctly, it must be used in conjunction with [action-dockerization](https://github.com/matiascariboni/action-dockerization), which generates the required inputs, such as the Docker image to be deployed and Docker Compose configurations.

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

### `COMPOSE_PORTS`
- **Required**: `false`
- **Description**: The ports to be exposed for the Docker containers. Format: `'8080:80,3000:3000'`. If not provided, the container will run without exposed ports.

### `COMPOSE_NETWORKS`
- **Required**: `false`
- **Description**: The networks for Docker Compose. Format: `'network1,network2'`. If not provided, the container will use Docker's default networking.

### `COMPOSE_VOLUMES`
- **Required**: `false`
- **Description**: The volumes for Docker Compose. Format: `'/host/path:/container/path,volume_name:/data'`. If not provided, no volumes will be mounted.

### `COMPOSE_FILE_NAME`
- **Required**: `true`
- **Description**: The name of the Docker Compose file that will be created.

## Example Usage

### Basic deployment (without ports, networks, or volumes)

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout repository
      uses: actions/checkout@v2
    
    - name: Dockerize project
      uses: matiascariboni/action-dockerization@v1
      with:
        # Dockerization inputs like Dockerfile path, etc.
    
    - name: Deploy to EC2
      uses: matiascariboni/action-deployer@v1
      with:
        METHOD: 'EC2'
        EC2_IP: ${{ secrets.EC2_IP }}
        EC2_USER: ${{ secrets.EC2_USER }}
        EC2_KEY: ${{ secrets.EC2_KEY }}
        IMAGE_NAME: 'my-docker-image'
        COMPOSE_FILE_NAME: 'docker-compose.yml'
```

### Full deployment (with all optional parameters)

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout repository
      uses: actions/checkout@v2
    
    - name: Dockerize project
      uses: matiascariboni/action-dockerization@v1
      with:
        # Dockerization inputs like Dockerfile path, etc.
    
    - name: Deploy to EC2
      uses: matiascariboni/action-deployer@v1
      with:
        METHOD: 'EC2'
        EC2_IP: ${{ secrets.EC2_IP }}
        EC2_USER: ${{ secrets.EC2_USER }}
        EC2_KEY: ${{ secrets.EC2_KEY }}
        IMAGE_NAME: 'my-docker-image'
        COMPOSE_PORTS: '8080:80,3000:3000'
        COMPOSE_NETWORKS: 'my_network,backend_network'
        COMPOSE_VOLUMES: '/var/log/app:/app/logs,app_data:/data'
        COMPOSE_FILE_NAME: 'docker-compose.yml'
```

## How It Works

1. The action first makes the necessary scripts executable.
2. It then prepares the EC2 PEM key for SSH connections.
3. Once the PEM key is prepared, it copies the Docker image file to the EC2 instance.
4. It executes a script (`ec2_deploy.sh`) on the EC2 instance to:
   - Install Docker and Docker Compose if not already installed.
   - Load the Docker image and set up the Docker Compose configuration.
   - Deploy the service with Docker Compose.
5. The script intelligently handles optional parameters:
   - If `COMPOSE_PORTS` is not provided, the container runs without port mappings
   - If `COMPOSE_NETWORKS` is not provided, Docker's default networking is used
   - If `COMPOSE_VOLUMES` is not provided, no volumes are mounted
   - Network sections are only created in the Compose file when networks are actually used

## License

This action is licensed under the MIT License.