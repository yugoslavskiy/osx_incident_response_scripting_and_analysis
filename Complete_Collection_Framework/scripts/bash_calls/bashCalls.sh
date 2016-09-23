#!/bin/bash

#set up variables
IRfolder=collection
systemCommands=$IRfolder/bashCalls

#create output directory
mkdir -p $systemCommands

#collect volatile bash data
echo "Running system commands..."

#collect bash history
history > $systemCommands/history.txt

systemInfo_commands=(
  "date"
  "hostname"
  "uname -a"
  "sw_vers"
  "nvram"
  "uptime"
  "spctl --status"
  "bash --version"
)

whoInfo_commands=(
  "ls -la /Users"
  "whoami"
  "who"
  "w"
  "last"
)

networkInfo_commands=(
  "netstat"
  "netstat -ru"
  "networksetup -listallhardwareports"
  "lsof -i"
  "arp -a"
  "security dump-trust-settings"
)

processInfo_commands=(
  "ps aux"
  "lsof"
)

startupInfo_commands=(
  "launchctl list"
  "atq"
)

driverInfo_commands=(
  "kextstat"
)

hardDriveInfo_commands=(
  "diskutil list"
  "df -h"
  "du -h"
)

bashCalls_list=(
  "systemInfo"
  "whoInfo"
  "networkInfo"
  "processInfo"
  "startupInfo"
  "driverInfo"
  "hardDriveInfo"
)

for type in "${bashCalls_list[@]}"
do
  IFS="
  "
  result_file="${systemCommands}/${type}.txt"
  touch ${result_file}

  commands_list="${type}_commands[@]"
  for command in "${!commands_list}"
  do
    echo "---${command}---" >> "${result_file}"
    bash -c "${command}" >> "${result_file}"
    echo >> "${result_file}"
  done
done

unset IFS

#collect user info
userInfo=$systemCommands/userInfo.txt
echo ---Users on this system--- >>$userInfo; dscl . -ls /Users >> $userInfo; echo >> $userInfo
#for each user
dscl . -ls /Users | egrep -v ^_ | while read user 
  do 
    echo *****$user***** >> $userInfo
    echo ---id \($user\)--- >>$userInfo; id $user >> $userInfo; echo >> $userInfo
    echo ---groups \($user\)--- >> $userInfo; groups $user >> $userInfo; echo >> $userInfo
    echo ---finger \($user\) --- >> $userInfo; finger -m $user >> $userInfo; echo >> $userInfo
    echo >> $userInfo
    echo >> $userInfo
    # find a way to provide printenv
  done
