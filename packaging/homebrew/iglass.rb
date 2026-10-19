# Homebrew formula for iglass. Published in github.com/vukkt/homebrew-tap as Formula/iglass.rb; keep both in sync.
class Iglass < Formula
  desc "Liquid Glass theme for iTerm2, Ghostty and kitty"
  homepage "https://github.com/vukkt/iglass"
  url "https://github.com/vukkt/iglass/archive/refs/tags/v1.4.0.tar.gz"
  sha256 "a3e1a65bb5d5a529afb68acf9ad9270de76bca9e6e4cd66d3e4deae87823d7bd"
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
      To install the theme into your terminal (iTerm2, Ghostty or kitty), run:
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
