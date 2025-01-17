## Test of canonicalization-after-commit cases
!echo This exercises many combine cases in the test repo
set echo
read <testrepo.fi
set interactive
coverage
:7,:8 squash
coverage       # Expect this to show case 1 covered.
:10,:11 squash
coverage       # Expect this to show case 3 covered.
:17,:18 squash
coverage       # Expect this to show case 2 covered.
:25,:26 squash
coverage       # Expect this to show case 4 covered.
:29,:30 squash
coverage       # Expect this to show case 6 covered.
1..$ resolve
:34 delete     # Test the code that checks for non-D fileops present.
1..$ resolve
write -
drop testrepo
clear interactive
read <testrepo.fi
coverage
:4,:7 squash --pushback
coverage
:23..:25 squash --pushback
coverage
write -
