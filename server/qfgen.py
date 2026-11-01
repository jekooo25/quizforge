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
import urllib.error
import urllib.request

# Minimum characters on a page before we trust its text layer. Below this the
# page is almost certainly a scan, and has to go to a vision model instead.
TEXT_LAYER_MIN_CHARS = 60

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif"}
TEXT_EXTS = {".txt", ".md", ".csv", ".json"}


# --------------------------------------------------------------------- errors


class ExtractError(Exception):
    """The file could not be turned into text at all."""


class ProviderError(Exception):
    """The AI call failed, or no key is configured."""


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
    """Rule-based multiple choice: blank out a key word, borrow distractors.

    Ugly next to an LLM, but it needs no key, no network, and always runs.
    This is the fallback the app uses when the AI is unreachable.
    """
    rng = random.Random(seed)

    # build a pool of sentences that actually carry content
    candidates = []
    for page in pages:
        for s in _sentences(page["text"]):
            if 70 <= len(s) <= 260 and _key_terms(s) and not _looks_like_noise(s):
                candidates.append((s, page["page"]))
    if len(candidates) < 4:
        return []

    # every distinct term in the document becomes a distractor source
    vocab = []
    seen_vocab = set()
    for s, _ in candidates:
        for t in _key_terms(s):
            if t.lower() not in seen_vocab:
                seen_vocab.add(t.lower())
                vocab.append(t)

    rng.shuffle(candidates)
    questions = []
    used_terms = set()

    for sentence, page_no in candidates:
        if len(questions) >= count:
            break
        terms = [t for t in _key_terms(sentence) if t.lower() not in used_terms]
        if not terms:
            continue
        # longest term is usually the most meaningful one
        answer = max(terms, key=len)
        low = answer.lower()

        pool = [
            t for t in vocab
            if t.lower() != low
            and t.lower() not in {a.lower() for a in [answer]}
            and abs(len(t) - len(answer)) <= max(3, len(answer) // 2)
        ]
        rng.shuffle(pool)
        distractors = []
        for t in pool:
            if t.lower() in {d.lower() for d in distractors}:
                continue
            if t.lower() in sentence.lower():  # it would appear in the visible text
                continue
            distractors.append(t)
            if len(distractors) == 3:
                break
        if len(distractors) < 3:
            continue

        blanked = re.sub(rf"\b{re.escape(answer)}\b", "_____", sentence, count=1)
        choices = distractors + [answer]
        rng.shuffle(choices)

        used_terms.add(low)
        questions.append({
            "id": f"q{len(questions) + 1}",
            "question": f"Fill in the blank: {blanked}",
            "choices": choices,
            "answer": choices.index(answer),
            "explanation": f"The passage names {answer} here.",
            "source_quote": sentence,
            "page": page_no,
        })

    return questions


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
      "source_quote": "the sentence from the source this came from"
    }
  ]
}
Rules:
- exactly 4 choices per question, exactly one correct.
- "answer" is the 0-based index of the correct choice.
- questions must be answerable ONLY from the source text.
- no duplicate questions, no "all of the above", no trick wording.
- use the source's own terminology.
"""


def build_prompt(text: str, count: int) -> str:
    trimmed = text[:24000]
    return (
        f"You are writing a quiz for a student revising from their own notes.\n"
        f"Write {count} multiple-choice questions from the source material below.\n"
        f"{QUESTION_SCHEMA_HINT}\n"
        f"--- SOURCE MATERIAL ---\n{trimmed}\n--- END SOURCE ---"
    )


# -------------------------------------------------------------- ai: gemini/openai


def _post_json(url: str, payload: dict, headers: dict, timeout: int = 120) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:400]
        raise ProviderError(f"HTTP {e.code}: {detail}") from e
    except urllib.error.URLError as e:
        raise ProviderError(f"network: {e.reason}") from e


def _parse_questions(raw: str) -> dict:
    """LLMs wrap JSON in fences and chatter. Dig the object out anyway."""
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```[a-zA-Z]*\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    start, end = cleaned.find("{"), cleaned.rfind("}")
    if start == -1 or end == -1:
        raise ProviderError("model returned no JSON object")
    data = json.loads(cleaned[start:end + 1])
    questions = data.get("questions")
    if not isinstance(questions, list) or not questions:
        raise ProviderError("model returned no questions")
    return data


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
        choices = [str(c).strip() for c in choices]
        if any(not c for c in choices) or len(set(choices)) != 4:
            continue
        if not isinstance(answer, int) or not 0 <= answer <= 3:
            continue
        key = re.sub(r"\W+", "", q.lower())
        if key in seen:
            continue
        seen.add(key)
        out.append({
            "id": f"q{len(out) + 1}",
            "question": q,
            "choices": choices,
            "answer": answer,
            "explanation": str(item.get("explanation", "")).strip(),
            "source_quote": str(item.get("source_quote", "")).strip(),
        })
    return out


def gemini_questions(pages: list[dict], count: int = 10, images: list[bytes] | None = None) -> dict:
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key:
        raise ProviderError("GEMINI_API_KEY is not set")
    model = os.environ.get("QF_GEMINI_MODEL", "gemini-2.5-flash")
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent?key={key}"
    )

    parts = [{"text": build_prompt(all_text({"pages": pages}), count)}]
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
    resp = _post_json(url, payload, {"Content-Type": "application/json"})
    try:
        raw = resp["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as e:
        raise ProviderError(f"unexpected response shape: {str(resp)[:300]}") from e
    data = _parse_questions(raw)
    return {"title": data.get("title", ""), "questions": _clean_questions(data)}


def openai_questions(pages: list[dict], count: int = 10, images: list[bytes] | None = None) -> dict:
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        raise ProviderError("OPENAI_API_KEY is not set")
    model = os.environ.get("QF_OPENAI_MODEL", "gpt-4o-mini")
    url = "https://api.openai.com/v1/chat/completions"

    content = [{"type": "text", "text": build_prompt(all_text({"pages": pages}), count)}]
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
        raise ProviderError(f"unexpected response shape: {str(resp)[:300]}") from e
    data = _parse_questions(raw)
    return {"title": data.get("title", ""), "questions": _clean_questions(data)}


PROVIDERS = {
    "gemini": gemini_questions,
    "openai": openai_questions,
}


def ai_questions(extracted: dict, path: str, count: int = 10, provider: str = "gemini") -> dict:
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

    return PROVIDERS[provider](extracted["pages"], count=count, images=images)


# ----------------------------------------------------------------------- facade


def build(path: str, count: int = 10, provider: str = "offline", seed: int = 0) -> dict:
    """The one function the server and the CLI both call."""
    extracted = extract(path)

    notes = []
    if provider == "offline":
        questions = offline_questions(extracted["pages"], count=count, seed=seed)
        if extracted["pending_images"]:
            notes.append(
                f"pages {extracted['pending_images']} have no text layer; "
                "they need an AI provider to be read"
            )
        title = os.path.splitext(extracted["file"])[0][:60]
    else:
        result = ai_questions(extracted, path, count=count, provider=provider)
        questions = result["questions"]
        title = result.get("title") or os.path.splitext(extracted["file"])[0][:60]

    return {
        "source": {
            "file": extracted["file"],
            "pages": len(extracted["pages"]),
            "chars": len(all_text(extracted)),
            "method": extracted["method"],
            "pending_images": extracted["pending_images"],
            "provider": provider,
        },
        "title": title,
        "pages": extracted["pages"],
        "questions": questions,
        "notes": notes,
    }
