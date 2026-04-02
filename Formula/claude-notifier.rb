class ClaudeNotifier < Formula
  desc "Desktop notifications for Claude Code — done and waiting alerts"
  homepage "https://github.com/rezaiyan/claude-notifier"
  url "https://github.com/rezaiyan/claude-notifier/archive/refs/tags/v1.1.6.tar.gz"
  sha256 "2dc13396bc9dd743de4e5460cee2867175efce02447b89e78ded6909a5effcee"
  version "1.1.6"
  license "MIT"

  bottle do
    root_url "https://github.com/rezaiyan/claude-notifier/releases/download/v1.1.6"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "d7ce15152ba63ad7a9a6d667afdf5e2e09473f8f4381c0f1321dbb4ec0a1446e"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "0db9aa9fcb777f8b56941bdd7417681888699341bd311864b785fc5e8a9ff11a"
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
    app_contents.install "Sources/ClaudeNotifier/Info.plist"
    (app_contents/"MacOS").install "ClaudeNotifier"

    # Ad-hoc sign — no Team ID, no cert; safe for open-source distribution.
    # Homebrew-installed tools are not quarantined, so Gatekeeper is not an issue.
    system "codesign", "--force", "--deep", "--sign", "-",
           prefix/"ClaudeNotifier.app"

    # ── Python hook scripts ────────────────────────────────────────────────────
    libexec.install "claude-notifier.py"
    libexec.install "scripts/patch-settings.py"
    libexec.install "scripts/unpatch-settings.py"

    # Bin wrappers run in the user's shell (no sandbox), so they can write to
    # ~/.claude/settings.json — unlike post_install which is sandboxed.
    (bin/"claude-notifier-setup").write <<~SH
      #!/bin/bash
      python3 "#{libexec}/patch-settings.py" "#{libexec}/claude-notifier.py" || exit 1
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
      exec python3 "#{libexec}/unpatch-settings.py" "#{libexec}/claude-notifier.py"
    SH
  end

  def caveats
    <<~EOS
      Run once to activate:
        claude-notifier-setup

      To uninstall cleanly:
        claude-notifier-teardown && brew uninstall claude-notifier

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
