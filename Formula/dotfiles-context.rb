class DotfilesContext < Formula
  desc "Universal AI context management for all AI providers"
  homepage "https://github.com/anivar/dotfiles-context"
  url "https://github.com/anivar/dotfiles-context/archive/v1.0.0.tar.gz"
  sha256 "SHA256_PLACEHOLDER"
  license "MIT"

  depends_on "bash"

  def install
    bin.install "bin/context"
    libexec.install "context.sh"
    
    # Create wrapper script
    (bin/"context").write <<~EOS
      #!/usr/bin/env bash
      source "#{libexec}/context.sh"
      context "$@"
    EOS
    
    # Install documentation
    doc.install "README.md"
    doc.install "MCP-GUIDE.md" if File.exist?("MCP-GUIDE.md")
  end

  test do
    # Test that the script loads without errors
    system bin/"context", "help"
  end
end