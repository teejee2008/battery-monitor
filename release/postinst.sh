#!/bin/bash

app_name='aptik-battery-monitor'
app_fullname='Aptik Battery Monitor'

echo "Creating log directory..."
mkdir -p /var/log/${app_name}
chmod a+rwx /var/log/${app_name}

echo "Starting service..."
/etc/init.d/${app_name} start
update-rc.d ${app_name} defaults

