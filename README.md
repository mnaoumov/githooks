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

### commit-msg ###

Executed after commit message was set. Hook enforces to provide TFS WorkItem ID or mark commit as an ad-hoc.

Hook accepts commit if

- it looks like **TFS1234 Some message**
- it looks like **ADH Some message** - ADH (stands for *ad-hoc*) will be trimmed out
- it is a merge, fixup, squash or revert commit
- current branch has name like **TFS1234** - branch name will be inserted as a prefix to the commit message

In all other cases it will prompt with a dialog asking for TFS WorkItem ID or if you are committing from console it will show an interactive prompt (if **showDialogFromConsole** setting is set to true)

![Provide TFS WorkItem ID dialog](https://bitbucket.org/mnaoumov/githooks/raw/master/Help/images/provide-tfs-work-item-id-dialog.png)

### post-merge & post-commit ###

Executed after non-conflict merge and conflict merge correspondingly. Hook handles the situation when you have pull merge and helps to use pull rebase instead.

![Merge commit dialog](https://bitbucket.org/mnaoumov/githooks/raw/master/Help/images/merge-commit-dialog.png)

Hooks also check if merge between branches is allowed. List of allowed commits is specified under **Merges** node in a configuration file.
If merge is not allowed it prompts the following dialog

![Unallowed merge dialog](https://bitbucket.org/mnaoumov/githooks/raw/master/Help/images/unallowed-merge-dialog.png)

### pre-rebase ###

Executed before rebase is started. Hook checks if you are trying to rebase a branch which was already pushed and denies the whole rebase before it is started.

    The pre-rebase hook refused to rebase.
    WARNING: *****
    WARNING: You cannot rebase branch 'master' because it was already pushed.
    WARNING: *****

### pre-receive ###

Server-side hook, executed after push but before changes were actually applied in a remote repository. Hook checks against pull merges and another very annoying and weird case which is difficult to explain (see my [blogpost](http://mnaoumov.wordpress.com/2012/09/20/guide-how-to-easy-screw-up-your-git-repository/) which describes this case).

    remote: WARNING: *****
    remote: WARNING: The following commit should not exist in branch release.1.0
    remote: WARNING: 72c4545c5c35587517fd9f595528b381427ab388 Merge branch 'release.1.0'
    remote: WARNING: *****

### post-receive ###
Server-side hook, executed after push after changes were actually applied. Hooks reminds the committer to merge his change in a corresponding branch if applicable

    remote: WARNING: *****
    remote: WARNING: You pushed branch 'release.1.0'. Please merge it to the branch 'master' and push it as well ASAP
    remote: WARNING: *****