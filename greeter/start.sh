#!/bin/sh
# Run by uwc (-s) inside the greetd session: shows the greeter, then quits uwc when it exits (after login).
qs -p /etc/greetd/ushell-greeter
uwc msg quit
