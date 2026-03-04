function r2d2 --description "SSH into r2d2 and attach to tmux"
    ssh r2d2 -t "tmux new-session -A -s main"
end
