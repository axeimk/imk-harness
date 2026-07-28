#!/usr/bin/env bats
# imk-subagent-creator の validate-agent.sh を検査する。
# テスト名は ASCII にする（bats + macOS bash 3.2 は多バイトのテスト名を解決できない）

load helpers

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FAKE_HOME="$(mktemp -d)"
  export HOME="$FAKE_HOME"
  VALIDATOR="$REPO/shared/skills/imk-subagent-creator/scripts/validate-agent.sh"
}

teardown() {
  rm -rf "$FAKE_HOME"
}

@test "valid claude code agent passes" {
  cat > "$HOME/reviewer.md" <<'EOF'
---
name: reviewer
description: Reviews code changes after implementation.
tools: Read, Glob, Grep
model: inherit
---

Review the requested changes and return evidence-backed findings.
EOF

  run "$VALIDATOR" claude-code "$HOME/reviewer.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: reviewer.md"* ]]
}

@test "claude code agent requires description" {
  cat > "$HOME/reviewer.md" <<'EOF'
---
name: reviewer
---

Review the requested changes.
EOF

  run "$VALIDATOR" claude-code "$HOME/reviewer.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"description がありません"* ]]
}

@test "cursor agent rejects claude background field" {
  cat > "$HOME/reviewer.md" <<'EOF'
---
name: reviewer
description: Reviews code changes.
background: true
---

Review the requested changes.
EOF

  run "$VALIDATOR" cursor "$HOME/reviewer.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"is_background"* ]]
}

@test "valid codex agent passes" {
  cat > "$HOME/reviewer.toml" <<'EOF'
name = "reviewer"
description = "Reviews code changes after implementation."
sandbox_mode = "read-only"

developer_instructions = """
Review the requested changes and return evidence-backed findings.
"""
EOF

  run "$VALIDATOR" codex "$HOME/reviewer.toml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: reviewer.toml"* ]]
}

@test "codex agent requires developer instructions" {
  cat > "$HOME/reviewer.toml" <<'EOF'
name = "reviewer"
description = "Reviews code changes after implementation."
EOF

  run "$VALIDATOR" codex "$HOME/reviewer.toml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"developer_instructions がありません"* ]]
}

@test "codex agent rejects empty developer instructions" {
  cat > "$HOME/reviewer.toml" <<'EOF'
name = "reviewer"
description = "Reviews code changes after implementation."
developer_instructions = ""
EOF

  run "$VALIDATOR" codex "$HOME/reviewer.toml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"developer_instructions がありません"* ]]
}

@test "codex agent rejects cursor readonly field" {
  cat > "$HOME/reviewer.toml" <<'EOF'
name = "reviewer"
description = "Reviews code changes after implementation."
readonly = true
developer_instructions = "Review the requested changes."
EOF

  run "$VALIDATOR" codex "$HOME/reviewer.toml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sandbox_mode"* ]]
}
