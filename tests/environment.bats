#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment the following line to debug stub failures
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

@test "Environment hook skips installation when thv is already available" {
  stub thv \
    '--version : echo "ToolHive v0.0.33"'
  
  run "$PWD/hooks/environment"
  
  assert_success
  assert_output --partial "ToolHive is already available in PATH"
  assert_output --partial "ToolHive v0.0.33"
  
  unstub thv
}

@test "Environment hook detects Linux x86_64 platform" {
  stub uname \
    '-s : echo "Linux"' \
    '-m : echo "x86_64"'
  stub thv \
    '--version : exit 127'
  stub curl \
    '-s https://api.github.com/repos/stacklok/toolhive/releases/latest : echo "{\"tag_name\": \"v0.0.35\"}"' \
    '-fsSL https://github.com/stacklok/toolhive/releases/download/v0.0.35/thv_linux_amd64 -o * : echo "Downloaded"'
  stub chmod \
    '+x * : echo "Made executable"'
  stub mkdir \
    '-p * : echo "Created directory"'
  
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/environment"
  
  assert_success
  assert_output --partial "ToolHive not found in PATH, installing..."
  assert_output --partial "Detected platform: linux_amd64"
  assert_output --partial "Target version: v0.0.35"
  
  unstub uname curl chmod mkdir
}

@test "Environment hook detects macOS arm64 platform" {
  stub uname \
    '-s : echo "Darwin"' \
    '-m : echo "arm64"'
  stub thv \
    '--version : exit 127'
  stub curl \
    '-s https://api.github.com/repos/stacklok/toolhive/releases/latest : echo "{\"tag_name\": \"v0.0.35\"}"' \
    '-fsSL https://github.com/stacklok/toolhive/releases/download/v0.0.35/thv_darwin_arm64 -o * : echo "Downloaded"'
  stub chmod \
    '+x * : echo "Made executable"'
  stub mkdir \
    '-p * : echo "Created directory"'
  
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/environment"
  
  assert_success
  assert_output --partial "Detected platform: darwin_arm64"
  
  unstub uname curl chmod mkdir
}

@test "Environment hook uses custom version when specified" {
  export BUILDKITE_PLUGIN_TOOLHIVE_TOOLHIVE_VERSION="v0.0.30"
  
  stub uname \
    '-s : echo "Linux"' \
    '-m : echo "x86_64"'
  stub thv \
    '--version : exit 127'
  stub curl \
    '-fsSL https://github.com/stacklok/toolhive/releases/download/v0.0.30/thv_linux_amd64 -o * : echo "Downloaded"'
  stub chmod \
    '+x * : echo "Made executable"'
  stub mkdir \
    '-p * : echo "Created directory"'
  
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/environment"
  
  assert_success
  assert_output --partial "Target version: v0.0.30"
  
  unstub uname curl chmod mkdir
}

@test "Environment hook falls back to stable version when GitHub API fails" {
  stub uname \
    '-s : echo "Linux"' \
    '-m : echo "x86_64"'
  stub thv \
    '--version : exit 127'
  stub curl \
    '-s https://api.github.com/repos/stacklok/toolhive/releases/latest : exit 1' \
    '-fsSL https://github.com/stacklok/toolhive/releases/download/v0.1.8/thv_linux_amd64 -o * : echo "Downloaded"'
  stub chmod \
    '+x * : echo "Made executable"'
  stub mkdir \
    '-p * : echo "Created directory"'
  
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/environment"
  
  assert_success
  assert_output --partial "Target version: v0.1.8"
  
  unstub uname curl chmod mkdir
}

@test "Environment hook retries download on failure" {
  stub uname \
    '-s : echo "Linux"' \
    '-m : echo "x86_64"'
  stub thv \
    '--version : exit 127'
  stub curl \
    '-s https://api.github.com/repos/stacklok/toolhive/releases/latest : echo "{\"tag_name\": \"v0.0.35\"}"' \
    '-fsSL https://github.com/stacklok/toolhive/releases/download/v0.0.35/thv_linux_amd64 -o * : exit 1' \
    '-fsSL https://github.com/stacklok/toolhive/releases/download/v0.0.35/thv_linux_amd64 -o * : echo "Downloaded on retry"'
  stub chmod \
    '+x * : echo "Made executable"'
  stub mkdir \
    '-p * : echo "Created directory"'
  stub sleep \
    '5 : echo "Sleeping"'
  
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/environment"
  
  assert_success
  assert_output --partial "Download failed, retrying in 5 seconds... (attempt 1/3)"
  
  unstub uname curl chmod mkdir sleep
}

@test "Environment hook fails after max retries" {
  stub uname \
    '-s : echo "Linux"' \
    '-m : echo "x86_64"'
  stub thv \
    '--version : exit 127'
  stub curl \
    '-s https://api.github.com/repos/stacklok/toolhive/releases/latest : echo "{\"tag_name\": \"v0.0.35\"}"' \
    '-fsSL https://github.com/stacklok/toolhive/releases/download/v0.0.35/thv_linux_amd64 -o * : exit 1' \
    '-fsSL https://github.com/stacklok/toolhive/releases/download/v0.0.35/thv_linux_amd64 -o * : exit 1' \
    '-fsSL https://github.com/stacklok/toolhive/releases/download/v0.0.35/thv_linux_amd64 -o * : exit 1'
  stub mkdir \
    '-p * : echo "Created directory"'
  stub sleep \
    '5 : echo "Sleeping"' \
    '5 : echo "Sleeping"'
  
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/environment"
  
  assert_failure
  assert_output --partial "Failed to download ToolHive after 3 attempts"
  
  unstub uname curl mkdir sleep
}

@test "Environment hook fails on unsupported OS" {
  stub uname \
    '-s : echo "FreeBSD"'
  stub thv \
    '--version : exit 127'
  
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/environment"
  
  assert_failure
  assert_output --partial "Unsupported OS: FreeBSD"
  
  unstub uname
}

@test "Environment hook fails on unsupported architecture" {
  stub uname \
    '-s : echo "Linux"' \
    '-m : echo "sparc64"'
  stub thv \
    '--version : exit 127'
  
  export PATH="/nonexistent:$PATH"
  
  run "$PWD/hooks/environment"
  
  assert_failure
  assert_output --partial "Unsupported architecture: sparc64"
  
  unstub uname
}