# Homebrew formula for iglass. Published in github.com/vukkt/homebrew-tap as Formula/iglass.rb; keep both in sync.
class Iglass < Formula
  desc "Liquid Glass-inspired theme for iTerm2"
  homepage "https://github.com/vukkt/iglass"
  url "https://github.com/vukkt/iglass/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "23948db7ed595e5e3f69710395c29d188d651b7a5e049f0e1618dcb658068f9b"
  license "MIT"

  depends_on :macos

  def install
    libexec.install "bin", "lib", "data"
    bin.install_symlink libexec/"bin/iglass"
  end

  def caveats
    <<~EOS
      To install the theme into iTerm2, run:
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
