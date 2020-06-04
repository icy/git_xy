## Description

`git_sync` helps to synchronize sub directories between git repositories
semi-automatically, and may generate pull requests on `github` if
changes are detected on the destination repository.

`git_sync` reads a list of watch configuration from file, and for each
of them, `git_sync` fetches changes from the source repository and
synchronizes them to destination path (thanks to `rsync`)

## TOC

* [Description](#description)
* [Usage](#usage)
* [TODO](#todo)
* [Why](#nhy)
* [Author. License](#author-license)

## Usage

**WARNING:** The project is still in `\alpha` stage.

See also in [git_sync.config-sample.txt](git_sync.config-sample.txt).

```
git@github.com:icy/pacapt ng lib/ git@github.com:icy/pacapt master lib/
```

Now execute the script

```
F_GIT_SYNC_CONFIG="git_sync.config-sample.txt" ./git_sync.sh
```

the script will fetch changes from `pacapt` repository

## TODO

- [ ] Make sure the top/root directory is not used
- [ ] Create a hook script to create pull requests
- [ ] Add tests and automation support for the project

## Why

There are many tools trying to solve the code-sharing problem:

* `git submodule`
* `git subtree`
* https://github.com/ingydotnet/git-subrepo
* https://github.com/twosigma/git-meta
* https://github.com/mateodelnorte/meta
* https://github.com/splitsh/lite
* https://github.com/unravelin/tomono
* https://sourceforge.net/projects/gitslave/
* https://github.com/teambit/bit (bit only)
* https://github.com/lerna/lerna (javascript only)
* https://gerrit.googlesource.com/git-repo/ (Android only?)

Well, there are too many tools, aren't they?
What I really need is a simple way to pull changes from some repository
to another repository, generates some pull request for review.

Morever, this process should be done automatically when the upstream
repository is updated. Human intervention is not the right way when
there are just 100 or 500 repositories because of the raise of the
micro-repository `design` (if any) :D

## Author. License

The script is writtedn by Ky-Anh Huynh.
The work is released under a MIT license.
