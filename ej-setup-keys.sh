echo 'Fixing s-1, s-2, s-3'

bind-key () {
    key=$1
    command=$2
    xfconf-query -c xfce4-keyboard-shortcuts -n -t 'string' -p "/commands/custom/$key" -s "$command"
}
bind-key '<Super>1'      'wmctrl -xR "emacs.Emacs"'
bind-key '<Super><Alt>1'      'wmctrl -a "Emacs at tpc"'
bind-key '<Super>2'      'wmctrl -xR "chromium.Chromium"'
bind-key '<Alt><Super>2' 'wmctrl -xR "Navigator.firefox"'
bind-key '<Super>3'      'wmctrl -xR "Telegram.TelegramDesktop"'
bind-key '<Super>0'      'emacsclient --no-wait --eval &apos;(ej/quick-copy-external)&apos; | xargs xdotool key'

bind-key '<Super><KP_1>'  "xdotool mousemove_relative --sync -- -10 10"
bind-key '<Super><KP_2>'  "xdotool mousemove_relative --sync -- 0 10"
bind-key '<Super><KP_3>'  "xdotool mousemove_relative --sync -- 10 10"
bind-key '<Super><KP_4>'  "xdotool mousemove_relative --sync -- -10 0"
bind-key '<Super><KP_6>'  "xdotool mousemove_relative --sync -- 10 0"
bind-key '<Super><KP_7>'  "xdotool mousemove_relative --sync -- -10 -10"
bind-key '<Super><KP_8>'  "xdotool mousemove_relative --sync -- 0 -10"
bind-key '<Super><KP_9>'  "xdotool mousemove_relative --sync -- 10 -10"
bind-key '<Super><KP_5>'  "xdotool click 1"
bind-key '<Alt><Super><KP_1>' "xdotool mousemove_relative --sync -- -30 30"
bind-key '<Alt><Super><KP_2>' "xdotool mousemove_relative --sync -- 0 30"
bind-key '<Alt><Super><KP_3>' "xdotool mousemove_relative --sync -- 30 30"
bind-key '<Alt><Super><KP_4>' "xdotool mousemove_relative --sync -- -30 0"
bind-key '<Alt><Super><KP_6>' "xdotool mousemove_relative --sync -- 30 0"
bind-key '<Alt><Super><KP_7>' "xdotool mousemove_relative --sync -- -10 -10"
bind-key '<Alt><Super><KP_8>' "xdotool mousemove_relative --sync -- 0 -30"
bind-key '<Alt><Super><KP_9>' "xdotool mousemove_relative --sync -- 30 -30"
bind-key '<Super><0>'     "emacsclient --no-wait --eval &apos;(ej/quick-copy-external)&apos; | xargs xdotool key"
bind-key '<Super><3>'     "wmctrl -x -a telegram.Telegram"
bind-key '<Super><8>'     "wmctrl -xa vlc.Vlc"
bind-key '<Super><minus>' "/home/j/bash-ej/move-to-next-monitor"
bind-key '<Super><7>'     "wmctrl -a &quot;Terminal&quot;"
bind-key '<Super><1>'     "wmctrl -a &quot;GNU Emacs at tpc&quot;"
