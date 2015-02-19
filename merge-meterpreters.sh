#!/bin/bash
set -e
set -x

CWD=`pwd`
WD=/tmp/merge
DST=$WD/metasploit-payloads
PREHISTORY_C=$WD/prehistory_c
CURRENT_C=$WD/meterpreter_c
CURRENT_PHP=$WD/meterpreter_php
CURRENT_PYTHON=$WD/meterpreter_python
PREHISTORY_JAVA=$WD/prehistory_java
CURRENT_JAVA=$WD/meterpreter_java
CURRENT_BINS=$WD/meterpreter_bins

(cd clean/metasploit-framework; git pull --rebase)
(cd clean/meterpreter; git pull --rebase)
(cd clean/metasploit-javapayload; git pull --rebase)

rm -fr $WD
mkdir -p $WD

rm -fr $CURRENT_BINS
cp -a clean/meterpreter_bins $CURRENT_BINS
(cd $CURRENT_BINS
   git filter-branch -f --index-filter \
	   'git ls-files -s | gsed "s-\t\"*-&gem/-" |
		   GIT_INDEX_FILE="$GIT_INDEX_FILE.new" \
			   git update-index --index-info &&
	    mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE" || true' HEAD
   git filter-branch -f --prune-empty --tree-filter 'rm -fr gem/meterpreter' HEAD
)

rm -fr $CURRENT_PHP
cp -a clean/metasploit-framework $CURRENT_PHP
(cd $CURRENT_PHP
   git filter-branch -f --prune-empty --subdirectory-filter data/meterpreter HEAD
   git filter-branch -f --index-filter \
	   'git ls-files -s | gsed "s-\t\"*-&php/meterpreter/-" |
		   GIT_INDEX_FILE="$GIT_INDEX_FILE.new" \
			   git update-index --index-info &&
	    mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE" || true' HEAD
   git filter-branch -f --prune-empty --tree-filter 'find . -type f -not -name '*.php' |xargs rm' HEAD
)

rm -fr $CURRENT_PYTHON
cp -a clean/metasploit-framework $CURRENT_PYTHON
(cd $CURRENT_PYTHON
   git filter-branch -f --prune-empty --subdirectory-filter data/meterpreter HEAD
   git filter-branch -f --index-filter \
	   'git ls-files -s | gsed "s-\t\"*-&python/meterpreter/-" |
		   GIT_INDEX_FILE="$GIT_INDEX_FILE.new" \
			   git update-index --index-info &&
	    mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE" || true' HEAD
   git filter-branch -f --prune-empty --tree-filter 'find . -type f -not -name '*.py' |xargs rm' HEAD
)

rm -fr $PREHISTORY_C
cp -a clean/meterpreter-prehistory $PREHISTORY_C
(cd $PREHISTORY_C
   git reset --hard HEAD^
   git filter-branch -f --index-filter \
	   'git ls-files -s | gsed "s-\t\"*-&c/meterpreter/-" |
		   GIT_INDEX_FILE="$GIT_INDEX_FILE.new" \
			   git update-index --index-info &&
	    mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE" || true' HEAD
   git filter-branch -f --prune-empty --tree-filter 'rm -fr meterpreter-c/java' HEAD
)

rm -fr $CURRENT_C
cp -a clean/meterpreter $CURRENT_C
(cd $CURRENT_C
   git filter-branch -f --index-filter \
	   'git ls-files -s | gsed "s-\t\"*-&c/meterpreter/-" |
		   GIT_INDEX_FILE="$GIT_INDEX_FILE.new" \
			   git update-index --index-info &&
	    mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE" || true' HEAD
  git fetch $PREHISTORY_C master:prehistory_c
  echo 3b16aa0be5570eec2d7a586bb2925dadb2251bf2 05981df5685e578fea0ae61f51dd8315f30f81cb > .git/info/grafts
  git fast-export --signed-tags=warn --all > ../export
)
rm -fr $CURRENT_C
mkdir $CURRENT_C
(cd $CURRENT_C
 git init
 git fast-import < ../export
)

rm -fr $PREHISTORY_JAVA
cp -a clean/meterpreter-prehistory $PREHISTORY_JAVA
(cd $PREHISTORY_JAVA
   git reset --hard HEAD~2
   git filter-branch -f --prune-empty --subdirectory-filter java HEAD
)

rm -fr $CURRENT_JAVA
cp -a clean/metasploit-javapayload $CURRENT_JAVA
(cd $CURRENT_JAVA
   git filter-branch -f --index-filter \
	   'git ls-files -s | gsed "s-\t\"*-&java/-" |
		   GIT_INDEX_FILE="$GIT_INDEX_FILE.new" \
			   git update-index --index-info &&
	    mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE" || true' HEAD
  git fetch $PREHISTORY_JAVA master:prehistory_java
  echo 4ef3449e7cff6dc0d3c05cb65bc401697426ad04 9595ece04ecca4d6adf74fe3620c12115750415e > .git/info/grafts
  git fast-export --signed-tags=warn --all > ../export
)
rm -fr $CURRENT_JAVA
mkdir $CURRENT_JAVA
(cd $CURRENT_JAVA
 git init
 git fast-import < ../export
)

rm -fr $DST
mkdir -p $DST
git init $DST
(
  cd $DST
  git remote add -f current_bins $CURRENT_BINS
  git remote add -f current_c $CURRENT_C
  git remote add -f current_java $CURRENT_JAVA
  git remote add -f current_php $CURRENT_PHP
  git remote add -f current_python $CURRENT_PYTHON
  git merge current_bins/master
  git merge current_c/master
  git merge current_java/master
  git merge current_php/master
  git merge current_python/master
  git mv c/meterpreter/.gitmodules .
  cp $CWD/gitmodules .gitmodules
  sed -e "s/\.\.\\\pssdk/\.\.\\\.\.\\\.\.\\\pssdk/" -i "" \
    c/meterpreter/make.bat c/meterpreter/workspace/ext_server_sniffer/ext_server_sniffer.vcxproj
  git commit . -m "Adjust submodule and pssdk paths"
  patch -p1 < $CWD/0001-add-Java-PHP-Python.patch
  git commit . -m "Add Java / PHP / Python to the gem"
)
