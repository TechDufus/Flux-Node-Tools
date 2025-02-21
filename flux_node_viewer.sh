#!/bin/bash

#disable terminal history while inside of app
set +o history

#colors
YELLOW='\033[0;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE="\\033[38;5;27m"
SEA="\\033[38;5;49m"
NC='\033[0m'
TAB='  '

# add alias to bashrc so you can just call fluxnodeview from CLI
if [[ $(cat /etc/bash.bashrc | grep 'fluxnodeview' | wc -l) == "0" ]]; then
  echo "alias fluxnodeview='bash -i <(curl -s https://raw.githubusercontent.com/JKTUNING/Flux-Node-Tools/main/flux_node_viewer.sh)'" | sudo tee -a /etc/bash.bashrc
  source /etc/bash.bashrc
fi

clear
sleep 0.5

echo -e ""
echo -e "${SEA}starting flux node viewer ..."
echo -e ""
echo -e "${BLUE}checking required packages ... ${NC}"

if ! dpkg -s miniupnpc 2>/dev/null | grep "ok installed" >/dev/null 2>&1; then
  echo -e "UPNPC ${RED}not installed${NC} ... installing miniupnpc"
  sleep 2
  sudo apt install miniupnpc -y >/dev/null 2>&1
fi

if ! jq --version >/dev/null 2>&1; then
  echo -e "${RED}jq not found ... installing jq${NC}"
  sleep 2
  sudo apt install jq -y >/dev/null 2>&1

  if ! jq --version >/dev/null 2>&1; then
    echo "jq install was not successful - exiting"
    set -o history
    exit
  fi
fi

if ! lsof -v > /dev/null 2>&1; then
  echo -e "${RED}lsof not found ... installing lsof${NC}"
  sleep 2
  sudo apt-get install lsof -y >/dev/null 2>&1
fi

version='Flux Node Viewer 1.0.0'

WRENCH='\xF0\x9F\x94\xA7'
YELLOW_ARROW="${YELLOW}\xE2\x96\xB6${NC}  "
RED_ARROW="${RED}\xE2\x96\xB6${NC}  "
GREEN_ARROW="${GREEN}\xE2\x96\xB6${NC}  "
BLUE_CIRCLE="${SEA}\xE2\x96\xB6${NC}  "
BLUE_HEADER="${BLUE}\xE2\x96\xB6${NC}  "

_HLINE="\xE2\x94\x80"
_VLINE="\xE2\x94\x82"

DASH_BENCH_TITLE='FLUX BENCHMARK INFO'
DASH_BENCH_DETAILS_TITLE='FLUX BENCHMARK DETAILS'
DASH_BENCH_ERROR_TITLE='FLUX BENCH ERROR LOG'
DASH_BENCH_PORT_TITLE='FLUX BENCHMARK PORT'

DASH_NODE_TITLE='FLUX NODE INFO'
DASH_NODE_PORT_TITLE='FLUX NODE PORTS'
DASH_NODE_SERVICE_TITLE='FLUX NODE SERVICES'
DASH_NODE_FLUX_LOG_TITLE="FLUX OS ERROR LOG"

DASH_DAEMON_TITLE='FLUX DAEMON INFO'
DASH_DAEMON_PORT_TITLE='FLUX DAEMON PORT'
DASH_DAEMON_ERROR_TITLE='FLUX DAEMON ERROR LOG'

DASH_COMMANDS_TITLE='APPLICATION COMMANDS'

WINDOW_WIDTH=$(tput cols)
WINDOW_HALF_WIDTH=$(bc <<<"$WINDOW_WIDTH / 2")

COIN_CLI='flux-cli'
BENCH_CLI='fluxbench-cli'
CONFIG_FILE='flux.conf'
BENCH_DIR_LOG='.fluxbenchmark'
FLUX_DIR='zelflux'

PORT_CHECK_URL='https://ports.yougetsignal.com/check-port.php'

# RE-ENABLE FOR PRODUCTION VERSION TO CHECK FOR CLI TOOLS!!
# if ! [ -f /usr/local/bin/flux-cli ]; then
#   echo -e "${RED}flux-cli tool not installed${NC}"
#   echo -e "${RED}application will exit in 5 seconds ...${NC}"
#   sleep 5
#   exit
# fi

# if ! [ -f /usr/local/bin/fluxbench-cli ]; then
#   echo -e "${RED}fluxbench-cli tool not installed${NC}"
#   echo -e "${RED}application will exit in 5 seconds ...${NC}"
#   sleep 5
#   exit
# fi

BENCH_LOG_FILE_DIR="/home/$USER/$BENCH_DIR_LOG/debug.log"
DAEMON_LOG_DIR="/home/$USER/.flux/debug.log"
WATCHDOG_LOG_DIR="home/$USER/watchdog/watchdog_error.log"
FLUX_LOG_DIR="/home/$USER/$FLUX_DIR/debug.log"

docker_service_status=""
mongodb_service_status=""
daemon_service_status=""
flux_process_status=""
watchdog_process_status=""
flux_node_dos=""

#variables to draw windows
show_bench='0'
show_daemon='0'
show_node='0'
show_commands='0'
show_flux_node_details='0'
show_external_port_details='0'
show_node_kda_details='0'
show_node_fix_details='0'
last_user_input=''
checking_ports='0'

# get a list of the LISTEN ports
# listen_ports=$(sudo lsof -i -n | grep LISTEN)
flux_api_port=""
flux_ui_port=""
mongodb_port=""
flux_bench_port=""
flux_daemon_port=""
flux_ip_check=""
flux_node_version_check=""

#initialize flux node variables to avoid null
flux_node_status=""
flux_node_collateral=""
flux_node_added_height=""
flux_node_confirmed_height=""
flux_node_last_confirmed_height=""
flux_node_last_paid_height=""

#get local device name
local_device=$(ip addr | grep 'BROADCAST,MULTICAST,UP,LOWER_UP' | awk 'NR==1 {print $2}')
#get node version on device
flux_node_version=$(jq -r '.version' /home/$USER/$FLUX_DIR/package.json 2>/dev/null)

#log variables
daemon_log=""
bench_log=""
flux_log=""

# variable to see if the terminal size has changed
redraw_term='1'

#Function to collect all benchmark information for display
function get_flux_bench_info(){
  #gets fluxbench version info
  flux_bench_version=$(($BENCH_CLI getinfo) 2>/dev/null | jq -r '.version' 2>/dev/null)

  #gets fluxbench info
  flux_bench_details=$($BENCH_CLI getstatus 2>/dev/null)
  flux_bench_back=$(jq -r '.flux' <<<"$flux_bench_details" 2>/dev/null)
  flux_bench_flux_status=$(jq -r '.status' <<<"$flux_bench_details" 2>/dev/null)
  flux_bench_benchmark=$(jq -r '.benchmarking' <<<"$flux_bench_details" 2>/dev/null)

  #gets flux node benchmark info
  flux_bench_stats=$($BENCH_CLI getbenchmarks 2>/dev/null)
  flux_bench_stats_real_cores=$(jq -r '.real_cores' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_cores=$(jq -r '.cores' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_ram=$(jq -r '.ram' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_ssd=$(jq -r '.ssd' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_hhd=$(jq -r '.hdd' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_ddwrite=$(jq -r '.ddwrite' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_storage=$(jq -r '.totalstorage' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_eps=$(jq -r '.eps' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_ping=$(jq -r '.ping' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_download=$(jq -r '.download_speed' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_upload=$(jq -r '.upload_speed' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_speed_test_version=$(jq -r '.speed_version' <<<"$flux_bench_stats" 2>/dev/null)
  flux_bench_stats_error=$(jq -r '.error' <<<"$flux_bench_stats" 2>/dev/null)
}

## Function to collect flux block chain daemon data
function get_flux_blockchain_info(){
  #gets blockchain info
  flux_daemon_details=$($COIN_CLI getinfo 2>/dev/null)
  flux_daemon_version=$(jq -r '.version' <<<"$flux_daemon_details" 2>/dev/null)
  flux_daemon_protocol_version=$(jq -r '.protocolversion' <<<"$flux_daemon_details" 2>/dev/null)
  flux_daemon_block_height=$(jq -r '.blocks' <<<"$flux_daemon_details" 2>/dev/null)
  flux_daemon_connections=$(jq -r '.connections' <<<"$flux_daemon_details" 2>/dev/null)
  flux_daemon_difficulty=$(jq -r '.difficulty' <<<"$flux_daemon_details" 2>/dev/null)
  flux_daemon_error=$(jq -r '.error' <<<"$flux_daemon_details" 2>/dev/null)
}

## Function to get flux node data
function get_flux_node_info(){
  #gets flux node info
  flux_node_details=$($COIN_CLI getzelnodestatus 2>/dev/null)
  flux_node_status=$(jq -r '.status' <<<"$flux_node_details" 2>/dev/null)
  flux_node_collateral=$(jq -r '.collateral' <<<"$flux_node_details" 2>/dev/null)
  flux_node_added_height=$(jq -r '.added_height' <<<"$flux_node_details" 2>/dev/null)
  flux_node_confirmed_height=$(jq -r '.confirmed_height' <<<"$flux_node_details" 2>/dev/null)
  flux_node_last_confirmed_height=$(jq -r '.last_confirmed_height' <<<"$flux_node_details" 2>/dev/null)
  flux_node_last_paid_height=$(jq -r '.last_paid_height' <<<"$flux_node_details" 2>/dev/null)
}

#calculated block height since last confirmed
function get_blocks_since_last_confirmed(){
  ## require daemon block height to must get blockchain info
  get_flux_blockchain_info
  if [[ ! -z $flux_node_last_confirmed_height && $flux_node_last_confirmed_height != "null" ]] ; then
    blockDiff=$((flux_daemon_block_height-flux_node_last_confirmed_height))
    maint_window=$(((120-(flux_daemon_block_height-flux_node_last_confirmed_height))*2))
  else
    maint_window='0'
  fi
}

function update (){
  local userInput
  local noInput

  read -s -n 1 -t 1 userInput
  if [[ -z $userInput ]]; then
    noInput=1
    userInput="$last_user_input"
  else
    last_user_input=$userInput
  fi
  #'b' shows benchmark screen and the last 5 lines of bench mark error log
  #'d' shows daemon screen and the last 5 lines of daemon error log
  #'n' shows node screen
  #'u' shows ubuntu operating system update screen
  #'c' shows available commands
  #'t' shows flux network node details
  #'p' shows external flux ports
  #'k' shows node kda details (address)
  #'f' shows fucntions to manage node services
  #'l' shows Mowat's tmux log view pane
  #'q' will quit
  show_node='0'
  show_daemon='0'
  show_bench='0'
  show_commands='0'
  show_flux_node_details='0'
  show_external_port_details='0'
  show_node_kda_details='0'
  show_node_fix_details='0'
  redraw_term='0'

  if [[ $noInput != 1 ]]; then
    valid_input=('b' 'n' 'd' 'u' 'c' 't' 'p' 'k')
    for i in "${valid_input[@]}"; do
      if [[ $userInput == $i ]]; then
        redraw_term='1'
        sleep 0.1
      fi
    done
  fi

  if [[ $userInput == 'b' ]]; then
    check_benchmark_log
    show_bench='1'
  elif [[ $userInput == 'n' ]]; then
    show_node='1'
  elif [[ $userInput == 'd' ]]; then
    check_daemon_log
    show_daemon='1'
  elif [[ $userInput == 'u' ]]; then
    node_os_update
  elif [[ $userInput == 'c' ]]; then
    show_commands='1'
  elif [[ $userInput == 't' ]]; then
    show_flux_node_details='1'
  elif [[ $userInput == 'p' ]]; then
    show_external_port_details='1'
  elif [[ $userInput == 'k' ]]; then
    show_node_kda_details='1'
  elif [[ $userInput == 'f' ]]; then
    clear
    get_flux_bench_info
    if [[ $checking_ports != '1' ]]; then
      sleep 0.25
      check_bench
      sleep 0.1
      check_back
      sleep 0.1
      show_node_fix_tile
    fi
    sleep 0.1
  elif [[ $userInput == 'q' ]]; then
    clear
    set -o history
    exit
  elif [[ $userInput == 'l' ]]; then
    whiptail --title "Mowat's Node Log Viewer" --msgbox "Please use ctrl+c to exit log view mode" 8 50;
    # Mowats script to run tmux to view flux logs
    bash -i <(curl -s https://gist.githubusercontent.com/mattconres/670ffd527cb0e83b754ff39b2d37ce3a/raw/f9ef92147c4c3ce397c847494a0869c3ea379498/flux-log-tmux.sh)
  else
    redraw_term='0'
  fi
}

function show_flux_daemon_info_tile(){
  clear
  echo -e "${GREEN}checking current blockchain height from explorer ... ${NC}"
  check_current_blockheight
  clear
  sleep 0.25
  make_header "$DASH_DAEMON_TITLE" "$BLUE"
  echo -e "$BLUE_CIRCLE   Flux daemon version          -    $flux_daemon_version"
  echo -e "$BLUE_CIRCLE   Flux protocol version        -    $flux_daemon_protocol_version"
  echo -e "$BLUE_CIRCLE   Flux daemon block height     -    $flux_daemon_block_height"
  echo -e "$daemon_sync_status"
  echo -e "$BLUE_CIRCLE   Flux daemon connections      -    $flux_daemon_connections"
  echo -e "$BLUE_CIRCLE   Flux deamon difficulty       -    $flux_daemon_difficulty"
  make_header "$DASH_DAEMON_PORT_TITLE" "$BLUE"
  echo -e "$flux_daemon_port"
  echo -e "$daemon_service_status"

  if [[ $daemon_log != "" ]]; then
    make_header "$DASH_DAEMON_ERROR_TITLE" "$RED"
    echo -e "$daemon_log"
  fi
  navigation
}

function show_flux_node_info_tile(){
  clear
  sleep 0.25
  # check dhcp first
  check_dhcp_enable 
  echo -e "${GREEN}   Checking external flux ports ...${NC}"
  check_external_ports
  echo -e "${GREEN}   Checking UPNP details ...${NC}"
  check_upnp
  echo -e "${GREEN}   Checking node uptime ...${NC}"
  get_flux_uptime
  clear
  sleep 0.25
  make_header "$DASH_NODE_TITLE" "$BLUE"
  echo -e "$BLUE_CIRCLE   Flux node status             -    $flux_node_status"
  if [[ "$flux_node_status" == "DOS" ]]; then
    check_flux_dos_list
    echo -e "$flux_node_dos"
  fi
  echo -e "$BLUE_CIRCLE   Flux node added height       -    $flux_node_added_height"
  echo -e "$BLUE_CIRCLE   Flux node confirmed height   -    $flux_node_confirmed_height"
  echo -e "$BLUE_CIRCLE   Flux node last confirmed     -    $flux_node_last_confirmed_height"
  echo -e "$BLUE_CIRCLE   Flux node last paid height   -    $flux_node_last_paid_height"
  echo -e "$BLUE_CIRCLE   Blocks since last confirmed  -    $blockDiff"
  echo -e "$BLUE_CIRCLE   Node Maintenance Window      -    $maint_window mins"
  echo -e "$BLUE_CIRCLE   Node Uptime                  -    $flux_uptime"
  echo -e "$flux_node_version_check"
  make_header "$DASH_NODE_PORT_TITLE" "$BLUE"
  echo -e "$flux_ip_check"
  if [[ $dhcp_status != "" ]]; then
    echo -e "${YELLOW_ARROW}   $dhcp_status${NC}"
  fi
  echo -e "$flux_api_port"
  echo -e "$flux_ui_port"
  echo -e "$mongodb_port"
  make_header "FLUX NODE EXTERNAL PORT DETAILS" "$BLUE"
  echo -e "$external_flux_ui_port"
  echo -e "$external_flux_api_port"
  make_header "FLUX UPNP DETAILS" "$BLUE"
  echo -e "$upnp_status"
  make_header "$DASH_NODE_SERVICE_TITLE" "$BLUE"
  echo -e "$flux_process_status"
  echo -e "$mongodb_service_status"
  echo -e "$docker_service_status"
  echo -e "$watchdog_process_status"

  if [[ $flux_log != "" ]]; then
    make_header "$DASH_NODE_FLUX_LOG_TITLE" "$RED"
    echo -e "$flux_log"
  fi

  navigation
}

function show_flux_benchmark_info_tile(){
  clear
  sleep 0.25
  make_header "$DASH_BENCH_TITLE" "$BLUE"
  echo -e "$BLUE_CIRCLE   Flux bench version           -    $flux_bench_version"
  echo -e "$BLUE_CIRCLE   Flux back status             -    $flux_bench_back"
  echo -e "$BLUE_CIRCLE   Flux bench status            -    $flux_bench_flux_status"
  echo -e "$BLUE_CIRCLE   Flux benchmarks              -    $flux_bench_benchmark"
  make_header "$DASH_BENCH_DETAILS_TITLE" "$BLUE"
  echo -e "$BLUE_CIRCLE   Bench Real Cores             -    $flux_bench_stats_real_cores"
  echo -e "$BLUE_CIRCLE   Bench Cores                  -    $flux_bench_stats_cores"
  echo -e "$BLUE_CIRCLE   Bench Ram                    -    $flux_bench_stats_ram"
  echo -e "$BLUE_CIRCLE   Bench SSD                    -    $flux_bench_stats_ssd"
  echo -e "$BLUE_CIRCLE   Bench HHD                    -    $flux_bench_stats_hhd"
  echo -e "$BLUE_CIRCLE   Bench ddWrite                -    $flux_bench_stats_ddwrite"
  echo -e "$BLUE_CIRCLE   Bench Total Storage          -    $flux_bench_stats_storage"
  echo -e "$BLUE_CIRCLE   Bench EPS                    -    $flux_bench_stats_eps"
  echo -e "$BLUE_CIRCLE   Bench Ping                   -    $flux_bench_stats_ping"
  echo -e "$BLUE_CIRCLE   Bench Download Speed         -    $flux_bench_stats_download"
  echo -e "$BLUE_CIRCLE   Bench Upload Speed           -    $flux_bench_stats_upload"
  echo -e "$BLUE_CIRCLE   Bench Speed Test Version     -    $flux_bench_stats_speed_test_version"
  echo -e "$BLUE_CIRCLE   Bench Errors                 -    $flux_bench_stats_error"
  make_header "$DASH_BENCH_PORT_TITLE" "$BLUE"
  echo -e "$flux_bench_port"

  if [[ $bench_log != "" ]]; then
    make_header "$DASH_BENCH_ERROR_TITLE" "$RED"
    echo -e "$bench_log"
  fi
 
  navigation
}

#show available commands for the application
function show_available_commands_tile(){
  clear
  sleep 0.25
  make_header "$DASH_COMMANDS_TITLE" "$BLUE"
  echo -e "$BLUE_CIRCLE   'd'            -    Show Flux Daemon Info"
  echo -e "$BLUE_CIRCLE   'n'            -    Show Flux Node Info"
  echo -e "$BLUE_CIRCLE   'b'            -    Show Flux Node Benchmark Info"
  echo -e "$BLUE_CIRCLE   'u'            -    Update Ubuntu Operating System"
  echo -e "$BLUE_CIRCLE   't'            -    Show Flux Network Node Details"
  echo -e "$BLUE_CIRCLE   'p'            -    Check External Flux Ports"
  echo -e "$BLUE_CIRCLE   'k'            -    Check Kadena Address"
  echo -e "$BLUE_CIRCLE   'f'            -    Flux Node Control"
  echo -e "$BLUE_CIRCLE   'l'            -    Flux Log Viewer"
  echo -e "$BLUE_CIRCLE   'c'            -    Show Available Application Commands"
  echo -e "$BLUE_CIRCLE   'q'            -    Quit Application"
  make_title
  navigation
}


# show the flux network node details
function show_network_node_details_tile(){
  clear
  sleep 0.25
  echo -e "${GREEN}   Checking flux network node details ...${NC}"
  check_total_nodes
  echo -e "${GREEN}   Checking flux price details ...${NC}"
  check_flux_price
  clear
  sleep 0.25
  make_header "FLUX NETWORK NODE DETAILS" "$BLUE"
  echo -e "$BLUE_CIRCLE   Total nodes                  -    $total_nodes"
  echo -e "$BLUE_CIRCLE   Cumulus nodes                -    $cumulus_nodes"
  echo -e "$BLUE_CIRCLE   Nimbus nodes                 -    $nimbus_nodes"
  echo -e "$BLUE_CIRCLE   Stratus nodes                -    $stratus_nodes"
  
  echo -e "$BLUE_CIRCLE   Flux Price                   -    $flux_price"
  navigation
}

#show external port info
function show_external_port_info_tile(){
  clear
  sleep 0.25
  echo -e "${GREEN}   Checking external flux ports ...${NC}"
  check_external_ports
  echo -e "${GREEN}   Checking UPNP details ...${NC}"
  check_upnp
  clear
  sleep 0.25
  make_header "FLUX NODE EXTERNAL PORT DETAILS" "$BLUE"
  echo -e "$external_flux_ui_port"
  echo -e "$external_flux_api_port"
  make_header "FLUX UPNP DETAILS" "$BLUE"
  echo -e "$upnp_status"
  navigation
  checking_ports='0'
}

#show node kda address info
function show_node_kda_tile(){
  clear
  sleep 0.25
  echo -e "${GREEN}   checking node kda details ...${NC}"
  check_kda_address
  clear
  sleep 0.25
  make_header "FLUX NODE KDA DETAILS" "$BLUE"
  echo -e "$BLUE_CIRCLE   NODE KDA ADDRESS                -    $node_kda_address"
  echo -e "$BLUE_CIRCLE   USER KDA ADDRESS                -    $user_kda_address"
  navigation
}

# check to see if docker service is running
function check_docker_service(){
  if systemctl --type=service --state=running --quiet 2>/dev/null |grep docker >/dev/null 2>&1; then
    docker_service_status="${GREEN_ARROW}   Docker Service is ${GREEN}running${NC}"
  elif systemctl --type=service --state=failed --quiet 2>/dev/null |grep docker >/dev/null 2>&1; then
    docker_service_status="${RED_ARROW}   Docker Service is ${RED}inactive${NC}"
  else
    docker_service_status="${RED_ARROW}   Docker Service is ${RED}not installed${NC}"
  fi
}

#check to see if mongoDB service is running
function check_mongodb_service(){
  if systemctl --type=service --state=running --quiet 2>/dev/null |grep mongod >/dev/null 2>&1; then
    mongodb_service_status="${GREEN_ARROW}   MongoDB Service is ${GREEN}running${NC}"
  elif systemctl --type=service --state=failed --quiet 2>/dev/null |grep mongod >/dev/null 2>&1; then
    mongodb_service_status="${RED_ARROW}   MongoDB Service is ${RED}inactive${NC}"
  else
    mongodb_service_status="${RED_ARROW}   MongoDB Service is ${RED}not installed${NC}"
  fi
}

#check to ese if Daemon Service is running
function check_daemon_service(){
  if systemctl --type=service --state=running --quiet 2>/dev/null |grep zelcash >/dev/null 2>&1; then
    daemon_service_status="${GREEN_ARROW}   Flux Daemon Service is ${GREEN}running${NC}"
  elif systemctl --type=service --state=failed --quiet 2>/dev/null |grep zelcash >/dev/null 2>&1; then
    daemon_service_status="${RED_ARROW}   Flux Daemon Service is ${RED}inactive${NC}"
  else
    daemon_service_status="${RED_ARROW}   Flux Daemon Service is ${RED}not installed${NC}"
  fi
}

#check if pm2 flux process is running
function check_pm2_flux_service(){
  local pm2_status_check=$(pm2 info flux 2>/dev/null | grep 'status')

  if [[ $pm2_status_check == *"online"* ]]; then
    flux_process_status="${GREEN_ARROW}   Flux PM2 process is ${GREEN}running${NC}"
  elif [[ $pm2_status_check == *"offline"* ]]; then
    flux_process_status="${RED_ARROW}   Flux PM2 process is ${RED}offline${NC}"
  else
    flux_process_status="${RED_ARROW}   Flux PM2 process ${RED}not found${NC}"
  fi
}

#check pm2 watchdog process is running
function check_pm2_flux_watchdog_service(){
  local pm2_watchdog_status_check=$(pm2 info watchdog 2>/dev/null | grep 'status')

  if [[ $pm2_watchdog_status_check == *"online"* ]]; then
    watchdog_process_status="${GREEN_ARROW}   Watchdog PM2 process is ${GREEN}running${NC}"
  elif [[ $pm2_watchdog_status_check == *"offline"* ]]; then
    watchdog_process_status="${RED_ARROW}   Watchdog PM2 process is ${RED}offline${NC}"
  else
    watchdog_process_status="${RED_ARROW}   Watchdog PM2 process ${RED}not found${NC}"
  fi

}

#checks last 100 lines of daemon log file for errors or failed entries
function check_daemon_log(){
  if [[ -f $DAEMON_LOG_DIR ]]; then
    daemon_log=$(tail -100 $DAEMON_LOG_DIR | egrep -a -wi 'error|failed')
    if [[ $daemon_log == "" ]]; then
      daemon_log="${GREEN_ARROW}   No Daemon Errors logged"
    fi
  else
    daemon_log="${GREEN_ARROW}   No Daemon Errors logged"
  fi
}

function check_benchmark_log(){
  if [[ -f $BENCH_LOG_FILE_DIR ]]; then
    bench_log=$(tail -100 $BENCH_LOG_FILE_DIR | egrep -a -wi 'failed')
    if [[ $bench_log == "" ]]; then
      bench_log="${GREEN_ARROW}   No failed benchmark errors logged"
    fi
  else
    bench_log="${GREEN_ARROW}   No failed benchmark errors logged"
  fi
}

#check Flux Error file
function check_flux_log(){
  if [[ -f $FLUX_LOG_DIR ]]; then
    flux_log=$(tail -100 $FLUX_LOG_DIR | egrep -a -wi "Unable to detect Flux IP|Daemon not yet|Flux geolocation service is awaiting|Connection timed out while searching for the gateway|Node hardware requirements not met")
    if [[ $flux_log == "" ]]; then
      flux_log="${GREEN_ARROW}   No common flux errors logged"
    fi
  else
    flux_log="${GREEN_ARROW}   No flux errors logged"
  fi
}

#check node external IP address and compare it to device IP address
function check_ip(){
  WANIP=$(curl --silent -m 15 https://api.ipify.org | tr -dc '[:alnum:].')
  if [[ "$WANIP" == "" ]]; then
    WANIP=$(curl --silent -m 15 https://ipv4bot.whatismyipaddress.com | tr -dc '[:alnum:].')
  else
  WANIP=$(curl --silent -m 15 https://checkip.amazonaws.com | tr -dc '[:alnum:].')
  fi

  local_device_ip=$(ip a list $local_device | grep -o $WANIP)

  if [[ "$WANIP" == "$local_device_ip" ]]; then
    flux_ip_check="${GREEN_ARROW}   Public IP ${GREEN}matches${NC} device IP"
  else
    flux_ip_check="${RED_ARROW}   Public IP ${RED}does NOT match${NC} device IP"
  fi
}

#this function checks for listen ports using lsof
function check_port_info()
{
  listen_ports=$(sudo lsof -i -n | grep LISTEN)
  
  if [[ $listen_ports == *'27017'* && $listen_ports == *'mongod'* ]]; then
    mongodb_port="${GREEN_ARROW}   MongoDB is listening on port ${GREEN}27017${NC}"
  else
    mongodb_port="${RED_ARROW}   MongoDB is ${RED}not listening${NC}"
  fi

  if [[ $listen_ports == *'16125'* && $listen_ports == *'fluxd'* ]]; then
    flux_daemon_port="${GREEN_ARROW}   Flux Daemon is listening on port ${GREEN}16125${NC}"
  else
    flux_daemon_port="${RED_ARROW}   Flux Daemon is ${RED}not listening${NC}"
  fi

   if [[ $listen_ports == *'16224'* && $listen_ports == *'bench'* ]]; then
    flux_bench_port="${GREEN_ARROW}   Flux Bench is listening on port ${GREEN}16224${NC}"
  else
    flux_bench_port="${RED_ARROW}   Flux Bench is ${RED}not listening${NC}"
  fi

  #use awk to parse lsof results - find any entry with "node" in the first column and print the port info column $9 - then check to see if that result has a * before the field seperator ":" - return the first row then the second row results
  api_port=$(awk -v var="${listen_ports}" 'BEGIN {print var}' | awk ' { if ($1 == "node") {print $9} }' | awk -F ":" '{ if ($1 == "*") {print $2} }' | awk 'NR==1 {print $1}')
  ui_port=$(awk -v var="${listen_ports}" 'BEGIN {print var}' | awk ' { if ($1 == "node") {print $9} }' | awk -F ":" '{ if ($1 == "*") {print $2} }' | awk 'NR==2 {print $1}')

  if [[ $api_port != "" ]]; then
    flux_api_port="${GREEN_ARROW}   Flux API Listening on ${GREEN}$api_port${NC}"
  else
    flux_api_port="${RED_ARROW}   Flux API is ${RED}not listening${NC}"
  fi

  if [[ $ui_port != "" ]]; then
    flux_ui_port="${GREEN_ARROW}   Flux UI Listening on ${GREEN}$ui_port${NC}"
  else
    flux_ui_port="${RED_ARROW}   Flux UI is ${RED}not listening${NC}"
  fi
}

# function to check flux ports are open to external world
# Only checks Flux UI port and Flux API Port at this time
function check_external_ports(){
  checkPort=$(curl --silent --max-time 8 --data "remoteAddress=$WANIP&portNumber=$ui_port" $PORT_CHECK_URL | grep 'open on')
  if [[ -z $checkPort ]]; then
    external_flux_ui_port="${RED_ARROW}   Flux UI Port $ui_port is ${RED}closed${NC} - please check your network settings"
  else
    external_flux_ui_port="${GREEN_ARROW}   Flux UI Port $ui_port is ${GREEN}open${NC}"
  fi

  checkPort=$(curl --silent --max-time 8 --data "remoteAddress=$WANIP&portNumber=$api_port" $PORT_CHECK_URL | grep 'open on')
   if [[ -z $checkPort ]]; then
    external_flux_api_port="${RED_ARROW}   Flux API Port $api_port is ${RED}closed${NC} - please check your network settings"
    
  else
    external_flux_api_port="${GREEN_ARROW}   Flux API Port $api_port is ${GREEN}open${NC}"
  fi
}

#check to see if upnp is enabled and ports routed for LANIP
#requires installation of miniupnpc 
function check_upnp(){
  LANIP=$(hostname -I | awk '{print $1}')
  upnp_check=""
  upnp_check=$(upnpc -l 2>/dev/null | grep $LANIP)

  if [[ $ui_port != "" && $api_port != "" ]]; then
    if [[ $upnp_check == *$ui_port* && $upnp_check == *$api_port* && $upnp_check != "" ]]; then
      upnp_status="${GREEN_ARROW}   UPNP ${GREEN}enabled${NC} and registered for Flux UI $ui_port and Flux API $api_port ports"
    else
      upnp_status="${RED_ARROW}   UPNP ${RED}disabled${NC} on UI port $ui_port and API port $api_port"
    fi
  else
      upnp_status="${RED_ARROW}   UPNP ${RED}disabled${NC} - UI port and API port not listening"
  fi
}

function check_version(){
  ## grab current version requirements from the flux api and compare to current node version
  #flux_required_version=$(curl -sS --max-time 5 https://api.runonflux.io/flux/version | jq -r '.data')
  flux_required_version=$(curl -sS --max-time 5 https://raw.githubusercontent.com/RunOnFlux/flux/master/package.json | jq -r '.version')
  if [[ "$flux_required_version" == "$flux_node_version" ]]; then
    flux_node_version_check="${GREEN_ARROW}   You have the required version ${GREEN}$flux_node_version${NC}"
  else
    flux_node_version_check="${RED_ARROW}   You do not have the required version ${GREEN}$flux_required_version${NC} - your current version is ${RED}$flux_node_version${NC}"
  fi
}

# grab current node counts from https://api.runonflux.io/daemon/getzelnodecount
function check_total_nodes(){
  local nodeInfo=$(curl -sS --max-time 5 https://api.runonflux.io/daemon/getzelnodecount | jq -r '.data')
  total_nodes=$(jq -r '.total' <<<"$nodeInfo" 2>/dev/null)
  cumulus_nodes=$(jq -r '."cumulus-enabled"' <<<"$nodeInfo" 2>/dev/null)
  nimbus_nodes=$(jq -r '."nimbus-enabled"' <<<"$nodeInfo" 2>/dev/null)
  stratus_nodes=$(jq -r '."stratus-enabled"' <<<"$nodeInfo" 2>/dev/null)
}

# check current flux price
function check_flux_price(){
  local currencyInfo=$(curl -sS --max-time 5 https://explorer.runonflux.io/api/currency | jq -r '.data' | jq -r '.rate')
  flux_price=$(printf "%.3f" $currencyInfo)
}

# check flux DoS List
function check_flux_dos_list(){
  get_flux_node_info
  local dosList=$(curl -sS --max-time 5 https://api.runonflux.io/daemon/getdoslist | jq .[] | grep "$flux_node_collateral" -A5 -B1)

  #if node collateral in the DoS list then show number of blocks left
  if [[ "$dosList" != "" ]]; then
    local dosTime=$(jq -r '."eligible_in"' <<<"$dosList" 2>/dev/null)
    flux_node_dos="${RED_ARROW}   Node in DoS for ${RED}$dosTime${NC} blocks${NC}"
  fi
}

# grab current kda address from user config file in zelflux directory
#check node_kda_address on the node api side
#check user_kda_address in the user config file
function check_kda_address(){
  LANIP=$(hostname -I | awk '{print $1}')
  node_kda_address=$(curl -sS --max-time 5 http://$LANIP:$api_port/flux/kadena 2>/dev/null | jq -r '.data' 2>/dev/null)
  user_kda_address=$(grep -w kadena ~/$FLUX_DIR/config/userconfig.js 2>/dev/null | awk -F"'" '/1/ {print $2}' 2>/dev/null)

  while true; do
    if [[ "$node_kda_address" == "" || "$user_kda_address" == "" ]]; then
      if whiptail --title "KDA ADDRESS" --yesno "Node KDA Address Not Found - would you like to update it?" 8 60; then
        kda_input=$(whiptail --inputbox "Enter your kadena address (chain 0)" 8 60 3>&1 1>&2 2>&3)

        if whiptail --title "Verify Address" --yesno "Is the Kadena address entered correct? \n$kda_input" 8 60; then
          kda_address="kadena:$kda_input?chainid=0"

          #make sure the file exist first before trying to update or add kda address
          if [[ -f /home/$USER/zelflux/config/userconfig.js ]]; then
            if [[ $(cat /home/$USER/zelflux/config/userconfig.js | grep "kadena") != "" ]]; then
              #make a backup copy of the userconfig.js file
              sudo cp /home/$USER/zelflux/config/userconfig.js /home/$USER/zelflux/config/userconfig_backup.js
              #sed -i "s/$(grep -e kadena /home/$USER/zelflux/config/userconfig.js)/    kadena: '$kda_address',/" /home/$USER/zelflux/config/userconfig.js
              if [[ $(grep -w $KDA_A /home/$USER/zelflux/config/userconfig.js) != "" ]]; then
                whiptail --title "Update KDA Address" --msgbox "KDA Address Updated successfully" 8 60;
                user_kda_address=kda_address
              fi
            else
              #make a backup copy of the userconfig.js file
              sudo cp /home/$USER/zelflux/config/userconfig.js /home/$USER/zelflux/config/userconfig_backup.js
              #sudo sed -i -e "/zelid/a"$'\\\n'"    kadena: '$kda_address',"$'\n' "/home/$USER/zelflux/config/userconfig_backup.js"
              whiptail --title "Add KDA Address" --msgbox "KDA Address Added successfully" 8 60;
              user_kda_address=kda_address
            fi
          else
            whiptail --title "CONFIG NOT FOUND" --msgbox "userconfig.js file not found - KDA Address not updated" 8 60;
          fi
          break
        fi
      else
        break
      fi
    else
      break
    fi
  done

  if [[ "$node_kda_address" == "" ]]; then
    node_kda_address="node kda address ${RED}not found${NC}"
  fi

  if [[ "$user_kda_address" == "" ]]; then
    user_kda_address="user kda address ${RED}not found${NC} in zelflux config"
  fi

}

#This function simply draws a title header if arguments are provided and a footer if no arguments are provided
#If text is provided it will be centered and if a second color argument is provided it will have that color
function make_header(){
  local output
  local inputLength
  local halfInputLength
  local HEADER_TEXT_START
  local HEADER_TEXT_STOP
  output=""
  if [[ -z $1 ]]; then
    for (( c=1; c<=$WINDOW_WIDTH; c++ ))
    do 
      output="${output}${_HLINE}"
    done
  else
    #output="${_HLINE}${_HLINE}${_HLINE}${_HLINE}${_HLINE}${_HLINE}$2$1${NC}${_HLINE}${_HLINE}${_HLINE}${_HLINE}${_HLINE}${_HLINE}"
    #output="----$2$1${NC}----"
    output="${WRENCH}      $2$1${NC}"
    # inputLength=${#1}
    # halfInputLength=$(bc <<<"$inputLength / 2")
    # HEADER_TEXT_START=$((WINDOW_HALF_WIDTH-halfInputLength))
    # HEADER_TEXT_STOP=$((HEADER_TEXT_START+inputLength))
    # for (( c=1; c<=$WINDOW_WIDTH; c++ ))
    # do 
    #   if [[ $c -lt $HEADER_TEXT_START || $c -gt $HEADER_TEXT_STOP ]]; then
    #     output="${output}${NC}${_HLINE}"
    #   else
    #     offset=$((c-HEADER_TEXT_START))
    #     output="${output}${2}${1:offset:1}"
    #   fi
    # done
  fi

  echo -e ${output}
}

#this function simply prints tile navigation at the bottom of the current tile
function navigation(){
  make_header
  echo -e "d - daemon | b - benchmarks | n - node | p - ports | q - quit | c - commands" 
}

#this function simply prints the version at the top of the page
function make_title(){
  make_header "$version" "$BLUE"
}

#checks the current window size and compares it to the last windows size to see if we need to redraw the term
function check_term_resize(){
  local currentWidth
  currentWidth=$(tput cols)
  if [[ $WINDOW_WIDTH -ne $currentWidth  ]]; then
    redraw_term='1'
  fi
}

# checks to see if the benchmarks pass and asks to restart the benchmarks
function check_bench() {
  if [[ ($flux_bench_benchmark == "failed") || ($flux_bench_benchmark == "toaster") || ($flux_bench_benchmark == "") ]]; then
    if [[ $flux_bench_stats_error == *"FluxOS is not working properly"* ]]; then
      if whiptail --title "Benchmarks Failed - $flux_bench_benchmark" --yesno "Flux OS is not working properly - would you like to check external ports?" 8 60; then
        echo -e "${GREEN}checking external flux ports ... ${NC}"
        checking_ports='1'
        show_external_port_info_tile
      fi
    elif [[ $flux_bench_stats_error == *"Failed: HW requirements not sufficient"* ]]; then
      whiptail --title "Benchmarks Failed - $flux_bench_benchmark" --msgbox "$flux_bench_stats_error" 8 60;
    else
      if whiptail --title "Benchmarks Failed - $flux_bench_benchmark" --yesno "Would you like to restart your node benchmarks?" 8 60; then
        flux_update_benchmarks
      else
        whiptail --msgbox "User would not like to restart benchmarks" 8 60;
      fi
    fi
  fi
}

#check flux back
function check_back(){
  if [[ $flux_bench_back != *"connected"* ]]; then
    if whiptail --title "Flux Back Status Not Connected" --yesno "Would you like to update and restart the flux daemon and node?" 8 60; then
      flux_update_service
    else
      whiptail --msgbox "User would not like to update and restart flux daemon and flux node" 8 60;
    fi
  fi
}

# Update Ubuntu OS
function node_os_update(){
  if whiptail --title "Ubuntu Operating System Update" --yesno "Would you like to update the operating system?" 8 60; then
      sudo apt-get update -y && sudo apt-get --with-new-pkgs upgrade -y && sudo apt autoremove -y
    else
      whiptail --msgbox "User would not like to update the operating system" 8 60;
    fi
 
}

# Gets the node's uptime in minutes
function get_flux_uptime(){
  #curl local node IP's API port for uptime -s (silent) -S(show error)
  #converts seconds to minutes .. d/h/m/s will come at some point 
  local get_uptime=$(curl -sS --max-time 5 "http://$LANIP:$api_port/flux/uptime" 2>&1 | jq -r '.data')
  flux_uptime=$(bc <<< "$get_uptime / 60" | awk '{print $1 " mins"}')

  if [[ $flux_uptime == "" ]]; then
    flux_uptime="0 mins"
  fi
}

# Get api network blockheight
function check_current_blockheight(){
  local api_current_height=$(curl -sk -m 5 https://explorer.runonflux.io/api/status?q=getInfo getinfo 2>/dev/null | jq '.info.blocks' 2> /dev/null)

  if [[ $flux_daemon_block_height == "" ]]; then
      daemon_sync_status="${RED_ARROW}   Flux daemon sync status      -    ${RED}N/A${NC}"
  else
    if [[ "$api_current_height" != "0" ]]; then
      if [[ $flux_daemon_block_height == $api_current_height ]]; then
        daemon_sync_status="${GREEN_ARROW}   Flux daemon sync status      -    ${GREEN}Synced${NC}"
      else
        daemon_sync_status="${RED_ARROW}   Flux daemon sync status      -    ${RED}NOT Synced${NC} $((api_current_height-flux_daemon_block_height)) blocks behind"
      fi
    else
       daemon_sync_status="${RED_ARROW}   Flux daemon sync status      -    ${RED}N/A${NC}"
    fi
  fi
}


#check for dhcp with ip r 
function check_dhcp_enable(){
  local dhcpCheck=$(ip r | grep dhcp)
  if [[ "$dhcpCheck" != "" ]]; then
    dhcp_status="${YELLOW}DHCP DETECTED .. CHECK NODE LAN IP ADDRESS IS STATIC ON YOUR ROUTER${NC}"
  fi
}


# restart daemon service and restart FluxOS
function flux_update_service(){
  #stop daemon
  flux_daemon_stop

  #start daemon
  flux_daemon_start

  #stop flux
  flux_stop

  #start flux
  flux_start
}

#show node fixer tile - whiptail options to restart services/benchmarks and processes
function show_node_fix_tile(){
  if [[ -z $1 ]]; then
    
    # choose a node control menu option
    menuOption=$(whiptail --title "Choose Node Control" --menu "Choose an option:" 12 60 5 \
    "Flux Bench Controls" "" \
    "Flux OS Controls" "" \
    "Flux Daemon Controls" "" \
    "Flux Watchdog Controls" "" \
    "Flux PM2 Monitor" "" 3>&1 1>&2 2>&3 )

    # show submenu optoins for node controls
    if [[ "$menuOption" == "Flux Bench Controls" ]]; then
      userOption=$(whiptail --title "Flux Bench Controls" --menu "Choose an option: " 12 60 3 \
      "1"   "Restart Node Benchmarks      " \
      "2"   "Stop Benchmark               " \
      "3"   "Start Benchmark Service      " 3>&1 1>&2 2>&3 )
    elif [[ "$menuOption" == "Flux OS Controls" ]]; then
      userOption=$(whiptail --title "Flux OS Controls" --menu "Choose option: " 10 60 2 \
      "4"   "Stop Flux                    " \
      "5"   "Start Flux                   " 3>&1 1>&2 2>&3 )
    elif [[ "$menuOption" == "Flux Daemon Controls" ]]; then
      userOption=$(whiptail --title "Flux Daemon Controls" --menu "Choose option: " 10 60 2 \
      "6"   "Stop Flux Daemon             " \
      "7"   "Start Flux Daemon            " 3>&1 1>&2 2>&3 )
    elif [[ "$menuOption" == "Flux Watchdog Controls" ]]; then
      userOption=$(whiptail --title "Watchdog Controls" --menu "Choose option: " 12 60 3 \
      "8"   "Stop watchdog                " \
      "9"   "Start watchdog               " \
      "10"  "Restart watchdog             " 3>&1 1>&2 2>&3 )
    elif [[ "$menuOption" == "Flux PM2 Monitor" ]]; then
        #display pm2 monitor helpful for viewing watchdog actions every 4 minutes
        pm2 monit 2>/dev/null
    fi
  else
    if [[ $1 -gt 0 ]] && [[ $1 -lt 11 ]]; then
      userOption="$1"
    fi
  fi 

  # could use case switch here
  if [[ "$userOption" == "1" ]]; then
    flux_update_benchmarks
  elif [[ "$userOption" == "2" ]]; then
    flux_stop_benchmarks
  elif [[ "$userOption" == "3" ]]; then
    flux_start_benchmarks
  elif [[ "$userOption" == "4" ]]; then
    flux_stop
  elif [[ "$userOption" == "5" ]]; then
    flux_start
  elif [[ "$userOption" == "6" ]]; then
    flux_daemon_stop
  elif [[ "$userOption" == "7" ]]; then
    flux_daemon_start
  elif [[ "$userOption" == "8" ]]; then
    flux_watchdog_stop
  elif [[ "$userOption" == "9" ]]; then
    flux_watchdog_start
  elif [[ "$userOption" == "10" ]]; then
    flux_watchdog_restart
  fi
  redraw_term='1'
}

# restart the node benchmarks
function flux_update_benchmarks(){
  echo -e "${GREEN}starting${NC} node benchmarks ... please allow approx 5 mins for benchmarks to complete"
  $BENCH_CLI restartnodebenchmarks
  sleep 5
}

# stop the node benchmarks
function flux_stop_benchmarks(){
  echo -e "${RED}stopping${NC} node benchmarks ... "
  BENCH_CLI stop
  sleep 3
}

# start the node benchmarks
function flux_start_benchmarks(){
  echo -e "${GREEN}restarting${NC} node benchmark service ... please allow approx 5 minutes to complete"
  sudo systemctl restart zelcash
  sleep 5
}

# stop the flux node OS
function flux_stop(){
  echo -e "pm2 ${RED}stopping${NC} flux node os service ... "
  pm2 stop flux
  sleep 5
}

# start the flux node OS
function flux_start(){
  echo -e "pm2 ${GREEN}starting${NC} flux node os service ... "
  pm2 start flux
  sleep 5
}

# stop the flux daemon
function flux_daemon_stop(){
  echo -e "${RED}stopping${NC} flux daemon service ... "
  sudo systemctl stop zelcash
  sleep 5
}

# start flux daemon
function flux_daemon_start(){
  echo -e "${GREEN}starting${NC} flux daemon service ... "
  sudo systemctl start zelcash
  sleep 5
}

# stop watchdog
function flux_watchdog_stop(){
  echo -e "pm2 ${RED}stopping${NC} flux watchdog service ..."
  pm2 stop watchdog
  sleep 3
}

# start watchdog
function flux_watchdog_start(){
  echo -e "pm2 ${GREEN}starting${NC} flux watchdog service ... "
  pm2 start watchdog --watch
  sleep 3
}

# restart watchdog
function flux_watchdog_restart(){
  echo -e "pm2 ${GREEN}re-starting${NC} flux watchdog service ..."
  pm2 reload watchdog --watch
  sleep 3
}

function main_terminal(){
 
  while true; do
    check_term_resize

    WINDOW_WIDTH=$(tput cols)
    WINDOW_HALF_WIDTH=$(bc <<<"$WINDOW_WIDTH / 2")

    if [[ $redraw_term == '1' ]]; then
      if [[ $show_daemon == '1' ]]; then
        get_flux_blockchain_info
        check_daemon_log
        check_daemon_service
        check_port_info
        show_flux_daemon_info_tile
      elif [[ $show_node == '1' ]]; then
        get_flux_node_info
        get_blocks_since_last_confirmed
        check_pm2_flux_service
        check_docker_service
        check_mongodb_service
        check_pm2_flux_watchdog_service
        check_port_info
        check_flux_log
        #check_back
        show_flux_node_info_tile
      elif [[ $show_bench == '1' ]]; then
        get_flux_bench_info
        check_benchmark_log
        check_port_info
        #check_bench
        show_flux_benchmark_info_tile
      elif [[ $show_commands == '1' ]]; then
        show_available_commands_tile
      elif [[ $show_flux_node_details == '1' ]]; then
        show_network_node_details_tile
      elif [[ $show_external_port_details == '1' ]]; then
        show_external_port_info_tile
      elif [[ $show_node_kda_details == '1' ]]; then
        show_node_kda_tile
      fi
    fi
    update
  done
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
  clear
  echo -e "exiting .. clearing history ..."
  sleep 1.5
  set -o history
  clear
  sleep 0.5
  exit
}

echo -e "\n${GREEN}gathering node and daemon info ... ${NC}"

#get_flux_bench_info
#get_flux_blockchain_info
#get_flux_node_info
#get_blocks_since_last_confirmed
#check_port_info
#check_docker_service
#check_mongodb_service
#check_daemon_service
#check_pm2_flux_service
check_ip
check_version

# allow for user input to go right to desired tile
# allow arguments are 
# - node, bench, daemon, ports
if [ -z "$1" ]; then
   show_bench='1'
else
  if [[ $1 == "node" ]]; then
    show_node='1'
  elif [[ $1 == "bench" ]]; then
    show_bench='1'
  elif [[ $1 == "daemon" ]]; then
    show_daemon='1'
  elif [[ $1 == "ports" ]]; then
    show_external_port_details='1'
  else
    show_bench='1'
  fi
fi

main_terminal

#flux_external_available=$(curl -i -H "Accept: application/json" "https://api.runonflux.io/flux/checkfluxavailability/$WANIP" | grep 'success')
