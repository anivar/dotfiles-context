#!/usr/bin/env bash
# Context Management System
# Professional AI context persistence layer

set -euo pipefail
IFS=$'\n\t'

# System Configuration
readonly VERSION="2.0.0"
readonly SYSTEM_NAME="context"
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/${SYSTEM_NAME}"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/${SYSTEM_NAME}"
readonly CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/${SYSTEM_NAME}"
readonly RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/${SYSTEM_NAME}-$$"

# Security Configuration
readonly MAX_INPUT_LENGTH=2000
readonly MAX_FIELD_LENGTH=50
readonly ALLOWED_CHARS_REGEX='^[a-zA-Z0-9 ._,/:@#-]+$'
readonly FIELD_NAME_REGEX='^[a-zA-Z][a-zA-Z0-9_-]*$'

# Performance Configuration
readonly CACHE_TTL=300
readonly LOG_RETENTION_DAYS=30
readonly MAX_MEMORY_ENTRIES=1000

# Initialize system directories
_init_system() {
    local dirs=(
        "$CONFIG_HOME"
        "$DATA_HOME/contexts"
        "$DATA_HOME/providers"
        "$CACHE_HOME"
        "$RUNTIME_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] || mkdir -p "$dir"
        chmod 700 "$dir"
    done
    
    # Initialize configuration if not exists
    [[ -f "$CONFIG_HOME/config.json" ]] || _create_default_config
}

# Create default configuration
_create_default_config() {
    cat > "$CONFIG_HOME/config.json" << 'EOF'
{
    "version": "2.0.0",
    "features": {
        "mcp_enabled": true,
        "auto_sync": true,
        "provider_validation": true
    },
    "providers": {
        "claude": {
            "enabled": true,
            "file": "CLAUDE.md",
            "format": "markdown_reference"
        },
        "cursor": {
            "enabled": true,
            "file": ".cursorrules",
            "format": "plaintext"
        },
        "copilot": {
            "enabled": true,
            "file": ".github/copilot-instructions.md",
            "format": "markdown"
        },
        "gemini": {
            "enabled": true,
            "file": "GEMINI.md",
            "format": "symlink"
        }
    },
    "security": {
        "input_validation": true,
        "path_validation": true,
        "audit_logging": true
    }
}
EOF
}

# Input validation layer
_validate_input() {
    local input="$1"
    local max_length="${2:-$MAX_INPUT_LENGTH}"
    local pattern="${3:-$ALLOWED_CHARS_REGEX}"
    
    # Null byte and control character sanitization
    input="$(printf '%s' "$input" | tr -d '\000-\037\177')"
    
    # Length validation
    if (( ${#input} > max_length )); then
        _log_error "Input exceeds maximum length: ${#input} > $max_length"
        return 1
    fi
    
    # Pattern validation
    if ! [[ "$input" =~ $pattern ]]; then
        _log_error "Input contains invalid characters"
        return 1
    fi
    
    printf '%s' "$input"
}

# Field name validation
_validate_field_name() {
    local field="$1"
    
    if (( ${#field} > MAX_FIELD_LENGTH )); then
        _log_error "Field name too long: ${#field} > $MAX_FIELD_LENGTH"
        return 1
    fi
    
    if ! [[ "$field" =~ $FIELD_NAME_REGEX ]]; then
        _log_error "Invalid field name format: $field"
        return 1
    fi
    
    printf '%s' "$field"
}

# Path security validation
_validate_path() {
    local path="$1"
    local allowed_base="$2"
    
    # Resolve to absolute path
    local resolved_path
    resolved_path="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")" || {
        _log_error "Cannot resolve path: $path"
        return 1
    }
    
    # Verify path is within allowed base
    if [[ "$resolved_path" != "$allowed_base"* ]]; then
        _log_error "Path traversal attempt detected: $resolved_path"
        return 1
    fi
    
    printf '%s' "$resolved_path"
}

# Atomic file operations
_atomic_write() {
    local target_file="$1"
    local content="$2"
    local mode="${3:-644}"
    
    local temp_file
    temp_file="$(mktemp)" || {
        _log_error "Failed to create temporary file"
        return 1
    }
    
    # Write content to temporary file
    if printf '%s' "$content" > "$temp_file"; then
        chmod "$mode" "$temp_file"
        
        # Atomic move to target
        if mv -f "$temp_file" "$target_file"; then
            _log_debug "Successfully wrote: $target_file"
            return 0
        fi
    fi
    
    rm -f "$temp_file"
    _log_error "Failed to write: $target_file"
    return 1
}

# Logging subsystem
_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
    
    printf '[%s] %s: %s\n' "$timestamp" "$level" "$message" >&2
    
    # Persist to log file if in production mode
    if [[ "${CONTEXT_LOG_LEVEL:-INFO}" != "DEBUG" ]]; then
        printf '[%s] %s: %s\n' "$timestamp" "$level" "$message" >> "$DATA_HOME/system.log"
    fi
}

_log_error() { _log "ERROR" "$1"; }
_log_warn() { _log "WARN" "$1"; }
_log_info() { _log "INFO" "$1"; }
_log_debug() { [[ "${CONTEXT_LOG_LEVEL:-INFO}" == "DEBUG" ]] && _log "DEBUG" "$1"; }

# Import existing context from provider files
_import_existing_context() {
    local project_root
    project_root="$(pwd)" || return 1
    
    local imported=0
    
    # Ensure context directory exists
    local context_dir="$project_root/.ai-context"
    [[ -d "$context_dir" ]] || mkdir -p "$context_dir"
    
    # Initialize memory file if needed
    local memory_file="$context_dir/memory.md"
    if [[ ! -f "$memory_file" ]]; then
        echo "# Project Context" > "$memory_file"
        echo "" >> "$memory_file"
        echo "Generated by Context Management System v$VERSION" >> "$memory_file"
    fi
    
    # Check for existing CLAUDE.md
    if [[ -f "$project_root/CLAUDE.md" ]] && ! grep -q "CONTEXT-SYSTEM-MANAGED" "$project_root/CLAUDE.md" 2>/dev/null; then
        echo "Found existing CLAUDE.md - importing context..."
        local claude_content="$(cat "$project_root/CLAUDE.md")"
        # Direct write to avoid recursion
        local memory_file="$project_root/.ai-context/memory.md"
        local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "" >> "$memory_file"
        echo "## [imported-claude] $timestamp" >> "$memory_file"
        echo "From CLAUDE.md: $claude_content" >> "$memory_file"
        ((imported++))
    fi
    
    # Check for existing .cursorrules
    if [[ -f "$project_root/.cursorrules" ]] && ! grep -q "CONTEXT-SYSTEM" "$project_root/.cursorrules" 2>/dev/null; then
        echo "Found existing .cursorrules - importing context..."
        local cursor_content="$(cat "$project_root/.cursorrules")"
        # Direct write to avoid recursion
        local memory_file="$project_root/.ai-context/memory.md"
        local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "" >> "$memory_file"
        echo "## [imported-cursor] $timestamp" >> "$memory_file"
        echo "From .cursorrules: $cursor_content" >> "$memory_file"
        ((imported++))
    fi
    
    # Check for existing .github/copilot-instructions.md
    if [[ -f "$project_root/.github/copilot-instructions.md" ]] && ! grep -q "CONTEXT-SYSTEM" "$project_root/.github/copilot-instructions.md" 2>/dev/null; then
        echo "Found existing copilot instructions - importing context..."
        local copilot_content="$(cat "$project_root/.github/copilot-instructions.md")"
        # Direct write to avoid recursion
        local memory_file="$project_root/.ai-context/memory.md"
        local timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "" >> "$memory_file"
        echo "## [imported-copilot] $timestamp" >> "$memory_file"
        echo "From copilot-instructions.md: $copilot_content" >> "$memory_file"
        ((imported++))
    fi
    
    if [[ $imported -gt 0 ]]; then
        echo "✓ Imported $imported existing context files into memory.md"
        echo "Original files will now reference the centralized context"
    else
        echo "No existing context files to import"
    fi
}

# Context storage operations
_store_context() {
    local category="$1"
    local content="$2"
    local project_root
    project_root="$(pwd)" || {
        _log_error "Cannot determine working directory"
        return 1
    }
    
    # Validate inputs
    category="$(_validate_field_name "$category")" || return 1
    content="$(_validate_input "$content")" || return 1
    
    # Warn about sensitive content
    if [[ "$category" == "secrets" ]] || [[ "$category" == "credentials" ]]; then
        echo "⚠️  Storing secrets? Consider using references instead:"
        echo "   Example: 'AWS creds in 1Password vault: Production'"
        if [[ -t 0 ]]; then  # Interactive mode
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] || return 1
        fi
    fi
    
    # Check for common secret patterns
    if echo "$content" | grep -qE "(password|api_key|secret|token)[\s]*[:=]"; then
        echo "⚠️  Detected possible secret. Use references instead of values!"
        if [[ -t 0 ]]; then  # Interactive mode
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] || return 1
        else
            echo "   Skipping in non-interactive mode. Use -f to force."
            return 1
        fi
    fi
    
    # Ensure context directory exists
    local context_dir="$project_root/.ai-context"
    [[ -d "$context_dir" ]] || mkdir -p "$context_dir"
    chmod 755 "$context_dir"
    
    # Check .gitignore
    if [[ -d "$project_root/.git" ]]; then
        if [[ ! -f "$project_root/.gitignore" ]] || ! grep -q "^.ai-context" "$project_root/.gitignore"; then
            echo "📝 Adding .ai-context/ to .gitignore..."
            echo -e "\n# AI context (contains project decisions/memory)\n.ai-context/" >> "$project_root/.gitignore"
        fi
    fi
    
    # Load or create memory file
    local memory_file="$context_dir/memory.md"
    local memory_content=""
    
    if [[ -f "$memory_file" ]]; then
        memory_content="$(cat "$memory_file")"
    else
        memory_content="# Project Context

Generated by Context Management System v$VERSION
"
        # Import existing context on first use
        _import_existing_context
    fi
    
    # Append new entry
    memory_content+="
## [$category] $(date -u +%Y-%m-%dT%H:%M:%SZ)
$content
"
    
    # Write atomically
    _atomic_write "$memory_file" "$memory_content" || return 1
    
    # Trigger provider sync
    _sync_providers "$project_root" || {
        _log_warn "Provider sync failed"
    }
    
    _log_info "Context stored: [$category] ${content:0:50}..."
    printf '✓ Stored [%s]: %s\n' "$category" "$content"
}

# Context retrieval
_retrieve_context() {
    local filter="${1:-}"
    local project_root
    project_root="$(pwd)" || return 1
    
    local memory_file="$project_root/.ai-context/memory.md"
    
    if [[ ! -f "$memory_file" ]]; then
        printf 'No context found in current project.\n'
        return 1
    fi
    
    if [[ -n "$filter" ]]; then
        filter="$(_validate_input "$filter" 100)" || return 1
        grep -i "$filter" "$memory_file" 2>/dev/null || printf 'No matches found.\n'
    else
        cat "$memory_file"
    fi
}

# Provider synchronization
_sync_providers() {
    local project_root="$1"
    local memory_file="$project_root/.ai-context/memory.md"
    
    [[ -f "$memory_file" ]] || return 0
    
    # Load configuration
    local config
    config="$(cat "$CONFIG_HOME/config.json")" || {
        _log_error "Cannot load configuration"
        return 1
    }
    
    # Extract project metadata
    local project_name
    project_name="$(basename "$project_root")"
    
    local git_branch="main"
    if command -v git >/dev/null 2>&1; then
        git_branch="$(git -C "$project_root" branch --show-current 2>/dev/null)" || git_branch="main"
    fi
    
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # Sync each enabled provider
    _sync_claude "$project_root" "$project_name" "$git_branch" "$timestamp"
    _sync_cursor "$project_root" "$project_name" "$git_branch" "$timestamp"
    _sync_copilot "$project_root" "$project_name" "$git_branch" "$timestamp"
    _sync_gemini "$project_root" "$project_name" "$git_branch" "$timestamp"
    
    _log_info "Provider synchronization completed"
}

# Provider-specific sync functions
_sync_claude() {
    local project_root="$1"
    local project_name="$2"
    local branch="$3"
    local timestamp="$4"
    
    local file_path="$project_root/CLAUDE.md"
    
    if [[ -f "$file_path" ]]; then
        # File exists - check if it has our reference
        if ! grep -q "@.ai-context/memory.md" "$file_path" 2>/dev/null; then
            # Add reference at the top
            local existing_content="$(cat "$file_path")"
            local content="<!-- CONTEXT-SYSTEM-MANAGED -->
Project: $project_name | Branch: $branch | Updated: $timestamp

## Project Context
@.ai-context/memory.md

---

$existing_content"
            _atomic_write "$file_path" "$content"
            _log_info "Added context reference to existing CLAUDE.md"
        fi
        # If reference exists, do nothing - all context is in memory.md
    else
        # Create new file with reference
        local content="# Claude Context
<!-- CONTEXT-SYSTEM-MANAGED -->
Project: $project_name | Branch: $branch | Updated: $timestamp

## Project Context
@.ai-context/memory.md

## Usage
This file provides Claude with persistent project context through file references.
All project-specific information is maintained in the memory file above.
"
        _atomic_write "$file_path" "$content"
    fi
}

_sync_cursor() {
    local project_root="$1"
    local project_name="$2"
    local branch="$3"
    local timestamp="$4"
    
    local file_path="$project_root/.cursorrules"
    
    if [[ -f "$file_path" ]]; then
        # File exists - check if it has our reference
        if ! grep -q ".ai-context/memory.md" "$file_path" 2>/dev/null; then
            # Prepend reference instruction
            local existing_content="$(cat "$file_path")"
            local content="# CONTEXT-SYSTEM-MANAGED
# Project: $project_name | Updated: $timestamp
# Always check .ai-context/memory.md for project context

$existing_content"
            _atomic_write "$file_path" "$content"
            _log_info "Added context reference to existing .cursorrules"
        fi
        # If reference exists, do nothing
    else
        # Create new minimal file
        local content="# Cursor Rules
# CONTEXT-SYSTEM-MANAGED
# Project: $project_name | Updated: $timestamp

# Always check .ai-context/memory.md for project-specific context
# All project decisions and patterns are documented there
"
        _atomic_write "$file_path" "$content"
    fi
}

_sync_copilot() {
    local project_root="$1"
    local project_name="$2"
    local branch="$3"
    local timestamp="$4"
    
    [[ -d "$project_root/.github" ]] || mkdir -p "$project_root/.github"
    
    local content="# GitHub Copilot Instructions

Project: $project_name | Branch: $branch | Updated: $timestamp

## Context Reference
../.ai-context/memory.md

## Guidelines
Reference project-specific context for improved code suggestions.
"
    
    _atomic_write "$project_root/.github/copilot-instructions.md" "$content"
}

_sync_gemini() {
    local project_root="$1"
    
    # Create symlink for Gemini
    local target=".ai-context/memory.md"
    local link="$project_root/GEMINI.md"
    
    [[ -L "$link" ]] && rm "$link"
    ln -sf "$target" "$link" 2>/dev/null || {
        _log_warn "Cannot create Gemini symlink"
    }
}

# Status reporting
_show_status() {
    local project_root
    project_root="$(pwd)" || return 1
    
    printf 'Context Management System v%s\n' "$VERSION"
    printf '================================\n\n'
    
    printf 'Configuration: %s\n' "$CONFIG_HOME"
    printf 'Data Storage: %s\n' "$DATA_HOME"
    printf 'Cache: %s\n\n' "$CACHE_HOME"
    
    if [[ -f "$project_root/.ai-context/memory.md" ]]; then
        local entry_count
        entry_count="$(grep -c "^## \[" "$project_root/.ai-context/memory.md" 2>/dev/null || echo "0")"
        printf 'Project Context: %d entries\n' "$entry_count"
        
        # Show provider sync status
        printf '\nProvider Files:\n'
        [[ -f "$project_root/CLAUDE.md" ]] && printf '  ✓ Claude\n'
        [[ -f "$project_root/.cursorrules" ]] && printf '  ✓ Cursor\n'
        [[ -f "$project_root/.github/copilot-instructions.md" ]] && printf '  ✓ GitHub Copilot\n'
        [[ -L "$project_root/GEMINI.md" ]] && printf '  ✓ Gemini\n'
        
        # Security status
        printf '\nSecurity:\n'
        if [[ -f "$project_root/.gitignore" ]] && grep -q "^.ai-context" "$project_root/.gitignore"; then
            printf '  ✓ .ai-context in .gitignore\n'
        else
            printf '  ⚠️  .ai-context not in .gitignore\n'
        fi
        
        # Check for potential secrets
        if grep -qE "(password|api_key|secret|token)[\s]*[:=]" "$project_root/.ai-context/memory.md" 2>/dev/null; then
            printf '  ⚠️  Possible secrets detected in memory.md\n'
        else
            printf '  ✓ No obvious secrets in memory.md\n'
        fi
    else
        printf 'No context initialized in current project.\n'
    fi
}

# Track documentation with timestamps
_track_doc() {
    local doc_path="$1"
    local description="${2:-}"
    
    if [[ ! -f "$doc_path" ]]; then
        echo "File not found: $doc_path"
        return 1
    fi
    
    # Get file modification time
    local mtime
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$doc_path" 2>/dev/null)
    else
        mtime=$(date -r "$doc_path" "+%Y-%m-%d %H:%M" 2>/dev/null)
    fi
    local size=$(du -h "$doc_path" | cut -f1)
    
    local entry="Doc: $doc_path - Modified: $mtime, Size: $size"
    if [[ -n "$description" ]]; then
        entry="$entry - $description"
    fi
    
    _store_context "docs" "$entry"
}

# List recent documentation changes
_list_recent_docs() {
    local days="${1:-7}"
    local project_root="$(pwd)"
    
    echo "Recent documentation (last $days days):"
    echo "====================================="
    
    find . -name "*.md" -type f -mtime -"$days" -print0 2>/dev/null | \
    while IFS= read -r -d '' file; do
        # Skip system files
        [[ "$file" == *".ai-context"* ]] && continue
        [[ "$file" == "./CLAUDE.md" ]] && continue
        [[ "$file" == "./GEMINI.md" ]] && continue
        
        local mtime
        if [[ "$OSTYPE" == "darwin"* ]]; then
            mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null)
        else
            mtime=$(date -r "$file" "+%Y-%m-%d %H:%M" 2>/dev/null)
        fi
        local size=$(du -h "$file" | cut -f1)
        printf "  %-40s %s  %s\n" "$file" "$mtime" "$size"
    done | sort -k2 -r
}

# Command interface
context() {
    local command="${1:-help}"
    shift 2>/dev/null || true
    
    case "$command" in
        store|remember)
            [[ $# -ge 2 ]] || {
                printf 'Usage: context store <category> <content>\n' >&2
                return 1
            }
            _store_context "$1" "$2"
            ;;
        
        doc|track-doc)
            [[ $# -ge 1 ]] || {
                printf 'Usage: context doc <file> [description]\n' >&2
                return 1
            }
            _track_doc "$1" "${2:-}"
            ;;
        
        recent-docs)
            _list_recent_docs "${1:-7}"
            ;;
        
        retrieve|recall)
            _retrieve_context "${1:-}"
            ;;
        
        status)
            _show_status
            ;;
        
        sync)
            _sync_providers "$(pwd)"
            ;;
        
        import)
            _import_existing_context
            _sync_providers "$(pwd)"
            ;;
        
        help|--help|-h)
            cat << 'EOF'
Context Management System

Commands:
  context store <category> <content>    Store contextual information
  context retrieve [filter]             Retrieve stored context
  context status                        Show system status
  context sync                          Force provider synchronization
  context import                        Import existing AI files into memory
  context doc <file> [description]      Track a document with timestamp
  context recent-docs [days]            List recently modified docs
  context help                          Display this help

Categories:
  architecture    System design and architecture decisions
  requirements    Business and technical requirements
  implementation  Code implementation details
  infrastructure  Deployment and infrastructure setup
  decisions       Technical decisions and rationale
  issues          Known issues and resolutions
  docs            Documentation references with timestamps

Examples:
  context store architecture "Microservices with event sourcing"
  context store decisions "PostgreSQL for ACID compliance"
  context doc API.md "REST endpoint documentation"
  context doc docs/DEPLOY.md
  context recent-docs 14    # Show docs modified in last 14 days
  context retrieve "docs"   # Find all doc references
  context import            # Import existing CLAUDE.md, .cursorrules, etc.

Configuration stored in: ~/.config/context/
Data stored in: ~/.local/share/context/

Security Tips:
  - Don't store passwords/tokens directly - use references
  - .ai-context/ is auto-added to .gitignore  
  - Treat like .bashrc - same security model
  - Good:  context store api "Using AWS API Gateway with auth"
  - Bad:   context store api "api_key=sk-abc123..."
  - Good:  context store secrets "DB creds in 1Password: Prod-DB"
EOF
            ;;
        
        *)
            printf 'Invalid command: %s\n' "$command" >&2
            printf 'Run "context help" for usage information.\n' >&2
            return 1
            ;;
    esac
}

# Initialize on source
_init_system

# Export public interface
export -f context