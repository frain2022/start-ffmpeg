#!/bin/bash
set -e
#set -v

wait_ready(){
  echo "wait until $1 success ..."
  for i in {1..30}
  do
    count=`ps -ef | grep $1 |  grep -v "grep" | wc -l`
    if [ $count -gt 0 ]; then
      echo  "$1 is ready!"     
      break
    else
      sleep 1
    fi
  done
}

kill_pid () {
    local pids=`ps aux | grep $1 | grep -v grep | awk '{print $2}'`
    if [ "$pids" != "" ]; then
        echo "Killing the following $1 processes: $pids"
        kill -n $2 $pids
    else
        echo "No $1 processes to kill"
    fi
}

wait_shutdown(){
  echo "wait until $1 shutdown ..."
  for i in {1..30}
  do
    count=`ps -ef | grep $1 |  grep -v "grep" | wc -l`
    if [ $count -eq 0 ]; then
      echo  "$1 is shutdown!"     
      break
    else
      sleep 1
    fi
  done
}

# start xvfb screen
record_time=$1
buff=300
(( node_time_out=record_time+buff ))
echo  "start xvfb-run ..."
xvfb-run --listen-tcp --server-num=76 --server-arg="-screen 0 $3" --auth-file=$XAUTHORITY  nohup node record.js $node_time_out $2 $4 $6 > /tmp/chrome.log 2>&1 &

# start pulseaudio service
pulseaudio -D --exit-idle-time=-1
pacmd load-module module-virtual-sink sink_name=v1
pacmd set-default-sink v1
pacmd set-default-source v1.monitor

wait_ready pulseaudio
wait_ready xvfb-run
wait_ready Xvfb
wait_ready chrome
wait_ready record.js

sleep 20s

echo  "ffmpeg start recording ..."
nohup ffmpeg -y -loglevel debug  -f x11grab  -video_size $5 -r 30  -i :76 -f alsa -ac 2 -ar 44100 -i default /var/output/test.mp4  > /tmp/ffmpeg.log 2>&1 &

wait_ready ffmpeg

sleep $record_time

# ffmpeg 必须先于 xvfb 退出
echo  "clean process ..."
kill_pid ffmpeg 2
wait_shutdown ffmpeg

cat /tmp/ffmpeg.log

ls -lh /var/output

sleep 3s

kill_pid record.js 15
wait_shutdown record.js
kill_pid Xvfb 15
wait_shutdown Xvfb
kill_pid chrome 15
wait_shutdown chrome
kill_pid xvfb-run 15
wait_shutdown xvfb-run
kill_pid pulseaudio 15
wait_shutdown pulseaudio

sleep 3s

ps auxww

echo  "record worker finished!!!"