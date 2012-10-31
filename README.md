# GitHooks #

In my [blog](http://mnaoumov.wordpress.com/2012/10/10/useful-git-hooks/) I provide more background for these hooks

Different useful hooks for git repositories

To use this hooks to your repository you should put all files in **tools\GitHooks** folder

**Tools\GitHooks\Install-GitHooks.ps1** - installs all hooks in your repository

**Invoke-Tests.ps1** - tests all hooks

Hooks controlled via configuration file **Tools\GitHooks\HooksConfiguration.xml** 

    <?xml version="1.0" encoding="UTF-8"?>
    <HooksConfiguration>
      <CommitMessages enforceTfsPrefix="true" showDialogFromConsole="false">
        <FakeWorkItems>
          <FakeWorkItem>0</FakeWorkItem>
          <FakeWorkItem>123</FakeWorkItem>
          <FakeWorkItem>1234</FakeWorkItem>
        </FakeWorkItems>
      </CommitMessages>
      <Merges fixPullMerges="true" allowAllMerges="false">
        <Merge branch="release.1.0" into="master" />
      </Merges>
      <Rebases allowRebasePushedBranches="false" />
    </HooksConfiguration>

## Available hooks: ##

**commit-msg** - executed after commit message was set. Hooks enforces to provide TFS WorkItem ID or mark commit as an ad-hoc.

Hook accepts commit if

- it looks like **TFS1234 Some message**
- it looks like **ADH Some message** - ADH (stands for *ad-hoc*) will be trimmed out
- it is a merge, fixup, squash or revert commit
- current branch has name like **TFS1234** - branch name will be inserted as a prefix to the commit message

In all other cases it will prompt with a dialog asking for TFS WorkItem ID

![Provide TFS WorkItem ID dialog](https://bitbucket.org/mnaoumov/githooks/raw/master/Help/images/provide-tfs-work-item-id-dialog.png)

**post-merge** & **post-commit** - executed after non-conflict merge and conflict merge correspondingly. Hook handles the situation when you have pull merge and helps to use pull rebase instead.

![Merge commit dialog](https://bitbucket.org/mnaoumov/githooks/raw/master/Help/images/merge-commit-dialog.png)


**post-merge** & **post-commit** - another hook checks if merge between branches allowed. And prompts the following dialog

![Unallowed merge dialog](https://bitbucket.org/mnaoumov/githooks/raw/master/Help/images/unallowed-merge-dialog.png)