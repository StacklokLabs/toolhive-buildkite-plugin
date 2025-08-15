#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup() {
  export PATH="$BATS_TEST_TMPDIR:$PATH"
  # Ensure we have a clean environment for each test
  unset BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES
}

@test "Pre-command hook requires server configuration" {
  unset BUILDKITE_PLUGIN_TOOLHIVE_SERVER
  
  run "$PWD/hooks/pre-command"
  
  assert_failure
  assert_output --partial "Error: 'server' configuration is required"
}

@test "Pre-command hook fails when thv is not available" {
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="fetch"
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/pre-command"
  
  assert_failure
  assert_output --partial "Error: ToolHive (thv) not found in PATH"
}

@test "Pre-command hook generates server name from step context" {
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="fetch"
  export BUILDKITE_BUILD_NUMBER="123"
  export BUILDKITE_STEP_KEY="test-step"
  
  stub thv \
    'registry info fetch : exit 0' \
    'list --all : echo ""' \
    'run --name build-123-step-test-step-fetch fetch : echo "Server started"' \
    'list --all : echo "build-123-step-test-step-fetch running stdio 8080 http://localhost:8080"'
  
  run "$PWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "Instance Name: build-123-step-test-step-fetch"
  assert_output --partial "✅ MCP server 'build-123-step-test-step-fetch' started successfully"
  
  unstub thv
}

@test "Pre-command hook generates MCP configuration file" {
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="fetch"
  export BUILDKITE_BUILD_NUMBER="123"
  export BUILDKITE_STEP_KEY="test-step"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILE="./test_mcp_config.json"
  
  # Create a temporary directory for the test
  temp_dir=$(mktemp -d)
  cd "$temp_dir"
  
  stub thv \
    'registry info fetch : exit 0' \
    'list --all : echo ""' \
    'run --name build-123-step-test-step-fetch --label buildkite.pipeline=build-123-step-test-step fetch : echo "Server started"' \
    'list --all : echo "build-123-step-test-step-fetch running stdio 8080 http://localhost:8080"' \
    'list --format=mcpservers -l buildkite.pipeline=build-123-step-test-step : echo "{\"mcpServers\":{\"build-123-step-test-step-fetch\":{\"url\":\"http://localhost:8080/mcp\",\"type\":\"streamable-http\"}}}"'
  
  run "$OLDPWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "✅ MCP configuration file generated: ./test_mcp_config.json"
  assert_output --partial "Exported BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILE=./test_mcp_config.json"
  
  # Check that the config file was created
  [ -f "./test_mcp_config.json" ]
  
  # Check the content of the config file
  run cat "./test_mcp_config.json"
  assert_output --partial '"mcpServers"'
  assert_output --partial '"build-123-step-test-step-fetch"'
  
  # Clean up
  rm -f "./test_mcp_config.json"
  cd "$OLDPWD"
  rmdir "$temp_dir"
  
  unstub thv
}

@test "Pre-command hook uses custom name when provided" {
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="fetch"
  export BUILDKITE_PLUGIN_TOOLHIVE_NAME="my-custom-server"
  
  stub thv \
    'registry info fetch : exit 0' \
    'list --all : echo ""' \
    'run --name my-custom-server fetch : echo "Server started"' \
    'list --all : echo "my-custom-server running stdio 8080 http://localhost:8080"'
  
  run "$PWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "Instance Name: my-custom-server"
  assert_output --partial "✅ MCP server 'my-custom-server' started successfully"
  
  unstub thv
}

@test "Pre-command hook handles Docker image references" {
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="my-registry/my-mcp:latest"
  export BUILDKITE_BUILD_NUMBER="123"
  
  stub thv \
    'registry info my-registry/my-mcp:latest : exit 1' \
    'list --all : echo ""' \
    'run --name build-123-my-mcp my-registry/my-mcp:latest : echo "Server started"' \
    'list --all : echo "build-123-my-mcp running stdio 8080 http://localhost:8080"'
  
  run "$PWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "Instance Name: build-123-my-mcp"
  assert_output --partial "✅ MCP server 'build-123-my-mcp' started successfully"
  
  unstub thv
}

@test "Pre-command hook handles protocol schemes" {
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="uvx://some-python-package@1.0.0"
  export BUILDKITE_BUILD_NUMBER="123"
  
  stub thv \
    'registry info uvx://some-python-package@1.0.0 : exit 1' \
    'list --all : echo ""' \
    'run --name build-123-some-python-package uvx://some-python-package@1.0.0 : echo "Server started"' \
    'list --all : echo "build-123-some-python-package running stdio 8080 http://localhost:8080"'
  
  run "$PWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "Instance Name: build-123-some-python-package"
  assert_output --partial "✅ MCP server 'build-123-some-python-package' started successfully"
  
  unstub thv
}

@test "Pre-command hook adds transport option when specified" {
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="fetch"
  export BUILDKITE_PLUGIN_TOOLHIVE_TRANSPORT="sse"
  export BUILDKITE_BUILD_NUMBER="123"
  
  stub thv \
    'registry info fetch : exit 0' \
    'list --all : echo ""' \
    'run --name build-123-fetch --transport sse fetch : echo "Server started"' \
    'list --all : echo "build-123-fetch running sse 8080 http://localhost:8080"'
  
  run "$PWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "✅ MCP server 'build-123-fetch' started successfully"
  
  unstub thv
}

@test "Pre-command hook stops existing server before starting new one" {
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="fetch"
  export BUILDKITE_BUILD_NUMBER="123"
  
  stub thv \
    'registry info fetch : exit 0' \
    'list --all : echo "build-123-fetch running stdio 8080 http://localhost:8080"' \
    'stop build-123-fetch : echo "Server stopped"' \
    'rm build-123-fetch : echo "Server removed"' \
    'run --name build-123-fetch fetch : echo "Server started"' \
    'list --all : echo "build-123-fetch running stdio 8080 http://localhost:8080"'
  
  run "$PWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "MCP server 'build-123-fetch' is already running, stopping it first..."
  assert_output --partial "✅ MCP server 'build-123-fetch' started successfully"
  
  unstub thv
}