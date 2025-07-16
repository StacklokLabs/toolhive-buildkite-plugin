#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

@test "Pre-exit hook skips cleanup when disabled" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="false"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAME="test-server"
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Cleanup disabled, skipping MCP server cleanup"
}

@test "Pre-exit hook skips cleanup when no server name is set" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  unset BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAME
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "No MCP server name found, nothing to clean up"
}

@test "Pre-exit hook warns when thv is not available" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAME="test-server"
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Warning: ToolHive (thv) not found in PATH, cannot clean up MCP server"
}

@test "Pre-exit hook successfully cleans up running server" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAME="test-server"
  
  stub thv \
    'list --all : echo "test-server running stdio 8080 http://localhost:8080"' \
    'list : echo "test-server running stdio 8080 http://localhost:8080"' \
    'stop test-server : echo "Server stopped"' \
    'rm test-server : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP server 'test-server', proceeding with cleanup..."
  assert_output --partial "Stopping MCP server 'test-server'..."
  assert_output --partial "✅ MCP server stopped successfully"
  assert_output --partial "Removing MCP server 'test-server'..."
  assert_output --partial "✅ MCP server removed successfully"
  assert_output --partial "✅ Cleanup completed successfully"
  
  unstub thv
}

@test "Pre-exit hook cleans up stopped server" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAME="test-server"
  
  stub thv \
    'list --all : echo "test-server stopped stdio 8080 http://localhost:8080"' \
    'list : echo ""' \
    'rm test-server : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP server 'test-server', proceeding with cleanup..."
  assert_output --partial "MCP server 'test-server' is already stopped"
  assert_output --partial "Removing MCP server 'test-server'..."
  assert_output --partial "✅ MCP server removed successfully"
  assert_output --partial "✅ Cleanup completed successfully"
  
  unstub thv
}

@test "Pre-exit hook handles non-existent server gracefully" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAME="non-existent-server"
  
  stub thv \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "MCP server 'non-existent-server' not found, nothing to clean up"
  
  unstub thv
}

@test "Pre-exit hook handles thv command failures gracefully" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAME="test-server"
  
  stub thv \
    'list --all : echo "test-server running stdio 8080 http://localhost:8080"' \
    'list : echo "test-server running stdio 8080 http://localhost:8080"' \
    'stop test-server : exit 1' \
    'rm test-server : exit 1' \
    'list --all : echo "test-server running stdio 8080 http://localhost:8080"'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP server 'test-server', proceeding with cleanup..."
  assert_output --partial "Warning: Failed to thv stop server 'test-server'"
  assert_output --partial "Warning: Failed to thv rm server 'test-server'"
  assert_output --partial "⚠️  Server may still exist after cleanup"
  
  unstub thv
}

@test "Pre-exit hook defaults cleanup to true when not specified" {
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAME="test-server"
  unset BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP
  
  stub thv \
    'list --all : echo "test-server running stdio 8080 http://localhost:8080"' \
    'list : echo "test-server running stdio 8080 http://localhost:8080"' \
    'stop test-server : echo "Server stopped"' \
    'rm test-server : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP server 'test-server', proceeding with cleanup..."
  assert_output --partial "✅ Cleanup completed successfully"
  
  unstub thv
}