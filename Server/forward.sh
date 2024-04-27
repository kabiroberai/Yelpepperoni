#!/bin/bash -eu

ssh -o ControlPersist=yes -NTR 8080:localhost:8001 web
