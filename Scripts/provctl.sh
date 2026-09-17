#!/bin/bash
set -e

cakectl delete $1 || :
cakectl duplicate vanilla-$1 $1
cakectl provision $1 --foreground
