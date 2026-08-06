

# ziyao233.github.io

A lightweight personal blog and technical journal built with Lua and a custom `md2html` static site generator. This repository hosts articles covering low-level systems programming, operating system internals, algorithmic problem-solving, and personal engineering logs.

## 📖 Description

`ziyao233.github.io` is a statically generated website featuring a clean, minimalistic design with built-in MathJax support for mathematical and scientific rendering. The content is written in Markdown, processed through Lua templates (`Article.tpl.html`, `index.tpl.html`), and outputs static HTML.

**Key topics covered in the repository:**
- Low-level architecture & memory barriers (x86/AMD64, RISC-V, LoongArch)
- Systems programming & OS development (Linux boot protocols, u-boot, custom distro `eweOS`)
- Competitive programming & algorithms (Dynamic Programming, number theory, C++)
- Tooling & utilities (`mVim`, `asmbf`, `zpartprobe`)
- Personal technical logs & reflections

## 🛠️ Installation

Since this is a static site, there are no runtime dependencies or complex build systems. To view or host the site locally:

1. **Clone the repository**
   ```bash
   git clone https://github.com/ziyao233/ziyao233.github.io.git
   cd ziyao233.github.io
   ```

2. **Install Lua (Required for site generation)**
   The site generator relies on Lua scripts. Install Lua 5.1 or later:
   ```bash
   # Debian/Ubuntu
   sudo apt install lua5.3
   # macOS
   brew install lua
   ```

3. **Serve the generated files**
   Once the Markdown sources are processed (see Usage), you can serve the resulting HTML files with any static web server:
   ```bash
   python3 -m http.server 8080
   ```

## 🚀 Usage

### Generating the Site
The repository uses a custom Lua-based generator (`md2html`) to convert Markdown sources into HTML using pre-defined templates.

```bash
# Run the md2html generator to compile .md files into .html
lua md2html.lua
# or simply run the main generation script if named differently in the repo
./md2html
```

### Writing a New Post
1. Create a new Markdown file (e.g., `new_topic.md`).
2. Structure the content following the existing template logic. The HTML output inherits `<head>` assets automatically, including MathJax 3 from `jsdelivr`.
3. Use `$ ... $` for inline math and `$$ ... $$` for block math.
4. Run the generator to produce the static HTML files.
5. Verify the output by opening `index.html` or running the local server.

## 📄 License

- **Source Code & Scripts:** MIT License
- **Website Content & Articles:** CC-BY-SA 4.0

For full license text, refer to the repository root directory.
