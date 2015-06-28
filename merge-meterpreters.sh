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
CURRENT_GEM=$WD/metasploit-payloads-gem
SIGN=-S

(cd clean/metasploit-framework; git pull --rebase)
(cd clean/meterpreter; git pull --rebase)
(cd clean/metasploit-javapayload; git pull --rebase)
(cd clean/metasploit-payloads-gem; git pull --rebase)

rm -fr $WD
mkdir -p $WD

function filter_gem()
{
    rm -fr $CURRENT_GEM
    cp -a clean/metasploit-payloads-gem $CURRENT_GEM
    (cd $CURRENT_GEM
       git filter-branch -f --index-filter \
           'git ls-files -s | gsed "s-\t\"*-&gem/-" |
               GIT_INDEX_FILE="$GIT_INDEX_FILE.new" \
                   git update-index --index-info &&
            mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE" || true' HEAD
       git filter-branch -f --prune-empty --tree-filter 'rm -fr gem/meterpreter' HEAD
    )
}

function filter_php()
{
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
}

function filter_python()
{
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
}

function filter_c()
{
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
  echo `git log --pretty=oneline --reverse|head -1|cut -f 1 -d ' '` `git log --pretty=oneline prehistory_c |head -1|cut -f 1 -d ' '` > .git/info/grafts
  git fast-export --signed-tags=warn --all > ../export
)
rm -fr $CURRENT_C
mkdir $CURRENT_C
(cd $CURRENT_C
 git init
 git fast-import < ../export
)
}

function filter_java()
{
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
}

function update_repo()
{
(
  rm -fr $DST
  mkdir -p $DST
  git clone git@github.com:rapid7/metasploit-payloads.git $DST

  filter_c
  filter_java

  cd $DST
  git remote add -f current_c $CURRENT_C
  git merge $SIGN -m "Merged c" current_c/master
  git remote add -f current_java $CURRENT_JAVA
  git merge $SIGN -m "Merged java" current_java/master
  git push
)
}

function init_repo()
{
(
  rm -fr $DST
  mkdir -p $DST
  git init $DST
  cd $DST

  filter_gem
  git remote add -f current_gem $CURRENT_GEM
  git merge $SIGN -m "Merged gem" current_gem/master

  filter_c
  git remote add -f current_c $CURRENT_C
  git merge $SIGN -m "Merged c" current_c/master

  filter_java
  git remote add -f current_java $CURRENT_JAVA
  git merge $SIGN -m "Merged java" current_java/master

  filter_php
  git remote add -f current_php $CURRENT_PHP
  git merge $SIGN -m "Merged php" current_php/master

  filter_python
  git remote add -f current_python $CURRENT_PYTHON
  git merge $SIGN -m "Merged python" current_python/master

  git mv c/meterpreter/.gitmodules .
  cp $CWD/gitmodules .gitmodules
  sed -e "s/\.\.\\\pssdk/\.\.\\\.\.\\\.\.\\\pssdk/" -i "" \
    c/meterpreter/make.bat c/meterpreter/workspace/ext_server_sniffer/ext_server_sniffer.vcxproj
  git commit $SIGN . -m "Adjust submodule and pssdk paths"
  patch -p1 < $CWD/0001-adjust-java-install-paths.patch
  git commit $SIGN . -m "Adjust java install paths"
  patch -p1 < $CWD/0002-adjust-posix-install-paths.patch
  git commit $SIGN . -m "Adjust posix install paths"
  cp $CWD/README.md $CWD/Makefile .
  git add README.md Makefile
  git commit $SIGN . -m "Add top-level README and Makefile"

  git remote add github git@github.com:rapid7/metasploit-payloads.git
  #git push -f github --mirror
)
}

update_repo
