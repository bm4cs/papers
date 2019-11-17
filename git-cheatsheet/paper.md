---
title: "git"
author: "Benjamin Simmonds"
description: "argf argf gotcha"
---

Assume all commands are prefixed with `git`.


# checkout

`checkout <tree-ish>` checkout a branch
`checkout -- <pathspec>` checkout a file from branch



# rebase or merge

`pull --rebase` rebase any new commits from others


# log

`show --pretty='' --name-status deadb33f` show files in a commit
`TODO` show diff of a file between commits
`TODO` show commits for a user
`log -- grep contents`
`log --all --grep='bug-1337'` find commits with log text


# reset

`reset --hard`
`reset --soft`
`reset --mixed`

