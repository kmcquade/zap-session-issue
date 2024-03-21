#!/usr/bin/env bash

set -x

start_docker_container() {
  rm -rf /tmp/session
  rm -f /tmp/nv_zap.session.zip
  rm -rf /tmp/session_unzipped
  docker run --platform linux/amd64/v8 --name zap-session-experiment -v /tmp/shared-volume:/home/zap/shared-volume:rw -p 8080:8080 -d softwaresecurityproject/zap-stable:2.14.0 /zap/zap-x.sh -daemon -port 8080 -host 0.0.0.0 -notel -silent -config api.incerrordetails=true -config database.recoverylog=false -config database.compact=false -config database.request.bodysize=4194304 -config database.response.bodysize=4194304 -config wappalyzer.enabled=false -config api.disablekey=true -config 'api.addrs.addr.name=.*' -config api.addrs.addr.regex=true
  # Give ZAP time to boot
  curl --retry 30 --retry-all-errors --retry-delay 1 --fail --insecure http://localhost:8080
}

kill_docker() {
  docker rm -fv zap-session-experiment
  rm -rf /tmp/shared-volume/
}

check_scan_status() {
  # Check if the spider has finished
  local scanId="$1"
  local url="http://localhost:8080/JSON/spider/view/status/?scanId=$scanId"
  while true; do
    response=$(curl -s "$url")
    if echo "$response" | grep -q '"status":"100"'; then
      echo "Scan $scanId completed."
      break
    else
      echo "Scan $scanId in progress..."
    fi
    sleep 1
  done
}

run_spider() {
  # Run the curl command and capture the JSON response
  response=$(curl -s 'http://localhost:8080/JSON/spider/action/scan/?url=https%3A%2F%2Fpublic-firing-range.appspot.com')
  # Use jq to parse the JSON response and extract the scanId
  scanId=$(echo "$response" | jq -r '.scan')
  # Wait for the spider to finish.
  check_scan_status $scanId
}

save_session() {
  curl http://localhost:8080/JSON/core/action/saveSession/\?name\=nv_zap\&overwrite\=true
  docker cp zap-session-experiment:/home/zap/.ZAP/session/ /tmp/session
}

zip_session() {
  # Zip up the session
  cd /tmp/session
  zip -vr ../nv_zap.session.zip ./ -x "*.DS_Store"
  ls -al /tmp/
}

open_session_in_zap_desktop() {
  echo "This assumes you are on a Mac (sorry, Windows/Linux users. If you are not on a  Mac, craft the command to open the session in ZAP Desktop)"
  unzip /tmp/nv_zap.session.zip -d /tmp/session_unzipped/
  /Applications/ZAP.app/Contents/MacOS/ZAP.sh -notel -silent -session /tmp/session_unzipped/nv_zap.session -config api.incerrordetails=true -config database.recoverylog=false -config database.compact=false -config database.request.bodysize=4194304 -config database.response.bodysize=4194304 -config wappalyzer.enabled=false -config api.disablekey=true -config 'api.addrs.addr.name=.*' -config api.addrs.addr.regex=true
}
