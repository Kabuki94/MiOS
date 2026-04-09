#!/bin/bash
# CloudWS service dashboard — sourced on every login
[[ $- != *i* ]] && return
[[ -n "$CLOUDWS_NO_MOTD" ]] && return
[[ -f /usr/libexec/cloudws-motd ]] && /usr/libexec/cloudws-motd
