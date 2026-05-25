#!/bin/bash

# OpenCode Local AI Setup - Uninstall Script
# Reverses the changes made by install.sh
#
# Usage:
#   ./scripts/uninstall.sh            # Interactive uninstall
#   ./scripts/uninstall.sh --dry-run  # Preview what would be removed

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
START_MARKER="# >>> opencode-local-setup >>>"
END_MARKER="# <<< opencode-local-setup <<<"

# Files that install.sh copies directly into CONFIG_DIR
INSTALLED_SCRIPTS=(
    "providers.mjs"
    "sync-core.mjs"
    "sync-provider.mjs"
    "sync-local-models.mjs"
    "sync-on-launch.mjs"
    "opencode-functions.sh"
    "opencode-functions.zsh"
)

# Files install.sh creates that the user may have since edited
USER_FILES=(
    ".env.local"
    "opencode.json"
)

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

# ---- helpers ----------------------------------------------------------------

say()    { echo "  $*"; }
header() { echo ""; echo "$*"; }

remove_file() {
    local path="$1"
    if [ "$DRY_RUN" -eq 1 ]; then
        say "[dry-run] would remove: $path"
    else
        rm -f "$path"
        say "Removed: $path"
    fi
}

confirm() {
    # Returns 0 if user answers y/Y, 1 otherwise
    local prompt="$1"
    local reply
    read -rp "  ${prompt} (y/N): " -n 1 reply
    echo
    [[ "$reply" =~ ^[Yy]$ ]]
}

remove_managed_block() {
    local rc_file="$1"
    local label="$2"

    if [ ! -f "$rc_file" ]; then
        say "$label not found, skipping."
        return
    fi

    if ! grep -qF "$START_MARKER" "$rc_file" 2>/dev/null; then
        say "No managed block found in $label (already clean)."
        return
    fi

    say "Found managed block in $label."

    if [ "$DRY_RUN" -eq 1 ]; then
        say "[dry-run] would back up $rc_file to ${rc_file}.uninstall.bak"
        say "[dry-run] would remove managed block from $rc_file"
        return
    fi

    cp "$rc_file" "${rc_file}.uninstall.bak"
    say "Backed up to ${rc_file}.uninstall.bak"
    sed -i "/^${START_MARKER}$/,/^${END_MARKER}$/d" "$rc_file"
    say "Removed managed block from $rc_file"
}

# ---- banner -----------------------------------------------------------------

echo "OpenCode Local AI Setup - Uninstaller"
echo "======================================"
if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "  Dry-run mode: no changes will be made."
fi

# ---- step 1: remove managed block from shell configs ------------------------

header "Step 1: Shell config files"
remove_managed_block "$HOME/.bashrc" "~/.bashrc"
remove_managed_block "$HOME/.zshrc"  "~/.zshrc"

# ---- step 2: remove installed scripts ---------------------------------------

header "Step 2: Installed scripts in $CONFIG_DIR"

found_scripts=0
for script in "${INSTALLED_SCRIPTS[@]}"; do
    target="${CONFIG_DIR}/${script}"
    if [ -f "$target" ]; then
        found_scripts=1
        remove_file "$target"
    fi
done

if [ "$found_scripts" -eq 0 ]; then
    say "No installed scripts found (already clean)."
fi

# ---- step 3: user-created config files (prompt before removing) -------------

header "Step 3: User configuration files in $CONFIG_DIR"
say "These files may contain your custom settings and will only be removed if you confirm."
echo ""

found_user_files=0
for user_file in "${USER_FILES[@]}"; do
    target="${CONFIG_DIR}/${user_file}"
    if [ -f "$target" ]; then
        found_user_files=1
        if [ "$DRY_RUN" -eq 1 ]; then
            say "[dry-run] would prompt to remove: $target"
        else
            if confirm "Remove $target?"; then
                remove_file "$target"
            else
                say "Kept: $target"
            fi
        fi
    fi
done

if [ "$found_user_files" -eq 0 ]; then
    say "No user configuration files found."
fi

# ---- step 4: remove config directory if it is now empty --------------------

header "Step 4: Config directory $CONFIG_DIR"

if [ ! -d "$CONFIG_DIR" ]; then
    say "Directory does not exist, nothing to do."
elif [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] would check if directory is empty and prompt to remove it."
else
    remaining=$(find "$CONFIG_DIR" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l)
    if [ "$remaining" -eq 0 ]; then
        if confirm "$CONFIG_DIR is empty. Remove it?"; then
            rmdir "$CONFIG_DIR"
            say "Removed: $CONFIG_DIR"
        else
            say "Kept: $CONFIG_DIR"
        fi
    else
        say "Directory still contains $remaining item(s), leaving it in place."
        find "$CONFIG_DIR" -maxdepth 1 -mindepth 1 2>/dev/null | sort | while read -r item; do
            say "  Remaining: $item"
        done
    fi
fi

# ---- done -------------------------------------------------------------------

echo ""
echo "======================================"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run complete. Re-run without --dry-run to apply changes."
else
    echo "Uninstall complete."
    echo ""
    echo "  Shell functions (opencode, oc-local, sync-models, etc.) will be"
    echo "  gone in new shell sessions. To clean the current session run:"
    echo ""
    echo "      source ~/.bashrc    # if you use bash"
    echo "      source ~/.zshrc     # if you use zsh"
    echo ""
    echo "  Backups of any modified shell configs are at:"
    echo "      ~/.bashrc.uninstall.bak  (if ~/.bashrc was modified)"
    echo "      ~/.zshrc.uninstall.bak   (if ~/.zshrc was modified)"
    echo "      ~/.bashrc.bak            (created by install.sh, if present)"
    echo "      ~/.zshrc.bak             (created by install.sh, if present)"
fi
echo ""
