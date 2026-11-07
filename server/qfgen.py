"""Quizforge question generation.

One idea holds this file together: everything downstream of us (Godot, the
review screen, the battle) only ever sees ONE shape. A dict like:

    {
      "source": {"file": ..., "pages": n, "chars": n, "method": "text|vision"},
      "pages":  [{"page": 1, "text": "..."}, ...],
      "questions": [
        {"id": "q1", "question": "...", "choices": ["...","...","...","..."],
         "answer": 2, "explanation": "...", "source_quote": "..."}
      ]
    }

Whether those questions came from an LLM or from the offline rule-based
generator is our problem, not the app's.
"""

from __future__ import annotations

import base64
import io
import json
import os
import random
import re
import time
import urllib.error
import urllib.request

# Minimum characters on a page before we trust its text layer. Below this the
# page is almost certainly a scan, and has to go to a vision model instead.
TEXT_LAYER_MIN_CHARS = 60

# How much source text the model sees per request. The app is played on small,
# old phones, so the reply must stay small too: whole pages are added until the
# budget is spent, never a mid-sentence cut.
SOURCE_BUDGET_CHARS = 24000
SOURCE_CHUNKS = 6          # pieces of the content spread across the file
FRONT_MATTER_SCAN_PAGES = 12  # only the start of a file can be front matter

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif"}
TEXT_EXTS = {".txt", ".md", ".csv", ".json"}


# --------------------------------------------------------------------- errors


class ExtractError(Exception):
    """The file could not be turned into text at all."""


class ProviderError(Exception):
    """The AI call failed, or no key is configured.

    `status` is the HTTP status when the provider answered at all, so the retry
    loop can tell a temporary 503 apart from a permanent 400. `retryable` is set
    only for the statuses that are worth trying again.
    """

    def __init__(self, message: str, status: int = 0, retryable: bool = False):
        super().__init__(message)
        self.status = status
        self.retryable = retryable


class QualityError(ProviderError):
    """The AI answered, but kept asking about the document instead of its subject."""


# ------------------------------------------------------------------ extraction


def extract(path: str) -> dict:
    """File -> {"file", "pages": [{"page", "text"}], "method", "pending_images"}.

    `pending_images` lists pages that have no usable text layer. They are the
    ones that need a vision model; the offline generator cannot help with them.
    """
    ext = os.path.splitext(path)[1].lower()
    if not os.path.isfile(path):
        raise ExtractError(f"no such file: {path}")

    if ext == ".pdf":
        return _extract_pdf(path)
    if ext in TEXT_EXTS:
        return _extract_plain(path)
    if ext in IMAGE_EXTS:
        return _extract_image(path)
    raise ExtractError(f"unsupported file type: {ext or '(none)'}")


def _extract_pdf(path: str) -> dict:
    import pymupdf  # imported lazily so the rest of the module works without it

    doc = pymupdf.open(path)
    pages, pending = [], []
    try:
        for i, page in enumerate(doc):
            text = page.get_text("text").strip()
            pages.append({"page": i + 1, "text": text})
            if len(text) < TEXT_LAYER_MIN_CHARS:
                pending.append(i + 1)
        total = sum(len(p["text"]) for p in pages)
        method = "text" if total >= TEXT_LAYER_MIN_CHARS else "vision"
        return {
            "file": os.path.basename(path),
            "pages": pages,
            "method": method,
            "pending_images": pending,
        }
    finally:
        doc.close()


def _extract_plain(path: str) -> dict:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read().strip()
    if not text:
        raise ExtractError("file is empty")
    return {
        "file": os.path.basename(path),
        "pages": [{"page": 1, "text": text}],
        "method": "text",
        "pending_images": [],
    }


def _extract_image(path: str) -> dict:
    # No OCR dependency on purpose: a vision model reads photos better than
    # any local OCR we could bolt on, and it writes the questions at the same
    # time. So an image is "all pending" until an AI is involved.
    return {
        "file": os.path.basename(path),
        "pages": [{"page": 1, "text": ""}],
        "method": "vision",
        "pending_images": [1],
    }


def render_page_png(path: str, page_number: int, dpi: int = 150) -> bytes:
    """Render one PDF page to PNG bytes, for the vision path."""
    import pymupdf

    doc = pymupdf.open(path)
    try:
        page = doc[page_number - 1]
        pix = page.get_pixmap(dpi=dpi)
        return pix.tobytes("png")
    finally:
        doc.close()


def read_image_png(path: str, max_side: int = 1600) -> bytes:
    """Load an image, downscale it, return PNG bytes."""
    from PIL import Image

    img = Image.open(path)
    img = img.convert("RGB")
    longest = max(img.size)
    if longest > max_side:
        scale = max_side / longest
        img = img.resize((int(img.width * scale), int(img.height * scale)))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def all_text(extracted: dict) -> str:
    return "\n\n".join(p["text"] for p in extracted["pages"] if p["text"])


# --------------------------------------------------------------- page selection

_RANGE_RE = re.compile(
    r"^(?:pdf\s+)?(?:pages?|pp?\.?)?\s*(\d+)\s*(?:(?:-|\.\.|to)\s*(\d+))?\s*$",
    re.IGNORECASE,
)

# Signals that a page belongs to the front of a book rather than to its subject.
# Deliberately generic: no publisher names, no titles. A single hit is not
# enough; a page must look like *more than one* kind of front matter.
_FRONT_MATTER_SIGNALS = [
    r"all rights reserved",
    r"\bcopyright\b",
    r"\b(?:isbn|issn)\b",
    r"creative commons",
    r"licensed under",
    r"no part of this (?:book|publication|work)",
    r"printed in the (?:united states|u\.s\.a)",
    r"senior contributing authors?",
    r"contributing authors?",
    r"about the authors?",
    r"\backnowledg(?:e)?ments?\b",
    r"list of (?:reviewers|contributors)",
    r"table of contents",
    r"\bpreface\b",
    r"\bforeword\b",
    r"how to use this (?:book|textbook)",
    r"access for free",
    r"openly licensed",
    r"peer-reviewed",
    r"\byour (?:book|textbook)\b",
    r"\bour books?\b",
    r"\bthis (?:book|textbook|volume)\b",
    r"\bthis edition\b",
    r"instructor resources",
    r"ancillary",
]


def parse_page_range(text: str, total_pages: int) -> tuple[int, int] | None:
    """'pages 40-65' -> (40, 65). Empty -> None. Bad input -> ExtractError."""
    raw = (text or "").strip()
    if raw == "":
        return None
    cleaned = raw.lower().replace("\u2013", "-").replace("\u2014", "-").replace(",", "")
    match = _RANGE_RE.match(cleaned)
    if not match:
        raise ExtractError(f"could not read the page range {raw!r}; try something like 40-65")
    low = int(match.group(1))
    high = int(match.group(2) or low)
    if low < 1:
        raise ExtractError("page numbers start at 1")
    if high < low:
        low, high = high, low
    if total_pages and low > total_pages:
        raise ExtractError(f"this file only has {total_pages} PDF pages, so page {low} does not exist")
    if total_pages:
        high = min(high, total_pages)
    return low, high


def _looks_like_toc(text: str) -> bool:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    low = text.lower()
    if "table of contents" in low or low.lstrip().startswith("contents"):
        return True
    if len(lines) < 8:
        return False
    number_ended = sum(
        1 for line in lines
        if re.search(r"(?:\.{3,}|\s)\s*\d{1,4}\s*$", line)
    )
    dotted = sum(1 for line in lines if "..." in line)
    if dotted >= 3 and number_ended / len(lines) >= 0.4:
        return True
    # chapter/section lists: "5.2 The Definite Integral 456" on most lines
    if number_ended >= 6 and number_ended / len(lines) >= 0.6:
        return True
    return False


def _front_matter_score(text: str) -> int:
    """How much a page looks like publication boilerplate. 0 = ordinary content."""
    if len(text.strip()) < TEXT_LAYER_MIN_CHARS:
        return 0  # handled separately: blank pages are not "front matter"
    low = text.lower()
    return sum(1 for pattern in _FRONT_MATTER_SIGNALS if re.search(pattern, low))


def strip_front_matter(pages: list[dict]) -> tuple[list[dict], list[int]]:
    """Split off the opening pages that describe the document, not its subject.

    Only the first `FRONT_MATTER_SCAN_PAGES` (or the first tenth of the file,
    whichever is larger) are candidates, so a real content page later can never
    be mistaken for a copyright page. If everything is filtered out we keep the
    file as it was: a one-page handout must never vanish.
    """
    if not pages:
        return [], []
    # Front matter lives at the very start: up to a dozen pages is enough for a
    # title, copyright, contents, preface, and the odd marketing page.
    scan = min(len(pages), FRONT_MATTER_SCAN_PAGES)
    kept: list[dict] = []
    skipped: list[int] = []
    for i, page in enumerate(pages):
        text = str(page.get("text", "")).strip()
        if i >= scan:
            kept.append(page)
            continue
        blank = len(text) < TEXT_LAYER_MIN_CHARS
        toc = _looks_like_toc(text)
        boilerplate = _front_matter_score(text) >= 2
        if blank or toc or boilerplate:
            skipped.append(int(page.get("page", i + 1)))
        else:
            kept.append(page)
    if not kept:
        return list(pages), []
    return kept, skipped


def _sample_pages(
    pages: list[dict],
    budget: int = SOURCE_BUDGET_CHARS,
    chunks: int = SOURCE_CHUNKS,
    rng: random.Random | None = None,
) -> list[dict]:
    """Whole pages from several places in the file, up to the character budget.

    Taking the first `budget` characters is what used to send fifteen pages of
    copyright and table of contents to the model. Spreading chunks across the
    content instead keeps the quiz about the subject even without a page range.
    """
    if not pages:
        return []
    total = sum(len(str(p.get("text", ""))) for p in pages)
    if total <= budget:
        return list(pages)

    count = max(1, min(chunks, len(pages)))
    per_chunk = max(1, budget // count)
    picked: dict[int, dict] = {}

    for chunk in range(count):
        low = round(chunk * len(pages) / count)
        high = max(low + 1, round((chunk + 1) * len(pages) / count))
        segment = pages[low:high]
        if rng is not None and len(segment) > 1:
            # a regenerated set should start somewhere else in the same region
            shift = rng.randrange(len(segment))
            segment = segment[shift:] + segment[:shift]
        taken = 0
        for page in segment:
            size = len(str(page.get("text", "")))
            if taken and taken + size > per_chunk:
                break
            picked[int(page.get("page", 0))] = page
            taken += size

    if not picked:
        return [pages[0]]
    return [page for _, page in sorted(picked.items()) if str(page.get("text", "")).strip()]


def select_pages(
    pages: list[dict],
    page_range: tuple[int, int] | None = None,
    seed: int | None = None,
    budget: int = SOURCE_BUDGET_CHARS,
) -> dict:
    """Choose the pages that will be sent, and say which they were.

    Returns {"pages", "used_pages", "skipped_front_matter", "requested"}.
    """
    rng = random.Random(seed) if seed is not None else None
    working = list(pages)
    if page_range is not None:
        low, high = page_range
        working = [p for p in working if low <= int(p.get("page", 0)) <= high]
        if not working:
            raise ExtractError(f"no text found on PDF pages {low}-{high}")

    content, skipped = strip_front_matter(working)
    used = _sample_pages(content, budget=budget, rng=rng)
    return {
        "pages": used,
        "used_pages": [int(p.get("page", 0)) for p in used],
        "skipped_front_matter": skipped,
        "requested": f"{page_range[0]}-{page_range[1]}" if page_range else "",
    }


# -------------------------------------------------------- document-question filter

# A question is about the document, not the subject, when it points at the
# document itself ("this textbook", "the preface", "who are the authors") or at
# publication paperwork ("all rights reserved", "ISBN"). Bare topic words are
# deliberately not enough: a law quiz may ask about a licence, a literature quiz
# about the author, an IT quiz about an edition.
_DOC_NOUN = (
    r"(?:book|textbook|text\s*book|document|pdf|file|handout|worksheet|"
    r"reader|manual|edition|volume|presentation|slide\s*deck)"
)

_DOCUMENT_QUESTION_PATTERNS = [
    re.compile(r"\b(?:this|the)\s+" + _DOC_NOUN + r"\b", re.IGNORECASE),
    re.compile(r"\b(?:table of contents|preface|foreword|front matter|"
               r"copyright page|title page|cover page|back cover)\b", re.IGNORECASE),
    re.compile(r"\bwho\s+(?:wrote|authored|is the author|are the authors|"
               r"are the contributors)\b", re.IGNORECASE),
    re.compile(r"\bsenior\s+contributing\s+authors?\b", re.IGNORECASE),
    re.compile(r"\bcontributing\s+authors?\b", re.IGNORECASE),
    re.compile(r"\b(?:isbn|issn)\b", re.IGNORECASE),
    re.compile(r"\ball rights reserved\b", re.IGNORECASE),
    re.compile(r"\bcopyright\s*(?:©|\(c\)|\d{4})\b", re.IGNORECASE),
    re.compile(r"\b(?:licensed|released|distributed)\s+under\b", re.IGNORECASE),
    re.compile(r"\bunder\s+(?:what|which)\b[^.?]{0,40}\blicen[cs]e\b", re.IGNORECASE),
    re.compile(r"\blicen[cs]e\b[^.?]{0,30}\b(?:this|the)\s+" + _DOC_NOUN + r"\b",
               re.IGNORECASE),
    re.compile(r"\b(?:who|which)\b[^.?]{0,30}\bpublish(?:ed|er)\b[^.?]{0,20}"
               r"\b(?:this|the)\s+" + _DOC_NOUN + r"\b", re.IGNORECASE),
    re.compile(r"\b(?:this|the)\s+" + _DOC_NOUN + r"\b[^.?]{0,30}\bpublish(?:ed|er)\b",
               re.IGNORECASE),
    re.compile(r"\bedition\s+of\s+(?:this|the)\s+" + _DOC_NOUN + r"\b", re.IGNORECASE),
    re.compile(r"\b(?:which|what)\s+edition\s+is\s+this\b", re.IGNORECASE),
    re.compile(r"\btitle\s+of\s+(?:this|the)\s+(?:book|textbook|document|chapter|section)\b",
               re.IGNORECASE),
    re.compile(r"\bhow many\s+(?:pages|chapters|sections|volumes)\b", re.IGNORECASE),
    re.compile(r"\baccording to the\s+(?:preface|foreword|table of contents|"
               r"copyright page)\b", re.IGNORECASE),
    re.compile(r"\baccess for free\b", re.IGNORECASE),
    re.compile(r"\b(?:front|back)\s+cover\b", re.IGNORECASE),
    re.compile(r"\bcitation format\b", re.IGNORECASE),
]


def is_document_question(question: dict) -> bool:
    """True when the question is about the file rather than what it teaches."""
    # Choices are excluded on purpose: an option may legitimately be the word
    # "author" or "licence" without the question being about the document.
    text = " ".join([
        str(question.get("question", "")),
        str(question.get("explanation", "")),
    ])
    return any(pattern.search(text) for pattern in _DOCUMENT_QUESTION_PATTERNS)


def filter_document_questions(questions: list[dict]) -> list[dict]:
    return [q for q in questions if not is_document_question(q)]


def _enough(questions: list[dict], count: int, final: bool = False) -> bool:
    need = max(3, count // 2) if final else max(5, int(count * 0.6 + 0.999))
    return len(questions) >= need


# ------------------------------------------------------------ offline questions

STOPWORDS = set("""
a about above after again against all also am an and any are aren't as at be
because been before being below between both but by can cannot could couldn't
did didn't do does doesn't doing don't down during each few for from further
had hadn't has hasn't have haven't having he her here hers herself him himself
his how however i if in into is isn't it its itself just let's like me more
most mustn't my myself no nor not of off on once only or other ought our ours
ourselves out over own same shan't she should shouldn't so some such than that
the their theirs them themselves then there these they this those through to
too under until up very was wasn't we were weren't what when where which while
who whom why will with won't would wouldn't you your yours yourself yourselves
also may might must shall upon within without among across per via etc
this these those such other another each every either neither
""".split())

_SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+")
_WORD = re.compile(r"[A-Za-z][A-Za-z\-']{3,}")


def _sentences(text: str) -> list[str]:
    flat = re.sub(r"\s+", " ", text)
    return [s.strip() for s in _SENTENCE_SPLIT.split(flat) if s.strip()]


_NOISE_PATTERNS = [
    r"https?://", r"doi\.org", r"\bet al\b", r"Proceedings of", r"ISBN",
    r"F-ITM", r"\bpp\.\s*\d", r"@\w+\.", r"____", r"\|", r"\bVol\.\s*\d",
    r"Approved by", r"\bFig\.\s*\d", r"\bTable\s*\d",
]


def _looks_like_noise(sentence: str) -> bool:
    """Citations, URLs, form fields, table rows: text that carries no knowledge."""
    low = sentence.lower()
    for pat in _NOISE_PATTERNS:
        if re.search(pat, sentence, re.IGNORECASE):
            return True
    letters = [c for c in sentence if c.isalpha()]
    if not letters:
        return True
    # a sentence that is mostly capital letters is a heading or a form, not prose
    caps = sum(1 for c in letters if c.isupper())
    if caps / len(letters) > 0.42:
        return True
    # digit-heavy sentences are usually tables, dates, or reference numbers
    digits = sum(1 for c in sentence if c.isdigit())
    if digits > max(6, len(sentence) * 0.10):
        return True
    # prose has verbs; fragments do not
    if not re.search(r"\b(is|are|was|were|has|have|had|can|means|refers|"
                     r"describes|includes|allows|requires|uses|causes|"
                     r"represents|defines|contains|provides)\b", low):
        return True
    return False


def _key_terms(sentence: str) -> list[str]:
    """Words worth blanking out: long, not stopwords, and inside the sentence."""
    out = []
    for m in _WORD.finditer(sentence):
        w = m.group(0)
        low = w.lower()
        if low in STOPWORDS:
            continue
        if low.endswith("ing") and len(low) < 7:
            continue
        # prefer terms that appear with a capital letter mid-sentence, or that
        # are simply long enough to carry meaning
        if len(w) >= 5:
            out.append(w)
    return out


def offline_questions(pages: list[dict], count: int = 10, seed: int = 0) -> list[dict]:
    """Conservative definition MCQs; never invent missing facts or hide words.

    This fallback only handles explicit definitions. A shorter honest quiz is
    preferable to random vocabulary blanks or an answer leaked in its stem.
    """
    rng = random.Random(seed)
    definitions = []
    seen = set()
    for page in pages:
        # Preserve glossary line boundaries before splitting prose sentences.
        for line in str(page.get("text", "")).splitlines():
            for sentence in _sentences(line):
                if not 20 <= len(sentence) <= 500 or _looks_like_noise(sentence):
                    # Glossary entries with a colon may have no copula.
                    if not 20 <= len(sentence) <= 500 or ":" not in sentence:
                        continue
                match = re.match(r"^(?:A |An |The )?([A-Za-z][A-Za-z '-]{1,65}?)\s*(?::|\bis defined as\b|\brefers to\b|\bmeans\b|\bis\b|\bare\b)\s+(.+?)[.!]?$", sentence, re.I)
                if not match:
                    continue
                term, definition = match.groups()
                term, definition = term.strip(), definition.strip().rstrip(".")
                if len(term.split()) > 6 or len(definition.split()) < 5:
                    continue
                if re.search(r"\b" + re.escape(term) + r"\b", definition, re.I):
                    continue  # e.g. 'Solution: ... is a solution ...'
                if re.search(r"https?://|ISBN|copyright|_{2,}|-{3,}",sentence,re.I):
                    continue
                key = _choice_key(term)
                if key in seen:
                    continue
                seen.add(key)
                definitions.append((term,definition,sentence,int(page.get("page",0))))
    rng.shuffle(definitions)
    out = []
    for answer, definition, quote, page in definitions:
        # Terms occurring in the description would make conspicuous distractors.
        distractors = [t for t,d,_,_ in definitions if _choice_key(t) != _choice_key(answer)
                       and _choice_key(d) != _choice_key(definition)
                       and not re.search(r"\b"+re.escape(t)+r"\b",definition,re.I)]
        rng.shuffle(distractors)
        if len(distractors) < 3 or page < 1:
            continue
        choices = distractors[:3] + [answer]
        rng.shuffle(choices)
        out.append({"id":f"q{len(out)+1}",
                    "question":f"Which term matches this description: {definition}?",
                    "choices":choices,"answer":choices.index(answer),
                    "explanation":f"The reviewer defines {answer} as {definition}.",
                    "source_quote":quote,"page":page})
        if len(out) >= count:
            break
    return _clean_questions({"questions":out})


# ------------------------------------------------------------------ ai prompts

QUESTION_SCHEMA_HINT = """Return ONLY JSON, no prose, no code fences, in exactly this shape:
{
  "title": "short title for this reviewer, max 6 words",
  "questions": [
    {
      "question": "the question text",
      "choices": ["first", "second", "third", "fourth"],
      "answer": 0,
      "explanation": "one sentence on why this is correct",
      "source_quote": "the sentence from the source this came from",
      "page": 40
    }
  ]
}
Rules:
- Write direct, self-contained multiple-choice questions, not fill-in-the-blank tasks.
- Never include underscores, dashed blanks, "fill in the blank", or unfinished stems.
- Do not reveal the correct term in a definition question or repeat its answer in the stem.
- exactly 4 distinct, plausible choices of comparable type, exactly one correct.
- Avoid synonymous choices that could both be correct, and avoid "none of the above".
- Include a substantive explanation supported by an exact source_quote from the cited page.
- If evidence is insufficient, return fewer questions; never invent facts to reach the count.
- "answer" is the 0-based index of the correct choice.
- "page" is the PDF page number shown in the [[page N]] marker where the answer appears.
- questions must be answerable ONLY from the source text.
- no duplicate questions, no "all of the above", no trick wording.
- use the source's own terminology.
"""

TEACHING_RULES = """What to test:
- the subject being taught: concepts, definitions, formulas, procedures, and worked examples.
- understanding, not recall of wording: apply a rule, predict a result, choose the correct
  definition, or identify the next step in a procedure.
- prefer questions a student who understood the material could answer without having
  memorised the page.
What NOT to test (these are about the document, never the subject):
- the title, authors, contributors, publisher, licence, copyright, ISBN, or edition;
- the preface, foreword, table of contents, chapter list, or page layout;
- how to access, buy, cite, or use the book;
- anything whose answer is a fact about the file rather than about the subject.
"""

STRONG_RULES = """IMPORTANT: earlier output failed quality checks. Avoid blanks, leaked answers, unsupported claims, and questions about the document instead of its subject.
Ignore every page that describes the book itself. Write only questions whose answer
is a fact about the subject being taught. If the supplied text is publication
boilerplate, write nothing rather than asking about it.
"""


def build_prompt(pages: list[dict], count: int, strong: bool = False) -> str:
    """Build the prompt from whole pages, each tagged with its PDF page number."""
    blocks = []
    for page in pages:
        text = str(page.get("text", "")).strip()
        if not text:
            continue
        blocks.append(f"[[page {int(page.get('page', 0))}]]\n{text}")
    source = "\n\n".join(blocks)[:SOURCE_BUDGET_CHARS + 2000]
    if not source:
        source = "(This file has no text layer. Read the attached page images.)"

    prompt = (
        "You are writing a quiz for a student revising from their own course material.\n"
        f"Write {count} multiple-choice questions about the subject taught in the source below.\n"
        f"{TEACHING_RULES}\n"
    )
    if strong:
        prompt += STRONG_RULES + "\n"
    prompt += (
        f"{QUESTION_SCHEMA_HINT}\n"
        f"--- SOURCE MATERIAL (page markers are PDF page numbers) ---\n{source}\n"
        "--- END SOURCE ---"
    )
    return prompt



# -------------------------------------------------------------- ai: gemini/openai

# Diagnostics for the server log. Each provider call appends one entry: the
# HTTP status, the raw reply, and how many questions survived cleaning. The
# request handler clears this at the start and prints it afterwards, so a
# failure can be diagnosed from the server window alone.
LAST_CALLS: list[dict] = []


def reset_calls() -> None:
    LAST_CALLS.clear()


def _note(key: str, value) -> None:
    if LAST_CALLS:
        LAST_CALLS[-1][key] = value


# Model choice lives in the environment so a capstone demo can be moved to a
# different model without editing code. The defaults are the current stable
# (non-preview) models from Google's model list; the fallback is a smaller
# stable model that is less likely to be hit by capacity spikes.
DEFAULT_GEMINI_MODEL = "gemini-3.6-flash"
DEFAULT_GEMINI_FALLBACK_MODEL = "gemini-3.5-flash-lite"

# Temporary provider trouble: try again before giving up on the request.
RETRY_STATUSES = {429, 500, 503}
RETRY_ATTEMPTS = 3          # first try plus two retries
RETRY_BACKOFF_SECONDS = (1.0, 2.0)   # short: a student is waiting


def gemini_models() -> list[str]:
    """Primary model, then the optional fallback, without duplicates."""
    primary = os.environ.get("QF_GEMINI_MODEL", DEFAULT_GEMINI_MODEL).strip()
    fallback = os.environ.get(
        "QF_GEMINI_FALLBACK_MODEL", DEFAULT_GEMINI_FALLBACK_MODEL
    ).strip()
    chain = [primary or DEFAULT_GEMINI_MODEL]
    if fallback and fallback != chain[0]:
        chain.append(fallback)
    return chain


def _post_json(url: str, payload: dict, headers: dict, timeout: int = 120) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", "replace")
            LAST_CALLS.append({"status": resp.status, "raw": raw, "error": ""})
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        retryable = e.code in RETRY_STATUSES
        LAST_CALLS.append({"status": e.code, "raw": detail[:6000],
                           "error": f"HTTP {e.code}: {detail[:300]}",
                           "retryable": retryable})
        raise ProviderError(f"HTTP {e.code}: {detail[:400]}",
                            status=e.code, retryable=retryable) from e
    except urllib.error.URLError as e:
        # A dropped connection or timeout is also worth one more try.
        LAST_CALLS.append({"status": 0, "raw": "", "error": f"network: {e.reason}",
                           "retryable": True})
        raise ProviderError(f"network: {e.reason}", retryable=True) from e
    except json.JSONDecodeError as e:
        LAST_CALLS.append({"status": 200, "raw": raw[:6000],
                           "error": f"invalid JSON: {e}"})
        raise ProviderError(f"invalid JSON from the model: {e}") from e



def _parse_questions(raw: str) -> dict:
    """LLMs wrap JSON in fences and chatter. Dig the object out anyway."""
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```[a-zA-Z]*\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    start, end = cleaned.find("{"), cleaned.rfind("}")
    if start == -1 or end == -1:
        if LAST_CALLS:
            LAST_CALLS[-1]["error"] = "no JSON object in the reply"
        raise ProviderError("model returned no JSON object")
    text = cleaned[start:end + 1]

    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        # Models occasionally emit a bare "\u" or a raw control character.
        # Repair those two shapes before giving up on an otherwise good reply.
        repaired = re.sub(r"\\u(?![0-9a-fA-F]{4})", r"\\\\u", text)
        repaired = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", repaired)
        try:
            data = json.loads(repaired)
        except json.JSONDecodeError as e:
            if LAST_CALLS:
                LAST_CALLS[-1]["error"] = f"unreadable JSON: {e}"
            raise ProviderError(f"model returned unreadable JSON: {e}") from e

    questions = data.get("questions")
    if not isinstance(questions, list) or not questions:
        if LAST_CALLS:
            LAST_CALLS[-1]["error"] = "reply contained no questions"
            LAST_CALLS[-1]["raw"] = raw[:6000]
        raise ProviderError("model returned no questions")
    return data



def _choice_key(text: str) -> str:
    return re.sub(r"[\W_]+", "", text.casefold())


def _ground_questions(questions: list[dict], pages: list[dict]) -> list[dict]:
    """Verify page/quote support where a text layer is available.

    An exact quote is evidence of provenance, not proof of semantic correctness.
    Image-only pages still need human review because their quotes cannot be
    checked against an extracted text layer.
    """
    sources = {int(p.get("page",0)): str(p.get("text", "")) for p in pages}
    out = []
    for q in questions:
        if q["page"] not in sources:
            continue
        text = sources[q["page"]]
        normal = lambda t: re.sub(r"\s+", " ", t).strip().casefold()
        if text.strip() and normal(q["source_quote"]) not in normal(text):
            continue
        out.append(q)
    return out


def _clean_questions(data: dict) -> list[dict]:
    """Drop anything malformed. Models pad, duplicate, and miscount."""
    out, seen = [], set()
    for item in data.get("questions", []):
        if not isinstance(item, dict):
            continue
        q = str(item.get("question", "")).strip()
        choices = item.get("choices")
        answer = item.get("answer")
        if not q or not isinstance(choices, list) or len(choices) != 4:
            continue
        if not all(isinstance(c,str) for c in choices):
            continue
        choices = [c.strip() for c in choices]
        if any(not c for c in choices) or len({_choice_key(c) for c in choices}) != 4:
            continue
        if type(answer) is not int or not 0 <= answer <= 3:
            continue
        if re.search(r"fill\s+in\s+(?:the\s+)?blank|_{2,}|[-–—]{3,}|\.{4,}",q,re.I):
            continue
        if any(_choice_key(c) in {"alloftheabove","noneoftheabove","alltheabove","nonetheabove"} for c in choices):
            continue
        correct = choices[answer]
        if len(correct) >= 4 and re.search(r"which\s+(?:term|concept|word|process)|what\s+(?:term|concept)",q,re.I) and re.search(r"\b"+re.escape(correct)+r"\b",q,re.I):
            continue
        explanation = item.get("explanation", "")
        quote = item.get("source_quote", "")
        if not isinstance(explanation,str) or not explanation.strip() or not isinstance(quote,str) or not quote.strip():
            continue
        key = re.sub(r"\W+", "", q.lower())
        if key in seen:
            continue
        try:
            page = int(item.get("page"))
        except (TypeError, ValueError):
            page = None
        if page is None or page < 1:
            continue
        seen.add(key)
        out.append({
            "id": f"q{len(out) + 1}",
            "question": q,
            "choices": choices,
            "answer": answer,
            "explanation": str(item.get("explanation", "")).strip(),
            "source_quote": str(item.get("source_quote", "")).strip(),
            "page": page,
        })
    return out


def gemini_questions(
    pages: list[dict],
    count: int = 10,
    images: list[bytes] | None = None,
    strong: bool = False,
) -> dict:
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key:
        raise ProviderError("GEMINI_API_KEY is not set")

    parts = [{"text": build_prompt(pages, count, strong=strong)}]
    for png in images or []:
        parts.append({
            "inline_data": {
                "mime_type": "image/png",
                "data": base64.b64encode(png).decode("ascii"),
            }
        })
    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseMimeType": "application/json", "temperature": 0.4},
    }

    # 503 UNAVAILABLE and friends are usually gone within seconds. Retry the
    # model a couple of times, then try the configured fallback model before
    # letting the caller degrade to the offline generator.
    last_error: ProviderError | None = None
    models = gemini_models()
    for model_index, model in enumerate(models):
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:generateContent?key={key}"
        )
        for attempt in range(1, RETRY_ATTEMPTS + 1):
            try:
                resp = _post_json(url, payload, {"Content-Type": "application/json"})
                _note("model", model)
                _note("attempt", attempt)
                try:
                    candidate = resp["candidates"][0]
                    raw = candidate["content"]["parts"][0]["text"]
                except (KeyError, IndexError) as e:
                    _note("error", f"unexpected response shape: {str(resp)[:300]}")
                    raise ProviderError(
                        f"unexpected response shape: {str(resp)[:300]}"
                    ) from e
                _note("finish", candidate.get("finishReason", ""))
                _note("model_text", raw[:6000])
                data = _parse_questions(raw)
                clean = _ground_questions(_clean_questions(data), pages)
                _note("parsed", len(data.get("questions", []) or []))
                _note("cleaned", len(clean))
                return {"title": data.get("title", ""), "questions": clean}
            except ProviderError as e:
                last_error = e
                _note("model", model)
                _note("attempt", attempt)
                if not getattr(e, "retryable", False):
                    raise
                if attempt < RETRY_ATTEMPTS:
                    delay = RETRY_BACKOFF_SECONDS[
                        min(attempt - 1, len(RETRY_BACKOFF_SECONDS) - 1)
                    ]
                    time.sleep(delay)

        # Switch models only for the documented temporary capacity outage.
        # Rate limits, internal errors, and network failures finish with the
        # offline fallback instead of silently multiplying provider requests.
        if model_index + 1 < len(models):
            unavailable = last_error is not None and (
                last_error.status == 503 or "UNAVAILABLE" in str(last_error).upper()
            )
            if model_index == 0 and unavailable:
                continue
            break

    raise last_error or ProviderError("no Gemini model configured")


def openai_questions(
    pages: list[dict],
    count: int = 10,
    images: list[bytes] | None = None,
    strong: bool = False,
) -> dict:
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        raise ProviderError("OPENAI_API_KEY is not set")
    model = os.environ.get("QF_OPENAI_MODEL", "gpt-4o-mini")
    url = "https://api.openai.com/v1/chat/completions"

    content = [{"type": "text", "text": build_prompt(pages, count, strong=strong)}]
    for png in images or []:
        b64 = base64.b64encode(png).decode("ascii")
        content.append({
            "type": "image_url",
            "image_url": {"url": f"data:image/png;base64,{b64}"},
        })
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": content}],
        "response_format": {"type": "json_object"},
        "temperature": 0.4,
    }
    resp = _post_json(url, payload, {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {key}",
    })
    try:
        raw = resp["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as e:
        _note("error", f"unexpected response shape: {str(resp)[:300]}")
        raise ProviderError(f"unexpected response shape: {str(resp)[:300]}") from e
    _note("model_text", raw[:6000])
    data = _parse_questions(raw)
    clean = _ground_questions(_clean_questions(data), pages)
    _note("parsed", len(data.get("questions", []) or []))
    _note("cleaned", len(clean))
    return {"title": data.get("title", ""), "questions": clean}


PROVIDERS = {
    "gemini": gemini_questions,
    "openai": openai_questions,
}


def ai_questions(
    extracted: dict,
    path: str,
    count: int = 10,
    provider: str = "gemini",
    strong: bool = False,
) -> dict:
    """Vision-aware AI generation: text goes up as text, scans go up as images."""
    if provider not in PROVIDERS:
        raise ProviderError(f"unknown provider: {provider}")

    images = []
    for page_no in extracted["pending_images"][:6]:
        try:
            if os.path.splitext(path)[1].lower() == ".pdf":
                images.append(render_page_png(path, page_no))
            else:
                images.append(read_image_png(path))
        except Exception:
            continue  # a page we cannot render is a page we skip, not a crash

    return PROVIDERS[provider](
        extracted["pages"], count=count, images=images, strong=strong
    )


def _used_or_all(selection: dict, extracted: dict) -> list[dict]:
    """Scanned files have no text to sample, so the pages stay as they are."""
    used = selection["pages"]
    if extracted["method"] == "vision" and not any(p["text"] for p in used):
        return extracted["pages"]
    return used


def ai_generate(
    extracted: dict,
    path: str,
    count: int = 10,
    provider: str = "gemini",
    page_range: tuple[int, int] | None = None,
    seed: int = 0,
) -> dict:
    """Select content, ask the AI, drop document questions, retry once stronger."""
    if provider not in PROVIDERS:
        raise ProviderError(f"unknown provider: {provider}")

    selection = select_pages(extracted["pages"], page_range, seed=seed)
    used = _used_or_all(selection, extracted)

    result = ai_questions(
        {"pages": used, "pending_images": extracted["pending_images"]},
        path, count=count, provider=provider,
    )
    questions = filter_document_questions(result["questions"])

    if not _enough(questions, count):
        # Different pages, stricter instructions: the first pass read something
        # that looked like front matter or drifted into document trivia.
        retry = select_pages(extracted["pages"], page_range, seed=seed + 7919)
        retry_used = _used_or_all(retry, extracted)
        retry_result = ai_questions(
            {"pages": retry_used, "pending_images": extracted["pending_images"]},
            path, count=count, provider=provider, strong=True,
        )
        retry_questions = filter_document_questions(retry_result["questions"])
        if len(retry_questions) >= len(questions):
            selection, used = retry, retry_used
            result, questions = retry_result, retry_questions

    if not _enough(questions, count, final=True):
        raise QualityError(
            "Too few questions passed the wording and source-quality checks. "
            "Try again, or enter a PDF page range so it reads course content."
        )

    return {
        "title": result.get("title", ""),
        "questions": questions,
        "used_pages": [int(p.get("page", 0)) for p in used],
        "skipped_front_matter": selection["skipped_front_matter"],
        "requested": selection["requested"],
    }


def offline_generate(
    extracted: dict,
    count: int = 10,
    page_range: tuple[int, int] | None = None,
    seed: int = 0,
) -> dict:
    selection = select_pages(extracted["pages"], page_range, seed=seed)
    used = _used_or_all(selection, extracted)
    questions = filter_document_questions(
        offline_questions(used, count=count, seed=seed)
    )
    return {
        "title": "",
        "questions": questions,
        "used_pages": [int(p.get("page", 0)) for p in used],
        "skipped_front_matter": selection["skipped_front_matter"],
        "requested": selection["requested"],
    }


def _resample(pages: list[dict], rng: random.Random, avoid: set[int]) -> list[dict]:
    """A different slice of the same reviewer, for Regenerate."""
    candidates = [p for p in pages if str(p.get("text", "")).strip()]
    if not candidates:
        return []
    fresh = [p for p in candidates if int(p.get("page", 0)) not in avoid]
    pool = fresh if len(fresh) >= 3 else candidates

    take = max(1, int(len(pool) * 0.65 + 0.999))
    if take >= len(candidates) and len(candidates) > 3:
        take = max(1, len(candidates) - 1)
    chosen = rng.sample(pool, min(take, len(pool)))
    return sorted(chosen, key=lambda p: int(p.get("page", 0)))


def regenerate_questions(
    pages: list[dict],
    count: int = 10,
    provider: str = "gemini",
    seed: int = 0,
    avoid: list[int] | None = None,
) -> dict:
    """Write a fresh set from a different part of the same extracted text."""
    avoid_set = set(avoid or [])
    rng = random.Random(seed)
    subset = _resample(pages, rng, avoid_set)
    if not subset:
        raise ExtractError("no text left to regenerate from")

    if provider == "offline":
        questions = filter_document_questions(
            offline_questions(subset, count=count, seed=seed)
        )
        return {
            "title": "", "provider": "offline", "questions": questions,
            "used_pages": [int(p.get("page", 0)) for p in subset],
        }

    result = ai_questions({"pages": subset, "pending_images": []},
                          "", count=count, provider=provider)
    questions = filter_document_questions(result["questions"])

    if not _enough(questions, count):
        retry_avoid = avoid_set | {int(p.get("page", 0)) for p in subset}
        retry_subset = _resample(pages, random.Random(seed + 7919), retry_avoid)
        if retry_subset:
            retry_result = ai_questions({"pages": retry_subset, "pending_images": []},
                                        "", count=count, provider=provider, strong=True)
            retry_questions = filter_document_questions(retry_result["questions"])
            if len(retry_questions) >= len(questions):
                subset, result, questions = retry_subset, retry_result, retry_questions

    if not _enough(questions, count, final=True):
        raise QualityError(
            "Too few questions passed the wording and source-quality checks. "
            "Try Regenerate again, or upload the file with a page range."
        )

    return {
        "title": result.get("title", ""),
        "provider": provider,
        "questions": questions,
        "used_pages": [int(p.get("page", 0)) for p in subset],
    }


# ----------------------------------------------------------------------- facade


def build(
    path: str,
    count: int = 10,
    provider: str = "offline",
    seed: int = 0,
    page_range: tuple[int, int] | None = None,
) -> dict:
    """The one function the server and the CLI both call."""
    extracted = extract(path)

    notes = []
    if provider == "offline":
        result = offline_generate(extracted, count=count, page_range=page_range, seed=seed)
        if extracted["pending_images"]:
            notes.append(
                f"pages {extracted['pending_images']} have no text layer; "
                "they need an AI provider to be read"
            )
    else:
        result = ai_generate(extracted, path, count=count, provider=provider,
                             page_range=page_range, seed=seed)

    used_pages = result.get("used_pages", [])
    used_text = [
        p for p in extracted["pages"] if int(p.get("page", 0)) in set(used_pages)
    ]
    title = result.get("title") or os.path.splitext(extracted["file"])[0][:60]

    return {
        "source": {
            "file": extracted["file"],
            "pages": len(extracted["pages"]),
            "used_pages": used_pages,
            "page_range": result.get("requested", ""),
            "skipped_front_matter": result.get("skipped_front_matter", []),
            "chars": sum(len(p["text"]) for p in used_text),
            "method": extracted["method"],
            "pending_images": extracted["pending_images"],
            "provider": provider,
        },
        "title": title,
        "pages": used_text,
        "questions": result["questions"],
        "notes": notes,
    }

