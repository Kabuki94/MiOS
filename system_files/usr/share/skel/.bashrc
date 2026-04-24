# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment and startup programs

# CloudWS-bootc aliases
alias ls='ls --color=auto'
alias ll='ls -lha --color=auto'
alias grep='grep --color=auto'

# Diagnostic Dashboard on login
if command -v cloudws &> /dev/null && [ -z "$VTE_VERSION" ] && [ "$TERM" != "linux" ]; then
    cloudws dash
fi
