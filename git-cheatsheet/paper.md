---
title: "git cheatsheet v0.1 (@bm4cs)"
description: "argf argf gotcha"
---

Assume all commands are prefixed with `git`.


# checkout

`checkout <tree-ish>` checkout a branch

`checkout -- <pathspec>` checkout a file from branch



# rebase or merge

`pull --rebase` rebase any new commits from others


# log

`show --pretty='' --name-status deadb33f` list commit

`TODO` show diff of a file between commits

`TODO` show commits for a user

`log -- grep contents`

`log --all --grep='bug-1337'` find commits with log text


# reset

`reset --hard`

`reset --soft`

`reset --mixed`


# patches

`diff > b.patch`

`add . && diff --cached > b.patch` + new

`diff --cached --binary > b.patch` + binaries

`apply b.patch`


