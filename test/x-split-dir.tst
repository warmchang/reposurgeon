## Split a commit based on a directory prefix
echo 1
relax
verbose 1
quiet on
# There's a --nobranch embedded in the test load so it can be checked standalone.
# This invocation would make the load work even without that.
read --nobranch <x-split-dir.svn
:2 split by bar
# Expect the split on zed to fail
:5 split by zed
:5 split by f
inspect
