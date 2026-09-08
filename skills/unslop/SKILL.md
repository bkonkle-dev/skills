---
name: unslop
description: Detects and rewrites generic, overly polished, or AI-sounding prose while preserving meaning. Use when the user asks to "unslop", humanize, de-AI, tighten, or review whether writing sounds generated.
---

# Unslop

Make prose sound like a specific, attentive human wrote it. Preserve the
author's meaning, facts, voice, intended audience, and level of formality.
Do not replace one generic style with another.

Use this skill for articles, documentation, announcements, emails, release
notes, product copy, reports, and pasted prose. It is not a substitute for a
fact check, technical review, copy edit, or accessibility review.

## Core principle

AI-sounding writing is not defined by a word, punctuation mark, or sentence
shape. A phrase is evidence only when it is part of a pattern: repeated vague
claims, overly symmetrical cadence, or polished language that does no work.

Do not flag or remove a construction merely because it resembles a known tell.
Technical documentation, legal prose, and concise announcements naturally use
some of these shapes. Judge whether the sentence contributes a concrete fact,
decision, example, constraint, or useful transition. Keep it when it does.

## Review workflow

1. Read the whole piece before changing it. For a URL, inspect the main
   content rather than navigation, footers, comments, or repeated interface
   text.
2. Identify the piece's purpose, audience, and existing voice. Preserve any
   intentional register, including terse reference documentation or formal
   communication.
3. Scan for *clusters*, not isolated instances, of the patterns below.
4. For every potential issue, compare it with this false-positive question:
   does it carry a specific claim or necessary structural purpose? If yes,
   retain it unless the surrounding density is the actual problem.
5. Make the smallest edits that improve specificity, rhythm, and credibility.
   Do not invent details to make prose feel more concrete.
6. Read the revised text aloud mentally. Vary sentence length only where the
   original has a mechanical rhythm. Do not add quirks or fragments for their
   own sake.

## Patterns to look for

### Hollow emphasis

Watch for stacked intensifiers and importance claims that do not say what is
important: "powerful", "seamless", "robust", "comprehensive", "game-changing",
"vibrant", "key", "crucial", "thoughtful", "elevate", "unlock", "transform",
or "delve". These are acceptable when a concrete noun or measurable outcome
does the real work.

Prefer the underlying fact over a label. Remove praise that merely repeats the
reader's expected reaction.

### Generic transitions and scene-setting

Cut openings such as "In today's fast-paced world", "Whether you are...",
"At its core", "It's worth noting", "In conclusion", or "Let's dive in" when
they do not establish a real condition, scope, or decision. Start with the
claim, event, or constraint instead.

Keep transitions that genuinely clarify sequence, contrast, cause, or scope.

### False balance and tidy inversions

Be alert to repeated constructions such as:

- "not just X, but Y"
- "X is more than Y"
- "from X to Y"
- "whether X or Y"
- "X. The rest is Y."

One well-earned contrast can be clear writing. A run of them makes prose feel
templated, especially when the second half simply rephrases the first. Replace
only the hollow instances with the direct claim.

### Epigrams and billboard sentences

Short, quotable closers can be effective. They become artificial when several
paragraphs end with an absolute, slogan-like line or a neat reversal. Flag the
document-level pattern, not a single useful sentence.

Ask: would the reader lose information if this sentence disappeared? If not,
cut it or fold its concrete content into the preceding sentence.

### Repetition disguised as progression

Look for consecutive paragraphs that restate one vague idea with different
adjectives, or headings whose body repeats the heading. Collapse them into the
one strongest version. Preserve genuinely distinct benefits, examples, or
steps.

### Over-uniform rhythm

Prose can feel generated when paragraphs share the same length and movement,
or when each follows claim, elaboration, neat conclusion. Vary the structure
by following the material: a short sentence for a real conclusion, an example
after an abstract claim, or a direct instruction where appropriate.

Do not force variation into reference material, lists, or deliberate parallel
structure.

### Excessive hedging or certainty

Repeated "may", "can", "often", and "typically" can evade a claim. Repeated
"always", "never", and "ensures" can overstate one. Retain qualifiers that
accurately express uncertainty, policy, compatibility, or scope. Strengthen or
qualify only when the supplied evidence supports it.

### Decorative punctuation and formatting

Do not treat em dashes, colons, semicolons, bold text, or headings as proof of
AI writing. Simplify them when they create a repeated theatrical cadence or
obscure the sentence. Preserve them when they improve clarity.

Do not use semicolons to join clauses in revised prose. Split the thought into
two sentences or use a comma when the grammar permits. This rule does not
apply to code, commands, data formats, or verbatim quotations.

## Calibration examples

Use these examples to decide whether a pattern is genuinely hollow or merely
shares a shape with good writing. They are judgment anchors, not templates or
string-matching rules. A single positive example is weak evidence. A cluster
of similar positive examples in the same piece is stronger evidence.

### Hollow emphasis

**Positive examples**

- "This powerful update transforms how teams build." Nothing identifies the
  update, the affected work, or the outcome.
- "The platform delivers a seamless, robust, and comprehensive experience."
  The adjectives make the claim sound larger without adding a fact.

**Legitimate counter-examples**

- "The update batches writes for 250 ms, reducing database calls during import
  by about 80%." The benefit is specific and checkable.
- "The retry policy uses exponential backoff with jitter to avoid synchronized
  retries after an outage." The sentence names a mechanism and its purpose.

### False balance and rhetorical reframing

**Positive examples**

- "This is not just an editor. It is a new way to think about writing."
  The second sentence promotes the claim but says nothing more.
- "The migration was not about speed. It was about confidence." Neither side
  gives the reader a concrete diagnosis or outcome.

**Legitimate counter-examples**

- "The delay was not in the query. It came from opening a new connection for
  every request." The contrast identifies a distinct, testable cause.
- "The change updates both the command-line client and the API package." This
  expands the scope with two concrete artifacts.

### Epigrams and dramatic closers

**Positive examples**

- Several paragraphs close with lines such as "The cache was never the point"
  and "The real feature was restraint." The lines could be moved between
  paragraphs without changing their meaning.
- "The system remembered. Until it did not." The dramatic reversal supplies no
  information beyond the paragraph it follows.

**Legitimate counter-examples**

- "The flag is enabled for all accounts. The fallback path was removed in the
  same release." These are two operational facts, not a slogan.
- "We will enable the remaining regions after the next maintenance window."
  The closer gives the reader a next action and timeline.

### Repetition disguised as progression

**Positive examples**

- "The workflow is simple to use. It makes collaboration effortless. It gives
  every team a smoother path forward." Each sentence restates a vague benefit.
- A section titled "A faster workflow" explains that the workflow is quicker,
  more efficient, and saves time without adding an example or measurement.

**Legitimate counter-examples**

- "Imports run concurrently. Exports remain serialized because the destination
  API accepts only one active upload." The sentences describe different
  behavior and explain the constraint.
- "First create the key. Then assign it to the service account. Finally rotate
  the old key after confirming traffic." The repetition expresses real order.

### Mechanical rhythm and sweeping cadence

**Positive examples**

- "Everything is automatic. The exception is review. Everything is fast. The
  exception is recovery." Repeated absolute-and-exception pairs create a neat
  rhythm without adding much detail.
- Twelve similarly sized paragraphs all follow the same pattern of broad
  claim, brief elaboration, and quotable conclusion. The structure becomes
  visible before the subject does.

**Legitimate counter-examples**

- "Only `token` is required. The remaining fields have defaults listed in the
  table below." The contrast is useful reference information.
- "Each of the three phases writes a checkpoint, so a restart continues from
  the last completed phase." The quantified statement explains a mechanism.

## Applying the calibration

Before changing a candidate sentence, identify the closest example above.
Keep it when it is closer to a legitimate counter-example. Revise it only when
it is both vague in isolation and part of a repeated pattern. When the answer
is unclear, preserve the original wording and report the uncertainty rather
than treating a stylistic shape as evidence of generated text.

## Revision rules

- Preserve facts, numbers, names, links, quotations, code, commands, and
  product terminology exactly unless the user asks to change them.
- Never add a personal anecdote, opinion, metric, customer, or source that was
  not provided.
- Prefer concrete nouns and verbs to adjective-heavy claims.
- Prefer one precise sentence to a claim followed by a restatement.
- Keep the author's useful terminology. Do not replace domain language with
  casual synonyms merely to sound human.
- Keep intentional rhetoric when it has substance attached.
- Do not make all writing terse. The aim is earned detail, not minimum length.
- Do not use prose semicolons to join sentences. Split the sentence instead.
- If substantial factual gaps prevent a good rewrite, identify them instead of
  fabricating an answer.

## Response format

Choose the response that matches the request.

### Review only

Return:

```markdown
## Unslop Review

**Assessment**: Clean | Minor issues | Significant issues

### Findings

- **[pattern]**: Why the cluster weakens the prose. Excerpt: "..."

### Overall

One short paragraph on the dominant pattern, or state that the prose reads
naturally and specifically.
```

Report only real patterns. If there are no meaningful findings, write
`No significant AI-like patterns detected.` Do not accuse an author or claim
that text was generated. Describe how it reads instead.

### Rewrite or "unslop"

Return the revised text first. Follow it with a concise `## What Changed`
section containing only material edits, such as removed repetition, replaced
vague claims with supplied specifics, or varied an overly repetitive cadence.
Do not enumerate trivial copy edits.

### Ambiguous requests

If the user asks whether text sounds AI-written but also wants it improved,
provide the short review followed by the revised text. If they provide only a
topic rather than prose, ask for the draft or offer to write a first draft in
their requested voice.

## Final quality check

Before responding, verify that the revision:

- says no more than the source supports.
- has not lost a necessary constraint or qualification.
- does not replace every sentence with the same terse style.
- contains no prose semicolons that join clauses.
- has removed redundant language rather than merely swapping buzzwords.
- still sounds appropriate for its audience and medium.
