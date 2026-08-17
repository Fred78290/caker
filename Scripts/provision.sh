#!/bin/bash

set -e

caked delete $1 || :
caked duplicate vanilla-$1 $1
caked provision $1 --foreground --log-level=debug
