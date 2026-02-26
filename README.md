# Caker
Caker is a Swift-based tool for building and managing containerized applications with a focus on simplicity and developer experience.

## Wiki

- Local wiki home: [wiki/Home.md](wiki/Home.md)

## caked

`caked` is the core daemon process that handles container lifecycle management, including building, running, and orchestrating containers with configuration-driven workflows.

## cakectl

`cakectl` is the command-line interface tool used to interact with `caked`. It provides commands to:
- Build and deploy applications
- Manage container configurations
- View logs and status
- Control the daemon process

## caked Service

`caked` is a background service component that runs containerized workloads. It handles the core execution and management of containers, including:

- **Container Lifecycle Management**: Starting, stopping, and monitoring running containers
- **Resource Allocation**: Managing CPU, memory, and storage resources for containers
- **Service Registration**: Registering containers as system services for persistent operation
- **Health Monitoring**: Continuously checking container health status and auto-recovery
- **Logging and Diagnostics**: Collecting and streaming container logs and diagnostic information

Working in conjunction with `cakectl`, the command-line control interface, `caked` provides the backend daemon that executes administrative commands and maintains the operational state of all managed containers.
Together, `caked` and `cakectl` form a powerful system for container development and deployment.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue to report bugs or suggest enhancements.

- Contributor guide: [CONTRIBUTING.md](CONTRIBUTING.md)