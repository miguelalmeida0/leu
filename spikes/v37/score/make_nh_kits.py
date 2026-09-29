"""V37 NH holdout (throwaway): writes each NH author's kit (guides, own catalogue, validator, brief) and the
committed `guides/nh-author-briefs.md`. Kits live outside the repository and are deleted after sealing.

usage: python3 make_nh_kits.py <spike-dir> <kits-dir>
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nh_rules import AUTHORS, NH_QUOTAS, NH_STATE_RANGES, REASONING  # noqa: E402

PERSONAS = {
    "Q": "Your first language is Italian (you also read French). You are a conscientious student, and your English shows real "
         "Romance-language transfer: articles added or dropped ('the security is...'), prepositions ('depends from', 'discuss "
         "about'), false friends ('actually' for 'currently', 'eventually' for 'possibly'), adjective or adverb placement, and "
         "the occasional literal translation. You negate things often ('it is not that...', 'is not only...'). Never a "
         "caricature: every answer is understandable, and many are good.",
    "R": "You study on your phone in short gaps (bus, queue, between lectures). You type fast, mostly lowercase, with real "
         "typos (dropped, doubled or swapped letters, autocorrect slips), abbreviations (w/, bc, smth, idk, ngl), and many "
         "terse or very short answers. Occasionally you dash off a longer, messy answer.",
    "S": "You are a fluent, confident, articulate explainer. You write polished, well-organised and often long explanations "
         "and always sound certain. Sometimes one clause inside an otherwise excellent answer is wrong in an important way; "
         "sometimes you restate a common misconception in elegant words.",
    "T": "You explain through analogies, stories and everyday examples (restaurants, trains, libraries, sport, post offices). "
         "You often reach for a comparison or a little scene instead of a definition. Some of your analogies capture the idea "
         "well; some mislead; some are only an example and never state the general idea.",
    "U": "You reason out loud: 'because...', 'so...', 'that's why...', 'which means...'. You like explaining why and how. "
         "Often your conclusion is right but the reason is wrong, circular or invented; sometimes a sensible reason leads you "
         "to a wrong conclusion; sometimes you take two things that happen together as cause and effect; sometimes you swap "
         "cause and effect.",
    "V": "Your first language is Korean or Bengali (pick one and keep to it). Your English is functional, with typical "
         "transfer patterns: articles missing, plural and tense slips ('it make', 'when user login'), topic-first word order, "
         "and sentence-final softeners ('I think', 'maybe'). You often use absolute words (always, never, only, all) and "
         "sometimes mix up who does what to whom. You are careful and often brief. Never a caricature.",
}
GUIDES = [("guide.md", "Packages/ShelfCore/Tests/Fixtures/diagnosis-generalization-guide.md"),
          ("guide-v36-addendum.md", "Packages/ShelfCore/Tests/Fixtures/diagnosis-generalization-guide-v36-addendum.md"),
          ("guide-v37-spike-addendum.md", "spikes/v37/guides/guide-v37-spike-addendum.md"),
          ("guide-v37-nh-addendum.md", "spikes/v37/guides/guide-v37-nh-addendum.md")]
VALIDATOR = ["validate_nh.py", "validate_fixture.py", "spike_rules.py", "nh_rules.py"]


def brief(author):
    tags = ", ".join(f"{tag} ≥ {n}" for tag, n in NH_QUOTAS[author].items())
    states = ", ".join(f"{s} {lo}–{hi}" for s, (lo, hi) in NH_STATE_RANGES[author].items())
    true, both = REASONING[author]
    return (f"## Author {author}\n\n{PERSONAS[author]}\n\n* Cases: exactly 40, ids `{author}-01` … `{author}-40`, written to "
            f"`out/cases.json` as `{{\"cases\": [...]}}`.\n* Minimum tag counts (`terse` counts terse or veryShort answers): {tags}.\n"
            f"* State ranges: {states}.\n* `reasoningIssue: true` on at least {true} cases, of which at least {both} are "
            f"misconception cases.\n* Also: at least 5 theme cases, every non-theme target at least 3 times, at most 20 cases on "
            f"Mobile Mastery, at least 12 cases in paraphrase groups (3–4 members, same target and state), at least 2 cases with "
            f"two or more misconceptions, at least 4 with a confusion or overgeneralization.\n* Check with "
            f"`python3 validate_nh.py out/cases.json catalog.json --author {author}` until it reports `problems 0`.\n")


def main(spike, kits):
    repo = os.path.dirname(os.path.dirname(os.path.abspath(spike)))
    briefs = ["# V37 NH author briefs\n", "Each NH author (a new agent instance) received the four guides, its own catalogue "
              "(`catalogs/nh/catalog-<letter>.json`), the NH validator and exactly one brief below.\n"]
    for author in AUTHORS:
        briefs.append(brief(author))
        kit = os.path.join(kits, author)
        os.makedirs(os.path.join(kit, "out"), exist_ok=True)
        for name, source in GUIDES:
            shutil.copy(os.path.join(repo, source), os.path.join(kit, name))
        shutil.copy(os.path.join(spike, "catalogs", "nh", f"catalog-{author}.json"), os.path.join(kit, "catalog.json"))
        for name in VALIDATOR:
            shutil.copy(os.path.join(spike, "score", name), os.path.join(kit, name))
        with open(os.path.join(kit, "BRIEF.md"), "w") as handle:
            handle.write(brief(author))
    briefs.append("## Second labeller (NH)\n\nA new agent instance labels 60 NH cases blind (10 per author, seed 3738): it sees "
                  "their text and target (neutral ids DL-01…DL-60), the four guides and the NH catalogue, never the first "
                  "labels, the authors' identities, prompts, model outputs, the scorer or development data.\n")
    with open(os.path.join(spike, "guides", "nh-author-briefs.md"), "w") as handle:
        handle.write("\n".join(briefs))
    print("kits written:", ", ".join(sorted(os.listdir(kits))))


if __name__ == "__main__":
    main(*sys.argv[1:3])
