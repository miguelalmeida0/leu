# Coverage review

This is a post-run, assistant-authored qualitative review, not independent human
validation or a new prompt-tuning round. Frozen prompts and labels were not
changed after inspecting challenge outputs.

The `coverage-review-*.tsv` files record individual raw-output reviews.
**Useful** means the proposed detail and its accompanying exact excerpt
provide at least one relevant, source-supported addition or correction, without
also adding a bad item. It also includes correctly empty coverage when the
learner already captures the question-relevant details; the rationale names
those cases explicitly. **Incorrect** includes redundant advice, irrelevant
sentences, misbound excerpts, unsupported statements, and important omissions
when the offered detail merely repeats the answer. **Ambiguous** explicitly
retains uncertain judgments about fragmentary advice or question relevance.
This is usefulness of the offered coverage advice, not exhaustive recall of
every possible missing detail. Claim support is scored separately: useful
corrective advice never cancels a false approval in the same response.

For guarded results, rejected outputs count as abstentions. Accepted coverage
uses the raw review because the guard does not rewrite coverage. All cases stay
in the denominator, including ambiguous judgments and abstentions. Baseline
coverage is empty on these ordinary-prose fixtures; its absence is not useful
coverage feedback. The baseline regression fixtures are reported separately.

The initial common subset was fixed to the first 20 challenge cases (concepts
09–12) before reviewing the other models. Full 100-case reviews were then added
where recorded; they do not replace or hide that initial subset. Both denominators
are shown separately. Unreviewed outputs remain unmeasured. The rubric is strict:
an otherwise useful answer with a separate redundant or irrelevant coverage item
is incorrect as a whole. Ambiguous judgments remain explicit.
