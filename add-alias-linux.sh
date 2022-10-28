#!/bin/bash

cp loopback-alias.service /etc/systemd/system/loopback-alias.service
systemctl daemon-reload
systemctl enable loopback-alias
systemctl start loopback-alias
