# Bonfire palette for fish.

set -l foreground e8dccb
set -l selection 1a0d08
set -l comment 875f5f
set -l red e03a1e
set -l orange ff8700
set -l yellow ffb000

set -g fish_color_normal $foreground
set -g fish_color_command $orange --bold
set -g fish_color_keyword $orange
set -g fish_color_quote $yellow
set -g fish_color_redirection $foreground
set -g fish_color_end $orange
set -g fish_color_error $red --underline
set -g fish_color_param $foreground
set -g fish_color_comment $comment
set -g fish_color_selection --background=$selection
set -g fish_color_search_match --background=$selection
set -g fish_color_operator $orange
set -g fish_color_escape $yellow
set -g fish_color_autosuggestion $comment

set -g fish_pager_color_progress $comment
set -g fish_pager_color_prefix $orange
set -g fish_pager_color_completion $foreground
set -g fish_pager_color_description $comment

set -gx LS_COLORS 'di=1;38;5;208:ln=38;5;179:so=38;5;132:pi=38;5;137:ex=1;38;5;196:bd=38;5;179;4:cd=38;5;179;4:su=38;5;160:sg=38;5;160:tw=1;38;5;208:ow=1;38;5;208:fi=38;5;223'
set -gx EZA_COLORS 'reset:di=1;38;5;208:ex=1;38;5;196:fi=38;5;223:ln=38;5;179:ur=38;5;214:uw=38;5;208:ux=38;5;196:ue=38;5;196:gr=38;5;214:gw=38;5;208:gx=38;5;196:tr=38;5;214:tw=38;5;208:tx=38;5;196:da=38;5;95:sn=38;5;214:sb=38;5;137:uu=38;5;208:gu=38;5;208:hd=4;38;5;223'
set -gx BAT_THEME gruvbox-dark
