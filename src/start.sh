diff /app/blink/blink.ino /data/blink.ino || PROGRAMMER=1
if [ "${PROGRAMMER:-}" == "1" ]; then
  echo $PROGRAMMER
  pushd /app/blink
  make upload && cp blink.ino /data/
  unset PROGRAMMER
  popd
fi
