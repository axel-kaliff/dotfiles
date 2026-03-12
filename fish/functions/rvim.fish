function rvim --description "Sync neovim config to remote host and open nvim"
    set -l host $argv[1]
    if test -z "$host"
        set host r2d2
    end

    set -l nvim_config "$HOME/.config/nvim"
    set -l remote_dest "$host:.config/nvim/"

    echo "Syncing nvim config to $host..."
    rsync -az --delete "$nvim_config/" "$remote_dest"
    or begin
        echo "Failed to sync nvim config"
        return 1
    end

    echo "Starting nvim on $host..."
    ssh $host -t "bash -lc 'nvim $argv[2..]'"
end
