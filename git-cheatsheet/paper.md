---
title: "git cheatsheet v0.1 (@bm4cs)"
description: "arf arf we gotcha"
---

# .gitconfig

	[user]
	  name = Ben Simmonds
	  email = ben@bencode.net
	  autocrlf = true
    [pull]
	  rebase = true
	[diff]
	  tool = bc4
	[difftool bc4]
	  path=~/opt/bc4/bcomp
	[merge]
	  tool = bc4
	[mergetool bc4]
	  path=~/opt/bc4/bcomp


# checkout

`checkout <tree-ish>` checkout a branch

`checkout -- <pathspec>` checkout a file from branch



# rebase or merge

`pull --rebase` rebase any new commits from upstream


# log

`show --pretty='' --name-status deadb33f` list files in commit

`log --author=Benjamin`

`log -- grep contents`

`log --all --grep='bug-1337'`

`log --after=01/10/2018`

`log --before="1 week ago"`



# diff

`diff HEAD^ HEAD Kerbal.java` to previous

`diff 957... HEAD Kerbal.java` to specific commit

`difftool HEAD~4 Kerbl.java` to 4 revs ago in GUI

`diff --cached` commit and stage

`diff master feature1 readme.md` a file between branches

`diff master...develop` branches



# commit

`commit --amend --no-edit`



# reset

`reset --hard deadb33f` resets everything (dirty, index) to commit or branch

`reset --soft deadb33f` preserve dirty, set HEAD to a commit, stage changes (squash)

`reset --mixed 1337123` like soft, without stage (unstage)


# patches

`diff > b.patch` make a patch file

`add . && diff --cached > b.patch` with new additions 

`diff --cached --binary > b.patch` with binary files

`apply b.patch` apply a patch file


# stash

`stash`

`stash pop`




# miscellaneous

`cherry-pick 1337123` apply commit from another branch


<!--
https://increment.com/open-source/more-productive-git/
-->

