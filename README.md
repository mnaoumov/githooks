# GitHooks #

Different useful hooks for git repositories

To use this hooks to your repository you should put all files in **tools\GitHooks** folder

**tools\GitHooks\Install-GitHooks.ps1** - installs all hooks in your repository


## Available hooks: ##

**post-merge** - executed after non-conflict merge. Hook handles the situation when you have pull merge and helps to use pull rebase instead.

To test it use

    git checkout test_merge_pull
    git reset --hard test_merge_pull_change
    git pull

Now post-merge hook should help you to do rebase

To reset branch to the initial state use the following commands. Last command is required only if you selected **Yes, permanently** in the hooks dialog

    git checkout test_merge_pull
    git reset --hard origin/test_merge_pull
    git config branch.test_merge_pull.rebase false
