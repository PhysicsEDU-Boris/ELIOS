#!/bin/zsh
# Record a phone test: phone screen video + screenshots, app logcat, camera track boxes. Usage: record_test.sh outdir seconds
OUT=$1; SECS=${2:-170}
ADB=~/Library/Android/sdk/platform-tools/adb
mkdir -p "$OUT/shots"
$ADB logcat -c
$ADB logcat -v time > "$OUT/logcat.txt" &
LOGPID=$!
$ADB shell screenrecord --time-limit $SECS --bit-rate 6000000 /sdcard/elios_test.mp4 &
RECPID=$!
~/.venvs/fake-maixcam/bin/python -I "${0:A:h}/camera_boxes.py" "$OUT/camera_boxes.jsonl" $SECS &
CAMPID=$!
for i in $(seq 0 5 $((SECS-5))); do
  $ADB exec-out screencap -p > "$OUT/shots/t$(printf %03d $i).png"
  sleep 4
done
wait $RECPID $CAMPID
kill $LOGPID 2>/dev/null
sleep 2
$ADB pull /sdcard/elios_test.mp4 "$OUT/screen.mp4" >/dev/null && $ADB shell rm /sdcard/elios_test.mp4
echo "done: $(ls "$OUT/shots" | wc -l) shots, $(wc -l < "$OUT/camera_boxes.jsonl") camera lines, $(wc -l < "$OUT/logcat.txt") log lines"
