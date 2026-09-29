"""V37 capability spike (throwaway): writes each authoring agent's kit (guides, catalogue, validator,
brief with quotas) and the committed `guides/author-briefs.md`. Kits live outside the repository.

usage: python3 make_kits.py <spike-dir> <kits-dir>
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from validate_fixture import QUOTAS, SIZE, STATE_RANGES  # noqa: E402

PERSONAS = {
    "J": "Your first language is Portuguese (you also speak Spanish). You are a careful, serious university student, and your "
         "English shows real transfer patterns: an article dropped or added ('the authentication is...'), prepositions "
         "('depends of', 'consists in'), false friends ('actually' for 'currently', 'eventually' for 'possibly'), word order "
         "('always the server checks'), and the occasional literal translation. You are never a caricature: every answer is "
         "understandable, and many are good.",
    "K": "You study on your phone between other things. You type fast, mostly in lowercase, with real typos (dropped or "
         "swapped letters, autocorrect slips), abbreviations (w/, bc, smth, idk, tbh), casual slang, and often very short "
         "answers. Now and then you write a longer, rushed answer.",
    "L": "You are a confident, articulate learner who writes polished, well-structured and often long explanations. You "
         "always sound sure of yourself, and sometimes you are wrong about something important while everything around the "
         "mistake is right.",
    "M": "You understand things through analogies, stories and everyday scenarios (kitchens, sports, travel, offices, "
         "queues). You often explain a concept through a comparison or a situation instead of a definition. Your analogies "
         "are sometimes apt and sometimes misleading.",
    "N": "You reason out loud: 'because...', 'so...', 'therefore...', 'that's why...'. You like to explain why things work. "
         "Often your conclusion is right but your reason is wrong or invented; sometimes a plausible reason leads you to a "
         "wrong conclusion; sometimes you treat two things that happen together as cause and effect.",
    "O": "Your first language is Mandarin or Hindi (pick one and keep to it). Your English is functional, with typical "
         "transfer patterns: missing articles, plural and tense slips ('it check', 'before I learn'), sentence-final hedges "
         "('I think so', 'maybe'), and simple sentence structures. You are often cautious and brief. Never a caricature.",
    "X": "You write development examples for a tutoring system's test set. Mix voices: some non-native English, some typos, "
         "some analogies, some confident absolutes ('always', 'never'), some reasoning out loud.",
}
GUIDES = [("guide.md", "Packages/ShelfCore/Tests/Fixtures/diagnosis-generalization-guide.md"),
          ("guide-v36-addendum.md", "Packages/ShelfCore/Tests/Fixtures/diagnosis-generalization-guide-v36-addendum.md"),
          ("guide-v37-spike-addendum.md", "spikes/v37/guides/guide-v37-spike-addendum.md")]


def brief(author):
    tags = ", ".join(f"{tag} ≥ {n}" for tag, n in QUOTAS[author].items())
    states = ", ".join(f"{s} {lo}–{hi}" for s, (lo, hi) in STATE_RANGES[author].items())
    return (f"## Author {author}\n\n{PERSONAS[author]}\n\n* Cases: exactly {SIZE[author]}, ids `{author}-01` … "
            f"`{author}-{SIZE[author]:02d}`.\n* Minimum tag counts (`terse` counts terse or veryShort answers): {tags}.\n"
            f"* State ranges: {states}.\n")


def main(spike, kits):
    repo = os.path.dirname(os.path.dirname(os.path.abspath(spike)))
    briefs = ["# V37 spike author briefs\n", "Every authoring agent received the three guides, its own catalogue, the validator, "
              "and exactly one brief below. Quotas are enforced by `score/validate_fixture.py --author <letter>`.\n"]
    for author in ["J", "K", "L", "M", "N", "O", "X"]:
        briefs.append(brief(author))
        kit = os.path.join(kits, author)
        os.makedirs(os.path.join(kit, "out"), exist_ok=True)
        for name, source in GUIDES:
            shutil.copy(os.path.join(repo, source), os.path.join(kit, name))
        shutil.copy(os.path.join(spike, "catalogs", f"catalog-{author}.json"), os.path.join(kit, "catalog.json"))
        shutil.copy(os.path.join(spike, "score", "validate_fixture.py"), os.path.join(kit, "validate_fixture.py"))
        with open(os.path.join(kit, "BRIEF.md"), "w") as handle:
            handle.write(brief(author))
    for agent, catalog, extra in (("Y", "catalog-Y.json", ("cases", "p2-input.json")), ("Z", "catalog-gate.json", None)):
        kit = os.path.join(kits, agent)
        os.makedirs(os.path.join(kit, "out"), exist_ok=True)
        for name, source in GUIDES:
            shutil.copy(os.path.join(repo, source), os.path.join(kit, name))
        shutil.copy(os.path.join(spike, "catalogs", catalog), os.path.join(kit, "catalog.json"))
        shutil.copy(os.path.join(spike, "score", "validate_fixture.py"), os.path.join(kit, "validate_fixture.py"))
        if extra:
            shutil.copy(os.path.join(spike, *extra), os.path.join(kit, extra[-1]))
    briefs.append("## Annotator Y (P2)\n\nLabels the 25 V36 adversarial sentences under the guides. It sees only its catalogue, "
                  "the guides and the unlabelled sentences.\n")
    briefs.append("## Second labeller Z (primary gate)\n\nLabels 60 gate cases blind: it sees their text and target, the guides and "
                  "the gate catalogue, and never the first labels or the authors' identities (neutral ids DL-01…DL-60).\n")
    with open(os.path.join(spike, "guides", "author-briefs.md"), "w") as handle:
        handle.write("\n".join(briefs))
    print("kits written:", ", ".join(sorted(os.listdir(kits))))


if __name__ == "__main__":
    main(*sys.argv[1:3])
