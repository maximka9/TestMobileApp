# AGENTS.md

## Primary goal

Complete the user's task correctly while minimizing:
- token usage,
- context size,
- file reads,
- tool calls,
- reasoning,
- output length,
- unnecessary work.

Prefer the smallest sufficient solution.

## Agent policy

- Use exactly ONE agent.
- Do NOT spawn subagents.
- Do NOT spawn background agents.
- Do NOT use parallel agents.
- Do NOT use Best-of-N or multiple competing implementations.
- Solve the task in the current agent unless the user explicitly overrides this rule.
- Do not delegate repository exploration to additional agents.

## Scope discipline

- Work only on files and directories relevant to the requested task.
- Do not scan the whole repository unless strictly necessary.
- Prefer targeted searches by:
  - filename,
  - symbol,
  - import,
  - route,
  - error message,
  - module.
- If likely relevant files are known, inspect them first.
- Stop exploring once there is enough evidence to make the change safely.
- Do not inspect unrelated code "just in case".

## File reading

- Read the smallest useful portion of a file.
- Avoid loading very large files completely when a relevant section is enough.
- Avoid generated files, lockfiles, build output, logs, vendored code,
  and dependencies unless directly relevant.
- Do not reread files unless they changed or important context was lost.
- Prefer search results and targeted ranges over broad dumps.

## Changes

- Make the smallest change that fully solves the task.
- Do not refactor unrelated code.
- Do not rename unrelated symbols.
- Do not reformat unrelated files.
- Do not reorganize code outside the requested scope.
- Prefer localized edits over full-file rewrites.
- Preserve existing architecture, patterns, naming, and style.
- Reuse existing utilities and components.
- Do not add dependencies unless necessary.

## Reasoning efficiency

- Use the minimum reasoning needed to solve the task reliably.
- Do not explore multiple approaches when one clear approach is sufficient.
- Do not repeatedly reconsider decisions without new evidence.
- Do not produce long internal plans for simple tasks.
- For simple tasks: inspect, change, verify.
- For complex tasks: create only a short plan, then execute.
- Stop investigating after the root cause is sufficiently established.

## Commands and tools

- Prefer targeted commands.
- Avoid commands that produce large amounts of output.
- Use paths, filters, limits, and specific targets.
- Do not repeat the same command unless something relevant changed.
- Do not run broad repository scans without necessity.
- Do not run expensive builds before they are needed.

## Testing

- Run the smallest relevant test/check first.
- Prefer tests for the changed file, module, or package.
- Do not run the full test suite unless:
  - targeted tests are insufficient,
  - the change affects many components,
  - project instructions require it,
  - or the user explicitly requests it.
- Do not rerun successful tests unless relevant code changed.

## Error handling

When something fails:

1. Read only the relevant failure.
2. Identify the most likely cause.
3. Apply a targeted fix.
4. Rerun only the relevant command or test.

Do not restart broad repository exploration after every failure.

## Context management

- Keep context focused on the current task.
- Do not load unrelated documentation.
- Do not accumulate unnecessary command output.
- Summarize important findings instead of retaining large raw outputs.
- Prefer repository documentation as the source of truth.
- If the task grows significantly beyond the original scope,
  ask before expanding it.

## Response policy

Responses must be SHORT.

By default, the final response should contain only:

- what changed,
- files changed,
- tests/checks result,
- blocker if one exists.

Rules:

- Maximum 3-6 short lines for routine tasks.
- No long explanations unless explicitly requested.
- No step-by-step narrative of work performed.
- No repeated summary of the user's request.
- No large code blocks unless requested.
- No full diffs unless requested.
- No lists of every command executed unless requested.
- Do not explain obvious implementation details.
- Do not provide multiple alternatives unless requested.
- If the task is completed successfully, say so briefly and stop.

## Communication during work

- Do not send frequent progress updates.
- Do not narrate every tool call.
- Do not explain each file inspection.
- Ask a question only when required information cannot be inferred safely.
- Otherwise proceed autonomously.

## Documentation

- Follow relevant repository documentation.
- Follow nested AGENTS.md instructions when applicable.
- Keep AGENTS.md concise.
- Put large architectural explanations in dedicated docs rather than here.

## Safety

- Do not delete user data unless required and explicitly authorized.
- Do not overwrite unrelated user changes.
- Do not expose secrets, credentials, tokens, or private data.
- Ask before destructive or difficult-to-reverse actions.

## Strict token budget

- Optimize for minimum total token usage.
- Use exactly one agent.
- Never spawn subagents or background agents.
- Never use Best-of-N.
- Keep responses to 3-5 short lines unless the user requests detail.
- Do not scan the entire repository unless strictly required.
- Read only relevant files and relevant portions of large files.
- Prefer targeted search over broad exploration.
- Prefer targeted tests over full test suites.
- Avoid large tool outputs; filter and limit command output.
- Do not reread unchanged files without a concrete reason.
- Do not perform speculative exploration.
- Do not refactor unrelated code.
- Start with the simplest viable approach.
- Stop once the requested task is correctly completed.