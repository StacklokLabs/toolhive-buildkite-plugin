#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

@test "Multiple plugin calls store all server names" {
  export BUILDKITE_BUILD_NUMBER="123"
  
  # First plugin call
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="fetch"
  export BUILDKITE_PLUGIN_TOOLHIVE_NAME="fetch-server"
  
  stub thv \
    'registry info fetch : exit 0' \
    'list --all : echo ""' \
    'run --name fetch-server fetch : echo "Server started"' \
    'list --all : echo "fetch-server running stdio 8080 http://localhost:8080"'
  
  run "$PWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "✅ MCP server 'fetch-server' started successfully"
  
  unstub thv
  
  # Verify first server is stored
  assert_equal "$BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES" "fetch-server"
  
  # Second plugin call (simulating multiple plugin usage)
  export BUILDKITE_PLUGIN_TOOLHIVE_SERVER="github"
  export BUILDKITE_PLUGIN_TOOLHIVE_NAME="github-server"
  
  stub thv \
    'registry info github : exit 0' \
    'list --all : echo ""' \
    'run --name github-server github : echo "Server started"' \
    'list --all : echo "github-server running stdio 8081 http://localhost:8081"'
  
  run "$PWD/hooks/pre-command"
  
  assert_success
  assert_output --partial "✅ MCP server 'github-server' started successfully"
  
  unstub thv
  
  # Verify both servers are stored
  assert_equal "$BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES" "fetch-server,github-server"
}

@test "Pre-exit cleans up multiple servers" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="fetch-server,github-server"
  
  stub thv \
    'list --all : echo "fetch-server running stdio 8080 http://localhost:8080"' \
    'list : echo "fetch-server running stdio 8080 http://localhost:8080"' \
    'stop fetch-server : echo "Server stopped"' \
    'rm fetch-server : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo "github-server running stdio 8081 http://localhost:8081"' \
    'list : echo "github-server running stdio 8081 http://localhost:8081"' \
    'stop github-server : echo "Server stopped"' \
    'rm github-server : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP servers to clean up: fetch-server,github-server"
  assert_output --partial "Cleaning up MCP server: fetch-server"
  assert_output --partial "✅ MCP server 'fetch-server' stopped successfully"
  assert_output --partial "✅ MCP server 'fetch-server' removed successfully"
  assert_output --partial "Cleaning up MCP server: github-server"
  assert_output --partial "✅ MCP server 'github-server' stopped successfully"
  assert_output --partial "✅ MCP server 'github-server' removed successfully"
  
  unstub thv
}

@test "Pre-exit handles mixed server states during cleanup" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES="running-server,stopped-server,missing-server"
  
  stub thv \
    'list --all : echo "running-server running stdio 8080 http://localhost:8080"' \
    'list : echo "running-server running stdio 8080 http://localhost:8080"' \
    'stop running-server : echo "Server stopped"' \
    'rm running-server : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo "stopped-server stopped stdio 8081 http://localhost:8081"' \
    'list : echo ""' \
    'rm stopped-server : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Found MCP servers to clean up: running-server,stopped-server,missing-server"
  assert_output --partial "✅ MCP server 'running-server' stopped successfully"
  assert_output --partial "MCP server 'stopped-server' is already stopped"
  assert_output --partial "✅ MCP server 'stopped-server' removed successfully"
  assert_output --partial "MCP server 'missing-server' not found, nothing to clean up"
  
  unstub thv
}

@test "Pre-exit handles servers with whitespace in names list" {
  export BUILDKITE_PLUGIN_TOOLHIVE_CLEANUP="true"
  export BUILDKITE_PLUGIN_TOOLHIVE_MCP_SERVER_NAMES=" server1 , server2 , server3 "
  
  stub thv \
    'list --all : echo "server1 running stdio 8080 http://localhost:8080"' \
    'list : echo "server1 running stdio 8080 http://localhost:8080"' \
    'stop server1 : echo "Server stopped"' \
    'rm server1 : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo "server2 running stdio 8081 http://localhost:8081"' \
    'list : echo "server2 running stdio 8081 http://localhost:8081"' \
    'stop server2 : echo "Server stopped"' \
    'rm server2 : echo "Server removed"' \
    'list --all : echo ""' \
    'list --all : echo "server3 running stdio 8082 http://localhost:8082"' \
    'list : echo "server3 running stdio 8082 http://localhost:8082"' \
    'stop server3 : echo "Server stopped"' \
    'rm server3 : echo "Server removed"' \
    'list --all : echo ""'
  
  run "$PWD/hooks/pre-exit"
  
  assert_success
  assert_output --partial "Cleaning up MCP server: server1"
  assert_output --partial "Cleaning up MCP server: server2"
  assert_output --partial "Cleaning up MCP server: server3"
  
  unstub thv
}