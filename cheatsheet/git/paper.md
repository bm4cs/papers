---
title: "git cheatsheet v0.1 (@bm4cs)"
description: "arf arf we gotcha"
---

## .gitconfig

    [user]
      name = Ben Simmonds
      email = ben@bencode.io
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

## checkout

`checkout <tree-ish>` checkout a branch

`checkout -- <pathspec>` checkout a file from branch

## rebase or merge

`pull --rebase` rebase any new commits from upstream

## log

`show --pretty='' --name-status deadb33f` files in a commit

`log --author=Benjamin`

`log -- grep contents`

`log --all --grep='bug-1337'`

`log --after=01/10/2018`

`log --before="1 week ago"`

## diff

Compare the contents of a file to an earlier revision.

`diff HEAD^ HEAD Kerbal.java` to previous

`diff HEAD^^ HEAD Kerbal.java` to 2 commits back

`diff deadb33f HEAD -- Kerbal.java` to specific commit

`difftool HEAD~4 Kerbl.java` to 4 revs ago in GUI

`diff --cached` commit and stage

`diff master feature1 readme.md` a file between branches

`diff master...develop` branches

## commit

`commit --amend --no-edit` ammends the last commit

## reset and clean

`reset --hard deadb33f` resets everything (untracked, index) to commit or branch

`reset --soft deadb33f` preserve untracked, set HEAD to a commit, stage changes (squash)

`reset --mixed 1337123` like soft, without stage

`clean -n` remove all untracked files recursively (dry run)

`clean -f` actually do it

`clean -f -d` recurse directories too

`clean -f -X` remove ignored files (e.g. build outputs)

`clean -dfX` recurse ignored

## patches

`diff > b.patch` make a patch file

`add . && diff --cached > b.patch` with new additions

`diff --cached --binary > b.patch` with binary files

`apply b.patch` apply a patch file

## stash

`stash` put draft changes away

`stash pop` work on draft changes once again

## remotes

`remote -v` list out remote URIs

`fetch origin dev/foo:dev/foo` bind the meta for a remote branch against a local branch (handy for huge repos), the branch can then used like normal `checkout dev/foo`

`branch -u origin/foo` make local branch track a remote branch

## miscellaneous

`cherry-pick 1337123` apply commit from another branch

<!--
https://increment.com/open-source/more-productive-git/
-->
