#!/usr/bin/env bats

load test_helper

setup() {
  load_utils
}

@test "install_prereqs_macos skips on non-macOS hosts" {
  run env ONBOARD_OS=linux ONBOARD_ARCH=x86_64 "${TEST_ROOT}/scripts/install_prereqs_macos.sh"
  [ "$status" -eq 0 ]
  [ -z "${output}" ]
}

@test "install_prereqs_macos installs brew when missing (dry-run preview)" {
  run env ONBOARD_OS=macos ONBOARD_ARCH=arm64 ONBOARD_DRY_RUN=1 PATH="/usr/bin:/bin" "${TEST_ROOT}/scripts/install_prereqs_macos.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'[INFO] Homebrew not found; installing via official script.'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Install Homebrew: /bin/bash -c $(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Install macOS prerequisites via Homebrew (git, gh, chezmoi): /opt/homebrew/bin/brew install git gh chezmoi'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Install Visual Studio Code via Homebrew: /opt/homebrew/bin/brew install --cask visual-studio-code'* ]]
  [[ "${output}" == *'DRY-RUN: Install VS Code Remote Development extension pack: code --install-extension ms-vscode-remote.vscode-remote-extensionpack --force'* ]]
  [[ "${output}" == *'DRY-RUN: Ensure VS Code settings at '*'/settings.json configure kevinaud/dotfiles as the dev container dotfiles repository.'* ]]
}

@test "install_prereqs_macos uses existing brew" {
  local temp_dir="${BATS_TEST_TMPDIR}/brew"
  mkdir -p "${temp_dir}"
  cat <<'BREW' >"${temp_dir}/brew"
#!/usr/bin/env bash
printf 'stub brew\n'
BREW
  chmod +x "${temp_dir}/brew"

  run env ONBOARD_OS=macos ONBOARD_ARCH=x86_64 ONBOARD_DRY_RUN=1 PATH="${temp_dir}:/usr/bin:/bin" "${TEST_ROOT}/scripts/install_prereqs_macos.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"[INFO] Homebrew detected at ${temp_dir}/brew"* ]]
  [[ "${output}" == *"[INFO] DRY-RUN: Install macOS prerequisites via Homebrew (git, gh, chezmoi): ${temp_dir}/brew install git gh chezmoi"* ]]
  [[ "${output}" == *"[INFO] DRY-RUN: Install Visual Studio Code via Homebrew: ${temp_dir}/brew install --cask visual-studio-code"* ]]
  [[ "${output}" == *'DRY-RUN: Install VS Code Remote Development extension pack: code --install-extension ms-vscode-remote.vscode-remote-extensionpack --force'* ]]
  [[ "${output}" == *'DRY-RUN: Ensure VS Code settings at '*'/settings.json configure kevinaud/dotfiles as the dev container dotfiles repository.'* ]]
}
