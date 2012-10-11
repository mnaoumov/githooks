# GitHooks #

In my [blog](http://mnaoumov.wordpress.com/2012/10/10/useful-git-hooks/) I provide more background for these hooks

Different useful hooks for git repositories

To use this hooks to your repository you should put all files in **tools\GitHooks** folder

**Tools\GitHooks\Install-GitHooks.ps1** - installs all hooks in your repository

**PrepareForTests.ps1** - prepares local repository for test for the usecases described below

## Available hooks: ##

**commit-msg** - executed after commit message was set. Hooks enforces to provide TFS WorkItem ID or mark commit as an ad-hoc.

Hook accepts commit if

- it looks like **TFS1234 Some message**
- it looks like **ADH Some message** - ADH (stands for *ad-hoc*) will be trimmed out
- it is a merge, fixup, squash or revert commit
- current branch has name like **TFS1234** - branch name will be inserted as a prefix to the commit message

In all other cases it will prompt with a dialog asking for TFS WorkItem ID

To test it use

    git checkout non_TFS_branch
    git commit --allow-empty -m "TFS1234 Some message"
    git commit --allow-empty -m "ADH Some message"

**ADH** will be trimmed out

    git merge test_merge_pull_conflict_backup

You will get a merge conflict. Resolve it and commit. Hook dialog will not appear.

    git reset --hard non_TFS_branch_backup

![Merge commit dialog](https://bitbucket.org/mnaoumov/githooks/raw/master/Help/images/provide-tfs-work-item-id-dialog.png)

**post-merge** - executed after non-conflict merge. Hook handles the situation when you have pull merge and helps to use pull rebase instead.

To test it use

    git checkout test_merge_pull
    git pull

Now **post-merge** hook should help you to do rebase

![Merge commit dialog](https://bitbucket.org/mnaoumov/githooks/raw/master/Help/images/merge-commit-dialog.png)

To reset branch to the initial state use the following commands. Last command is required only if you selected **Yes, permanently** in the hooks dialog

    git checkout test_merge_pull
    git reset --hard test_merge_pull_backup
    git config branch.test_merge_pull.rebase false

**post-commit** - executed after conflict merge. Hook handles the situation when you have pull merge with conflict and helps to use pull rebase instead.

To test it use

    git checkout test_merge_pull_conflict
    git pull

Now **post-commit** hook should help you to do rebase

To reset branch to the initial state use the following commands. Last command is required only if you selected **Yes, permanently** in the hooks dialog

    git checkout test_merge_pull_conflict
    git reset --hard test_merge_pull_conflict_backup
    git config branch.test_merge_pull_conflict.rebase false
