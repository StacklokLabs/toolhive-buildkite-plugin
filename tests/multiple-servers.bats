#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup() {
  # Ensure we have a clean environment for each test
  unset BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES
}

@test "Multiple plugin calls store all server names" {
  export BUILDKITE_BUILD_NUMBER="123"
  
  # First plugin call
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="fetch"
  export BUILDKITE_PLUGIN_TOOLHIVE_NAME="fetch-server"
  
  stub thv \
    'registry info fetch : exit 0' \
    'list --all : echo ""' \
    'run --name fetch-server --label buildkite.pipeline=build-123 fetch : echo "Server started"' \
    'list --all : echo "fetch-server running stdio 8080 http://localhost:8080"' \
    'list --format=mcpservers -l buildkite.pipeline=build-123 : echo "{\"mcpServers\": {}}"'
  
  # Source the hook instead of running it in a subshell to preserve environment variables
  source "$PWD/hooks/pre-command"
  
  # Verify first server is stored
  assert_equal "$BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES" "fetch-server"
  
  unstub thv
  
  # Second plugin call (simulating multiple plugin usage)
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="github"
  export BUILDKITE_PLUGIN_TOOLHIVE_NAME="github-server"
  
  stub thv \
    'registry info github : exit 0' \
    'list --all : echo ""' \
    'run --name github-server --label buildkite.pipeline=build-123 github : echo "Server started"' \
    'list --all : echo "github-server running stdio 8081 http://localhost:8081"' \
    'list --format=mcpservers -l buildkite.pipeline=build-123 : echo "{\"mcpServers\": {}}"'
  
  # Source the hook instead of running it in a subshell to preserve environment variables
  source "$PWD/hooks/pre-command"
  
  # Verify both servers are stored
  assert_equal "$BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES" "fetch-server,github-server"
  
  unstub thv
}

@test "Pre-exit cleans up multiple servers" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="fetch-server,github-server"
  
  stub thv \
    'list --all : echo "fetch-server running stdio 8080 http://localhost:8080"' \
    'rm fetch-server : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo "github-server running stdio 8081 http://localhost:8081"' \
    'rm github-server : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP servers to clean up: fetch-server,github-server"
  assert_output --partial "Cleaning up MCP server: fetch-server"
  assert_output --partial "✅ Cleanup completed successfully for 'fetch-server'"
  assert_output --partial "Cleaning up MCP server: github-server"
  assert_output --partial "✅ Cleanup completed successfully for 'github-server'"
  
  unstub thv
}

@test "Pre-exit handles mixed server states during cleanup" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="running-server,stopped-server,missing-server"
  
  stub thv \
    'list --all : echo "running-server running stdio 8080 http://localhost:8080"' \
    'rm running-server : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo "stopped-server stopped stdio 8081 http://localhost:8081"' \
    'rm stopped-server : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP servers to clean up: running-server,stopped-server,missing-server"
  assert_output --partial "✅ Cleanup completed successfully for 'running-server'"
  assert_output --partial "✅ Cleanup completed successfully for 'stopped-server'"
  assert_output --partial "MCP server 'missing-server' not found, nothing to clean up"
  
  unstub thv
}

@test "Pre-exit handles servers with whitespace in names list" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES=" server1 , server2 , server3 "
  
  stub thv \
    'list --all : echo "server1 running stdio 8080 http://localhost:8080"' \
    'rm server1 : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo "server2 running stdio 8081 http://localhost:8081"' \
    'rm server2 : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo "server3 running stdio 8082 http://localhost:8082"' \
    'rm server3 : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Cleaning up MCP server: server1"
  assert_output --partial "Cleaning up MCP server: server2"
  assert_output --partial "Cleaning up MCP server: server3"
  
  unstub thv
}