. ej-setup-env.sh

if ask_yes_no 'Set deps?'; then          setup-dependencies; fi
if :; then                               setup-link; fi
if ask_yes_no 'Set links?'; then         setup-links-2; fi
if ask_yes_no 'Set xdg-user-dirs?'; then setup-xdg; fi
if ask_yes_no 'Set ~/.gitconfig?'; then  setup-git; fi
if ask_yes_no 'Set ctrl:nocaps?'; then   setup-no-caps; fi
if ask_yes_no 'Set keys?'; then          setup-keys; fi
echo 'Done!'
