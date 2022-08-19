#!/bin/bash

#colors
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE="\\033[38;5;27m"
NC='\033[0m'

WRENCH="\xF0\x9F\x94\xA7"
BLUE_CIRCLE="\xF0\x9F\x94\xB5"

COIN_CLI='flux-cli'
BENCH_CLI='fluxbench-cli'
CONFIG_FILE='flux.conf'
BENCH_DIR_LOG='.fluxbenchmark'

#gets fluxbench version info
flux_bench_version=$(($BENCH_CLI getinfo) | jq -r '.version')

#gets fluxbench status
flux_bench_details=$($BENCH_CLI getstatus)
flux_bench_back=$(jq -r '.flux' <<<"$flux_bench_details")
flux_bench_flux_status=$(jq -r '.status' <<<"$flux_bench_details")
flux_bench_benchmark=$(jq -r '.benchmarking' <<<"$flux_bench_details")

#gets blockchain info
flux_daemon_details=$($COIN_CLI getinfo)
flux_daemon_version=$(jq -r '.version' <<<"$flux_daemon_details")
flux_daemon_protocol_version=$(jq -r '.protocolversion' <<<"$flux_daemon_details")
flux_daemon_block_height=$(jq -r '.blocks' <<<"$flux_daemon_details")
flux_daemon_connections=$(jq -r '.connections' <<<"$flux_daemon_details")
flux_daemon_difficulty=$(jq -r '.difficulty' <<<"$flux_daemon_details")
flux_daemon_error=$(jq -r '.error' <<<"$flux_daemon_details")

#gets flux node status
flux_node_details=$($COIN_CLI getzelnodestatus)
flux_node_status=$(jq -r '.status' <<<"$flux_node_details")
flux_node_collateral=$(jq -r '.collateral' <<<"$flux_node_details")
flux_node_added_height=$(jq -r '.added_height' <<<"$flux_node_details")
flux_node_confirmed_height=$(jq -r '.confirmed_height' <<<"$flux_node_details")
flux_node_last_confirmed_height=$(jq -r '.last_confirmed_height' <<<"$flux_node_details")
flux_node_last_paid_height=$(jq -r '.last_paid_height' <<<"$flux_node_details")

#calculated block height since last confirmed
blockDiff=$(($flux_daemon_block_height-$flux_node_last_confirmed_height))

function check_status() {
  if [[ $flux_bench_flux_status == "online" ]];
  then
    echo -e "Flux node status           -    ${GREEN}ONLINE${NC}"
  else
    echo -e "Flux node status           -    ${RED}OFFLINE${NC}"
  fi
}

function check_bench() {
  if [[ ($flux_bench_benchmark == "failed") || ($flux_bench_benchmark == "toaster") ]]; then
    echo -e "Flux node benchmark        -    ${RED}$flux_bench_status${NC}"
    read -p 'would you like to check for updates and restart benchmarks? (y/n) ' userInput
    if [ $userInput == 'n' ]; then
      echo 'user does not want to restart benchmarks'
    else
      echo 'user would like to restart benchmarks'
      flux_update_benchmarks
    fi
  elif [[ $flux_bench_benchmark == "running" ]]; then
    echo -e "${BLUE}node benchmarks running ... ${NC}"
  elif [[ $flux_bench_benchmark == "dos" ]]; then
    echo -e "${RED}node in denial of service state${NC}"
  else
    echo -e "Flux node benchmark        -    ${GREEN}$flux_bench_benchmark${NC}"
  fi
}

function check_back(){
  if [[ $flux_bench_back != *"connected"* ]];
  then
    echo -e "Flux back status           -    ${RED}DISCONNECTED${NC}"
    read -p 'would you like to check for updates and restart flux-back? (y/n) ' userInput
    if [ $userInput == 'n' ]; then
      echo -e "${RED}user does not want to restart flux back${NC}"
    else
      echo -e "${BLUE}user would like to update and restart flux-back${NC}"
      echo 'updating ... '
      flux_update_restart
    fi
  else
    echo -e "Flux back status           -    ${GREEN}CONNECTED${NC}"
  fi
}

function node_os_update(){
  sudo apt-get --with-new-pkgs upgrade -y && sudo apt autoremove -y
}

function flux_update_service(){
  node_os_update
  #sudo systemctl stop flux
  #sleep 2
  #sudo systemctl start flux
  #sleep 5
}

function flux_update_benchmarks(){
  node_os_update
  #$BENCH_CLI restartnodebenchmarks
}

function flux_daemon_info(){
  echo -e "${BLUE_CIRCLE}   Flux daemon version          -    $flux_daemon_version"
  echo -e "${BLUE_CIRCLE}   Flux protocol version        -    $flux_daemon_protocol_version"
  echo -e "${BLUE_CIRCLE}   Flux daemon block height     -    $flux_daemon_block_height"
  echo -e "${BLUE_CIRCLE}   Flux daemon connections      -    $flux_daemon_connections"
  echo -e "${BLUE_CIRCLE}   Flux deamon difficulty       -    $flux_daemon_difficulty"
}

function flux_node_info(){
  echo -e "${BLUE_CIRCLE}   Flux node status             -    $flux_node_status"
  echo -e "${BLUE_CIRCLE}   Flux node collateral         -    $flux_node_collateral"
  echo -e "${BLUE_CIRCLE}   Flux node added height       -    $flux_node_added_height"
  echo -e "${BLUE_CIRCLE}   Flux node confirmed height   -    $flux_node_confirmed_height"
  echo -e "${BLUE_CIRCLE}   Flux node last confirmed     -    $flux_node_last_confirmed_height"
  echo -e "${BLUE_CIRCLE}   Flux node last paid height   -    $flux_node_last_paid_height"
  echo -e "${BLUE_CIRCLE}   Blocks since last confirmed  -    $blockDiff"
}

flux_daemon_info
flux_node_info
check_status
check_back
check_bench