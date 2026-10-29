# when-core

[![GitHub](https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=white)](https://github.com/ExaDev/when-core) [![Release](https://img.shields.io/github/v/release/ExaDev/when-core)](https://github.com/ExaDev/when-core/releases/latest) [![CI](https://img.shields.io/github/actions/workflow/status/ExaDev/when-core/ci.yml?branch=main)](https://github.com/ExaDev/when-core/actions)

The shared front half of the `when` actions, such as [`merge-when`](https://github.com/ExaDev/merge-when): it reads the `when` condition lines and the `then` effect a workflow gives, checks them against the vocabulary the calling action (the engine) declares, and hands them back normalised. The engine keeps every predicate and effect; this action only decides whether the input is something the engine understands, and fails the step before the engine touches any pull request if it is not, so a typo can't silently drop a safeguard.

## Use

It is meant to be called from an engine's own `action.yml`, as the first step:

```yaml
runs:
  using: composite
  steps:
    - id: when
      uses: ExaDev/when-core@v1
      with:
        when: ${{ inputs.when }}
        conditions: |
          label:
          check:
          not-draft
        then: ${{ inputs.then }}
        effects: |
          merge
          ready
    - shell: bash
      env:
        WHEN: ${{ steps.when.outputs.conditions }}
        THEN: ${{ steps.when.outputs.then }}
      run: ${{ github.action_path }}/engine.sh
```

The engine gives `then` its own default through its input's `default`, so a workflow that leaves `then` out gets the engine's usual effect.

## Inputs

| Input        | Meaning                                                                                                                     |
| ------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `when`       | The condition lines, one per line. Blank lines and lines starting with `#` are ignored                                      |
| `conditions` | The condition names the engine knows, one per line. A name ending in a colon (`label:`) takes a value; any other takes none |
| `then`       | The one effect to apply once every condition holds                                                                          |
| `effects`    | The effect names the engine knows, one per line                                                                             |

All four are required.

## Outputs

| Output       | Value                                                                                                                        |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| `conditions` | One condition per line, as `name` or `name: value`, with blank lines, comments and the space around names and values removed |
| `then`       | The effect, with surrounding space removed                                                                                   |

## Rejections

The step fails, writing no outputs, when:

- a condition line names a condition the engine does not declare;
- a condition declared with a value has none (`label`, `label:`), or one declared without a value has one (`not-draft: yes`);
- a line has nothing before its colon (`: automerge`);
- `when` has no conditions once comments and blank lines are removed;
- `then` is empty, names more than one effect, or names one the engine does not declare;
- the engine's own `conditions` or `effects` list is empty or holds a malformed name.

## Development

`parse.sh` is a plain bash script that reads its inputs from the environment and appends its outputs to `$GITHUB_OUTPUT`, so it runs without Actions. `npm test` runs its [bats](https://bats-core.readthedocs.io) suite (`test/parse.bats`) and the unit tests for the release plugins, and `npm run shellcheck` lints the script. CI also runs the composite action itself from the checkout, and commitlint, actionlint, typecheck, lint and format checks, aggregated into one `Required Checks` job.

Releases are made by semantic-release from conventional commits on `main`: it tags the version, publishes the GitHub Release with the changelog entry and a full changelog link, and moves the major tag (`v1`) that engines pin to, with a release of that name carrying the changelog for the whole major version.
