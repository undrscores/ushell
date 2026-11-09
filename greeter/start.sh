#!/bin/sh
# Run by uwm (-s) inside the greetd session: shows the greeter, then quits uwm when it exits (after login).
qs -p /etc/greetd/ushell-greeter
printf 'quit\n' | nc -U "$UWM_SOCKET"
