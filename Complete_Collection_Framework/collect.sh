#!/bin/bash

#ensure that the script is being executed as root
if [[ $EUID -ne 0 ]]; then 
	echo 'Incident Response Script needs to be executed as root!'
	exit 1
fi

originalUser=`sh -c 'echo $SUDO_USER'`
echo "Collecting data as root escalated from the $originalUser account"

#insert company message here explaining the situation
cat << EOF

-----------------------------------------------------------------------
COLLECTING CRITICAL SYSTEM DATA. PLEASE DO NOT TURN OFF YOUR SYSTEM...
-----------------------------------------------------------------------

EOF

echo "Start time-> `date`"

#Create a pf rule to block all network access except for access to file server over ssh
quarentineRule=/etc/activeIr.conf
echo "Writing quarentine rule to $quarentineRule"
serverIP=192.168.1.111
cat > $quarentineRule << EOF
block in all
block out all
pass in proto tcp from $serverIP to any port 22
EOF

#load the pfconf rule and inform the user there is no internet access
pfctl -f $quarentineRule 2>/dev/null
pfctl -e 2>/dev/null
if [ $? -eq 0 ]; then
	echo "Quarentine Enabled. Internet access unavailable"
fi

#start tracing tcp connections in the background
scripts/soconnect_mac.d -o ${IRfolder}/soconnect.log &
#get pid of background process we just created.
#avoid using pgrep incase dtrace was already running
dtracePid=`ps aux | grep dtrace.*soconnect_mac.d | grep -v grep | awk '{print $2}'`
echo "Started tracing outbound TCP connections. Dtrace PID is ${dtracePid}"

#set up variables
IRfolder=collection
logFile=$IRfolder/collectlog.txt

mkdir $IRfolder
touch $logFile

#redirect errors
exec 2> $logFile

#memory collection
bash scripts/memory/memory_collection.sh

#bash calls collection
bash scripts/bash_calls/bashCalls.sh

#file system data collection 
bash scripts/file_system/file_system_collection.sh

#collect setuid binaries in the background
find / -usr root -perm -4000 -exec file {} \; &

#file listing collection
python scripts/file_system/file_walker.py -s / -d ${IRfolder}

#convert timestamps
python scripts/file_system/storyline.py

#asep collection
bash scripts/aseps/collect_aseps.sh

#browser history collection
bash scripts/browser_analysis/browser_Collection.sh
python scripts/browser_analysis/browser_parser.py

#run exfiltrator
python scripts/exfiltrator.py -s / -o ${IRfolder}/exfiltrator.txt

#stop tracing outgoing TCP data
kill -9 ${dtracePid}

#create a zip file of all the data in the current directory
#this will always be the last thing we do. Do not add code below this section through this book 
echo 'Archiving Data'
cname=`scutil --get ComputerName | tr ' ' '_' | tr -d \'`
now=`date +"_%Y-%m-%d"`
ditto -k --zlibCompressionLevel 5 -c ${IRfolder} ${cname}${now}.zip
