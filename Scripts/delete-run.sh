#!/bin/bash

gh api repos/Fred78290/caker/actions/runs --paginate --jq '.workflow_runs[].id' | while read -r id; do gh run delete "$id"; done
