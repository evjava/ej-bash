function get_connected_monitor_info() {
    echo $(xrandr --query | rg -w 'connected' | grep -v '+0+0')
}

function detect_orientation() {
    # 
    info=$(get_connected_monitor_info)
    # horizontal example: eDP-1 connected 1920x1080+2560+360 (normal left inverted right x axis y axis) 344mm x 193mm
    # vertical example: eDP-1 connected 1920x1080+298+1440 (normal left inverted right x axis y axis) 344mm x 193mm
    position=$(echo "$info" | awk '{print $3}' | cut -d+ -f2-)

    x_pos=$(echo "$position" | cut -d+ -f1)
    y_pos=$(echo "$position" | cut -d+ -f2)

    # Determine orientation
    if [ "$x_pos" -gt "$y_pos" ]; then
        echo "horizontal"
    elif [ "$y_pos" -gt "$x_pos" ]; then
        echo "vertical"
    else
        echo "horizontal"
    fi
}

function monitors-command() {
    arg=$1;
    case "$arg" in
        move) echo move;;
        info) echo "Orientation: $(detect_orientation)";;
        *) echo $arg
    esac
}
monitors-command $1
