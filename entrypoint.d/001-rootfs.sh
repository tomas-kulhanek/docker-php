#!/bin/bash -e

[[ -d /rootfs ]] && cp -a /rootfs/. /

echo 'Rootfs synced.'
