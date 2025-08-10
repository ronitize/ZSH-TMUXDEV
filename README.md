# ZSH-TMUXDEV

Automatically runs pnpm/npm/yarn/bun scripts (e.g., `pnpm dev`, `npm start`) in a dedicated `tmux` session.
Each script gets its own `tmux` window with a horizontal split:
- Left pane: Runs the dev server/script.
- Right pane: An interactive shell in the same project directory for additional commands.
Whenever you run lets say pnpm run dev it will take that command and run that in the same dir 
but in a new tmux session freeing your current terminal.

## Requirements

- `tmux` must be installed on your system.
- Zsh shell.

## Installation

### Using Oh My Zsh (Recommended)

1. Clone this repository into your Oh My Zsh custom plugins directory:
   ```bash
   git clone https://github.com/ronitize/ZSH-TMUXDEV.git ${ZSH_CUSTOM:- $HOME/.oh-my-zsh/custom}/plugins/ZSH-TMUXDEV
   ```
2. Add `ZSH-TMUXDEV` to your `plugins` array in your `~/.zshrc` file:
   ```zsh
   plugins=(git ZSH-TMUXDEV) # Add it to your existing plugins
   ```
3. Source your `~/.zshrc` file or open a new terminal session:
   ```bash
   source ~/.zshrc
   ```

### Using Antigen

1. Add the following line to your `~/.zshrc` file:
   ```zsh
   antigen bundle ronitize/ZSH-TMUXDEV
   ```
2. Source your `~/.zshrc` file or open a new terminal session.

### Using Zinit

1. Add the following line to your `~/.zshrc` file:
   ```zsh
   zinit light ronitize/ZSH-TMUXDEV
   ```
2. Source your `~/.zshrc` file or open a new terminal session.

### Manual Installation

1. Clone this repository to a convenient location (e.g., `~/.local/share/zsh-plugins/ZSH-TMUXDEV`):
   ```bash
   git clone https://github.com/ronitize/ZSH-TMUXDEV.git ~/.local/share/zsh-plugins/ZSH-TMUXDEV
   ```
2. Add the following line to your `~/.zshrc` file:
   ```zsh
   source ~/.local/share/zsh-plugins/ZSH-TMUXDEV/tmux-dev-wrapper.plugin.zsh
   ```
3. Source your `~/.zshrc` file or open a new terminal session.

## Usage

After installation, simply use `pnpm`, `npm`, `yarn`, or `bun` commands as you normally would for running scripts. This includes both explicit `run` commands and common direct script executions.

*   `pnpm run dev`
*   `npm start`
*   `yarn build`
*   `bun dev --watch`
*   `pnpm test`

These commands will now automatically open new `tmux` windows within the `TMUXDEV` session, each split horizontally with your script running in the top pane and an interactive shell in the bottom.

**To attach to your `tmux` development session:**

```bash
tmux attach -t TMUXDEV
```

**Inside the `TMUXDEV` session:**

*   **Switch windows:** `Ctrl+b` then `n` (next), `p` (previous), or `w` (show window list).
*   **Switch panes:** `Ctrl+b` then `up/down arrow keys`.
*   **Kill a server:** Navigate to its pane and press `Ctrl+c`. The interactive shell in the bottom pane will remain active.
*   **Close a pane/window:** Type `exit` or press `Ctrl+d` in the pane.
