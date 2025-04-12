
# good resource: https://daniel.melzaks.com/guides/ucore-server-setup/
# for zfs setup and snapshot stuff

##### set user/root password
# sudo passwd username

##### install brew
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# post brew install steps
# echo >> /var/home/core/.bashrc
# echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /var/home/core/.bashrc
# eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"


##### using laptop: keep going with closed lid
# sudo mkdir -p /etc/systemd/logind.conf.d
#  sudo nvim /etc/systemd/logind.conf.d/ignore-lid-switch.conf

# put this in
# [Login]
# HandleLidSwitch=ignore
# HandleLidSwitchExternalPower=ignore
# HandleLidSwitchDocked=ignore
#

# after
# sudo systemctl restart systemd-logind





##### Plex

# open firewall ports on container host
sudo firewall-cmd --add-port=1900/udp --add-port=32400/tcp --add-port=5353/udp --add-port=8324/tcp --add-port=32410/udp --add-port=32412/udp --add-port=32413/udp --add-port=32414/udp --add-port=32469/tcp --permanent

# load changes 
sudo firewall-cmd --reload

mkdir -p ~/.config/containers/systemd/
vim ~/.config/containers/systemd/plex.container

# in ~/.config/containers/systemd/, add plex-config.volume, plex-movies.volume, plex-tv.volume

# after making the files, load unit files into systemd
systemctl --user daemon-reload

# enable and restart
systemctl --user start plex.service

# enable automatic updates
systemctl --user enable --now podman-auto-update.service
# run updates at midnight
systemctl --user enable --now podman-auto-update.timer

