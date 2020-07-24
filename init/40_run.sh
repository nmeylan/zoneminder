#!/bin/bash
echo "Starting services..."
service mysql start

# Update the database if necessary
zmupdate.pl -nointeractive
zmupdate.pl -f

# set user crontab entries
crontab -r -u root
if [ -f /config/cron ]; then
	crontab -l -u root | cat - /config/cron | crontab -u root -
fi

# Fix memory issue
echo "Setting shared memory to : $SHMEM of `awk '/MemTotal/ {print $2}' /proc/meminfo` bytes"
umount /dev/shm
mount -t tmpfs -o rw,nosuid,nodev,noexec,relatime,size=${SHMEM} tmpfs /dev/shm

if [ $((MULTI_PORT_START)) -gt 0 ] && [ $((MULTI_PORT_END)) -gt $((MULTI_PORT_START)) ]; then

	echo "Setting ES multi-port range from ${MULTI_PORT_START} to ${MULTI_PORT_END}."

	ORIG_VHOST="_default_:443"

	NEW_VHOST=${ORIG_VHOST}
	PORT=${MULTI_PORT_START}
	while [[ ${PORT} -le ${MULTI_PORT_END} ]]; do
	    egrep -sq "Listen ${PORT}" /etc/apache2/ports.conf || echo "Listen ${PORT}" >> /etc/apache2/ports.conf
	    NEW_VHOST="${NEW_VHOST} _default_:${PORT}"
	    PORT=$(($PORT + 1))
	done

	perl -pi -e "s/${ORIG_VHOST}/${NEW_VHOST}/ if (/<VirtualHost/);" /etc/apache2/sites-enabled/default-ssl.conf
else
	if [ $((MULTI_PORT_START)) -ne 0 ];then
		echo "Multi-port error start ${MULTI_PORT_START}, end ${MULTI_PORT_END}."
	fi
fi

service apache2 start
service zoneminder start
