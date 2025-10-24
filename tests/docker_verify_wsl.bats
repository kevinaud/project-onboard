#!/usr/bin/env bats
# tests/docker_verify_wsl.bats

load test_helper

setup() {
  export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../scripts"
  source "$SCRIPT_DIR/utils.sh"
}

@test "docker_verify_wsl.sh: shows remediation when docker command not found" {
  # Mock command to simulate docker not being available
  docker() {
    return 127
  }
  export -f docker

  run bash -c "
    # Redefine command to fail for docker
    command() {
      if [[ \"\$1\" == '-v' && \"\$2\" == 'docker' ]]; then
        return 1
      fi
      return 0
    }
    export -f command
    source '$SCRIPT_DIR/utils.sh'
    source '$SCRIPT_DIR/../scripts/docker_verify_wsl.sh'
    verify_docker
  "

  [ "$status" -eq 1 ]
  [[ "$output" == *"Docker command not found in WSL"* ]]
  [[ "$output" == *"Docker Desktop Integration Issue"* ]]
  [[ "$output" == *"Docker Desktop is running on Windows"* ]]
  [[ "$output" == *"Ubuntu-22.04"* ]]
}

@test "docker_verify_wsl.sh: shows remediation when docker version fails" {
  run bash -c "
    # Mock docker command to fail on version check
    docker() {
      if [[ \"\$1\" == '--version' ]]; then
        return 1
      fi
      return 0
    }
    export -f docker

    command() {
      if [[ \"\$1\" == '-v' && \"\$2\" == 'docker' ]]; then
        return 0
      fi
      return 0
    }
    export -f command

    source '$SCRIPT_DIR/utils.sh'
    source '$SCRIPT_DIR/../scripts/docker_verify_wsl.sh'
    verify_docker
  "

  [ "$status" -eq 1 ]
  [[ "$output" == *"Docker version check failed"* ]]
  [[ "$output" == *"Docker Desktop Integration Issue"* ]]
}

@test "docker_verify_wsl.sh: shows remediation when hello-world test fails" {
  run bash -c "
    # Mock docker command
    docker() {
      if [[ \"\$1\" == '--version' ]]; then
        echo 'Docker version 24.0.0'
        return 0
      elif [[ \"\$1\" == 'run' ]]; then
        return 1
      fi
      return 0
    }
    export -f docker

    command() {
      if [[ \"\$1\" == '-v' && \"\$2\" == 'docker' ]]; then
        return 0
      fi
      return 0
    }
    export -f command

    source '$SCRIPT_DIR/utils.sh'
    source '$SCRIPT_DIR/../scripts/docker_verify_wsl.sh'
    verify_docker
  "

  [ "$status" -eq 1 ]
  [[ "$output" == *"Docker hello-world test failed"* ]]
  [[ "$output" == *"Docker Desktop Integration Issue"* ]]
  [[ "$output" == *"Apply & Restart"* ]]
}

@test "docker_verify_wsl.sh: succeeds when docker works correctly" {
  run bash -c "
    # Mock successful docker commands
    docker() {
      if [[ \"\$1\" == '--version' ]]; then
        echo 'Docker version 24.0.0, build abc123'
        return 0
      elif [[ \"\$1\" == 'run' ]]; then
        echo 'Hello from Docker!'
        return 0
      fi
      return 0
    }
    export -f docker

    command() {
      if [[ \"\$1\" == '-v' && \"\$2\" == 'docker' ]]; then
        return 0
      fi
      return 0
    }
    export -f command

    source '$SCRIPT_DIR/utils.sh'
    source '$SCRIPT_DIR/../scripts/docker_verify_wsl.sh'
    verify_docker
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"Docker Desktop integration verified successfully"* ]]
  [[ "$output" == *"Docker version: Docker version 24.0.0"* ]]
}
