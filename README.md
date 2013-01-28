# GitHooks #

In my [blog](http://mnaoumov.wordpress.com/2012/10/10/useful-git-hooks/) I provide more background for these hooks

Different useful hooks for git repositories

To use this hooks to your repository you should put all files in **tools\GitHooks** folder

**Tools\GitHooks\Install-GitHooks.ps1** - installs all hooks in your repository

**Invoke-Tests.ps1** - tests all hooks

Hooks controlled via configuration file **Tools\GitHooks\HooksConfiguration.xml** 

    <?xml version="1.0" encoding="UTF-8"?>
    <HooksConfiguration>
      <CommitMessages enforceTfsPrefix="true">
        <FakeWorkItems>
          <FakeWorkItem>0</FakeWorkItem>
          <FakeWorkItem>123</FakeWorkItem>
          <FakeWorkItem>1234</FakeWorkItem>
        </FakeWorkItems>
      </CommitMessages>
      <Branches>
        <Branch name="release.1.0" teamCityBuildTypeId="bt11">
          <Merge into="master" required="true" />
        </Branch>
        <Branch name="master" teamCityBuildTypeId="bt12" />
      </Branches>
      <Merges fixPullMerges="true" allowAllMerges="false" />
      <Pushes allowForcePushes="true" allowUnparsableMergeCommitMessages="false" allowMergePulls="true" allowedMergeIntervalInHours="24">
        <RemotesMap>
          <Map url="some-url" remoteName="origin" />
        </RemotesMap>
      </Pushes>
      <TeamCity mockBuildStatus="true" userName="user1" password="password1" url="some-url" allowUnknownBuildStatus="false" />
    </HooksConfiguration>


## Available hooks: ##

### commit-msg ###

Executed after commit message was set. Hook enforces to provide TFS WorkItem ID or mark commit as an ad-hoc.

Hook accepts commit if

- it looks like **TFS1357 Some message**
- it looks like **ADH Some message** - ADH (stands for *ad-hoc*) will be trimmed out
- it is a merge, fixup, squash or revert commit
- current branch has name like **TFS1357** - branch name will be inserted as a prefix to the commit message

In all other cases it will prompt with a dialog asking for TFS WorkItem ID or if you are committing from console it will show an interactive prompt (if **showDialogFromConsole** setting is set to false)

HooksConfiguration has node **FakeWorkItems** which contains some WorkItems that usually is fake. Sometime commiters are lazy to provide a WorkItem ID and put some random ones. Hook detects the situation and declines such commits.

![Provide TFS WorkItem ID dialog](https://raw.github.com/mnaoumov/githooks/master/Help/images/provide-tfs-work-item-id-dialog.png)

Interactive prompt:

    C:\Work\MyCode> git commit -m "My commit message"
    Enter TFS WorkItem ID (or ADH if ad-hoc): 1357
    [master 1ff8b5b] TFS1357 My commit message

### post-merge & post-commit ###

Executed after non-conflict merge and conflict merge correspondingly. Hook handles the situation when you have pull merge and helps to use pull rebase instead.

![Merge commit dialog](https://raw.github.com/mnaoumov/githooks/master/Help/images/merge-commit-dialog.png)

Hooks also check if merge between branches is allowed. List of allowed commits is specified under **Merges** node in a configuration file.
If merge is not allowed it prompts the following dialog

![Unallowed merge dialog](https://raw.github.com/mnaoumov/githooks/master/Help/images/unallowed-merge-dialog.png)

### pre-rebase ###

Executed before rebase is started. Hook checks if you are trying to rebase a branch which has merges

    WARNING: **********************************************************************
    WARNING: Pull rebase is not recommended because it affects merge commits.
    WARNING: See wiki-url/index.php?title=Git#Rebase_merges
    WARNING: **********************************************************************
    
    Pull rebase warning
    Do you want to continue rebase?
    [Y] Yes  [N] No  [?] Help (default is "N"):

### pre-receive ###

Server-side hook, executed after push but before changes were actually applied in a remote repository. Hook checks against broken builds, unmerged changes and incorrect merges.

### post-receive ###
Server-side hook, executed after push after changes were actually applied. Hooks reminds the committer to merge his change in a corresponding branch if applicable, it also uses git notes to provide access to the commits push dates.


## ForcePush ##

Utility provides a way to bypass all the **pre-receive** hook constraints. You have to run it and provide a reason for that, then it is being written in some GoogleSpreadsheet.

## Get-UnmergedCommits ##

Utility that helps to identify what commits should be made in what order.