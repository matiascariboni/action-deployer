# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2025-10-16

### Changed
- Made `COMPOSE_PORTS` parameter optional - containers can now be deployed without port mappings
- Made `COMPOSE_NETWORKS` parameter optional - containers can use Docker's default networking if not specified
- Improved network section handling in Docker Compose files - network configuration is only created when networks are actually used

### Fixed
- Fixed variable validation logic in `ec2_deploy.sh` to correctly handle optional parameters
- Improved empty network detection to prevent creating unnecessary network sections in Compose files

### Documentation
- Updated README with examples showing both basic and full deployment scenarios
- Added clear documentation for optional parameters and their formats

## [1.0.1] - 2025-XX-XX

### Added
- Initial support for `COMPOSE_VOLUMES` parameter

### Changed
- Improved script error handling and logging

## [1.0.0] - 2025-XX-XX

### Added
- Initial release
- EC2 deployment support
- Docker Compose configuration generation
- Automatic Docker and Docker Compose installation
- Network cleanup functionality
- Docker image loading and deployment

### Features
- SSH-based deployment to EC2 instances
- Dynamic Docker Compose file generation
- Support for ports, networks, and volumes configuration
- Automatic formatting of Docker Compose files
- Cleanup of unused Docker networks

[1.0.2]: https://github.com/matiascariboni/action-deployer/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/matiascariboni/action-deployer/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/matiascariboni/action-deployer/releases/tag/v1.0.0