#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup() {
  # Ensure we have a clean environment for each test
  unset BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES
  unset BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILES
  unset BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_CLEANUP_SETTING
}

@test "Pre-exit hook skips cleanup when disabled" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="false"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="test-server"
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Cleanup disabled, skipping MCP server cleanup"
}

@test "Pre-exit hook skips cleanup when no server name is set" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  unset BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "No MCP server names found, nothing to clean up"
}

@test "Pre-exit hook warns when thv is not available" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="test-server"
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Warning: ToolHive (thv) not found in PATH, cannot clean up MCP server"
}

@test "Pre-exit hook successfully cleans up running server" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="test-server"
  
  stub thv \
    'list --all : echo "test-server running stdio 8080 http://localhost:8080"' \
    'rm test-server : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP server 'test-server', proceeding with cleanup..."
  assert_output --partial "Removing MCP server 'test-server'..."
  assert_output --partial "✅ MCP server removed successfully"
  assert_output --partial "✅ Cleanup completed successfully for 'test-server'"
  
  unstub thv
}

@test "Pre-exit hook cleans up stopped server" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="test-server"
  
  stub thv \
    'list --all : echo "test-server stopped stdio 8080 http://localhost:8080"' \
    'rm test-server : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP server 'test-server', proceeding with cleanup..."
  assert_output --partial "Removing MCP server 'test-server'..."
  assert_output --partial "✅ MCP server removed successfully"
  assert_output --partial "✅ Cleanup completed successfully for 'test-server'"
  
  unstub thv
}

@test "Pre-exit hook cleans up MCP configuration file when enabled" {
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILES="./test_mcp_config.json"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_CLEANUP_SETTING="true"
  
  # Create a temporary config file
  echo '{"mcpServers": {}}' > "./test_mcp_config.json"
  
  # Verify file exists before cleanup
  [ -f "./test_mcp_config.json" ]
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Cleaning up MCP configuration files..."
  assert_output --partial "Removing MCP config file: ./test_mcp_config.json"
  
  # Verify file was removed
  [ ! -f "./test_mcp_config.json" ]
}

@test "Pre-exit hook skips MCP config cleanup when disabled" {
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_FILES="./test_mcp_config.json"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_CONFIG_CLEANUP_SETTING="false"
  
  # Create a temporary config file
  echo '{"mcpServers": {}}' > "./test_mcp_config.json"
  
  # Verify file exists before cleanup
  [ -f "./test_mcp_config.json" ]
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "MCP config file cleanup disabled or no files to clean up"
  
  # Verify file still exists
  [ -f "./test_mcp_config.json" ]
  
  # Clean up manually
  rm -f "./test_mcp_config.json"
}

@test "Pre-exit hook handles non-existent server gracefully" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="non-existent-server"
  
  stub thv \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "MCP server 'non-existent-server' not found, nothing to clean up"
  
  unstub thv
}

@test "Pre-exit hook handles thv command failures gracefully" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="test-server"
  
  stub thv \
    'list --all : echo "test-server running stdio 8080 http://localhost:8080"' \
    'rm test-server : exit 1' \
    'list --all : echo "test-server running stdio 8080 http://localhost:8080"'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP server 'test-server', proceeding with cleanup..."
  assert_output --partial "Warning: Failed to thv rm server 'test-server'"
  assert_output --partial "⚠️  Server 'test-server' may still exist after cleanup"
  
  unstub thv
}

@test "Pre-exit hook defaults cleanup to true when not specified" {
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="test-server"
  unset BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP
  
  stub thv \
    'list --all : echo "test-server running stdio 8080 http://localhost:8080"' \
    'rm test-server : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP server 'test-server', proceeding with cleanup..."
  assert_output --partial "✅ Cleanup completed successfully"
  
  unstub thv
}