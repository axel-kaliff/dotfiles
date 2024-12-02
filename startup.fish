#!/usr/bin/env fish

# Step 1: Perform git pull in the ~/dotfiles directory
if test -d ~/dotfiles
    cd ~/dotfiles
    git pull
else
    echo "Directory ~/dotfiles does not exist."
end

# Step 2: Start flatpaks
flatpak run md.obsidian.Obsidian &
flatpak run io.github.slgobinath.SafeEyes &

udot
