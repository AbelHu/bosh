#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cat > $chroot/var/vcap/bosh/agent.json <<JSON
{
  "Platform": {
    "Linux": {
      "DevicePathResolutionType": "scsi"
    }
  },
  "Infrastructure": {
    "NetworkingType": "dhcp",

    "Settings": {
      "Sources": [
        {
          "Type": "FILE",
          "MetaDataPath": "",
          "UserDataPath": "/var/lib/waagent/CustomData",
          "SettingsPath": ""
        }
      ],
      "UseServerName": true,
      "UseRegistry": true
    }
  }
}
JSON