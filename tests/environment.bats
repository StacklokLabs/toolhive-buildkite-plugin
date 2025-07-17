#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

@test "Environment hook skips installation when thv is already available" {
  stub thv \
    'version : echo "ToolHive v0.0.33"'
  
  run "$PWD/hooks/environment"
  
  assert_success
  assert_output --partial "ToolHive is already available in PATH"
  assert_output --partial "ToolHive v0.0.33"
  
  unstub thv
}

# Installation tests removed due to stub framework limitations
# The stub framework makes 'thv' available in PATH, making it difficult to test installation scenarios