import Foundation

/// Closed word lists for finding the main verb of a technical sentence. The lists are
/// deliberately conservative: an unknown word is never promoted to a verb.
enum ClauseLexicon {
    enum Form: Sendable { case base, thirdPerson, past, participle, gerund }

    static let auxiliaries: Set<String> = [
        "is", "are", "was", "were", "be", "been", "am", "can", "could", "may", "might", "must", "shall", "should",
        "will", "would", "does", "do", "did", "has", "have", "had", "cannot", "can't", "don't", "doesn't", "isn't",
        "aren't", "won't", "shouldn't", "mustn't", "didn't", "wasn't", "weren't"
    ]
    static let determiners: Set<String> = [
        "a", "an", "the", "this", "that", "these", "those", "each", "every", "any", "some", "no", "another", "other",
        "its", "their", "his", "her", "our", "your", "my", "one", "two", "three", "four", "five", "several", "many",
        "few", "all", "both", "either", "neither", "such", "much", "more", "most", "less", "fewer"
    ]
    static let prepositions: Set<String> = [
        "about", "above", "across", "after", "against", "along", "among", "around", "as", "at", "before", "behind",
        "below", "beneath", "beside", "between", "beyond", "by", "despite", "down", "during", "except", "for", "from",
        "in", "inside", "into", "like", "near", "of", "off", "on", "onto", "out", "outside", "over", "past", "per",
        "since", "than", "through", "throughout", "to", "toward", "towards", "under", "until", "up", "upon", "via",
        "with", "within", "without", "according"
    ]
    static let subordinators: Set<String> = [
        "when", "if", "unless", "because", "while", "although", "though", "whereas", "until", "once", "whether",
        "where", "which", "who", "whom", "whose", "that", "how", "what", "why", "so"
    ]
    static let pronounSubjects: Set<String> = ["it", "they", "this", "these"]
    static let adverbs: Set<String> = [
        "also", "often", "usually", "only", "still", "always", "never", "not", "automatically", "immediately",
        "typically", "generally", "sometimes", "then", "later", "already", "even", "just", "freely", "safely",
        "explicitly", "implicitly", "directly", "eventually", "rarely", "both", "all", "each", "really", "actually"
    ]

    /// Base forms of verbs common in explanatory technical prose.
    static let verbs: [String] = """
    accept access add affect aggregate allow alter analyze append apply ask assert assign associate attach attempt \
    authenticate authorize avoid await balance batch become begin behave belong bind block break bring build bundle \
    cache calculate call cancel capture carry catch cause change check choose clean clear close collect combine commit \
    compare compile complete compose compute confirm connect consider consist construct contain continue control \
    convert coordinate copy correct cost create debounce decide declare decode decrease decrypt define delay delete \
    deliver depend derive describe design destroy detect determine differ disable discard display distribute divide \
    drop duplicate emit enable encode encrypt enforce ensure enter establish evaluate exceed execute exist expand \
    expect expire explain expose express extend fail fetch fill filter find finish fire fix follow force forget \
    format free fulfill gain generate get give grant group grow guarantee guard handle happen help hide hold hook \
    identify ignore implement import improve include increase indicate inherit initialize insert inspect install \
    introduce invalidate invoke isolate issue join keep know lack lead leak learn leave let limit link listen load \
    locate lock log look lose lower maintain make manage map mark match matter mean measure memoize merge migrate \
    miss model modify monitor mount move mutate need negotiate normalize notify observe obtain occur offer open \
    operate optimize order own parse pass pause perform permit persist pick place point poll power predict prefer \
    prepare present preserve prevent proceed process produce protect prove provide proxy publish pull push put query \
    queue raise reach read rebuild receive recognize recompute record recover recreate reduce refer reference \
    refresh register reject release rely remain remember remount remove render reorder repeat replace reply report \
    represent request require reset resolve respond restart restore restrict retain retrieve retry return reuse reveal \
    reverse roll rotate route run save scale scan schedule search secure see select send separate serve set share \
    show sign simplify skip slow solve sort specify speed split spread start stay stop store stream structure \
    subscribe succeed supply support swap switch synchronize take target tell terminate test throttle throw tie time \
    track trade transfer transform translate travel treat trigger trust try turn undo unify unmount update upgrade use \
    validate verify violate visit wait want warn watch work wrap write yield scroll resize wrap own accumulate \
    answer arrive assume become bypass collapse contaminate count cover crash decline deserve die dominate double \
    enter fall fit flag forward happen hit last lie live nest pay pick promise prompt rank rate reason recur reflect \
    rethink rise rule seem shift shrink sit spend stand suggest suppose surround survive tend think throw vary \
    communicate conform summarize transport organize encapsulate hydrate abort settle chain infer narrow widen \
    annotate constrain steal inject sanitize escape hash salt revoke buffer paginate shard replicate partition \
    degrade revalidate prefetch preload compress minify profile trace alert deploy seed mock stub fetch \
    serialize deserialize stringify orchestrate ingest bubble propagate capture dispatch await compete coordinate
    """.split(whereSeparator: \.isWhitespace).map(String.init)

    /// Frequent noun/verb homographs: "requests", "calls", "keys", "changes" are often nouns.
    static let homographs: Set<String> = Set("""
    access balance batch block bundle cache call cause change check close commit control copy cost debounce delay \
    design display drop duplicate fire fix format group guard handle hook import increase index issue key lead leak \
    limit link list load lock log look map mark match model mount move need order point poll power present process \
    proxy push query queue record reference release reply report request reset return reverse roll route run save \
    scale scan schedule search set share show sign sort speed split spread start stop store stream structure supply \
    support swap switch target test throw tie time track trade transfer trigger trust turn update upgrade use view \
    visit wait want watch work wrap yield state value type result error form effect answer count double flag \
    forward hit last lie promise prompt rank rate reason rule shift stand fall hash salt buffer trace profile \
    alert seed mock stub chain escape shard partition bubble capture
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    static let irregularPast: [String: String] = [
        "became": "become", "began": "begin", "bound": "bind", "broke": "break", "brought": "bring", "built": "build",
        "caught": "catch", "chose": "choose", "came": "come", "did": "do", "drew": "draw", "drove": "drive",
        "fell": "fall", "found": "find", "forgot": "forget", "froze": "freeze", "gave": "give", "got": "get",
        "went": "go", "grew": "grow", "held": "hold", "hid": "hide", "kept": "keep", "knew": "know", "led": "lead",
        "left": "leave", "let": "let", "lost": "lose", "made": "make", "meant": "mean", "paid": "pay", "put": "put",
        "ran": "run", "read": "read", "rose": "rise", "said": "say", "sent": "send", "set": "set", "shut": "shut",
        "spent": "spend", "split": "split", "spread": "spread", "stood": "stand", "took": "take", "taught": "teach",
        "told": "tell", "thought": "think", "threw": "throw", "understood": "understand", "wrote": "write",
        "won": "win", "saw": "see", "cost": "cost", "hit": "hit"
    ]
    static let irregularParticiple: [String: String] = [
        "become": "become", "begun": "begin", "broken": "break", "chosen": "choose", "done": "do", "drawn": "draw",
        "driven": "drive", "fallen": "fall", "forgotten": "forget", "frozen": "freeze", "given": "give",
        "gotten": "get", "gone": "go", "grown": "grow", "hidden": "hide", "known": "know", "seen": "see",
        "shown": "show", "taken": "take", "thrown": "throw", "written": "write", "risen": "rise", "been": "be"
    ]

    static let forms: [String: (lemma: String, form: Form)] = {
        var index: [String: (String, Form)] = [:]
        func add(_ word: String, _ lemma: String, _ form: Form) { if index[word] == nil { index[word] = (lemma, form) } }
        for verb in verbs {
            add(verb, verb, .base)
            let consonantY = verb.hasSuffix("y") && !"aeiou".contains(verb.dropLast().last ?? "a")
            let sibilant = ["s", "x", "z", "ch", "sh", "o"].contains { verb.hasSuffix($0) }
            add(consonantY ? String(verb.dropLast()) + "ies" : verb + (sibilant ? "es" : "s"), verb, .thirdPerson)
            let pastStem = consonantY ? String(verb.dropLast()) + "i" : (verb.hasSuffix("e") ? String(verb.dropLast()) : verb)
            add(pastStem + "ed", verb, .past)
            let gerundStem = verb.hasSuffix("e") && !verb.hasSuffix("ee") ? String(verb.dropLast()) : verb
            add(gerundStem + "ing", verb, .gerund)
            if let last = verb.last, verb.count <= 6, !"aeiouwxy".contains(last),
               let middle = verb.dropLast().last, "aeiou".contains(middle) {
                add(verb + String(last) + "ed", verb, .past)
                add(verb + String(last) + "ing", verb, .gerund)
            }
        }
        for (word, lemma) in irregularPast { index[word] = (lemma, .past) }
        for (word, lemma) in irregularParticiple { index[word] = (lemma, .participle) }
        return index
    }()
}
