#!/bin/bash
SCRIPTOUTPUT=$1

echo "$SCRIPTOUTPUT" | base64 -d > script.out