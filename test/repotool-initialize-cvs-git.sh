## Test repotool initialize with cvs source and git dest

mkdir /tmp/test-workdir$$
cd /tmp/test-workdir$$
${REPOTOOL:-repotool} initialize xyzzy cvs git >/tmp/out$$
echo Return code: $? >>/tmp/out$$
cd - >/dev/null
./dir-md5 /tmp/test-workdir$$ >>/tmp/out$$

case $1 in
    --regress)
        diff --text -u $2.chk /tmp/out$$ || exit 1; ;;
    --rebuild)
	cat /tmp/out$$ >$2.chk;;
    --view)
	cat /tmp/out$$;;
esac

st=$?
if [ $st -eq 0 ]; then
	rm -rf /tmp/test-workdir$$ /tmp/out$$
fi

exit $st

#end

