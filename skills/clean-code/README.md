# clean-code

Clean Code skills for agent-assisted programming.

This repository provides a lightweight skill package that helps coding agents keep changes focused, readable, and maintainable. It is intended for day-to-day software work where the agent should favor small correct edits, clear reasoning, and practical engineering tradeoffs.

## What It Helps With

- Writing code that is easier to read, review, and change.
- Keeping implementations small instead of adding unnecessary abstraction.
- Improving naming, structure, and error handling.
- Reviewing code with attention to bugs, regressions, and missing tests.
- Communicating changes clearly while collaborating in an existing codebase.

## Why It Matters

- **Complexity grows exponentially** with each additional branch or decision point, making code harder to understand, test, and maintain. AI / Human teams both struggle when there are too many paths to hold in attention.
- **AI agents are not yet good at managing complexity**, so they need to be guided to avoid adding unnecessary paths and to keep the main path clear.

## Install

```sh
npx skills add zccz14/clean-code
npx skills update # to get the latest version
```

## Guiding Principles

1. **Complexity is the number of paths**: Every branch multiplies the paths that must be understood, tested, and proven to match the intended business semantics. Do not add a branch unless its necessity is explicit.
2. **Compatibility is debt**: Avoid adding code that is only compatible with existing systems or conventions without a clear business reason, as it increases complexity without providing value. Don't compatible-ize unless necessary for a specific business need.
3. **Minimal Error Handling**: Catch only errors the code knows how to handle, and keep error recovery separate from ordinary business flow. Avoid adding error handling that hides unknown states or swallows errors without a clear recovery strategy. Don't log or catch errors everywhere.
4. **Divide and Conquer**: When you need to solve a problem with multiple items, consider whether to solve it with a single path that iterates over the items, or with multiple paths that each handle one item. Don't add paths for each item unless there is a clear business reason to treat them separately.
5. **Linear Flow First**: Prefer a straight-line process inside each function. If the process requires category-by-category discussion, extract that classification into a more specific function where each case can be handled linearly.

## License

MIT
