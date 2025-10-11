# -*- mode: zsh -*-
#
# ZSH-TMUXDEV
# Automatically runs pnpm/npm/yarn/bun/vite scripts in a dedicated tmux session,
# creating a new window with a horizontal split for each script.
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
    vite() { command vite "$@"; } # Corrected vite fallback
    return 1
fi

_tmux_dev_wrapper_run_script() {
    local pkg_mgr="$1"
    local script_name="$3"
    local session_name="TMUXDEV"
    local current_dir="$(pwd)"
    local full_command_to_execute="command \"$pkg_mgr\" ${@:2}"

    local base_window_name="$(basename "$current_dir")-${script_name}-${pkg_mgr}"
    local window_name="$base_window_name"
    local counter=0
    while tmux has-window -t "${session_name}:${window_name}" 2>/dev/null; do
        counter=$((counter + 1))
        window_name="${base_window_name}-${counter}"
    done

    local server_pane_title="${window_name}"
    if (( ${#server_pane_title} > 25 )); then
        server_pane_title="${server_pane_title:0:22}..."
    fi

    local top_pane_id # This will store the ID of our target pane.

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "ZSH-TMUXDEV: Creating new session '$session_name'..." >&2
        # Create a new session and capture the ID of its first pane.
        top_pane_id=$(tmux new-session -d -s "$session_name" -n "$window_name" -c "$current_dir" "zsh -l" -P -F '#{pane_id}')
    else
        echo "ZSH-TMUXDEV: Using existing session '$session_name'. Creating new window '$window_name'..." >&2
        # Create a new window and capture the ID of its first pane.
        top_pane_id=$(tmux new-window -d -t "$session_name" -n "$window_name" -c "$current_dir" "zsh -l" -P -F '#{pane_id}')
    fi

    # Now, split the window using the guaranteed correct pane ID.
    local bottom_pane_id=$(tmux split-window -h -t "$top_pane_id" -c "$current_dir" "zsh -l" -P -F '#{pane_id}')

    # Send commands to the correct panes using their IDs.
    tmux send-keys -t "$top_pane_id" "clear" C-m
    tmux send-keys -t "$top_pane_id" "$full_command_to_execute" C-m
    tmux select-pane -t "$top_pane_id" -T "$server_pane_title"

    tmux send-keys -t "$bottom_pane_id" "clear" C-m
    tmux select-pane -t "$bottom_pane_id" -T "Interactive Shell"

    # Optionally, focus the top pane where the script is running.
    tmux select-pane -t "$top_pane_id"

    echo "ZSH-TMUXDEV: Task running in window '$window_name'. Your terminal is free." >&2
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

alias pnpm="_tmux_dev_wrapper_pkg_mgr_handler pnpm"
alias npm="_tmux_dev_wrapper_pkg_mgr_handler npm"
alias yarn="_tmux_dev_wrapper_pkg_mgr_handler yarn"
alias bun="_tmux_dev_wrapper_pkg_mgr_handler bun"
alias vite="_tmux_dev_wrapper_pkg_mgr_handler vite"
