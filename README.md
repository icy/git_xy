## Description

`git_xy` helps to synchronize sub directories between git repositories
semi-automatically, and may generate pull requests on `github` if
changes are detected on the destination repository.

`git_xy` reads a list of source/destination in a configuration file,
and for each of them, `git_xy` fetches changes from the source repository
and synchronizes them to destination path (thanks to `rsync`)

## TOC

* [Description](#description)
* [Usage](#usage)
* [TODO](#todo)
* [Why](#why)
* [Author. License](#author-license)

## Usage

**WARNING:** The project is still in `\alpha` stage.

See also in [git_xy.config-sample.txt](git_xy.config-sample.txt).

```
git@github.com:icy/pacapt ng lib/ git@github.com:icy/pacapt master lib/
```

Now execute the script

```
GIT_XY_CONFIG="git_xy.config-sample.txt" ./git_xy.sh
```

the script will fetch changes in `lib` directory from branch `ng`
in the `pacapt` repository,
and update the same repository on another branch `master`.
If changes are detected, a new branch will be created and/or
some pull request will be generated.

Samples Prs on Github:

* https://github.com/icy/pacapt/pull/136
* https://github.com/icy/pacapt/pull/135

## TODO

- [ ] Create a hook script to create pull requests
- [ ] Add tests and automation support for the project
- [ ] Provide a link to the original source
- [ ] Add some information from the last commit of the source repository
- [ ] More `POSIX` ;)
- [ ] Better hook to handle where PRs will be created

Done

- [x] Make sure the top/root directory is not used (we allow that)
- [x] Allow a repository to update itself

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

Well, there are too many tools...
What I really need is a simple way to pull changes from some repository
to another repository, generates some pull request for reviewing,
and the downstream maintainer will decide what they would do next.

Morever, this process should be done automatically when the upstream
repository is updated. Human intervention is not the right way when
there are just 100 or 500 repositories because of the raise of the
micro-repository `design` (if any) :D

## Author. License

The script is writtedn by Ky-Anh Huynh.
The work is released under a MIT license.
