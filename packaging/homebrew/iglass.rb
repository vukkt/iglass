# Homebrew formula for iglass. Published in github.com/vukkt/homebrew-tap as Formula/iglass.rb; keep both in sync.
class Iglass < Formula
  desc "Liquid Glass theme for iTerm2 and Ghostty"
  homepage "https://github.com/vukkt/iglass"
  url "https://github.com/vukkt/iglass/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "9fe3ec8982dc1b9aab4f7d0ee04d231784334f1187bb3f183cbbd699da00c1e3"
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
      To install the theme into your terminal (iTerm2 or Ghostty), run:
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
