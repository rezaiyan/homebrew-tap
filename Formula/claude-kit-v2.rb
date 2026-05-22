class ClaudeKitV2 < Formula
  desc "Quality-of-life hooks for Claude Code: memory, notifications, quality guards, and TUI"
  homepage "https://github.com/rezaiyan/claude-kit-v2"
  url "https://github.com/rezaiyan/claude-kit-v2/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "9475378f58b0aeb9c09972c4140d4b229a9103fc6e9b94e0c9df08d9226faa17"
  version "0.2.0"
  license "MIT"

  head "https://github.com/rezaiyan/claude-kit-v2.git", branch: "main"

  depends_on "bun"

  def install
    libexec.install Dir["*"]

    # Install deps — non-fatal if it fails (bin wrapper self-heals on first run)
    cd libexec do
      quiet_system "bun", "install"
    end

    # Bin wrapper: installs deps if missing, then launches TUI
    (bin/"claudekit").write <<~SH
      #!/bin/sh
      LIBEXEC="#{libexec}"
      if [ ! -d "$LIBEXEC/node_modules" ]; then
        echo "Installing claudekit dependencies..." >&2
        cd "$LIBEXEC" && bun install --silent
      fi
      exec bun "$LIBEXEC/bin/tui.js" "$@"
    SH
  end

  def caveats
    <<~EOS
      Run the TUI to manage tools:
        claudekit

      To use the Claude Code plugin (hooks + memory), install via Claude Code:
        /plugin marketplace add rezaiyan/claude-plugins
        /plugin install claude-kit-v2@rezaiyan

    EOS
  end

  test do
    assert_predicate bin/"claudekit", :exist?
  end
end
