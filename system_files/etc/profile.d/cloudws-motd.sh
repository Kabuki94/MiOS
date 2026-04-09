#!/bin/bash
[[ $- != *i* ]] && return
[[ -n "$CLOUDWS_NO_MOTD" ]] && return
[[ -f /usr/libexec/cloudws-motd ]] && /usr/libexec/cloudws-motd