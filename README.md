# ToolHive Buildkite Plugin

A Buildkite plugin that enables running Model Context Protocol (MCP) servers using [ToolHive](https://docs.stacklok.com/toolhive) in your CI/CD pipelines.

## Features

- **Automatic ToolHive Installation**: Downloads and installs ToolHive if not already available
- **MCP Server Management**: Start, manage, and clean up MCP servers during pipeline execution
- **Multiple Server Sources**: Support for registry servers, Docker images, and protocol schemes (`uvx://`, `npx://`, `go://`)
- **Flexible Configuration**: Customize transport methods, ports, volumes, secrets, and more

## Usage

Add the plugin to your pipeline step:

```yaml
steps:
  - label: "Run with MCP Server"
    command: "your-command-here"
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "fetch"  # Server from ToolHive registry
```

### Registry Server Example

```yaml
steps:
  - label: "Use Fetch MCP Server"
    command: "curl http://localhost:8080/some-endpoint"
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "fetch"
          transport: "stdio"
          proxy-port: 8080
```

### Docker Image Example

```yaml
steps:
  - label: "Use Custom MCP Server"
    command: "your-command"
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "my-registry/my-mcp-server:latest"
          transport: "sse"
          volumes:
            - "/host/path:/container/path:ro"
```

### Protocol Scheme Example

```yaml
steps:
  - label: "Use Python MCP Server"
    command: "your-command"
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "uvx://some-python-mcp-package@1.0.0"
          transport: "streamable-http"
          args:
            - "--verbose"
            - "--config=/path/to/config"
```

### With Secrets

```yaml
steps:
  - label: "Use GitHub MCP Server"
    command: "your-command"
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "github"
          secrets:
            - name: "github-token"
              target: "GITHUB_PERSONAL_ACCESS_TOKEN"
            - name: "api-key"
              target: "API_KEY"
```

## Configuration

### Required

| Option | Type | Description |
|--------|------|-------------|
| `server` | String | The MCP server to run (registry name, Docker image, or protocol scheme) |

### Optional

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `name` | String | Auto-generated | Custom name for the MCP server instance |
| `transport` | String | `""` (auto) | Transport method: `stdio`, `sse`, or `streamable-http` |
| `proxy-port` | Integer | Random | Specific port for the ToolHive proxy |
| `secrets` | Array | `[]` | Secrets to pass to the MCP server |
| `volumes` | Array | `[]` | Volume mounts in format `"host-path:container-path[:ro]"` |
| `args` | Array | `[]` | Additional arguments to pass to the MCP server |
| `permission-profile` | String | Default | Permission profile for the MCP server |
| `toolhive-version` | String | Latest | Specific version of ToolHive to download |
| `cleanup` | Boolean | `true` | Whether to clean up the MCP server on exit |
| `mcp-config-file` | String | `./mcp_servers.json` | Path where to generate the MCP config file |
| `mcp-config-cleanup` | Boolean | `true` | Whether to remove the MCP config file on exit |

### Secrets Configuration

Secrets are configured as an array of objects with `name` and `target` properties:

```yaml
secrets:
  - name: "secret-name-in-toolhive"
    target: "ENVIRONMENT_VARIABLE_NAME"
```

The `name` refers to a secret stored in ToolHive's secret management system, and `target` is the environment variable name that will be set in the MCP server container.

Note that secrets must be created in ToolHive before they can be used in the plugin.

### Volume Configuration

Volumes are specified as strings in Docker volume format:

```yaml
volumes:
  - "/host/path:/container/path"      # Read-write mount
  - "/host/path:/container/path:ro"   # Read-only mount
```

## Server Types

### Registry Servers

Use servers from the [ToolHive registry](https://docs.stacklok.com/toolhive/guides-cli/registry):

```yaml
server: "fetch"           # Fetch MCP server
server: "github"          # GitHub MCP server
server: "filesystem"      # Filesystem MCP server
```

### Docker Images

Use any Docker image that implements the MCP protocol:

```yaml
server: "my-registry/my-mcp-server:v1.0.0"
server: "ghcr.io/org/mcp-server:latest"
```

### Protocol Schemes

Use package managers to run MCP servers:

```yaml
server: "uvx://python-mcp-package@1.0.0"    # Python via uv
server: "npx://node-mcp-package@2.0.0"      # Node.js via npm
server: "go://github.com/org/go-mcp-server"  # Go module
```

## MCP Configuration File Generation

The plugin automatically generates an MCP configuration file that contains connection details for all spawned MCP servers. This makes it easy for MCP clients to discover and connect to available servers.

### Configuration File Format

The generated file follows the standard MCP configuration format:

```json
{
  "mcpServers": {
    "fetch-server": {
      "url": "http://localhost:8080/mcp",
      "type": "streamable-http"
    },
    "github-server": {
      "url": "http://localhost:8081/sse#github-server",
      "type": "sse"
    }
  }
}
```

### URL Format Details

- **SSE servers**: `http://localhost:{port}/sse#{server-name}`
- **Streamable HTTP servers**: `http://localhost:{port}/mcp`
- **Type**: Either `"sse"` or `"streamable-http"`

### Environment Variable

The plugin exports `BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILE` pointing to the generated configuration file:

```bash
echo "MCP config file: $BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILE"
cat $BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILE
```

### Usage with MCP Clients

```yaml
steps:
  - command: |
      # Use the generated MCP configuration with your tools
      my-mcp-client --config $BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILE
      
      # Or read the configuration programmatically
      python -c "
      import json
      import os
      config_file = os.environ['BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILE']
      with open(config_file) as f:
          config = json.load(f)
          print('Available MCP servers:', list(config['mcpServers'].keys()))
      "
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "fetch"
          mcp-config-file: "./my_mcp_config.json"
```

## How It Works

1. **Environment Hook**: Checks if ToolHive is available, downloads it if needed
2. **Pre-Command Hook**: Starts the specified MCP server with the given configuration
3. **Command Execution**: Your pipeline command runs with the MCP server available
4. **Pre-Exit Hook**: Stops and removes the MCP server (if cleanup is enabled)

## Server Naming

The plugin automatically generates unique server names to avoid conflicts:

- Uses custom name if provided via the `name` option
- Otherwise generates: `build-{BUILD_NUMBER}-step-{STEP_KEY}-{SERVER_NAME}`
- Names are normalized (lowercase, special characters replaced with hyphens)

## Requirements

- Docker or Podman container runtime
- Internet access to download ToolHive (if not already installed)
- Sufficient permissions to run containers

## Troubleshooting

### ToolHive Installation Issues

If ToolHive fails to install:

1. Check internet connectivity
2. Verify the GitHub releases are accessible
3. Ensure sufficient disk space
4. Check file permissions in the installation directory

### MCP Server Startup Issues

If the MCP server fails to start:

1. Check the server logs: `thv logs <server-name>`
2. Verify the server configuration
3. Ensure required secrets are available
4. Check container runtime (Docker/Podman) status

### Port Conflicts

If you encounter port conflicts:

1. Use the `proxy-port` option to specify a different port
2. Check for other services using the same port
3. Use dynamic port allocation (default behavior)

## Examples

### Complete Example with All Options

```yaml
steps:
  - label: "Complex MCP Server Setup"
    command: |
      echo "MCP server is running"
      curl http://localhost:9000/health
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "my-registry/custom-mcp:v2.0.0"
          name: "my-custom-server"
          transport: "sse"
          proxy-port: 9000
          secrets:
            - name: "api-token"
              target: "API_TOKEN"
            - name: "db-password"
              target: "DATABASE_PASSWORD"
          volumes:
            - "./config:/app/config:ro"
            - "./data:/app/data"
          args:
            - "--log-level=debug"
            - "--config=/app/config/server.yml"
          permission-profile: "network"
          toolhive-version: "v0.0.33"
          cleanup: true
          mcp-config-file: "./custom_mcp_config.json"
          mcp-config-cleanup: false
```

### Multiple Steps with Different Servers

```yaml
steps:
  - label: "Step 1: Use Fetch Server"
    command: "test-fetch-functionality"
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "fetch"
          
  - label: "Step 2: Use GitHub Server"
    command: "test-github-integration"
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "github"
          secrets:
            - name: "github-token"
              target: "GITHUB_PERSONAL_ACCESS_TOKEN"
```

### Multiple MCP Servers in One Step

You can run multiple MCP servers in a single step by calling the plugin multiple times:

```yaml
steps:
  - label: "Use Multiple MCP Servers"
    command: |
      echo "Both servers are now running"
      curl http://localhost:8080/fetch-endpoint
      curl http://localhost:8081/github-endpoint
    plugins:
      - StacklokLabs/toolhive#v0.0.2:
          server: "fetch"
          name: "fetch-server"
          proxy-port: 8080
      - StacklokLabs/toolhive#v0.0.2:
          server: "github"
          name: "github-server"
          proxy-port: 8081
          secrets:
            - name: "github-token"
              target: "GITHUB_PERSONAL_ACCESS_TOKEN"
```

**Important Notes for Multiple Servers:**
- Each server must have a unique `name` to avoid conflicts
- Each server should use a different `proxy-port` if specified
- All servers will be automatically cleaned up at the end of the step
- Servers are started in the order they appear in the plugin list

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the plugin
5. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Links

- [ToolHive Documentation](https://docs.stacklok.com/toolhive)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Buildkite Plugin Documentation](https://buildkite.com/docs/pipelines/integrations/plugins)
- [GitHub Repository](https://github.com/StacklokLabs/toolhive-buildkite-plugin)