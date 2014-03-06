#!/bin/bash

# mnt - simple sshfs connection manager.
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

_VER="0.2-1"

# Configuration
HOST_FILE="$HOME/.con_tool_hosts"
MOUNT_DIR="$HOME/mounts"
SSH_PORT=22

# File specification
# alias,127.0.0.1,22,username
DATA_DELIM=","
DATA_ALIAS=1
DATA_HADDR=2
DATA_HPORT=3
DATA_HUSER=4

# Check whether alias is set
function probe ()
{
	als=$1
	if [ "$als" == "" ]; then return 1; fi
	grep -e "^$als$DATA_DELIM" $HOST_FILE 2>&1 > /dev/null
	return $?
}

# Get data for alias
function get_raw ()
{
	als=$1
	grep -e "^$als$DATA_DELIM" $HOST_FILE 2> /dev/null
}

# Get address for the alias
function get_addr ()
{
	als=$1
	get_raw "$als" | awk -F "$DATA_DELIM" '{ print $'$DATA_HADDR' }'
}

# Get port for the alias
function get_port ()
{
	als=$1
	get_raw "$als" | awk -F "$DATA_DELIM" '{ print $'$DATA_HPORT'}'
}

# Get user for the alias
function get_user ()
{
	als=$1
	get_raw "$als" | awk -F "$DATA_DELIM" '{ print $'$DATA_HUSER' }'
}

# Check if alias is mounted (checks existence of the mount point)
function is_mounted ()
{
	als=$1

	mount | grep -w -e "$MOUNT_DIR/$als" 2>&1 > /dev/null
	
	return $?
}

function make_mount_point ()
{
	als=$1
	
	if [ ! -d "$MOUNT_DIR/$als" ]; then
		mkdir "$MOUNT_DIR/$als"
	fi
	
	return $?
}

function rm_mount_point ()
{
	als=$1
	
	rmdir "$MOUNT_DIR/$als"
	
	return $?
}

function sshfs_mount ()
{
	als=$1
	user=$2
	addr=$3
	port=$4
	
	make_mount_point "$als"
	
	if [ ! -d "$MOUNT_DIR/$als" ]; then
		echo "$p: cannot create mount point."
		return 1
	fi
	
	sshfs $user@$addr:/ "$MOUNT_DIR/$als" -p $port 2> /dev/null
	
	if [ ! $? -eq 0 ];then
		echo "Cannot mount the alias '$als'."
		
		is_mounted "$als"
		
		if [ $? -eq 0 ]; then
			sshfs_umount "$als"
		fi
	fi
	
	return $?
}

function sshfs_umount ()
{
	als=$1
	
	fusermount -u "$MOUNT_DIR/$als" 2> /dev/null
	
	if [ ! $? -eq 0 ];then
		echo "Cannot umount the alias '$alias'. Resource is probably busy."
		return 1
	fi
	
	rm_mount_point "$als"
	
	return $?
}

p=$(basename $0)

cmd=$1

if [ ! -f $HOST_FILE ]; then touch "$HOST_FILE"; fi
if [ ! -d $MOUNT_DIR ]; then mkdir "$MOUNT_DIR"; fi

if [ $# -eq 0 ]; then
	echo -e "$p v$_VER\n\nUsage:\n\t$p <alias> [username]\n\t$p add <alias> <username>@<address>[:port]\n\t$p del <alias>\n\nAliases:"
	
	cat  $HOST_FILE | while read fline;
	do
		fline=($(echo $fline | awk -F "$DATA_DELIM" '{ print $1" "$2" "$3" "$4 }'))
		
		is_mounted "${fline[0]}"
		
		if [ $? -eq 1 ]; then
			echo -e "\t${fline[0]} => ${fline[3]}@${fline[1]}:${fline[2]}"
		else
			echo -e "\t*${fline[0]} => ${fline[3]}@${fline[1]}:${fline[2]}"
		fi
	done
	
	exit 0;
fi

case "$cmd" in

# Add new alias
	add )
		alias=$2
		data=($(echo ${3/@/:} | awk -F ":" '{ print $2" "$3" "$1 }'))
		
		if [ -z "$alias" ]; then
			echo "$p: alias is an empty string."
			exit 1
		fi
		
		if [ "$alias" == "add" ] || [ "$alias" == "del" ]; then
			echo "$p: invalid alias name."
			exit 1
		fi
		
		probe "$alias"
		
		if [ $? -eq 0 ]; then
			echo "$p: alias '$alias' is already in use."
			exit 1
		fi
		
		if [ ${#data[@]} -lt 2 ]; then
			echo "$p: invalid format of connection information."
			exit 1
		fi
		
		if [ ${#data[@]} -lt 3 ]; then
			data=("${data[0]}" "$SSH_PORT" "${data[1]}")
		fi
		
		echo "$alias$DATA_DELIM${data[0]}$DATA_DELIM${data[1]}$DATA_DELIM${data[2]}" >> $HOST_FILE
		;;
# Delete alias
	del )
		alias=$2
		
		if [ -z "$alias" ]; then
			echo "$p: alias is an empty string."
			exit 1
		fi
		
		probe "$alias"
		
		if [ ! $? -eq 0 ]; then
			echo "$p: unknown alias '$alias'."
		fi
		
		is_mounted "$alias"
		
		if [ $? -eq 0 ]; then
			echo "$p: cannot delete alias '$alias' - is mounted."
			exit 1
		fi
		
		cat $HOST_FILE | sed '/^'$alias$DATA_DELIM'/d' > /tmp/.con.$$
		mv /tmp/.con.$$ $HOST_FILE
		;;
# Connect to host
	* )
		alias=$1
		user=$2
		
		probe "$alias"
		
		if [ $? -eq 0 ]; then
			if [ "$user" == ""  ]; then
				user=$(get_user "$alias")
			fi

			addr=$(get_addr "$alias")
			port=$(get_port "$alias")
		
			# Use default port when parameter is missing
			if [ "$port" == "" ]; then
				port=$SSH_PORT
			fi

			is_mounted "$alias"
			
			# Alias is not mounted
			if [ $? -eq 1 ];then
				echo "Mounting '$alias' ($user@$addr:$port):"
				sshfs_mount "$alias" "$user" "$addr" "$port"
			else
				echo "Umounting '$alias'."
				sshfs_umount "$alias"
			fi
		else
			echo "$p: unknown alias '$alias'."
		fi
		;;
esac

exit 0
