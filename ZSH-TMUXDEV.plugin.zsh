# -*- mode: zsh -*-
#
# ZSH-TMUXDEV
# Automatically runs pnpm/npm/yarn/bun/vite scripts in a dedicated tmux session,
# creating a new window with a split for each script.
#
# Configuration (optional, in your .zshrc):
#   export ZSH_TMUXDEV_SESSION_NAME="MyDev" # Customize the tmux session name
#   export ZSH_TMUXDEV_ATTACH="true"        # Auto-attach to the session after starting a task
#   export ZSH_TMUXDEV_SPLIT_DIRECTION="-v" # Use "-v" for vertical split, "-h" for horizontal
#
# To install:
#   - Oh My Zsh: Add 'ZSH-TMUXDEV' to your plugins array in .zshrc
#   - Antigen:   antigen bundle ronitize/ZSH-TMUXDEV
#   - Zinit:     zinit light ronitize/ZSH-TMUXDEV
#   - Manual:    source /path/to/tmux-dev-wrapper.plugin.zsh in your .zshrc

if [[ -n "$_ZSH_TMUX_DEV_WRAPPER_LOADED" ]]; then
  return 0
fi
_ZSH_TMUX_DEV_WRAPPER_LOADED="true"

if ! hash tmux 2>/dev/null; then
    echo "Warning: tmux not found. ZSH-TMUXDEV will not function." >&2
    pnpm() { command pnpm "$@"; }
    npm() { command npm "$@"; }
    yarn() { command yarn "$@"; }
    bun() { command bun "$@"; }
    vite() { command vite "$@"; }
    return 1
fi

_tmux_dev_wrapper_run_script() {
    local pkg_mgr="$1"
    local script_name="$3"
    local session_name="${ZSH_TMUXDEV_SESSION_NAME:-TMUXDEV}"
    local split_direction="${ZSH_TMUXDEV_SPLIT_DIRECTION:--h}"
    local current_dir="$(pwd)"

    # EDGE CASE FIX 1: Use an array to handle arguments with spaces/special characters robustly.
    local -a command_parts
    command_parts=("command" "$pkg_mgr" "${@:2}")

    # EDGE CASE FIX 2: Sanitize directory name to remove invalid characters for tmux windows.
    local sanitized_dir_name=$(basename "$current_dir" | tr -d '.:')
    local base_window_name="${sanitized_dir_name}-${script_name}-${pkg_mgr}"
    local window_name="$base_window_name"
    local counter=0
    while tmux list-windows -t "$session_name" -F '#{window_name}' 2>/dev/null | grep -q "^${window_name}$"; do
        counter=$((counter + 1))
        window_name="${base_window_name}-${counter}"
    done

    local server_pane_title="${window_name}"
    if (( ${#server_pane_title} > 25 )); then
        server_pane_title="${server_pane_title:0:22}..."
    fi

    local top_pane_id
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "ZSH-TMUXDEV: Creating new session '$session_name' with window '$window_name'..." >&2
        top_pane_id=$(tmux new-session -d -s "$session_name" -n "$window_name" -c "$current_dir" "zsh -l" -P -F '#{pane_id}')
    else
        echo "ZSH-TMUXDEV: Using session '$session_name', creating new window '$window_name'..." >&2
        top_pane_id=$(tmux new-window -d -t "$session_name" -n "$window_name" -c "$current_dir" "zsh -l" -P -F '#{pane_id}')
    fi

    # EDGE CASE FIX 3: Check if pane creation was successful before proceeding.
    if [[ -z "$top_pane_id" ]]; then
        echo "ZSH-TMUXDEV: Error: Failed to create new tmux pane. Aborting." >&2
        return 1
    fi

    local bottom_pane_id=$(tmux split-window "$split_direction" -t "$top_pane_id" -c "$current_dir" "zsh -l" -P -F '#{pane_id}')

    tmux send-keys -t "$top_pane_id" "clear" C-m
    tmux send-keys -t "$top_pane_id" "${command_parts[@]}" C-m # Use the robust array here
    tmux select-pane -t "$top_pane_id" -T "$server_pane_title"

    tmux send-keys -t "$bottom_pane_id" "clear" C-m
    tmux select-pane -t "$bottom_pane_id" -T "Interactive Shell"

    tmux select-pane -t "$top_pane_id"

    # EDGE CASE FIX 4: Use attach-session or switch-client depending on the context.
    if [[ "$ZSH_TMUXDEV_ATTACH" == "true" ]]; then
        if [[ -n "$TMUX" ]]; then
            tmux switch-client -t "$session_name"
        else
            tmux attach-session -t "$session_name"
        fi
    fi

    echo "ZSH-TMUXDEV: Task running in '$window_name'. Your terminal is now free." >&2
}

_tmux_dev_wrapper_pkg_mgr_handler() {
    local pkg_mgr_name="$1"
    shift

    local subcommand="$1"
    local implicit_run_scripts=("dev" "start" "test" "build" "serve" "watch" "preview")
    local should_run_in_tmux=false

    if [[ "$subcommand" == "run" && -n "$2" ]]; then
        should_run_in_tmux=true
        _tmux_dev_wrapper_run_script "$pkg_mgr_name" "$@"
    elif [[ -n "$subcommand" && " ${implicit_run_scripts[*]} " =~ " ${subcommand} " ]]; then
        should_run_in_tmux=true
        _tmux_dev_wrapper_run_script "$pkg_mgr_name" "run" "$@"
    elif [[ "$pkg_mgr_name" == "vite" && -z "$subcommand" ]]; then
        should_run_in_tmux=true
        _tmux_dev_wrapper_run_script "$pkg_mgr_name" "run" "dev" "$@"
    fi

    if ! $should_run_in_tmux; then
        command "$pkg_mgr_name" "$@"
    fi
}

_tmux_dev_wrapper_kill_session() {
    local session_name="${ZSH_TMUXDEV_SESSION_NAME:-TMUXDEV}"
    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux kill-session -t "$session_name" && echo "ZSH-TMUXDEV: Session '$session_name' killed."
    else
        echo "ZSH-TMUXDEV: Session '$session_name' not found."
    fi
}

alias pnpm="_tmux_dev_wrapper_pkg_mgr_handler pnpm"
alias npm="_tmux_dev_wrapper_pkg_mgr_handler npm"
alias yarn="_tmux_dev_wrapper_pkg_mgr_handler yarn"
alias bun="_tmux_dev_wrapper_pkg_mgr_handler bun"
alias vite="_tmux_dev_wrapper_pkg_mgr_handler vite"
alias tmuxdev-kill="_tmux_dev_wrapper_kill_session"
