# Homebrew formula for iglass. Published in github.com/vukkt/homebrew-tap as Formula/iglass.rb; keep both in sync.
class Iglass < Formula
  desc "Liquid Glass theme for iTerm2 and Ghostty"
  homepage "https://github.com/vukkt/iglass"
  url "https://github.com/vukkt/iglass/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "f8a9c9b2e45d98a18821f0fef701e742c6fde0ab37edf9898bc5c805705f0eb4"
  license "MIT"

  depends_on :macos

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
    assert_match "iglass Frosted", shell_output("#{bin}/iglass export")
  end
end
