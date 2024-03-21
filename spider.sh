#!/usr/bin/env bash
set -ex

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

start_docker_container
run_spider
save_session
zip_session
kill_docker
open_session_in_zap_desktop
