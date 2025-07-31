# Dotfiles Context - Universal AI Memory System

> Stop losing context! Keep your AI assistants informed across all providers and projects.

[![npm version](https://badge.fury.io/js/dotfiles-context.svg)](https://www.npmjs.com/package/dotfiles-context)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## What It Does

**Problem**: AI assistants forget your project context between conversations. You repeat yourself constantly.

**Solution**: A universal context system that works with **ALL** AI providers:
- ✅ **Claude** (Desktop & Web)
- ✅ **Cursor** IDE
- ✅ **GitHub Copilot**
- ✅ **Gemini CLI**
- ✅ **OpenAI ChatGPT**
- ✅ **Any AI tool** that can read markdown files

## Quick Start

### Install via npm (Recommended)
```bash
npm install -g dotfiles-context
```

### Install via curl
```bash
curl -sSL https://raw.githubusercontent.com/anivar/dotfiles-context/main/install.sh | bash
```

### Manual Install
```bash
git clone https://github.com/anivar/dotfiles-context.git
cd dotfiles-context
./install.sh
```

## Usage

### Store Project Context
```bash
# Store architecture decisions
context store architecture "Microservices with event sourcing"

# Store technical decisions  
context store decisions "PostgreSQL for ACID compliance"

# Store API documentation
context store api "REST endpoints with JWT authentication"

# Track documentation with timestamps
context doc API.md "REST endpoint documentation"
```

### Retrieve Context
```bash
# Get all context
context retrieve

# Search for specific information
context retrieve "database"
context retrieve "API"

# Check project status
context status
```

### Import Existing Files
```bash
# Import existing AI configuration files
context import

# This imports content from:
# - CLAUDE.md
# - .cursorrules  
# - .github/copilot-instructions.md
```

## How It Works

### Single Source of Truth
All context is stored in `.ai-context/memory.md`:
```markdown
# Project Context

## [architecture] 2024-01-15T10:30:00Z
Microservices with event sourcing and CQRS pattern

## [decisions] 2024-01-15T11:00:00Z  
PostgreSQL for main database, Redis for caching
```

### Provider Integration
The system creates provider-specific files that reference the central memory:

**Claude** (`CLAUDE.md`):
```markdown
## Project Context
@.ai-context/memory.md
```

**Cursor** (`.cursorrules`):
```bash
# Always check .ai-context/memory.md for project context
```

**GitHub Copilot** (`.github/copilot-instructions.md`):
```markdown
## Context Reference
../.ai-context/memory.md
```

**Gemini** (`GEMINI.md` → symlink to memory.md)

## Features

### 🧠 Universal Memory
- Works with **any AI provider**
- Persistent across conversations
- Project-specific context

### 🔄 Auto-Sync
- Automatically creates provider files
- Updates timestamps
- Handles existing configurations

### 🔒 Security First
- Warns about storing secrets
- Auto-adds to `.gitignore`
- Validates all inputs
- Treats secrets like dotfiles

### 📚 Documentation Tracking
- Track docs with timestamps
- List recent changes
- Reference-based (no content duplication)

### 🛠 Developer Friendly
- XDG Base Directory compliant
- Atomic file operations
- Comprehensive logging
- Professional architecture

## Examples

### For Web Development
```bash
context store architecture "Next.js with TypeScript and Tailwind"
context store database "Prisma with PostgreSQL"  
context store auth "NextAuth.js with Google OAuth"
context doc components/README.md "Component documentation"
```

### For Mobile Apps
```bash
context store platform "React Native with Expo"
context store state "Redux Toolkit for state management"
context store api "REST API with React Query"
```

### For Backend Services
```bash
context store architecture "Express.js microservices"
context store database "MongoDB with Mongoose ODM"
context store deployment "Docker containers on AWS ECS"
```

## AI Provider Setup

### Claude Desktop (MCP Integration)
Add to `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/your/projects"]
    }
  }
}
```

### Cursor IDE
Works automatically! Cursor reads `.cursorrules` files.

### GitHub Copilot
Works automatically! Copilot reads `.github/copilot-instructions.md`.

### Gemini CLI
Install the wrapper:
```bash
# The symlink approach works automatically
ls -la GEMINI.md  # -> .ai-context/memory.md
```

### OpenAI/ChatGPT
Simply reference the context:
```
"Check my project context in .ai-context/memory.md and help me implement..."
```

## Categories

Use these standard categories for consistency:

- `architecture` - System design decisions
- `requirements` - Business/technical requirements  
- `implementation` - Code implementation details
- `infrastructure` - Deployment and infrastructure
- `decisions` - Technical decisions and rationale
- `issues` - Known issues and resolutions
- `docs` - Documentation references
- `api` - API design and endpoints
- `database` - Database schema and decisions
- `auth` - Authentication and authorization
- `testing` - Testing strategies and patterns

## Security

### ✅ What We Do
- Input validation and sanitization
- Automatic `.gitignore` management
- Secret detection warnings
- Path traversal protection
- XDG directory compliance

### ⚠️ Best Practices
```bash
# Good - Store references
context store api "AWS credentials in 1Password: ProjectName-Prod"
context store database "Connection string in .env.local"

# Bad - Store actual secrets  
context store api "api_key=sk-abc123..."  # Will warn!
```

## Commands

```bash
context store <category> <content>     # Store contextual information
context retrieve [filter]              # Retrieve stored context  
context status                         # Show system status
context import                         # Import existing AI files
context doc <file> [description]       # Track documentation
context recent-docs [days]             # List recent documentation
context sync                           # Force provider sync
context help                           # Show help
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file.

## Support

- 🐛 [Report Issues](https://github.com/anivar/dotfiles-context/issues)
- 💬 [Discussions](https://github.com/anivar/dotfiles-context/discussions)
- 📖 [Documentation](https://github.com/anivar/dotfiles-context/wiki)

---

**Stop repeating yourself to AI assistants. Install dotfiles-context and keep them informed!** 🚀