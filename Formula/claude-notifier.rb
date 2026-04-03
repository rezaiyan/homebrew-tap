class ClaudeNotifier < Formula
  desc "Desktop notifications for Claude Code — done and waiting alerts"
  homepage "https://github.com/rezaiyan/claude-notifier"
  url "https://github.com/rezaiyan/claude-notifier/archive/refs/tags/v1.3.4.tar.gz"
  sha256 "3dcf2f27aa5bedfe14687327de3d8b779847fb013c2a0c95f9b234f7a0f87daa"
  version "1.3.4"
  license "MIT"

  bottle do
    root_url "https://github.com/rezaiyan/claude-notifier/releases/download/v1.3.4"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "39fdaf6b7dceff0a4903dada182b2a41ab0e78062b99f39853a4c53d7b5d25ab"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "a220e70b7fbd083f6fa67ea3ebed4d3c1ce9a13e10ff789fc84d8583c08bd0b0"
  end
  head "https://github.com/rezaiyan/claude-notifier.git", branch: "main"

  depends_on :macos
  depends_on xcode: :build  # compile-time only; end users receive pre-built bottles

  def install
    # ── Build the native notification helper ──────────────────────────────────
    system "swiftc",
           "-framework", "AppKit",
           "-framework", "UserNotifications",
           "Sources/ClaudeNotifier/main.swift",
           "-o", "ClaudeNotifier"

    # Assemble .app bundle
    app_contents = prefix/"ClaudeNotifier.app/Contents"
    (app_contents/"MacOS").mkpath
    (app_contents/"Resources").mkpath
    app_contents.install "Sources/ClaudeNotifier/Info.plist"
    (app_contents/"MacOS").install "ClaudeNotifier"
    (app_contents/"Resources").install "Sources/ClaudeNotifier/AppIcon.icns"

    # Ad-hoc sign — no Team ID, no cert; safe for open-source distribution.
    # Homebrew-installed tools are not quarantined, so Gatekeeper is not an issue.
    system "codesign", "--force", "--deep", "--sign", "-",
           prefix/"ClaudeNotifier.app"

    # ── Python hook scripts ────────────────────────────────────────────────────
    libexec.install "claude-notifier.py"
    libexec.install "scripts/patch-settings.py"
    libexec.install "scripts/unpatch-settings.py"
    libexec.install "scripts/log-watcher.py"

    # Bin wrappers run in the user's shell (no sandbox), so they can write to
    # ~/.claude/settings.json — unlike post_install which is sandboxed.
    (bin/"claude-notifier").write <<~SH
      #!/bin/bash
      exec python3 "#{opt_prefix}/libexec/claude-notifier.py" "$@"
    SH

    (bin/"claude-notifier-setup").write <<~SH
      #!/bin/bash
      # Pass the stable opt-prefix path so the registered hook survives brew upgrades.
      # patch-settings.py itself runs from the versioned libexec (always current), but
      # the hook path it writes uses the opt symlink, which brew updates on every upgrade.
      python3 "#{libexec}/patch-settings.py" "#{opt_prefix}/libexec/claude-notifier.py" \
        --watcher "#{opt_prefix}/libexec/log-watcher.py" || exit 1
      # Request notification permission so the dialog appears at install time,
      # not silently inside a restricted hook subprocess.
      APP_BIN="#{prefix}/ClaudeNotifier.app/Contents/MacOS/ClaudeNotifier"
      if [[ -x "$APP_BIN" ]]; then
        "$APP_BIN" -title "Claude Notifier" -message "Notifications are enabled." \
                   -subtitle "Setup complete" &>/dev/null &
        sleep 2
      fi
      BOLD="\\033[1m" GREEN="\\033[0;32m" CYAN="\\033[0;36m" YELLOW="\\033[1;33m" DIM="\\033[2m" NC="\\033[0m"
      echo
      echo -e "${BOLD}${GREEN}  ╭──────────────────────────────────────────────────────╮${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}                                                      ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}   ${BOLD}claude-notifier${NC} is ready                           ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}                                                      ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}   From now on, every Claude Code session will        ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}   notify you the moment Claude finishes a task       ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}   or is waiting for your input.                      ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}                                                      ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}   ${CYAN}◆  Claude Code — Done${NC}     task completed           ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}   ${YELLOW}◆  Claude Code — Waiting${NC}  needs your input         ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}                                                      ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}   ${DIM}Switch away freely — Claude will tap you.${NC}          ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  │${NC}                                                      ${BOLD}${GREEN}│${NC}"
      echo -e "${BOLD}${GREEN}  ╰──────────────────────────────────────────────────────╯${NC}"
      echo
    SH

    (bin/"claude-notifier-teardown").write <<~SH
      #!/bin/bash
      exec python3 "#{libexec}/unpatch-settings.py" "#{opt_prefix}/libexec/claude-notifier.py"
    SH
  end

  def caveats
    <<~EOS
      Run after install to activate:
        claude-notifier-setup

      To check status:
        claude-notifier

      To uninstall cleanly:
        claude-notifier uninstall

    EOS
  end

  test do
    output = pipe_output(
      "python3 #{libexec}/claude-notifier.py",
      '{"last_assistant_message": "done", "stop_hook_active": true}'
    )
    assert_equal "{}", output.strip
  end
end
