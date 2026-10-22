# Homebrew formula for iglass. Published in github.com/vukkt/homebrew-tap as Formula/iglass.rb; keep both in sync.
class Iglass < Formula
  desc "Liquid Glass theme for iTerm2, Ghostty, kitty and Warp"
  homepage "https://github.com/vukkt/iglass"
  url "https://github.com/vukkt/iglass/archive/refs/tags/v1.6.0.tar.gz"
  sha256 "08673f223c885c3ada1d2d75f8bd62a4e73321591e8958f81e4fad3176c45739"
  license "MIT"

  on_linux do
    depends_on "jq"
  end

  def install
    libexec.install "bin", "lib", "data"
    bin.install_symlink libexec/"bin/iglass"
  end

  def caveats
    <<~EOS
      To install the theme into your terminal (iTerm2, Ghostty, kitty or Warp), run:
        iglass install
      Remove it before uninstalling the formula:
        iglass uninstall
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/iglass --version")
    assert_match "iglass Frosted", shell_output("#{bin}/iglass export --terminal iterm2")
  end
end
