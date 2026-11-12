#!/usr/bin/env bash

sudo systemctl start midistro-estado.service
service_status=$?
journalctl -u midistro-estado.service -n 8 --no-pager
exit "$service_status"