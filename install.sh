#!/bin/bash

# con - con installer.
# Copyright (C) 2013 Erl Cash <erlcash@codeward.org>
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.

MNT_BIN="mnt.sh"
INSTALL_DIR="/usr/local/bin"

if [ ! $UID -eq 0 ]; then
	echo "$0: you must be root to run this script."
	exit 1
fi

if [ ! -f "$MNT_BIN" ]; then
	echo "$0: enc '$MNT_BIN' not found."
	exit 1
fi

echo -n "$MNT_BIN => $INSTALL_DIR/$(basename "$MNT_BIN" ".sh") "

install "$MNT_BIN" "$INSTALL_DIR/$(basename "$MNT_BIN" ".sh")" 2>&1 > /dev/null

if [ ! $? -eq 0 ]; then
	echo "[FAILED]"
	exit 1
else
	echo "[OK]"
fi

exit 0
