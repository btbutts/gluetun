#!/bin/bash
##Execute default Gluetun Docker Entrypoint executable after running fw-config.sh##
#ENTRYPOINT ["/gluetun-entrypoint"]
echo "Beginning fw (iptables) coconfig"
/root/scripts/fw-config.sh & /gluetun-entrypoint
