# Contributing to ToolHive Buildkite Plugin <!-- omit from toc -->

First off, thank you for taking the time to contribute to the ToolHive Buildkite Plugin! :+1: :tada: This plugin
is released under the Apache 2.0 license. If you would like to contribute
something or want to hack on the code, this document should help you get
started. You can find some hints for starting development in the plugin's
[README](https://github.com/StacklokLabs/toolhive-buildkite-plugin/blob/main/README.md).

## Table of contents <!-- omit from toc -->

- [Code of conduct](#code-of-conduct)
- [Reporting security vulnerabilities](#reporting-security-vulnerabilities)
- [How to contribute](#how-to-contribute)
  - [Using GitHub Issues](#using-github-issues)
  - [Not sure how to start contributing?](#not-sure-how-to-start-contributing)
  - [Pull request process](#pull-request-process)
  - [Commit message guidelines](#commit-message-guidelines)

## Code of conduct

This project adheres to the
[Contributor Covenant](https://github.com/StacklokLabs/toolhive-buildkite-plugin/blob/main/CODE_OF_CONDUCT.md)
code of conduct. By participating, you are expected to uphold this code. Please
report unacceptable behavior to
[code-of-conduct@stacklok.dev](mailto:code-of-conduct@stacklok.dev).

## Reporting security vulnerabilities

If you think you have found a security vulnerability in the ToolHive Buildkite Plugin please DO NOT
disclose it publicly until we've had a chance to fix it. Please don't report
security vulnerabilities using GitHub issues; instead, please follow this
[process](https://github.com/StacklokLabs/toolhive-buildkite-plugin/blob/main/SECURITY.md)

## How to contribute

### Using GitHub Issues

We use GitHub issues to track bugs and enhancements. If you have a general usage
question, please ask in the #toolhive channel of the
[Stacklok Discord server](https://discord.gg/stacklok).

If you are reporting a bug, please help to speed up problem diagnosis by
providing as much information as possible. Ideally, that would include a small
sample pipeline configuration that reproduces the problem.

### Not sure how to start contributing?

PRs to resolve existing issues are greatly appreciated and issues labeled as
["good first issue"](https://github.com/StacklokLabs/toolhive-buildkite-plugin/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22)
are a great place to start!

### Pull request process

-All commits must include a Signed-off-by trailer at the end of each commit
message to indicate that the contributor agrees to the Developer Certificate of
Origin. For additional details, check out the [DCO instructions](dco.md).

- Create an issue outlining the fix or feature.
- Fork the ToolHive Buildkite Plugin repository to your own GitHub account and clone it locally.
- Hack on your changes.
- Correctly format your commit messages, see
  [Commit message guidelines](#commit-message-guidelines) below.
- Open a PR by ensuring the title and its description reflect the content of the
  PR.
- Ensure that CI passes, if it fails, fix the failures.
- Every pull request requires a review from the core team before merging.
- Once approved, all of your commits will be squashed into a single commit with
  your PR title.

### Commit message guidelines

We follow the commit formatting recommendations found on
[Chris Beams' How to Write a Git Commit Message article](https://chris.beams.io/posts/git-commit/):

1. Separate subject from body with a blank line
1. Limit the subject line to 50 characters
1. Capitalize the subject line
1. Do not end the subject line with a period
1. Use the imperative mood in the subject line
1. Use the body to explain what and why vs. how